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

#import <MLFoundation/MLTCPAcceptor.h>

#import <MLFoundation/MLCore/MLFoundationErrors.h>
#import <MLFoundation/MLCore/MLCategories.h>
#import <MLFoundation/MLCore/MLAssert.h>
#import <MLFoundation/MLCore/MLIdioms.h>

#import <MLFoundation/MLConnection.h>

#include <unistd.h>
#include <fcntl.h>

@interface MLTCPAcceptor(private)
- (void)loop:(EVLoop *)loop ioWatcher:(EVIoWatcher *)w eventOccured:(int)event;
@end

@implementation MLTCPAcceptor
- init
{
	if (!(self = [super init])) return nil;

	acceptWatcher_ = [[EVIoWatcher alloc] init];
	MLReleaseSelfAndReturnNilUnless(acceptWatcher_);
	[acceptWatcher_ setTarget:self selector:@selector(loop:ioWatcher:eventOccured:)];
	[acceptWatcher_ setEvents:EV_READ];
	[acceptWatcher_ setPriority:EV_MAXPRI];
	[acceptWatcher_ setFd: 0];

	bindError_ = nil;
	port_ = 0;

	return self;
}

- (void)setDelegate:(id <MLAcceptorDelegate>)delegate
{
	delegate_ = delegate;
}

- (id <MLAcceptorDelegate>)delegate
{
	return delegate_;
}

- (BOOL)isStarted
{
	return [acceptWatcher_ isActive];
}

- (void)start
{
	if ([acceptWatcher_ isActive]) return;

	MLAssert(loop_);
	MLAssert([acceptWatcher_ fd]);

	[self startWatcher:acceptWatcher_];
}

- (void)stop
{
	if (![acceptWatcher_ isActive]) return;

	[self stopWatcher:acceptWatcher_];
}


- (void)setPort:(uint16_t)port
{
	MLAssert(![acceptWatcher_ isActive]);

	[bindError_ release];
	if ([acceptWatcher_ fd] > 0) {
		shutdown([acceptWatcher_ fd], SHUT_RDWR);
		close([acceptWatcher_ fd]);
		[acceptWatcher_ setFd:0];
	}

	port_ = 0;
	bindError_ = nil;

	int fd;
	struct sockaddr_in server;
	socklen_t flags;

	fd = socket(AF_INET, SOCK_STREAM, 0);
	if (fd < 0) {
		bindError_ = [[NSError alloc] initWithDomain:MLFoundationErrorDomain
			code:MLSocketOpenError 
			localizedDescriptionFormat:@"Failed to create socket : %s",
			strerror(ev_last_error())];
		return;
	}

	flags = 1;
	if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &flags, sizeof(int)) == -1) {
		bindError_ = [[NSError alloc] initWithDomain:MLFoundationErrorDomain
			code:MLSocketOpenError 
			localizedDescriptionFormat:@"Failed to SO_REUSEADDR : %s",
			strerror(ev_last_error())];

		close(fd);
		return;
	}

	server.sin_family = AF_INET;
	server.sin_addr.s_addr = INADDR_ANY;
	server.sin_port = htons(port);

	if (bind(fd, (struct sockaddr *)&server, sizeof(server))) {
		bindError_ = [[NSError alloc] initWithDomain:MLFoundationErrorDomain
			code:MLSocketBindError 
			localizedDescriptionFormat:@"Failed to bind to port %d : %s",
			port, strerror(ev_last_error())];

		close(fd);
		return;
	}

	if (!ev_set_nonblock(fd)) {
		bindError_ = [[NSError alloc] initWithDomain:MLFoundationErrorDomain
			code:MLSocketOpenError 
			localizedDescriptionFormat:@"Failed to make socket non-blocking: %s",
			strerror(ev_last_error())];

		close(fd);
		return;
	}

	if (listen(fd, 511) < 0) {
		bindError_ = [[NSError alloc] initWithDomain:MLFoundationErrorDomain
			code:MLSocketListenError 
			localizedDescriptionFormat:@"Failed to listen(): %s",
			strerror(ev_last_error())];

		close(fd);
		return;
	}

#ifdef WIN32
	fd = _open_osfhandle(fd, O_RDWR);
#endif
	[acceptWatcher_ setFd:fd];
	
	socklen_t addr_len = sizeof(server);
	getsockname(fd, (struct sockaddr *)&server, (socklen_t *)&addr_len);
	
	port_ = ntohs(server.sin_port);
}

- (uint16_t)port
{
	return port_;
}

- (void)loop:(EVLoop *)loop ioWatcher:(EVIoWatcher *)w eventOccured:(int)event
{
	NSError *error;
	NSSocketNativeHandle clientFd;
	struct sockaddr_in clientAddr;
	socklen_t clientLen = sizeof(clientAddr);

	NSSocketNativeHandle fd = ((struct ev_io *)w)->fd;
#ifdef WIN32
	fd = _get_osfhandle(fd);
#endif	

	clientFd = accept(fd, (struct sockaddr *)&clientAddr, &clientLen);
	BOOL nonblockResult = NO;
	if (clientFd >=0) nonblockResult = ev_set_nonblock(clientFd);

	if (clientFd == -1 || !nonblockResult) {
		int err = ev_last_error();
		if (err == EINTR || err == EWOULDBLOCK || 
			err == EAGAIN || err == EINPROGRESS) return;

		error = [NSError errorWithDomain:MLFoundationErrorDomain
			code: MLSocketAcceptError
			localizedDescriptionFormat: @"Error while accept()ing: %s",
			strerror(err)];

		if (clientFd >= 0) close(clientFd);

		[self stop];	
		[delegate_ acceptor:self error:error];
		return;
	}

	MLConnection *conn = [[MLConnection alloc] init];
	[conn setLoop:loop_];
#ifdef WIN32
	clientFd = _open_osfhandle(clientFd, O_RDWR);
#endif	
	[conn setFd:clientFd];

	if (!conn) {
		error = [NSError errorWithDomain:MLFoundationErrorDomain
			code: MLSocketListenError
			localizedDescriptionFormat: @"Error while allocating connection"];

		[self stop];	
		[delegate_ acceptor:self error:error];
		return;
	}

	if ([conn respondsToSelector:@selector(setDescription:)]) {
		[conn setDescription:[NSString stringWithFormat:@"%s:%d", 
			inet_ntoa(clientAddr.sin_addr), ntohs(clientAddr.sin_port)]];
	}
	[delegate_ acceptor:self receivedConnection:conn];

	[(NSObject *)conn release];
}

- (BOOL)validateForStart:(NSError **)error
{
	[super validateForStart:(NSError **)nil]; // Мы знаем, что там только ассерты.

	if (bindError_) {
		if (error) *error = [[bindError_ copy] autorelease]; 
		return NO;
	} else {
		return YES;
	}
}

- (void)dropAfterFork
{
	[self stop];
	if ([acceptWatcher_ fd] > 0) {
		close([acceptWatcher_ fd]);
		[acceptWatcher_ setFd: 0];
	}
}

- (int)fd
{
	return [acceptWatcher_ fd];
}

- (void)dealloc
{
	[self stop];

	[bindError_ release];
	if ([acceptWatcher_ fd] > 0) {
		shutdown([acceptWatcher_ fd], SHUT_RDWR);
		close([acceptWatcher_ fd]);
	}

	[acceptWatcher_ release];

	[super dealloc];
}
@end
