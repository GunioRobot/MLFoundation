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

#import <MLFoundation/MLCore/MLAssert.h>
#import <MLFoundation/MLCore/MLCategories.h>
#import <MLFoundation/MLCore/MLFoundationErrors.h>

#import <MLFoundation/MLBlockingBufferedEvent.h>
#import <MLFoundation/MLStreamFastAccess.h>
#import <MLFoundation/MLStreamFunctions.h>

#import <MLFoundation/MLBlockingBufferedEventEvents.h>

typedef MLBlockingBufferedEvent *be_fd;

ssize_t be_read(be_fd fd, void *buf, size_t count) {
	return [fd readBlockingToBuf:buf size:count];
}

ssize_t be_write(be_fd fd, const void *buf, size_t count) {
	return [fd writeBlockingFromBuf:buf size:count];
}

int be_close(be_fd fd) {
	[fd release];
	return 0;
}

const char *be_last_error(be_fd fd) {
	return [[[fd lastError] description] UTF8String];
}

int be_signal_pending(be_fd fd)
{
    return ((struct { @defs( MLBlockingBufferedEvent ) } *) fd)->signalPending_;
}

int be_wait_event(be_fd fd)
{
	return [fd waitForEvent];
}

@interface MLBlockingBufferedEvent (private)
- (void)goToEventLoop;
@end

@implementation MLBlockingBufferedEvent
- (id)initWithBufferedEvent:(id <MLBufferedEvent>)bufEv
{
	if (!(self = [super init])) return nil;
	
	bufEv_ = [bufEv retain];
	[bufEv_ setDelegate:self];
	state_ = MLBBESleeping;

	return self;
}

- (int)waitForEvent
{
	MLAssert(state_ == MLBBESleeping);

	if (signalPending_) {
		signalPending_ = NO;
		return be_event_signal;
	}

	if (error_) {
		return be_event_error;
	}

	state_ = MLBBEWaiting;
	[self goToEventLoop];
	state_ = MLBBESleeping;

	return lastEvent_;
}

- (ssize_t)readBlockingToBuf:(uint8_t *)buf size:(size_t)count
{
	MLAssert(state_ == MLBBESleeping);

	// Если bufferedEvent stopped - сразу к возврату ошибки 
	if ([bufEv_ isStarted]) {
		while (MLStreamLength(bufEv_) <= 0 && !error_) {
			state_ = MLBBEReading;
			[self goToEventLoop];
		}
		state_ = MLBBESleeping;

	} else {
		// 4) Если ошибки нет (?!) возвращаем EIO
		if (!error_) {
			errno = EIO;
			return -1;
		}
	}
	
	// 2) Если error не EOF - возвращаем -1 (и ставим errno)
	if (error_ && NSErrorCode(error_) != MLSocketEOFError) {
		errno = [error_ errnoCode];
		return -1;
	}

	// 3) Если EOF (или какая ещё бяка) - возвращаем всё что есть в буфере
	uint8_t *data = MLStreamData(bufEv_);
	uint64_t availableData = MIN(MLStreamLength(bufEv_), count);
	if (availableData > 0) {
		memcpy(buf, data, (size_t)availableData);
		MLStreamDrain(bufEv_, availableData);
	}

	return availableData;
}

- (ssize_t)writeBlockingFromBuf:(const uint8_t *)buf size:(size_t)count
{
	MLAssert(state_ == MLBBESleeping);

	// Если bufferedEvent stopped - к возврату ошибки
	if ([bufEv_ isStarted]) {	
		MLStreamAppendBytes(bufEv_, (uint8_t *)buf, (uint64_t)count);

		while (MLBufferLength(MLS_OPEN(bufEv_)->outputBuffer_) > 0 && !error_) {
			state_ = MLBBEWriting;
			[self goToEventLoop];
		}

		state_ = MLBBESleeping;
	} else {
		// 4) Если ошибки нет (?!) возвращаем EIO
		if (!error_) {
			errno = EIO;
			return -1;
		}
	}

	// 2) Если error не EOF - возвращаем -1 (и ставим errno)
	if (error_) {
		if (NSErrorCode(error_) != MLSocketEOFError) {
			errno = [error_ errnoCode];
		} else {
			errno = EPIPE;
		}
		return -1;
	}

	return count;
}

- (void)goToEventLoop
{
	myCoro_ = [MLCoroutine current];

	if (!caller_) {
		caller_ = [MLCoroutine new];
		[caller_ runEventLoop:[bufEv_ loop]];
	} else {
		[caller_ resume];
	}
}

- (void)dataAvailableOnEvent:(id<MLBufferedEvent>)bufEvent
{
	if (state_ == MLBBEReading || state_ == MLBBEWaiting) {
		caller_ = [MLCoroutine current];
		MLAssert(caller_ != myCoro_);
		lastEvent_ = be_event_read;
		[myCoro_ resume];
	}
}

- (void)writtenToEvent:(id <MLBufferedEvent>)bufEvent
{
	if (state_ == MLBBEWriting || state_ == MLBBEWaiting) {
		caller_ = [MLCoroutine current];
		MLAssert(caller_ != myCoro_);
		lastEvent_ = be_event_write;
		[myCoro_ resume];
	}
}

- (void)timeout:(int)what onEvent:(id <MLBufferedEvent>)bufEvent
{
	[error_ release];
	
	// Создать годный error_ (и остановить всё нафиг?)
	error_ = [[NSError alloc] initWithDomain:MLFoundationErrorDomain
								code: MLSocketEOFError
								localizedDescriptionFormat: 
									@"Timeout on blocking socket (EOF simulated)"];

	[bufEv_ stop];
	
	if (state_ != MLBBESleeping) {
		caller_ = [MLCoroutine current];
		MLAssert(caller_ != myCoro_);
		lastEvent_ = be_event_timeout;
		[myCoro_ resume];
	}
}

- (void)error:(NSError *)details onEvent:(id<MLBufferedEvent>)bufEvent
{
	[error_ release];
	error_ = [details copy];

	if (state_ != MLBBESleeping) {
		caller_ = [MLCoroutine current];
		MLAssert(caller_ != myCoro_);
		lastEvent_ = be_event_error;
		[myCoro_ resume];
	}
}

- (NSError *)lastError
{
	return error_;
}

- (void)signal
{
	// Сигнал из блокирующей корутины - ничего не делает.
	if (!myCoro_ || [MLCoroutine current] == myCoro_) return;


	// Если мы не ждём события - ничего и не делаем.
	if (state_ != MLBBEWaiting) {
		signalPending_ = YES;
		return;
	} else {
		lastEvent_ = be_event_signal;

		caller_ = [MLCoroutine current];
		MLAssert(caller_ != myCoro_);
		[myCoro_ resume];
	}
}

- (void)dealloc
{
	MLAssert(caller_ != myCoro_);

	[error_ release];
	[bufEv_ flushAndRelease];

	if ([myCoro_ isCurrent]) {
		[caller_ release];
	} else {
		[myCoro_ release];
	}

	[super dealloc];
}
@end
