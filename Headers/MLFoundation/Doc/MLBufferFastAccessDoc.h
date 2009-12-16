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

/** @defgroup mlbuffer_fastaccess MLBuffer Fast read/write functions. 
 *
 * Функции, применяющиеся для работы с MLBuffer.
 *
 * Последовательность действий при чтении следующая:
 *
 * @code
 * uint8_t *data = MLBufferData(buf);
 * NSUInteger len = MLBufferLength(buf);
 *
 * // Do something with data
 *
 * MLBufferDrain(buf, readBytesCount);
 * @endcode
 *
 * Если readBytesCount больше len - буфер опустошится.
 *
 * При записи: 
 *
 * @code
 * // Decide upper limit of write size
 * uint8_t *writeHere = MLBufferReserve(buf, upperWriteSizeLimit);
 * 
 * // Copy data to writeHere
 *
 * MLBufferWritten(buf, reallyWritten);
 * @endcode
 *
 * reallyWritten жёстко должен быть меньше или равен upperWriteSizeLimit. 
 * Если запрошен MLBufferReserve на больше, чем есть непрерывного места в буфере,
 * то сначала происходит попытка переместить данные буфера так, чтобы освободить
 * больше непрерывной памяти. Если этого недостаточно, происходит реаллокация.
 * Занятая буфером память не отдаётся системе до деаллокации.
 *
 * Copyright 2009 undev
 * @{
 **/

/** Сколько байт сейчас доступно для чтения в потоке. */
uint64_t MLBufferLength(id<MLBuffer> buf);

/** Указатель на буфер с байтами потока. Там содержится MLBufferLength байт. */
uint8_t *MLBufferData(id<MLBuffer> buf);

/** Убрать из потока первые n байт. Возвращает YES, если в потоке ещё остались байты. */
BOOL MLBufferDrain(id<MLBuffer> buf, uint64_t n);

/** Зарезервировать n байт в буфере и вернууть адрес для их записи.
 * Если буфер ограничен по размеру и закончился, возвращает NULL. */
uint8_t *MLBufferReserve(id<MLBuffer> buf, uint64_t n);

/** Извещение о том, что m байт записаны в буфер по адресу, возвращённому
 * reserveBytes. Строго должно быть m <= n. Если у буфера потока есть ограничения по размеру
 * и они были исчераны, возвращает NO. */
BOOL MLBufferWritten(id<MLBuffer> buf, uint64_t m);

/** Извлечь все данные из буфера в новый авторелизнутый буфер. Применять с осторожностью. */
MLBuffer *MLBufferExtractData(id<MLBuffer> buf);

/*@}*/


