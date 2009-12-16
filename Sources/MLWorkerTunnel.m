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

#import <MLFoundation/MLWorkerTunnel.h>

#import <MLFoundation/MLCore/MLIdioms.h>
#import <MLFoundation/MLCore/MLLogger.h>
#import <MLFoundation/MLCore/MLAssert.h>

#import <portability/normalized_networking.h>
#import <portability/normalized_msg.h>

@implementation MLWorkerTunnel
+ (BOOL)createWorkerTunnel:(MLWorkerTunnel **)tunnel andAcceptor:(MLWorkerAcceptor **)acceptor
{
	// First, clean pointers.
	tunnel[0] = nil; acceptor[0] = nil;

	// Create socketpair.
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

	tunnel[0] = [[MLWorkerTunnel alloc] initWithFd:sockets[0]];
	if (!tunnel[0]) {
		close(sockets[0]); close(sockets[1]);
		return NO;
	}

	acceptor[0] = [[MLWorkerAcceptor alloc] initWithFd:sockets[1]];
	if (!acceptor[0]) {
		[tunnel[0] release]; tunnel[0] = nil;
		close(sockets[0]); close(sockets[1]);
		return NO;
	}

	return YES;
}

- (id)initWithFd:(int)fd
{
	if (!(self = [super init])) return nil;

	ioWatcher_ = [[EVIoWatcher alloc] init];
	MLReleaseSelfAndReturnNilUnless(ioWatcher_);
	[ioWatcher_ setTarget:self selector:@selector(loop:ioWatcher:eventOccured:)];
	[ioWatcher_ setEvents:EV_READ];
	[ioWatcher_ setFd: fd];

	return self;
}


// Здесь происходит вытаскивание из воркера количества дочерних соединений
// по идее, именно сюда можно дописать ещё протокол общения ребенка с родителем
- (void)loop:(EVLoop *)loop ioWatcher:(EVIoWatcher *)w eventOccured:(int)event
{
	struct msghdr msg;
	struct iovec iov;
	char buf[32];

	memset(&msg, 0, sizeof(msg));
	memset(buf, 0, sizeof(buf));

	iov.iov_base = buf;
	iov.iov_len = sizeof(buf) - 1;

	msg.msg_iov = &iov;
	msg.msg_iovlen = 1;

	if (recvmsg([ioWatcher_ fd], &msg, 0) < 0) {
		int err = ev_last_error();
		if (err == EINTR || err == EWOULDBLOCK ||
			err == EAGAIN || err == EINPROGRESS) return;

		MLLog(LOG_INFO, "ERROR: Error while reading status from %@: %s", self, strerror(errno));
		return;
	}

	
	char *endPtr = NULL;
	uint32_t connCount = strtoul(buf, &endPtr, 10);
	if (buf[0] != '\0' && endPtr[0] == '\0') {
		connectionsCount_ = connCount;
		MLLog(LOG_VVVDEBUG, "%@: %d active connections", self, connectionsCount_);
	} else if (buf[0] != '\0') {
		MLLog(LOG_INFO, "ERROR: Error while parsing status from %@: %s", self, buf);
	}
}

- (void)sendMessage:(NSString *)message
{
	MLAssert([self isStarted]);

	struct msghdr msg;
	struct iovec vec;
	memset(&msg, 0, sizeof(msg));
	char buf[256];
	memset(buf, 0, sizeof(buf));
	if ([message lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > sizeof(buf) - 1) {
		MLLog(LOG_ERROR, "Trying to send through master-child channel too large message %@. 255 bytes is limit", message);
		return;
	}
	
	strncpy(buf, (char *)[message UTF8String], sizeof(buf) - 1);

	vec.iov_base = buf;
	vec.iov_len = sizeof(buf);
	msg.msg_iov = &vec;
	msg.msg_iovlen = 1;

	if (sendmsg([ioWatcher_ fd], &msg, 0) < 0) {
		MLLog(LOG_INFO, "ERROR: Failed to send graceful to child: %s", strerror(errno));
	};
	
}

// Отправка ребенку сообщения «прекрати принимать соединения и умри»
- (void)graceful
{
	[self sendMessage:@"graceful"];
}

- (void)logrotate
{
	[self sendMessage:@"logrotate"];
}


// Именно отсюда отправляется запакованный сокет в ребенка
- (void)passConnection:(id)connection
{
	MLAssert([connection isKindOfClass:[MLConnection class]]);
	MLAssert([self isStarted]);
	MLConnection *conn = (MLConnection *)connection;

	int fd = [conn fd];
	MLLog(LOG_VVVDEBUG, "%@ passing connection %@ // %d", self, conn, fd);

	// Stolen from
	// http://lists.canonical.org/pipermail/kragen-hacks/2002-January/000292.html

	struct msghdr msg;
	char ccmsg[CMSG_SPACE(sizeof(fd))];
	struct cmsghdr *cmsg;
	struct iovec vec;  /* stupidity: must send/receive at least one byte */
	char *str = "x";
	int rv;

	msg.msg_name = NULL;
	msg.msg_namelen = 0;

	vec.iov_base = str;
	vec.iov_len = 1;
	msg.msg_iov = &vec;
	msg.msg_iovlen = 1;

	/* old BSD implementations should use msg_accrights instead of 
	* msg_control; the interface is different. */
	msg.msg_control = ccmsg;
	msg.msg_controllen = sizeof(ccmsg);
	cmsg = CMSG_FIRSTHDR(&msg);
	cmsg->cmsg_level = SOL_SOCKET;
	cmsg->cmsg_type = SCM_RIGHTS;
	cmsg->cmsg_len = CMSG_LEN(sizeof(fd));
	*(int*)CMSG_DATA(cmsg) = fd;
	msg.msg_controllen = cmsg->cmsg_len;

	msg.msg_flags = 0;

	rv = (sendmsg([ioWatcher_ fd], &msg, 0) != -1);
	if (!rv) {
		MLLog(LOG_ERROR, "ERROR: Failed to pass fd to worker: %s", strerror(errno));
	}

	connectionsCount_++;

	MLLog(LOG_VVVDEBUG, "%@: %d active connections", self, connectionsCount_);

	[conn dropAfterFork]; // Hack and abuse :) FIXME
}

- (BOOL)validateForStart:(NSError **)error
{
	MLAssert([ioWatcher_ fd]);
	MLAssert(loop_);
	return YES;
}

- (void)start
{
	if ([ioWatcher_ isActive]) return;

	[self startWatcher:ioWatcher_];

	connectionsCount_ = 0;
}

- (void)stop
{
	[self stopWatcher:ioWatcher_];
}

- (BOOL)isStarted
{
	return [ioWatcher_ isActive];
}

- (void)dropAfterFork
{
	[self stop];
	close([ioWatcher_ fd]);
	[ioWatcher_ setFd:0];
}

- (double)business
{
	return (double)connectionsCount_;
}

- (void)dealloc
{
	[self stop];

	if ([ioWatcher_ fd] > 0) {
		MLLog(LOG_VVVDEBUG, "shutting down %@ of %d", self, [ioWatcher_ fd]);
		shutdown([ioWatcher_ fd], SHUT_RDWR);
		close([ioWatcher_ fd]);
	}

	[ioWatcher_ release];

	[super dealloc];
}
@end
