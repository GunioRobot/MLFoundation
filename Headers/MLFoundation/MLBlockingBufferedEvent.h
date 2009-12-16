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

#import <MLFoundation/Protocols/MLBufferedEventDelegate.h>
#import <MLFoundation/Protocols/MLBufferedEvent.h>
#import <MLFoundation/MLCoroutine.h>

enum {
	MLBBESleeping = 0,
	MLBBEReading = 1,
	MLBBEWriting = 2,
	MLBBEWaiting = 3
};

/** "Блокирующий MLBufferedEvent"
 *
 * Получает свой bufferedevent при инициализации, ретейнит его и больше никому не отдаёт.
 * 
 * После этого работать с ним предлагается функциями be_read и be_write, которые 
 * ведут себя так же как системные read и write, только вместо файлового дескриптора
 * получают указатель на MLBlockingBufferedEvent , он же - тип be_fd.
 *
 * Закрывается функцией be_close.
 *
 * При этом надо понимать, что если вызов случился не из той нитки, где делались блокировки,
 * то ожидающая возврата из блока нитка будет убита.
 *
 * TODO: УБРАТЬ СТАРЫЕ API: awake -> signal, wasAwakened -> signal_pending
 * TODO: Толковая документация на обвязочные функции.
 * TODO: socket, connect, listen, accept, shutdown :)
 *
 * Copyright 2009 undev
 */
@interface MLBlockingBufferedEvent : NSObject <MLBufferedEventDelegate> {
	id <MLBufferedEvent> bufEv_;
	MLCoroutine *myCoro_;

	MLCoroutine *caller_;

	int state_;
	NSError *error_;

	int lastEvent_;
	BOOL signalPending_;

}
- (id)initWithBufferedEvent:(id <MLBufferedEvent>)bufEv;

- (ssize_t)readBlockingToBuf:(uint8_t *)buf size:(size_t)count;
- (ssize_t)writeBlockingFromBuf:(const uint8_t *)buf size:(size_t)count;

- (int)waitForEvent;

- (NSError *)lastError;

- (void)signal;
@end

