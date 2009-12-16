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

/** Обобщённый поток.
 *
 * Интерфейс эффективного последовательного потокового чтения-записи. Поддерживается
 * MLBuffer и MLBufferedEvent.
 *
 * Применять эти вызовы не рекомендуется, рекомендуется применять \ref mlstream_fastaccess
 * "функции быстрого доступа". Из-за того, что их поддержка весьма implementation-specific,
 * вы наверняка не хотите реализовывать этот интерфейс.
 *
 * Подробно работа с этим интерфейсом описана в классе MLBuffer.
 *
 * Copyright 2009 undev
 */
@protocol MLStream <NSObject>
/** Сколько байт сейчас доступно для чтения в потоке. */
- (uint64_t)length;
/** Указатель на буфер с байтами потока. Там содержится length байт. */
- (uint8_t *)bytes;

/** Убрать из потока первые n байт. Возвращает YES, если в потоке ещё остались байты. */
- (BOOL)drainBytes:(uint64_t)n;

/** Зарезервировать n байт в буфере и вернууть адрес для их записи.
 * Если у буфера потока есть ограничение по размеру и оно исчерпано, возвращает NULL. */
- (uint8_t *)reserveBytes:(uint64_t)n;

/** Извещение о том, что m байт записаны в буфер по адресу, возвращённому
 * reserveBytes. Строго должно быть m <= n. Если у буфера потока есть ограничения по размеру
 * и они были исчераны, возвращает NO. */
- (BOOL)writtenBytes:(uint64_t)m;
@end
