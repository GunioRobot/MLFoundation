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

#import <MLFoundation/MLBufferedEvent.h>

/** MLStream-compliant абстракция SOCK_STREAM соединения.
 *
 * Является подклассом MLBufferedEvent со всеми вытекающими.
 *
 * При деллокации закрывает за собой fd. 
 *
 * Ещё одна важная подробность: этот класс устанавливает глобальное игнорирование
 * SIGPIPE.
 *
 * Copyright 2009 undev
 */
@interface MLConnection : MLBufferedEvent {
	NSString *description_;
}
/** Создаёт AF_UNIX SOCK_STREAM сокетпару и оборачивает её концы в MLConnection. */
+ (BOOL)newSocketpair:(MLConnection **)connections;

/* порт соединения */
- (uint16_t)port;

/** Установить описание соединения в понятной человеку форме. */
- (void)setDescription:(NSString *)description;

/** Закрыть ненужное соединение в чайлде после форка. После этого приходит в негодность и может
 * быть только released. */
- (void)dropAfterFork;
@end
