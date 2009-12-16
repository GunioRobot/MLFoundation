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

#error This file for documenting purposes only.

/** @defgroup mlstream_fastaccess MLStream Fast read/write functions. 
 *
 * Функции, применяющиеся для ввода-вывода в MLBuffer и в MLStream/MLBufferedEvent. 
 * Сделаны из пачки хаков для жалкой имитации статической типизации. Пойдут под 
 * полное переписывание препроцессором.
 *
 * Всё аналогично протоколу MLStream, но implementation-specific и поэтому работают
 * быстро. Точнее, с приемлемой скоростью. Подробно описаны в MLBuffer.
 *
 * Copyright 2009 undev
 * @{
 **/

/** Сколько байт сейчас доступно для чтения в потоке. */
uint64_t MLStreamLength(id<MLStream> buf);

/** Указатель на буфер с байтами потока. Там содержится MLStreamLength байт. */
uint8_t *MLStreamData(id<MLStream> buf);

/** Убрать из потока первые n байт. Возвращает YES, если в потоке ещё остались байты. */
BOOL MLStreamDrain(id<MLStream> buf, uint64_t n);

/** Возвращает актуальное количество байт в реальном потоке, проходя через вложенные транзакционные 
 * контексты насквозь. */
inline static uint64_t MLStreamTransactionOffset(id<MLStream> buf)

/** Зарезервировать n байт в буфере и вернууть адрес для их записи.
 * Если буфер ограничен по размеру и закончился, возвращает NULL. */
uint8_t *MLStreamReserve(id<MLStream> buf, uint64_t n);

/** Извещение о том, что m байт записаны в буфер по адресу, возвращённому
 * reserveBytes. Строго должно быть m <= n. Если у буфера потока есть ограничения по размеру
 * и они были исчераны, возвращает NO. */
BOOL MLStreamWritten(id<MLStream> buf, uint64_t m);

/** Извлечь все данные из потока в новый авторелизнутый буфер. Применять с осторожностью. */
MLBuffer *MLStreamExtractData(id<MLStream> buf);

/*@}*/
