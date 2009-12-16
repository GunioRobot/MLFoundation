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

/** Потоковый FIFO в памяти.
 *
 * Интерфейс эффективного последовательного потокового чтения-записи. Устроен так, что
 * не имеет никакой защиты от дурака. Его реализует MLBuffer, на нём же работает MLStream.
 *
 * Применять эти вызовы напрямую не рекомендуется, рекомендуется применять повторяющие их 
 * \ref mlstream_fastaccess "функции быстрого доступа". Исторически сложилось, что эти 
 * функции имеют префикс MLStream. По факту же они работают со всеми MLBytesFIFO.
 *
 * Все указатели на байты, полученные из bytes, валидны до смены фрейма стека (читай,
 * входа/выхода из какой-либо функции), вызова [MLBuffer initExtractingDataFrom:] 
 * или до следующего reserve. До этого момента их не тревожит даже drain.
 *
 * Указатель байты, полученые от reserve, валидны до выхода из функци (читай, до
 * разрушения фрейма стека) или до следующего reserve. До этого момента их не тревожит
 * ни written, ни drain.
 *
 */
@protocol MLBytesFIFO 
/** Сколько байт сейчас доступно для чтения в FIFO. */
- (uint64_t)length;
/** Указатель на буфер с байтами FIFO. Там содержится length байт. */
- (uint8_t *)bytes;

/** Убрать из FIFO первые n байт. Возвращает YES, если в FIFO ещё остались байты. */
- (BOOL)drainBytes:(uint64_t)n;

/** Зарезервировать n байт в FIFO и вернуть адрес для их записи.
 * Если у FIFO есть ограничение по размеру и оно исчерпано, возвращает NULL. */
- (uint8_t *)reserveBytes:(uint64_t)n;

/** Извещение о том, что m байт записаны в FIFO по адресу, возвращённому ранее
 * reserveBytes. Строго должно быть m <= n. Если у FIFO есть ограничения по размеру
 * и они были исчераны, возвращает NO. */
- (BOOL)writtenBytes:(uint64_t)m;
@end

