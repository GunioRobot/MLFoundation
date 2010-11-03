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

#include <Foundation/Foundation.h>

#import <MLFoundation/EVBindings/EVIoWatcher.h>
#import <MLFoundation/EVBindings/EVTimerWatcher.h>

#import <MLFoundation/MLStream.h>
#import <MLFoundation/MLBuffer.h>
#import <MLFoundation/MLEvLoopActivity.h>

#import <MLFoundation/Protocols/MLBufferedEvent.h>
#import <MLFoundation/Protocols/MLBufferedEventDelegate.h>

typedef int (*FILEFUNC_IMP)(int, void *, int);

@interface MLBufferedEvent : MLEvLoopActivity <MLBufferedEvent> {
@private /* MLStream interface */
	MLBuffer *inputBuffer_, *outputBuffer_;
	WRITECB_IMP writeCallBack_;
@protected
	id <MLBufferedEventDelegate>delegate_; /*!< Delegate. */
@private
	IMP delegateNewData_, delegateWritten_;
	
	FILEFUNC_IMP readFunction_, writeFunction_;

	EVIoWatcher *ioWatcher_;
	EVTimerWatcher *timeoutWatcher_;

	ev_tstamp readTimeout_, writeTimeout_;
	ev_tstamp lastRead_, lastWrite_;

	NSUInteger readSize_;
	BOOL flushing_;
	BOOL readCycle_;
}

- (void)setReadFunction:(FILEFUNC_IMP)func;
- (void)setWriteFunction:(FILEFUNC_IMP)func;

/** [RO, MANDATORY] Sets file descriptor to work on. */
- (void)setFd:(int)fd;
/** File descriptor to work on. */
- (int)fd;

/* При смене fd, надо сбрасывать буферы */
- (void)resetBuffers;

/** Вызывается во время деаллока для закрытия дескриптора. Вызывает close на дескрипторе и устанавливает дескриптор в 0. При наследовании необходимо вызывать метод родителя в конце метода наследника */
- (void)closeFd;

/** Возвращает описание ошибки чтения */
- (NSError *)readingError;

/** Возвращает описание ошибки записи */
- (NSError *)writingError;

@end
