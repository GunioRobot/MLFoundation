/*
 Copyright 2009 undev
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import <MLFoundation/MLHTTPClient.h>

#import <MLFoundation/MLCore/MLIdioms.h>
#import <MLFoundation/MLCore/MLAssert.h>
#import <MLFoundation/MLCore/MLFoundationErrors.h>
#import <MLFoundation/MLCore/MLCategories.h>

#import <MLFoundation/MLStreamFastAccess.h>
#import <MLFoundation/MLStreamFunctions.h>

enum {
	MLHTTPClientSendingRequest = 1,
	MLHTTPClientNoStatus = 2,
	MLHTTPClientStatusReceived = 3,
	MLHTTPClientHeadersReceived = 4
};

@interface MLHTTPClient (private)
- (BOOL)start;
- (void)stop;
@end

@implementation MLHTTPClient
- init
{
	if (!(self = [super init])) return nil;

	conn_ = [[MLTCPClientConnection alloc] init];
	MLReleaseSelfAndReturnNilUnless(conn_);
	[conn_ setDelegate:self];
	
	return self;
}

- (void)setDelegate:(id<MLHTTPClientDelegate>)delegate
{
	delegate_ = delegate;
}

- (id<MLHTTPClientDelegate>)delegate
{
	return delegate_;
}

- (void)setLoop:(EVLoop *)loop
{
	[conn_ setLoop:loop];
}

- (EVLoop *)loop
{
	return [conn_ loop];
}

- (void)setTimeout:(ev_tstamp)timeout
{
	MLAssert(!isStarted_);
	[conn_ setReadTimeout: timeout];
}

- (ev_tstamp)timeout
{
	return [conn_ readTimeout];
}

- (void)setWriteTimeout:(ev_tstamp)timeout
{
	MLAssert(!isStarted_);
	[conn_ setWriteTimeout: timeout];
}

- (ev_tstamp)writeTimeout
{
	return [conn_ writeTimeout];
}

- (NSDictionary *)currentResponseHeaders
{
	MLAssert(state_ >= MLHTTPClientHeadersReceived);
	return [NSDictionary dictionary];
}

- (NSUInteger)currentResponseStatus
{
	MLAssert(state_ >= MLHTTPClientHeadersReceived);
	return status_;
}

- (NSUInteger)currentResponseProtocolVersion
{
	MLAssert(state_ >= MLHTTPClientHeadersReceived);
	return 11;	
}

- (NSString *)currentResponseReason
{
	MLAssert(state_ >= MLHTTPClientHeadersReceived);
	return @"";	
}

- (uint64_t)currentResponseContentLength
{
	return contentLength_;
}

- (void)sendRequestWithMethod:(NSString *)method url:(NSURL *)url 
		headers:(NSDictionary *)headers
{
	// TODO check headers...
	[self beginSendRequestWithMethod:method url:url headers:headers];
	if (!isStarted_) return;
	[self finishSendRequest];
}

- (void)sendRequestWithMethod:(NSString *)method url:(NSURL *)url
	headers:(NSDictionary *)headers data:(uint8_t *)data length:(NSUInteger)length
{
	// TODO check headers...
	[self beginSendRequestWithMethod:method url:url headers:headers];
	if (!isStarted_) return;
	MLStreamAppendBytes(conn_, data, length);
	[self finishSendRequest];
}


- (void)beginSendRequestWithMethod:(NSString *)method url:(NSURL *)url
	headers:(NSDictionary *)headers
{
	MLAssert(!isStarted_);

	// TODO check headers...

	[url_ release];
	url_ = [url retain];

	[requestHeaders_ release];
	requestHeaders_ = [headers retain];

	[method_ release];
	method_ = [method retain];

	[self start];
}

- (void)finishSendRequest
{
	MLAssert(isStarted_);
	MLAssert(state_ == MLHTTPClientSendingRequest);
	
	state_ = MLHTTPClientNoStatus;

	[conn_ rescheduleRead];
}

- (void)setReadSize:(NSUInteger)readSize
{
	[conn_ setReadSize:readSize];
}

- (NSUInteger)readSize
{
	return [conn_ readSize];
}

- (BOOL)start
{
	if (isStarted_) return YES;

	[conn_ setHost:[url_ host]];
	[conn_ setPort:([url_ port] ? [[url_ port] unsignedIntValue] : 80)];

	NSError *e;
	if (![conn_ validateForStart:&e]) {
		[delegate_ httpClient:self failedWithError:e];
		return NO;
	}


	state_ = MLHTTPClientSendingRequest;

	NSString *urlString;
	if ([url_ query]) {
		urlString = [NSString stringWithFormat:@"%@?%@", [url_ path], [url_ query]];
	} else {
		urlString = [NSString stringWithFormat:@"%@", [url_ path]];
	}


	static char requestBuffer[4096];

	sprintf(requestBuffer, "%s %s HTTP/1.0\nConnection: close\n\n", 
		[method_ UTF8String], [urlString UTF8String]);		

	MLStreamAppendString(conn_, requestBuffer);	

	status_ = 0;
	contentLength_ = 0;

	isStarted_ = YES;

	[conn_ start];

	return YES;
}

- (void)stop
{
	if (!isStarted_) return;
	[conn_ stop];
	isStarted_ = NO;
}

- (void)cancelCurrentRequest
{
	[self stop];
	[conn_ dropAfterFork]; //XXX
}

- (BOOL)isStarted
{
	return isStarted_;
}

- (void)timeout:(int)what onEvent:(id<MLBufferedEvent>)stream
{
	[self stop];

	NSError *e = [NSError errorWithDomain:MLFoundationErrorDomain
		code: MLSocketTimeoutError
		localizedDescriptionFormat:@"Read timeout on TCP socket."];
	
	[delegate_ httpClient:self failedWithError:e];
}

- (void)error:(NSError *)details onEvent:(id<MLBufferedEvent>)stream
{
	[self stop];

	if ((NSErrorCode(details) == MLSocketEOFError) && 
		(contentLength_ == 0 || MLStreamLength(conn_) == contentLength_)) {
		[delegate_ httpClient:self 
			finishedLoadingBuffer:conn_];
	} else {
		[delegate_ httpClient:self failedWithError:details];
	}
}

- (void)dataAvailableOnEvent:(id <MLBufferedEvent>)stream
{
	char *str, *s;
	int strl;

	switch (state_) {
		case MLHTTPClientSendingRequest:
			return;
		case MLHTTPClientNoStatus:
			if ((str = MLStreamReadLine(stream))) {
				s = strchr(str, ' ');
				if (s) status_ = strtol(s + 1, NULL, 10);
				if (status_ < 100 || status_ > 505) {
					[self stop];

					NSError *e = [NSError errorWithDomain:MLFoundationErrorDomain
						code: MLSocketHTTPError
						localizedDescriptionFormat:@"Invalid HTTP response."];
					[delegate_ httpClient:self failedWithError:e];

					return;
				}
				MLStreamDrainLine(stream);
				state_ = MLHTTPClientHeadersReceived;
			} else {
				break;
			}
		case MLHTTPClientStatusReceived:
			while ((str = MLStreamReadLine(stream))) {
				strl = strlen(str);

				// "Content-Length: " len is 16
				// :-(
				if (!contentLength_ && strl > 0 && 
					!(strncmp(str, "Content-Length: ", MIN(strl, 16)))) {
						contentLength_ = strtoull(str + 16, NULL, 10);
				}
				MLStreamDrainLine(stream);
				if (!strl) {
					state_ = MLHTTPClientHeadersReceived;
					[stream rescheduleRead];

					if (contentLength_ > 0) {
						MLLog(LOG_DEBUG, "DEBUG: MLHttpClient reserving %lld bytes in buffer according to Content-Length", contentLength_);
						[stream reservePlaceInInputBuffer:contentLength_ + 32];
					}

					[delegate_ httpClient:self receivedResponseWithBody:YES];
					// TODO определять, есть ли body на самом деле.
					return; 
				}
			}
			break;
		case MLHTTPClientHeadersReceived:
			[delegate_ httpClient:self haveNewDataInBuffer:conn_];
			break;
		default:
			MLFail("Unknown HTTP Client state!");
	}
}

- (void)writtenToEvent:(id<MLBufferedEvent>)stream
{
  // No-op
}

- (id <MLStream>)requestStream
{
	return isStarted_ ? (id<MLStream>)conn_ : nil;
}

- (void)dealloc
{
	if (isStarted_) [self stop];

	[method_ release];
	[requestHeaders_ release];
	[url_ release];
	[conn_ flushAndRelease];

	[super dealloc];
}
@end
