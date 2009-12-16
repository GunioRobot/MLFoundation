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

#include <Foundation/Foundation.h>

#import <portability/normalized_networking.h>
#import <MLFoundation/EVBindings/EVIoWatcher.h>
#import <MLFoundation/EVBindings/EVTimerWatcher.h>

#import <MLFoundation/MLStream.h>
#import <MLFoundation/MLBuffer.h>
#import <MLFoundation/MLEvLoopActivity.h>

#import <MLFoundation/Protocols/MLBufferedEvent.h>
#import <MLFoundation/Protocols/MLBufferedEventDelegate.h>

/** MLStream-compliant абстракция SOCK_STREAM соединения.
 *
 * Имплементирует MLBufferedEvent со всеми вытекающими.
 *
 * При деллокации закрывает за собой fd. 
 *
 * Ещё одна важная подробность: этот класс устанавливает глобальное игнорирование
 * SIGPIPE.
 *
 * Copyright 2009 undev
 */
@interface MLConnection : MLEvLoopActivity <MLBufferedEvent> {
@private /* MLStream interface */
	MLBuffer *inputBuffer_, *outputBuffer_;
	WRITECB_IMP writeCallBack_;
@protected
	id <MLBufferedEventDelegate>delegate_; /*!< Delegate. */
@private
	IMP delegateNewData_, delegateWritten_;

	EVIoWatcher *ioWatcher_;
	EVTimerWatcher *timeoutWatcher_;

	ev_tstamp readTimeout_, writeTimeout_;
	ev_tstamp lastRead_, lastWrite_;

	NSUInteger readSize_;
	BOOL flushing_;
	BOOL readCycle_;

	NSString *description_;
}
/** Создаёт AF_UNIX SOCK_STREAM сокетпару и оборачивает её концы в MLConnection. */
+ (BOOL)newSocketpair:(MLConnection **)connections;

/** [RO, MANDATORY] Sets file descriptor to work on. */
- (void)setFd:(int)fd;
/** File descriptor to work on. */
- (int)fd;

/* порт соединения */
- (uint16_t)port;

/* При смене fd, надо сбрасывать буферы */
- (void)resetBuffers;

/** Установить описание соединения в понятной человеку форме. */
- (void)setDescription:(NSString *)description;

/** Закрыть ненужное соединение в чайлде после форка. После этого приходит в негодность и может
 * быть только released. */
- (void)dropAfterFork;
@end
