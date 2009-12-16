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

#import <MLFoundation/MLHTTPServerConnection.h>

#import <MLFoundation/MLCore/MLFoundationErrors.h>
#import <MLFoundation/MLCore/MLCategories.h>
#import <MLFoundation/MLCore/MLAssert.h>
#import <MLFoundation/MLCore/MLIdioms.h>

#import <MLFoundation/MLStreamFastAccess.h>
#import <MLFoundation/MLStreamFunctions.h>

enum {
	MLHTTPServerConnectionWaitingRequest = 1,
	MLHTTPServerConnectionPathReceived = 3,
	MLHTTPServerConnectionHeadersReceived = 4,
	MLHTTPServerConnectionBodyReceived = 5,
	MLHTTPServerConnectionSendingResponse = 6,
};

@implementation MLHTTPServerConnection
- (id)init
{
	if (!(self = [super init])) return nil;

	currentRequestHeaders_ = [NSMutableDictionary new];
	MLReleaseSelfAndReturnNilUnless(currentRequestHeaders_);

	responseProtocol_ = [@"HTTP" retain];

	return self;
}

- (void)setResponseProtocol:(NSString *)string
{
	if (string == responseProtocol_) return;
	[responseProtocol_ release];
	responseProtocol_ = [string retain];
}

- (void)setConnection:(MLConnection *)connection
{
	if (connection_ != connection) {
		[connection_ release];
		connection_ = [connection retain];
	}
	[connection_ setDelegate:self];
}

- (MLConnection *)connection
{
	return connection_;
}

- (void)setDelegate:(id<MLHTTPServerConnectionDelegate>)delegate
{
	delegate_ = delegate;
}

- (id<MLHTTPServerConnectionDelegate>)delegate
{
	return delegate_;
}

- (void)setWriteTimeout:(ev_tstamp)timeout
{
	if ([connection_ isStarted]) {
		[connection_ stop];
		[connection_ setWriteTimeout: timeout];
		[connection_ start];
	} else {
		[connection_ setWriteTimeout: timeout];
	}
}

- (ev_tstamp)writeTimeout
{
	return [connection_ writeTimeout];
}

- (void)setTimeout:(ev_tstamp)timeout
{
	if ([connection_ isStarted]) {
		[connection_ stop];
		[connection_ setReadTimeout: timeout];
		[connection_ start];
	} else {
		[connection_ setReadTimeout: timeout];
	}
}

- (ev_tstamp)timeout
{
	return [connection_ readTimeout];
}

- (void)sendResponseWithStatus:(NSUInteger)status reason:(NSString *)reason
	headers:(NSDictionary *)headers
{
	MLAssert(state_ >= MLHTTPServerConnectionHeadersReceived);

	// TODO check headers...
	[self beginSendResponseWithStatus:status reason:reason headers:headers];
	[self finishSendResponse];
}

- (void)sendResponseWithStatus:(NSUInteger)status reason:(NSString *)reason
	headers:(NSDictionary *)headers data:(uint8_t *)data length:(NSUInteger)length
{
	MLAssert(state_ >= MLHTTPServerConnectionHeadersReceived);

	// TODO check headers;
	// TODO optimize em
	NSMutableDictionary *newHeaders = [NSMutableDictionary dictionary];
	if (headers) {
		[newHeaders addEntriesFromDictionary:headers];
	}
	[newHeaders setObject:[NSNumber numberWithInt:length] forKey:@"Content-Length"];
	[self beginSendResponseWithStatus:status reason:reason headers:newHeaders];
	MLStreamAppendBytes(connection_, data, length);
	[self finishSendResponse];
}

- (void)beginSendResponseWithStatus:(NSUInteger)status reason:(NSString *)reason
	headers:(NSDictionary *)headers
{
	MLAssert(state_ >= MLHTTPServerConnectionHeadersReceived);

	// TODO check headers;
	// TODO optimize em
	static char buf[4096];

	sprintf(buf, "HTTP/1.1 %ld %s\r\n",
		(unsigned long) status, [reason UTF8String]);
	if (headers) {
		NSEnumerator *e = [headers keyEnumerator];
		id key;
		while ((key = [e nextObject])) {
			if (![key isEqualToString:@"Connection"])
				strcat(buf, ([[NSString stringWithFormat:@"%@: %@\r\n", key,
					[headers objectForKey:key]] UTF8String]));
		}
	}

	if (![headers objectForKey:@"Connection"]) {
		strcat(buf, "Connection: close\r\n");
	} else {
		strcat(buf, 
			([[NSString stringWithFormat:@"Connection: %@\r\n", [headers objectForKey:@"Connection"]] UTF8String])
		);
	}
	strcat(buf, "\r\n");
	MLStreamAppendString(connection_, buf);
	state_ = MLHTTPServerConnectionSendingResponse;
}

- (id <MLStream>)responseStream
{
	if (state_ == MLHTTPServerConnectionSendingResponse) {
		return connection_;
	} else {
		return nil;
	}
}

- (void)finishSendResponse
{
	MLAssert(state_ == MLHTTPServerConnectionSendingResponse);
	
	state_ = MLHTTPServerConnectionWaitingRequest;
	[currentRequestHeaders_ removeAllObjects];

	[connection_ rescheduleRead];
}

- (void)start
{
	if (!connection_) return;
	[currentRequestHeaders_ removeAllObjects];
	state_ = MLHTTPServerConnectionWaitingRequest;

	[connection_ start];
}

- (void)stop
{
	if (!connection_) return;
	[connection_ stop];
}

- (BOOL)isStarted
{
	return connection_ && [connection_ isStarted];
}

- (void)timeout:(int)what onEvent:(id <MLBufferedEvent>)stream
{
	[self stop];

	NSError *e = [NSError errorWithDomain:MLFoundationErrorDomain
		code: MLSocketTimeoutError
		localizedDescriptionFormat:@"Read timeout on TCP socket."];

	[self setDescription:[NSString stringWithFormat:@"<%@:%p> timed out %@", [self class], self, connection_]];
	[connection_ release];
	connection_ = nil;

	[delegate_ httpConnection:self closedWithError:e];
}

- (void)error:(NSError *)details onEvent:(id <MLBufferedEvent>)stream
{
	[self stop];

	[connection_ release];
	connection_ = nil;

	if (NSErrorCode(details) == MLSocketEOFError) {
		[delegate_ httpConnectionClosed:self];
	} else {
		[delegate_ httpConnection:self closedWithError:details];
	}
}

- (void)dataAvailableOnEvent:(id <MLBufferedEvent>)stream
{
	char *str = NULL, *s = NULL, *s2 = NULL;
	int strl;

	switch (state_) {
		case MLHTTPServerConnectionBodyReceived:
		case MLHTTPServerConnectionSendingResponse:
			return;
		case MLHTTPServerConnectionWaitingRequest:
			if ((str = MLStreamReadLine(stream))) {
				s = strchr(str, ' ');
				if (s) s++;
				if (s) s2 = strchr(s, ' ');
				if (s2) s2++;
				if (!s || !s2 || strncmp(s2, "HTTP/1", 6)) {
					[self stop];

					NSError *e = [NSError errorWithDomain:MLFoundationErrorDomain
						code: MLSocketHTTPError
						localizedDescriptionFormat:@"Invalid HTTP request."];
					[self stop];
					[connection_ release];
					connection_ = nil;
					[delegate_ httpConnection:self closedWithError:e];

					return;
				}
				MLStreamDrainLine(stream);
				path_ = [[NSString alloc] initWithBytes:s length:(s2-s-1) 
					encoding:NSASCIIStringEncoding];
				method_ = [[NSString alloc] initWithBytes:str length:(s-str-1) 
					encoding:NSASCIIStringEncoding];

				state_ = MLHTTPServerConnectionPathReceived;
			} else {
				break;
			}
		case MLHTTPServerConnectionPathReceived:
			while ((str = MLStreamReadLine(stream))) {
				strl = strlen(str);
				MLStreamDrainLine(stream);
				if (!strl) {

					NSString *contentLength = [currentRequestHeaders_ objectForKey:@"CONTENT-LENGTH"];
					if (contentLength) {
						contentLength_ = [contentLength intValue];
					}
					if (contentLength_ > 0) {
						state_ = MLHTTPServerConnectionHeadersReceived;
						[delegate_ httpConnection:self receivedRequestWithBody:YES];
					} else {
						state_ = MLHTTPServerConnectionBodyReceived;
						[delegate_ httpConnection:self receivedRequestWithBody:NO];
					}
					[stream rescheduleRead];
					return;
				} else {
					char *colon;
					if ((colon = strchr(str, ':')) && (strlen(colon) > 1)) {
						*colon = '\0';
						[currentRequestHeaders_ setObject:[NSString stringWithUTF8String:(colon+2)]
							forKey:[[NSString stringWithUTF8String:str] uppercaseString]];
						*colon = ':';
					}
				}
			}
			break;
		case MLHTTPServerConnectionHeadersReceived:
			{
				if (MLStreamLength(stream) >= contentLength_) {
					MLBuffer *buffer = [[MLBuffer alloc] initWithPreallocated:MLStreamData(stream) size:MLStreamLength(stream) capacity:MLStreamLength(stream)];
					state_ = MLHTTPServerConnectionBodyReceived;
					[delegate_ httpConnection:self haveNewDataInBuffer:buffer];
					[delegate_ httpConnection:self finishedLoadingBuffer:buffer];
					MLStreamDrain(stream, contentLength_);
				}
			}
			break;
		default:
			MLFail("Unknown HTTP Connection state!");
	}
}

- (void)writtenToEvent:(id <MLBufferedEvent>)stream
{
  // No-op
}


- (NSString *)currentRequestMethod
{
	return method_;
}

- (NSDictionary *)currentRequestHeaders
{
	return [NSDictionary dictionaryWithDictionary:currentRequestHeaders_];
}

- (NSString *)currentRequestPath
{
	return path_;
}

- (NSUInteger)currentRequestProtocolVersion
{
	return 11;
}

- (NSString *)remoteAddr
{
	return [connection_ description];
}

- (NSString *)description
{
	if (!description_)
		return [NSString stringWithFormat:@"<%@: %p> with %@", [self class], self, connection_];
	return description_;
}

- (void)setDescription:(NSString *)description
{
	if (description_ == description)
		return;
	[description_ release];
	description_ = [description retain];
}

- (void)dealloc
{
	[self stop];

	[path_ release];
	[currentRequestHeaders_ release];
	[method_ release];
	[connection_ flushAndRelease];
	[description_ release];
	[responseProtocol_ release];

	[super dealloc];
}
@end
