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

#import <MLFoundation/MLTCPClientConnection.h>

#import <MLFoundation/MLCore/MLCategories.h>
#import <MLFoundation/MLCore/MLFoundationErrors.h>
#import <MLFoundation/MLCore/MLAssert.h>
#include <fcntl.h>

#import <MLFoundation/EVBindings/EVLoop.h>

@interface MLTCPClientConnection (private)
- (void)prepareSocket;
@end

@implementation MLTCPClientConnection
+ (void)load
{
	initMLCategories();
}

- init
{
	if (!(self = [super init])) return nil;

	addr_.sin_family = AF_INET;
	addr_.sin_port = 0;
	addr_.sin_addr.s_addr = INADDR_ANY;
	memset(addr_.sin_zero, '\0', sizeof(addr_.sin_zero));

	return self;
}

- (void)setHost:(NSString *)host
{
	if (host == host_) return;

	[host_ release];
	host_ = [host retain];

	const char *string = NULL;
	if (host) string = [host UTF8String];

	if (!string || !inet_aton(string, &(addr_.sin_addr))) {
		addr_.sin_addr.s_addr = INADDR_ANY;
	}
}

- (NSString *)host
{
	return [NSString stringWithCString:inet_ntoa(addr_.sin_addr)];
}

- (void)setPort:(uint16_t)port
{
	port_ = port;
	addr_.sin_port = htons(port);
}

- (uint16_t)port
{
	return ntohs(addr_.sin_port);
}

- (BOOL)validateForStart:(NSError **)error
{
	MLAssert(loop_);

	if ([self port] <= 0 || addr_.sin_addr.s_addr == INADDR_ANY) {
		if (error) *error = [NSError errorWithDomain:MLFoundationErrorDomain
			code: MLSocketConnectError
			localizedDescriptionFormat:@"Invalid address %@:%d", host_, port_];

		return NO;
	}

	return YES;
}

- (void)start
{
	if ([self isStarted]) return;

	NSError *error = nil;
	
	NSSocketNativeHandle fd = socket(PF_INET, SOCK_STREAM, 0);
	if (fd == -1) {
		error = [NSError errorWithDomain:MLFoundationErrorDomain
			code: MLSocketOpenError
			localizedDescriptionFormat: @"Unable to create socket: %s",
			strerror(ev_last_error())];

		[self stop];
		[[(id)delegate_ async] error:error onEvent:self];
		return;
	}

	int yes = 1;
	if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes)) < 0) {
		error = [NSError errorWithDomain:MLFoundationErrorDomain
			code: MLSocketOpenError
			localizedDescriptionFormat: @"Unable to setsockopt SOL_SOCKET: %s",
			strerror(ev_last_error())];

		[self stop];
		[[(id)delegate_ async] error:error onEvent:self];

		close(fd);
		return;
	}

	if (!ev_set_nonblock(fd)) {
		error = [NSError errorWithDomain:MLFoundationErrorDomain
			code: MLSocketOpenError
			localizedDescriptionFormat: @"Unable to make socket non-blocking: %s",
			strerror(ev_last_error())];

		[self stop];
		[[(id)delegate_ async] error:error onEvent:self];

		close(fd);
		return;
	}

	if (connect(fd, (struct sockaddr *)&addr_, sizeof(addr_)) < 0) {
		int lasterr = ev_last_error();
		if (lasterr != EWOULDBLOCK &&
			lasterr != EAGAIN &&
			lasterr != EINPROGRESS &&
			lasterr != EINTR) {

			error = [NSError errorWithDomain:MLFoundationErrorDomain
				code: MLSocketOpenError
				localizedDescriptionFormat: @"Unable to make connect(): %s",
				strerror(lasterr)];

			[self stop];
			[[(id)delegate_ async] error:error onEvent:self];

			close(fd);
			return;
		}
	}

#ifdef WIN32
	fd = _open_osfhandle(fd, O_RDWR);
#endif
	[self setFd:fd];
	[super start];
}

- (void)stop
{
	if (![self isStarted]) return;
	[super stop];

	if ([self fd] > 0) {
		shutdown([self fd], SHUT_RDWR);
		close([self fd]);
		[self setFd:0];
	}
}

- (void)dealloc
{
	[host_ release];
	[super dealloc];
}
@end
