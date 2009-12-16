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

/** @defgroup mlbitstream_functions Bitstream.
 *
 * Частями слизан с GPAC. Предполагает, что везде старшие биты вначале.
 *
 * Если в ходе чтения битстрим кончился, или кончилось место в процессе записи, или 
 * что-то не удалось записать - выставляется флажок, который заставит MLBitStreamError 
 * вернуть YES.
 *
 * [TODO] Сейчас почти не оттестирован. Алсо не хватает прямой работы с MLBuffer.
 *
 * Copyright 2009 undev
 * @{
 **/

/** Открывает локальный битстрим на чтение. Все данные размещаются на стеке, 
 * поэтому все операции должны быть выполнены до возврата из функции. 
 * Закроется сам при выходе из функции. */
MLBitStream *MLBitStreamOpenLocalRead(uint8_t *data, uint64_t size);

/** Открывает локальный битстрим на запись. Все данные размещаются на стеке, 
 * поэтому все операции должны быть выполнены до возврата из функции. 
 * Закроется сам при выходе из функции. */
MLBitStream *MLBitStreamOpenLocalWrite(uint8_t *data, uint64_t size);

/** Произошли ли в каких-либо операциях с этим битстримом ошибки? */
BOOL MLBitStreamError(MLBitStream *bs);

/** Сколько байт прочитано/записано? */
uint64_t MLBitStreamPosition(MLBitStream *bs);

/** Выровнен ли битстрим по границе байта? */
BOOL MLBitStreamIsAligned(MLBitStream *bs);

/** Принудительно выровнять битстрим по границе байта (записав нолики или выкинув
 * ненужное) */
void MLBitStreamAlign(MLBitStream *bs);

/** Читает из потока в uint32_t число длиной nBits. */
uint32_t MLBitStreamReadInt(MLBitStream *bs, uint32_t nBits);

/** Читает из потока в uint32_t число длиной nBits, не доставая биты из потока. */
uint32_t MLBitStreamPeekInt(MLBitStream *bs, uint32_t nBits);

/** Читает из потока в uint64_t число длиной nBits. */
uint64_t MLBitStreamReadLongInt(MLBitStream *bs, uint32_t nBits);

/** Читает из потока в uint64_t число длиной nBits, не доставая биты из потока. */
uint64_t MLBitStreamPeekLongInt(MLBitStream *bs, uint32_t nBits);

/** Читает из потока uint8_t. Поток должен быть выровнен по границе байта! */
uint8_t MLBitStreamReadU8(MLBitStream *bs);

/** Читает из потока uint16_t. Поток должен быть выровнен по границе байта! */
uint16_t MLBitStreamReadU16(MLBitStream *bs);

/** Читает из потока uint32_t. Поток должен быть выровнен по границе байта! */
uint32_t MLBitStreamReadU32(MLBitStream *bs);

/** Читает из потока uint64_t. Поток должен быть выровнен по границе байта! */
uint64_t MLBitStreamReadU64(MLBitStream *bs);

/** Читает из потока len байт в dest. Поток должен быть выровнен по границе байта! */
void MLBitStreamReadData(MLBitStream *bs, uint8_t *dest, uint64_t len);

/** Записывает в поток из int32_t число длиной nBits. */
void MLBitStreamWriteInt(MLBitStream *bs, int32_t val, uint32_t nBits);

/** Записывает в поток из int64_t число длиной nBits. */
void MLBitStreamWriteLongInt(MLBitStream *bs, int64_t val, uint32_t nBits);

/** Записывает в поток uint8_t. Поток должен быть выровнен по границе байта! */
void MLBitStreamWriteU8(MLBitStream *bs, uint8_t val);

/** Записывает в поток uint16_t. Поток должен быть выровнен по границе байта! */
void MLBitStreamWriteU16(MLBitStream *bs, uint16_t val);

/** Записывает в поток uint32_t. Поток должен быть выровнен по границе байта! */
void MLBitStreamWriteU32(MLBitStream *bs, uint32_t val);

/** Записывает в поток uint64_t. Поток должен быть выровнен по границе байта! */
void MLBitStreamWriteU64(MLBitStream *bs, uint64_t val);

/** Записывает в поток len байт из src. Поток должен быть выровнен по границе байта! */
void MLBitStreamWriteData(MLBitStream *bs, uint8_t *src, uint64_t len);

/*@}*/
