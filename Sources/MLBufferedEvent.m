/* 
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

#import <MLFoundation/MLBufferedEvent.h>

#import <MLFoundation/MLCore/MLIdioms.h>
#import <MLFoundation/MLCore/MLAssert.h>
#import <MLFoundation/MLCore/MLFoundationErrors.h>
#import <MLFoundation/MLCore/MLCategories.h>
#import <MLFoundation/MLCore/MLLogger.h>

#import <MLFoundation/MLStreamFastAccess.h>

// Судя по раскладке #define EV_... эти значения более или менее сейфны. Но их можно менять! :-)
#define EV_ASYNC_READ  0x10
#define EV_ASYNC_WRITE 0x20

#define MLBUFFEREDEVENT_OPEN(mlev) ((struct { @defs( MLBufferedEvent ) } *) mlev)

void MLBufferedEventQueueWrite(MLBufferedEvent *ev)
{
	struct ev_io *io = (struct ev_io *)(MLBUFFEREDEVENT_OPEN(ev)->ioWatcher_);
	if ((!(io->events & EV_WRITE)) && ev_is_active((struct ev_watcher *)io)) {
		ev_io_stop((struct ev_loop *)(MLBUFFEREDEVENT_OPEN(ev)->loop_), io);
		io->events = EV_READ | EV_WRITE;
		ev_io_start((struct ev_loop *)(MLBUFFEREDEVENT_OPEN(ev)->loop_), io);
	}
}

@interface MLBufferedEvent (private)
- (void)loop:(EVLoop *)loop ioWatcher:(EVIoWatcher *)w eventOccured:(int)event;
- (void)loop:(EVLoop *)loop timerWatcher:(EVTimerWatcher *)w eventOccured:(int)event;

/* При смене fd, надо сбрасывать буферы */
- (void)resetBuffers;
@end

#define MIN_NONZERO(a,b) ( ((a)>0.0) ? (((b)>0.0) ? (((a)<(b))?(a):(b)) : (a) ): (b) )

@implementation MLBufferedEvent 

// FIXME: В этом классе должны быть глобальные ошибки
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

- (void)loop:(EVLoop *)loop ioWatcher:(EVIoWatcher *)w eventOccured:(int)event
{
	MLAssert(loop == loop_);
	MLAssert(w == ioWatcher_);

	NSError *error = nil;
	int fd = ((struct ev_io *)w)->fd;
	ev_tstamp now = ev_now((struct ev_loop *)loop_);
	NSUInteger write_len = MLBufferLength(outputBuffer_);

	if (event & EV_READ) {
		uint8_t *w_addr = MLBufferReserve(inputBuffer_, readSize_);
		if (!w_addr) {
			error = InputOverflowError();
		} else {
			int bytes_read = readFunction_(fd, w_addr, readSize_);

			if (bytes_read < 0) {
				error = [self readingError];
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

			int bytes_written = writeFunction_(fd, r_addr, write_len);

			if (bytes_written < 0) {
				error = [self writingError];
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
			if (delegate_) [delegate_ timeout:error onEvent:self];
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

- (BOOL)isStarted
{
	return [ioWatcher_ isActive];
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

	MLLog(LOG_VVVDEBUG, " @@ DEBUG: %@ 0x%p set delegate %p (%@)", [self class], self, delegate_, delegate_);
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

- (void)setReadSize:(NSUInteger)readSize
{
	MLAssert(!flushing_);
	readSize_ = readSize;
}

- (NSUInteger)readSize
{
	return readSize_;
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

- (void)reservePlaceInInputBuffer:(uint64_t)len
{
	MLBufferReserve(inputBuffer_, len + readSize_);
}

- (void)resetBuffers
{
	MLAssert(!flushing_);
	MLAssert(![ioWatcher_ isActive]);
	[inputBuffer_ reset];
	[outputBuffer_ reset];
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

- (void)rescheduleRead
{
	struct ev_watcher *io = (struct ev_watcher *)(MLBUFFEREDEVENT_OPEN(self)->ioWatcher_);
	if (ev_is_active(io) && (MLBufferLength(inputBuffer_) > 0)) {
		ev_feed_event(EVLOOP_LOOP(loop_), io, EV_ASYNC_READ);
	}
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

- (uint8_t *)reserveBytes:(uint64_t)n
{
	return [outputBuffer_ reserveBytes:n];
}

- (BOOL)writtenBytes:(uint64_t)m
{
	return [outputBuffer_ writtenBytes:m];
}

- (NSUInteger)memoryMovesCount
{
	return [inputBuffer_ memoryMovesCount] + [outputBuffer_ memoryMovesCount];
}

- (NSUInteger)reallocationsCount
{
	return [inputBuffer_ reallocationsCount] + [outputBuffer_ reallocationsCount];
}

- (id)init
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

	readFunction_ = NULL;
	writeFunction_ = NULL;
	writeCallBack_ = (WRITECB_IMP) MLBufferedEventQueueWrite;

	return self;
}

- (int)fd
{
	return [ioWatcher_ fd];
}

- (void)setFd:(int)fd
{
	MLAssert(![ioWatcher_ isActive]);
	[self resetBuffers];
	[ioWatcher_ setFd:fd];
}

- (void)closeFd
{
	close([self fd]);
	[self setFd:0];
}


- (NSError *)readingError
{
	return nil; // С ошибками должен разбираться подкласс
}

- (NSError *)writingError
{
	return nil; // С ошибками должен разбираться подкласс
}

- (void)dealloc
{
	if ([self isStarted]) [self stop];

	if ([self fd] > 0) {
		[self closeFd];
	}

	if (flushing_) MLLog(LOG_VVVDEBUG, " @@ DEBUG: 0x%p released.", self);

	struct ev_io *io = (struct ev_io *)(ioWatcher_);
	MLLog(LOG_VVVDEBUG, " @@ DEBUG: RELEASING %@ 0x%p. io W %d R %d inb %lld outb %lld",
		[self class],
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
