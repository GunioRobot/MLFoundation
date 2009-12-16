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
#import <MLFoundation/MLStreamFastAccess.h>

/** @defgroup mlstream_functions MLStream object read/write functions. 
 *
 * Функции, применяющиеся для ввода-вывода каких-то дельных объектов 
 * в MLBuffer и в MLBufferedEvent. Все они работают только через \ref mlstream_fastaccess
 * "функции быстрого доступа". Так же должны работать и функции для ввода-вывода своих
 * объектов.
 *
 * Copyright 2009 undev
 * @{
 **/

/** Если в начале потока есть строка, заканчивающаяся на \\r\\n, \\n, \\n\\r, \\r
 * вернуть длину этой строки вместе со \\r\\n, иначе вернуть 0. */
uint64_t MLStreamPeekLine(id<MLStream> buf);

/** Если в начале буфера есть строка, заканчивающаяся на \\r\\n, \\n, \\n\\r, \\r
 * вернуть эту строку null-terminated (без \\r / \\n!), иначе вернуть NULL. 
 * Если вернули не NULL то после этого вызова необходимо освободить эту строку
 * MLBufferDrainLine(buf) */
char *MLStreamReadLine(id<MLStream> buf);

/** Убрать из буфера прочитаную ранее MLBufferReadLine строку. */
void MLStreamDrainLine(id<MLStream> buf);

/** Записать m байт с адреса bytes в буфер buf. */
BOOL MLStreamAppendBytes(id<MLStream> buf, uint8_t *bytes, uint64_t m);

/** Записать содержимое buf2 в буфер buf. */
BOOL MLStreamAppendStream(id<MLStream> buf, id<MLStream> buf2);

/** Записать байт в буфер buf. */
BOOL MLStreamAppendByte(id<MLStream> buf, uint8_t byte);

/** Записать null-terminated строку s в буфер buf. */
BOOL MLStreamAppendString(id<MLStream> buf, char *s);
/*@}*/
