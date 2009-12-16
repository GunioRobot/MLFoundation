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

/** @page page5 Потоковый ввод/вывод
 *
 * \section stio_mlbytesfifo [TODO] MLBytesFIFO
 *
 * Всё потоковое чтение и запись происходит по протоколу MLBytesFIFO. Идея проста:
 * для чтения предоставлять прямой доступ к массиву uint8_t, предоставлять метод для 
 * убирания прочитаных байт и два метода для записи - выделить блок памяти для записи
 * байтов и подтвердить запись. Если массив байт для записи уже сформирован снаружи,
 * мы тратим время на лишнее копирование; с другой стороны можно формировать 
 * массив байт прямо в буфере. То же самое справедливо и для чтения.
 *
 * Писать и читать из MLBufferedFIFO рекомендуется функциями быстрого доступа. Исторически
 * их префикс - MLStream.
 *
 * Последовательность действий при чтении следующая:
 *
 * @code
 * uint8_t *data = MLStreamData(buf);
 * NSUInteger len = MLStreamLength(buf);
 *
 * // Do something with data
 *
 * MLStreamDrain(buf, readBytesCount);
 * @endcode
 *
 * Если readBytesCount больше len - буфер опустошится.
 *
 * При записи: 
 *
 * @code
 * // Decide upper limit of write size
 * uint8_t *writeHere = MLStreamReserve(buf, upperWriteSizeLimit);
 * 
 * // Copy data to writeHere
 * MLStreamWritten(buf, reallyWritten);
 * @endcode
 *
 * reallyWritten жёстко должен быть меньше или равен upperWriteSizeLimit. 
 * Enforced by assertion.
 *
 * Для удобства есть несколько функций для ввода-вывода примитивов: 
 * \ref mlstream_functions. Все они работают через эти 5 функций быстрого доступа
 * к MLBufferedFIFO, через эти же 5 функций должны работать и пользовательские 
 * сериализаторы и десериализаторы.
 *
 * Общий принцип работы сериализатора: 
 *
 *  - оценить, сколько нужно байт, чтобы сериализовать объект
 *  - MLStreamReserve столько байт, сколько нужно
 *  - Не получилось? Вернуть ошибку.
 *  - Записать сериализованый объект.
 *  - MLStreamWritten.
 *
 * Общий принцип работы десериализатора:
 *
 *  - оценить, сколько нужно байт, чтобы попытаться десериализовать объект
 *  - посмотреть на MLStreamLength и первые байты MLStreamData.
 *  - если из них следует, что байт ещё мало, вернуть «ошибки нет, но весь
 *    объект ещё не пришёл»
 *  - если из них следует что что-то не так, вернуть ошибку
 *  - десериализовать объект
 *  - MLStreamDrain
 *  - вернуть объект.
 *
 * Протокол MLBytesFIFO реализуют MLBuffer и протокол MLStream. 
 * "Функции быстрого ввода-вывода" жёстко к ним привязаны, поэтому просто так
 * написать свою имплементацию MLBytesFIFO не получится. Однако в большинстве 
 * случаев это не нужно, а нужно реализовывать MLStream.
 * 
 * \section stio_mlstream MLStream
 *
 * TODO:
 *
 * - delegate
 * - haveInput, haveOutput, haveTimeouts, haveConnection.
 *
 * Copyright 2009 undev
 */

#error "This file is for documentation only!"
