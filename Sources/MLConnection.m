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

#import <MLFoundation/MLConnection.h>

#import <MLFoundation/MLCore/MLFoundationErrors.h>
#import <MLFoundation/MLCore/MLCategories.h>

#ifdef WIN32
int readWinProxy(int fd, void * addr, int size)
{
	return recv(_get_osfhandle(fd), addr, size, 0);
}

int writeWinProxy(int fd, void * addr, int size)
{
	return send(_get_osfhandle(fd), addr, size, 0);
}
#endif

@implementation MLConnection 
+ (void)load
{
	// Я себя когда-нибудь за это прокляну
	// Но этот класс - место, где SIGPIPE вызовет 99% проблем
#ifndef WIN32
	signal(SIGPIPE, SIG_IGN);
#endif
}

+ (BOOL)newSocketpair:(MLConnection **)connections
{
	// Всё тело функции, кроме последней строчки не будет существовать
	// под виндой
#ifndef WIN32
	connections[0] = nil;
	connections[1] = nil;
	
	int sockets[2];

	if (socketpair(AF_UNIX, SOCK_STREAM, 0, sockets) < 0) {
		return NO;
	}

	if (!ev_set_nonblock(sockets[0])) {
		close(sockets[0]); close(sockets[1]);
		return NO;
	}

	if (!ev_set_nonblock(sockets[1])) {
		close(sockets[0]); close(sockets[1]);
		return NO;
	}

	connections[0] = [MLConnection new];
	if (!connections[0]) {
		close(sockets[0]); close(sockets[1]);
		return NO;
	}

	connections[1] = [MLConnection new];
	if (!connections[1]) {
		[connections[0] release]; connections[0] = nil;
		close(sockets[0]); close(sockets[1]);
		return NO;
	}

	[connections[0] setFd:sockets[0]];
	[connections[1] setFd:sockets[1]];
#endif

	return YES;
}

- init
{
	if (!(self = [super init])) return nil;	
	
#ifndef WIN32
	[self setReadFunction:(FILEFUNC_IMP)read];
	[self setWriteFunction:(FILEFUNC_IMP)write];
#else
	[self setReadFunction:(FILEFUNC_IMP)readWinProxy_];
	[self setWriteFunction:(FILEFUNC_IMP)writeWinProxy_];
#endif

	return self;
}

- (NSError *)readingError
{
	int lasterr = ev_last_error();
	if (lasterr != EAGAIN && lasterr != EWOULDBLOCK && 
		lasterr != EINPROGRESS && lasterr != EINTR) {
		return [NSError errorWithDomain:MLFoundationErrorDomain
			code: MLSocketReadError
			localizedDescriptionFormat: @"Error reading from socket: %s",
			strerror(lasterr)];

	}
	
	return nil;
}

- (NSError *)writingError
{
	int lasterr = ev_last_error();
	if (lasterr != EAGAIN && lasterr != EWOULDBLOCK && 
		lasterr != EINPROGRESS && lasterr != EINTR) {
		return [NSError errorWithDomain:MLFoundationErrorDomain
			code: MLSocketWriteError
			localizedDescriptionFormat: @"Error writing into socket: %s",
			strerror(lasterr)];
	}
	return nil;
}

- (uint16_t)port
{
	struct sockaddr_in addr;
	socklen_t len = sizeof(addr);
	getsockname([self fd], (struct sockaddr *)&addr, &len);
	return htons(addr.sin_port);
}

- (NSString *)description
{
	if (!description_) return [super description];
	return description_;
}

- (void)setDescription:(NSString *)description
{
	if (description_ == description) return;
	[description_ release];
	description_ = [description retain];
}

- (void)dropAfterFork
{
	[self stop];
	if ([self fd] > 0) close([self fd]);
	[self resetBuffers];
	[self setFd: 0];
}

- (void)dealloc
{
	[description_ release];

	[super dealloc];
}

@end
