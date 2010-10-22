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

#import <MLFoundation/MLCore/MLIdioms.h>
#import <MLFoundation/MLCore/MLAssert.h>
#import <MLFoundation/MLCore/MLFoundationErrors.h>
#import <MLFoundation/MLCore/MLCategories.h>
#import <MLFoundation/MLCore/MLLogger.h>

#import <MLFoundation/MLStreamFastAccess.h>

// Судя по раскладке #define EV_... эти значения более или менее сейфны. Но их можно менять! :-)
#define EV_ASYNC_READ  0x10
#define EV_ASYNC_WRITE 0x20

#define MLCONN_OPEN(mlev) ((struct { @defs( MLConnection ) } *) mlev)

void MLConnectionQueueWrite(MLConnection *ev)
{
#if !__OBJC2__
	struct ev_io *io = (struct ev_io *)(MLCONN_OPEN(ev)->ioWatcher_);
	if ((!(io->events & EV_WRITE)) && ev_is_active((struct ev_watcher *)io)) {
		ev_io_stop((struct ev_loop *)(MLCONN_OPEN(ev)->loop_), io);
		io->events = EV_READ | EV_WRITE;
		ev_io_start((struct ev_loop *)(MLCONN_OPEN(ev)->loop_), io);
	}
#else
	struct ev_io *io = (struct ev_io *)(ev.ioWatcher);
	if ((!(io->events & EV_WRITE)) && ev_is_active((struct ev_watcher *)io)) {
		ev_io_stop((struct ev_loop *)(ev.loop), io);
		io->events = EV_READ | EV_WRITE;
		ev_io_start((struct ev_loop *)(ev.loop), io);
	}	
#endif
}

@interface MLConnection(private)
- (void)loop:(EVLoop *)loop ioWatcher:(EVIoWatcher *)w eventOccured:(int)event;
- (void)loop:(EVLoop *)loop timerWatcher:(EVTimerWatcher *)w eventOccured:(int)event;

- (void)resetBuffers;
@end

#define MIN_NONZERO(a,b) ( ((a)>0.0) ? (((b)>0.0) ? (((a)<(b))?(a):(b)) : (a) ): (b) )

@implementation MLConnection
#if __OBJC2__
@synthesize ioWatcher = ioWatcher_;
#endif
static NSError *ReadEofError() 
{
	static NSError *readEofError = NULL;
	if (!readEofError) readEofError = [[NSError alloc] initWithDomain:MLFoundationErrorDomain
									code: MLSocketEOFError
									localizedDescriptionFormat: @"EOF while reading from socket"];
	MLAssert(readEofError);
	return readEofError;
}

static NSError *WriteEofError() 
{
	static NSError *writeEofError = NULL;
	if (!writeEofError) writeEofError = [[NSError alloc] initWithDomain:MLFoundationErrorDomain
									code: MLSocketEOFError
									localizedDescriptionFormat: @"EOF while writing into socket"];
	MLAssert(writeEofError);
	return writeEofError;
}

static NSError *InputOverflowError() 
{
	static NSError *inputOverflowError = NULL;
	if (!inputOverflowError) inputOverflowError = 
				[[NSError alloc] initWithDomain:MLFoundationErrorDomain
				code: MLSocketBufferOverflowError
				localizedDescriptionFormat: @"Connection input buffer overflow"];

	MLAssert(inputOverflowError);
	return inputOverflowError;
}

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

	ioWatcher_ = [[EVIoWatcher alloc] init];
	MLReleaseSelfAndReturnNilUnless(ioWatcher_);
	[ioWatcher_ setTarget:self selector:@selector(loop:ioWatcher:eventOccured:)];
	[ioWatcher_ setEvents:EV_READ | EV_WRITE];
	[ioWatcher_ setFd: 0];

	timeoutWatcher_ = [[EVTimerWatcher alloc] init];
	MLReleaseSelfAndReturnNilUnless(timeoutWatcher_);
	[timeoutWatcher_ setTarget:self selector:@selector(loop:timerWatcher:eventOccured:)];

	inputBuffer_ = [[MLBuffer alloc] init];
	MLReleaseSelfAndReturnNilUnless(inputBuffer_);

	outputBuffer_ = [[MLBuffer alloc] init];
	MLReleaseSelfAndReturnNilUnless(outputBuffer_);

	delegate_ = nil;
	readTimeout_ = 0.0;
	writeTimeout_ = 0.0;
	lastRead_ = 0.0;
	lastWrite_ = 0.0;

	readSize_ = 4096;
	flushing_ = NO;

	writeCallBack_ = (WRITECB_IMP) MLConnectionQueueWrite;

	return self;
}

- (void)loop:(EVLoop *)loop ioWatcher:(EVIoWatcher *)w eventOccured:(int)event
{
	MLAssert(loop == loop_);
	MLAssert(w == ioWatcher_);

	NSError *error = nil;
	NSSocketNativeHandle fd = ((struct ev_io *)w)->fd;
	ev_tstamp now = ev_now((struct ev_loop *)loop_);
	NSUInteger write_len = MLBufferLength(outputBuffer_);

	if (event & EV_READ) {
		uint8_t *w_addr = MLBufferReserve(inputBuffer_, readSize_);
		if (!w_addr) {
			error = InputOverflowError();
		} else {
			int bytes_read;
#ifndef WIN32
			bytes_read = read(fd, w_addr, readSize_);
#else
			bytes_read = recv(_get_osfhandle(fd), w_addr, readSize_, 0);
#endif
			if (bytes_read < 0) {
				int lasterr = ev_last_error();
				if (lasterr != EAGAIN && lasterr != EWOULDBLOCK && 
					lasterr != EINPROGRESS && lasterr != EINTR) {
					error = [NSError errorWithDomain:MLFoundationErrorDomain
						code: MLSocketReadError
						localizedDescriptionFormat: @"Error reading from socket: %s",
						strerror(lasterr)];

				}
			} else if (bytes_read == 0) {
				error = ReadEofError();
			} else {
				MLBufferWritten(inputBuffer_, bytes_read);
			}
		}

		if (!error) {
			lastRead_ = now;
			event |= EV_ASYNC_READ;
		}
	}

	if ((event & EV_WRITE) && (!error)) {
		if (write_len) {
			uint8_t *r_addr = MLBufferData(outputBuffer_);
			MLAssert(r_addr);

			int bytes_written;
#ifndef WIN32
			bytes_written = write(fd, r_addr, write_len);
#else
			bytes_written = send(_get_osfhandle(fd), r_addr, write_len, 0);
#endif
			if (bytes_written < 0) {
				int lasterr = ev_last_error();
				if (lasterr != EAGAIN && lasterr != EWOULDBLOCK && 
					lasterr != EINPROGRESS && lasterr != EINTR) {
					error = [NSError errorWithDomain:MLFoundationErrorDomain
						code: MLSocketWriteError
						localizedDescriptionFormat: @"Error writing into socket: %s",
						strerror(lasterr)];
				}
			} else if (bytes_written == 0) {
				error = WriteEofError();
			} else {
				MLBufferDrain(outputBuffer_, bytes_written);
			}
		}

		if (!error) {
			lastWrite_ = now;	
			event |= EV_ASYNC_WRITE;
		}
	}

	event &= (EV_ASYNC_WRITE | EV_ASYNC_READ);

	if (!error && !event) return;

	if (error) {
		if (!flushing_) {
			[self stop];
			if (delegate_) [delegate_ error:error onEvent:self];
		} else {
			[self release];
		}
	} else {
		if ((event & EV_ASYNC_WRITE) && (MLBufferLength(outputBuffer_) <= 0)) {
			if (flushing_) {
				[self release];
				return;
			} else {
				struct ev_io *io = (struct ev_io *)(ioWatcher_);
				if (ev_is_active((struct ev_watcher *)io) && ((io->events & EV_WRITE))) {
					ev_io_stop((struct ev_loop *)(loop_), io);
					io->events = EV_READ;
					ev_io_start((struct ev_loop *)(loop_), io);
				}
			}
		}

		readCycle_ = !readCycle_;
		struct ev_watcher *io = (struct ev_watcher *)(ioWatcher_);

		if (readCycle_) {
			if (event & EV_ASYNC_READ) {
				event &= (0xffffffff ^ EV_ASYNC_READ);
				if (event) ev_feed_event(EVLOOP_LOOP(loop), io, event);
				if (delegate_) delegateNewData_(delegate_, @selector(dataAvailableOnEvent:), self);
				return;
			}
			if (event & EV_ASYNC_WRITE) {
				event &= (0xffffffff ^ EV_ASYNC_WRITE);
				if (event) ev_feed_event(EVLOOP_LOOP(loop), io, event);
				if (delegate_) delegateWritten_(delegate_, @selector(writtenToEvent:), self);
				return;
			}
		} else {
			if (event & EV_ASYNC_WRITE) {
				event &= (0xffffffff ^ EV_ASYNC_WRITE);
				if (event) ev_feed_event(EVLOOP_LOOP(loop), io, event);
				if (delegate_) delegateWritten_(delegate_, @selector(writtenToEvent:), self);
				return;
			}
			if (event & EV_ASYNC_READ) {
				event &= (0xffffffff ^ EV_ASYNC_READ);
				if (event) ev_feed_event(EVLOOP_LOOP(loop), io, event);
				if (delegate_) delegateNewData_(delegate_, @selector(dataAvailableOnEvent:), self);
				return;
			}
		}
	}
}

- (void)loop:(EVLoop *)loop timerWatcher:(EVTimerWatcher *)w eventOccured:(int)event
{
	MLAssert(loop == loop_);
	MLAssert(w == timeoutWatcher_);

	int error = 0;
	ev_tstamp now = ev_now((struct ev_loop *)loop_);
	ev_tstamp readRepeat = 0.0, writeRepeat = 0.0;

	if (readTimeout_ > 0.0) {
		if (lastRead_ + readTimeout_ <= now) {
			error |= EV_READ;
			readRepeat = readTimeout_;
		} else {
			readRepeat = lastRead_ + readTimeout_ - now;	
		}
	}

	if (writeTimeout_ > 0.0) {
		if (lastWrite_ + writeTimeout_ <= now) {
			error |= EV_WRITE;
			writeRepeat = writeTimeout_;	
		} else {
			writeRepeat = lastWrite_ + writeTimeout_ - now;	
		}
	}

	if (ev_is_active((struct ev_io *)ioWatcher_)) {
		if (readRepeat > 0.0 || writeRepeat > 0.0) {
			((struct ev_timer *)timeoutWatcher_)->repeat = MIN_NONZERO(readRepeat, writeRepeat);
			ev_timer_again((struct ev_loop *)loop_, (struct ev_timer *)timeoutWatcher_);
		}
	}

	if (error) {
		if (flushing_) {
			[self release];
			return;
		} else {
			[delegate_ timeout:error onEvent:self];
		}
	}
}

- (BOOL)validateForStart:(NSError **)error
{
	MLAssert(!flushing_);

	MLAssert([ioWatcher_ fd]);
	MLAssert(loop_);

	return YES;
}

- (void)reservePlaceInInputBuffer:(uint64_t)len
{
	MLBufferReserve(inputBuffer_, len + readSize_);
}

- (void)start
{
	if ([ioWatcher_ isActive]) return;
	ev_tstamp now = ev_now((struct ev_loop *)loop_);

	[ioWatcher_ setEvents: EV_READ | EV_WRITE];
	[self startWatcher:ioWatcher_];

	lastRead_ = now;
	lastWrite_ = now;

	if (readTimeout_ > 0.0 || writeTimeout_ > 0.0) {
		[timeoutWatcher_ setRepeat:MIN_NONZERO(readTimeout_, writeTimeout_)];
		[timeoutWatcher_ againOnLoop:loop_];
	}
}

- (void)stop
{
	if (![ioWatcher_ isActive]) return;

	[self stopWatcher:ioWatcher_];
	[self stopWatcher:timeoutWatcher_];
}

- (id <MLBufferedEventDelegate>)delegate
{
	return delegate_;
}

- (void)setDelegate:(id <MLBufferedEventDelegate>)delegate
{
	MLAssert(!flushing_);

	delegate_ = delegate;
	if (delegate_) {
		delegateNewData_ = [(id)delegate_ methodForSelector:@selector(dataAvailableOnEvent:)];
		delegateWritten_ = [(id)delegate_ methodForSelector:@selector(writtenToEvent:)];

		MLAssert(delegateNewData_);
		MLAssert(delegateWritten_);
	} else {
		delegateNewData_ = NULL;
		delegateWritten_ = NULL;
	}

	MLLog(LOG_VVVDEBUG, " @@ DEBUG: MLConnection 0x%p set delegate %p (%@)", self, delegate_, delegate_);
}

- (void)setReadTimeout:(ev_tstamp)readTimeout
{
	MLAssert(!flushing_);

	MLAssert(![ioWatcher_ isActive]);
	readTimeout_ = readTimeout;
}

- (ev_tstamp)readTimeout
{
	return readTimeout_;
}

- (void)setWriteTimeout:(ev_tstamp)writeTimeout
{
	MLAssert(!flushing_);

	MLAssert(![ioWatcher_ isActive]);
	writeTimeout_ = writeTimeout;
}

- (ev_tstamp)writeTimeout
{
	return writeTimeout_;
}

- (BOOL)isStarted
{
	return [ioWatcher_ isActive];
}

- (void)setInputBufferSizeLimit:(NSUInteger)maxSize
{
	MLAssert(!flushing_);
	[inputBuffer_ setMaxSize:maxSize];
}

- (NSUInteger)inputBufferSizeLimit
{
	return [inputBuffer_ maxSize];
}

- (void)setOutputBufferSizeLimit:(NSUInteger)maxSize
{
	MLAssert(!flushing_);
	[outputBuffer_ setMaxSize:maxSize];
}

- (NSUInteger)outputBufferSizeLimit
{
	return [outputBuffer_ maxSize];
}

- (int)fd
{
	return [ioWatcher_ fd];
}

- (void)setFd:(int)fd
{
	MLAssert(![ioWatcher_ isActive]);
	[ioWatcher_ setFd:fd];
}

- (uint16_t)port
{
	struct sockaddr_in addr;
	socklen_t len = sizeof(addr);
	getsockname([self fd], (struct sockaddr *)&addr, &len);
	return htons(addr.sin_port);
}

- (void)setReadSize:(NSUInteger)readSize
{
	MLAssert(!flushing_);
	readSize_ = readSize;
}

- (NSUInteger)readSize
{
	return readSize_;
}

- (void)resetBuffers
{
	MLAssert(!flushing_);
	MLAssert(![ioWatcher_ isActive]);
	[inputBuffer_ reset];
	[outputBuffer_ reset];
}

- (void)rescheduleRead
{
	struct ev_watcher *io = (struct ev_watcher *)(self.ioWatcher);
	if (ev_is_active(io) && (MLBufferLength(inputBuffer_) > 0)) {
		ev_feed_event(EVLOOP_LOOP(loop_), io, EV_ASYNC_READ);
	}
}

- (NSUInteger)memoryMovesCount
{
	return [inputBuffer_ memoryMovesCount] + [outputBuffer_ memoryMovesCount];
}

- (NSUInteger)reallocationsCount
{
	return [inputBuffer_ reallocationsCount] + [outputBuffer_ reallocationsCount];
}

- (uint64_t)length
{
	return [inputBuffer_ length];
}

- (uint8_t *)bytes
{
	return [inputBuffer_ bytes];
}

- (BOOL)drainBytes:(uint64_t)n
{
	return [inputBuffer_ drainBytes:n];
}

- (void)flushAndRelease
{
	if (MLBufferLength(outputBuffer_) > 0) {
		MLLog(LOG_DEBUG, " @@ DEBUG: 0x%p flushAndRelease requested.", self);
		// После этого вызова нас нет.
		[self setDelegate:nil];
		[self start];

		flushing_ = YES;
	} else {
		[self release];
	}
}

- (uint8_t *)reserveBytes:(uint64_t)n
{
	return [outputBuffer_ reserveBytes:n];
}


- (BOOL)writtenBytes:(uint64_t)m
{
	return [outputBuffer_ writtenBytes:m];
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
	if ([self isStarted]) [self stop];

	if ([self fd] > 0) {
		MLLog(LOG_VVVDEBUG, "shutting down %@ of %d", self, [self fd]);
		shutdown([self fd], SHUT_RDWR);
		close([self fd]);
		[self setFd:0];
	}
	[description_ release];

	if (flushing_) MLLog(LOG_VVVDEBUG, " @@ DEBUG: 0x%p released.", self);

	struct ev_io *io = (struct ev_io *)(ioWatcher_);
	MLLog(LOG_VVVDEBUG, " @@ DEBUG: RELEASING MLConnection 0x%p. io W %d R %d inb %lld outb %lld",
		self,
		io->events & EV_WRITE,
		io->events & EV_READ,
		MLBufferLength(inputBuffer_),
		MLBufferLength(outputBuffer_));

	[ioWatcher_ release];
	[timeoutWatcher_ release];

	[inputBuffer_ release];
	[outputBuffer_ release];

	[super dealloc];
}
@end
