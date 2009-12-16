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

#import <MLFoundation/MLWorkerAcceptor.h>

#import <MLFoundation/MLCore/MLCategories.h>
#import <MLFoundation/MLCore/MLAssert.h>
#import <MLFoundation/MLCore/MLIdioms.h>
#import <MLFoundation/MLCore/MLLogger.h>
#import <MLFoundation/MLCore/MLFoundationErrors.h>
#import <MLFoundation/MLMultiWorkerApplication.h>

#import <MLFoundation/MLConnection.h>

#import <portability/normalized_networking.h>
#import <portability/normalized_msg.h>

@implementation MLWorkerAcceptor
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

- (void)setDelegate:(id<MLAcceptorDelegate>)delegate
{
	delegate_ = delegate;
}

- (id <MLAcceptorDelegate>)delegate
{
	return delegate_;
}

// Сюда приходит от родителя запакованный сокет, либо команда graceful
- (void)loop:(EVLoop *)loop ioWatcher:(EVIoWatcher *)w eventOccured:(int)event
{
	// Stolen from
	// http://lists.canonical.org/pipermail/kragen-hacks/2002-January/000292.html
	
	struct msghdr msg;
	struct iovec iov;
	uint8_t buf[256];
	int rv;
	char ccmsg[CMSG_SPACE(sizeof(int))];
	struct cmsghdr *cmsg;

	iov.iov_base = buf;
	iov.iov_len = sizeof(buf);
	
	memset(buf, 0, sizeof(buf));

	msg.msg_name = 0;
	msg.msg_namelen = 0;
	msg.msg_iov = &iov;
	msg.msg_iovlen = 1;
	/* old BSD implementations should use msg_accrights instead of 
	* msg_control; the interface is different. */
	msg.msg_control = ccmsg;
	msg.msg_controllen = sizeof(ccmsg); /* ? seems to work... */

	rv = recvmsg([ioWatcher_ fd], &msg, 0);
	if (rv <= 0) {
		NSError *error = nil;
		if (rv < 0) {
			int err = ev_last_error();
			if (err == EINTR || err == EWOULDBLOCK || 
				err == EAGAIN || err == EINPROGRESS) return;

			error = [NSError errorWithDomain:MLFoundationErrorDomain
				code: MLSocketAcceptError
				localizedDescriptionFormat: @"Failed to recvmsg() from ctrl socket: %s",
				strerror(err)];
		} else {
			error = [NSError errorWithDomain:MLFoundationErrorDomain
				code: MLSocketAcceptError
				localizedDescriptionFormat: @"Socket pair teardown"];
		}

		[self stop];	
		close([ioWatcher_ fd]);
		[ioWatcher_ setFd:0];

		[delegate_ acceptor:self error:error];
		return;
	}
	if (rv == 0) {
	}
	
	// Сначала пытаемся принять сокет, пришедший от мастера
	cmsg = CMSG_FIRSTHDR(&msg);
	if (cmsg) {
		if (!cmsg->cmsg_type == SCM_RIGHTS) {
			MLLog(LOG_ERROR, "ERROR: Unknown control message received at worker's socket: %d",
				cmsg->cmsg_type);
			return;
		}
		if (cmsg->cmsg_len == CMSG_LEN(sizeof(int))) {
			int connfd = *(int *)CMSG_DATA(cmsg);
			[self acceptNewConnection:connfd];
		}
	}
	
	// Теперь начинаем проверять ключевые сообщения
	if (!strcmp("graceful", (char *)buf)) {
		// Мы здесь смело уверены в том, что sharedApplication нам вернет по меньшей мере MultiWorkerApplication,
		// потому что текущий класс занимается общением экземпляров этого класса. 
		MLMultiWorkerApplication *app = (MLMultiWorkerApplication *)[MLApplication sharedApplication];
		[app gracefulInChild];
	}

	if (!strcmp("logrotate", (char *)buf)) {
		[MLLogger rotate];
	}
}

- (void)acceptNewConnection:(int)connfd
{
	struct sockaddr_in clientAddr;
	memset(&clientAddr, 0, sizeof(clientAddr));
	socklen_t clientLen = sizeof(clientAddr);

	MLConnection *conn = [[MLConnection alloc] init];

	getpeername(connfd, (struct sockaddr *)&clientAddr, &clientLen);
	if ([conn respondsToSelector:@selector(setDescription:)]) {
		[conn setDescription:[NSString stringWithFormat:@"%s:%d", 
			inet_ntoa(clientAddr.sin_addr), ntohs(clientAddr.sin_port)]];
	}

	[conn setLoop:loop_];
	[conn setFd:connfd];

	if (!conn) {
		NSError *error = [NSError errorWithDomain:MLFoundationErrorDomain
			code: MLSocketListenError
			localizedDescriptionFormat: @"Error while allocating connection"];

		[self stop];	
		close([ioWatcher_ fd]);
		[ioWatcher_ setFd:0];

		[delegate_ acceptor:self error:error];
		return;
	}

	[delegate_ acceptor:self receivedConnection:conn];

	[(NSObject *)conn release];
	
}

- (void)updateConnectionCount:(uint32_t)connectionCount
{
	char buf[32];
	memset(buf,0,sizeof(buf));
	snprintf(buf, 31, "%d", connectionCount); 

	struct msghdr msg;
	struct iovec vec;  
	memset(&msg, 0, sizeof(msg));

	vec.iov_base = buf;
	vec.iov_len = sizeof(buf);
	msg.msg_iov = &vec;
	msg.msg_iovlen = 1;

	if (sendmsg([ioWatcher_ fd], &msg, 0) < 0) {
		MLLog(LOG_INFO, "ERROR: Failed to send status to master: %s", strerror(errno));
	};
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

- (double)fitness
{
	return 1.0;
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
