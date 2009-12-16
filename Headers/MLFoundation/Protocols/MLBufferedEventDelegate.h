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

#import <Foundation/Foundation.h>

@protocol MLBufferedEvent;

/** Клиент BufferedEvent'а.
 *
 * Получает четыре типа коллбэков. Коллбэки чтения и записи дёргаются после 
 * успешного совершения соответствующих операций ввода-вывода.
 * 
 * Из всех коллбэков MLBufferedEvent можно останавливать или release'ить.
 *
 * В коллбэк таймаута приходит код what, являющийся OR'ом:
 *
 * - EV_READ - ошибка произошла при чтении
 * - EV_WRITE - ошибка произошла при записи
 *
 * В коллбэк error: MLBufferedEvent приходит в остановленом состоянии.
 *
 * Copyright 2009 undev
 */
@protocol MLBufferedEventDelegate
/** Во входном буфере stream появились новые данные. */
- (void)dataAvailableOnEvent:(id <MLBufferedEvent>)bufEvent;
/** Из выходного буфера stream отправились данные. */
- (void)writtenToEvent:(id <MLBufferedEvent>)bufEvent;

/** Сработал таймаут, точную семантику см. в MLBufferedEvent. */
- (void)timeout:(int)what onEvent:(id <MLBufferedEvent>)bufEvent;
/** Случилась ошибка. Stream остановлен. */
- (void)error:(NSError *)details onEvent:(id <MLBufferedEvent>)bufEvent;
@end
