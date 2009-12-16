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

#ifndef __ML_BIT_STREAM_H__
#define __ML_BIT_STREAM_H__

#import <Foundation/Foundation.h>

typedef uint8_t MLBitStreamMode;

enum {
	MLBitStreamModeRead = 0x00,
	MLBitStreamModeWrite = 0x01
};

struct s_MLBitStream {
	MLBitStreamMode mode;
	uint8_t *data;
	uint64_t size,position;
	uint32_t current;
	uint32_t nBits;
	BOOL error;

	BOOL(*writeOutOfMemory)(struct s_MLBitStream *bs, void *arg);
	void *outOfMemoryArg;	
};

typedef struct s_MLBitStream MLBitStream;

#define MLBitStreamOpenLocal(in_data, in_size, in_mode) ({ \
	MLBitStream *stream = alloca(sizeof(MLBitStream)); \
	stream->data = in_data; \
	stream->size = in_size; \
	stream->position = 0; \
	stream->error = NO; \
	stream->current = 0; \
	stream->mode = in_mode; \
	stream->nBits = (in_mode == MLBitStreamModeRead ? 8 : 0); \
	stream->writeOutOfMemory = NULL; \
	stream; \
})

#define MLBitStreamOpenLocalRead(data, size) \
	MLBitStreamOpenLocal(data,size,MLBitStreamModeRead)

#define MLBitStreamOpenLocalWrite(data, size) \
	MLBitStreamOpenLocal(data,size,MLBitStreamModeWrite)

inline static BOOL MLBitStreamIsAligned(MLBitStream *bs)
{
	if (bs->mode == MLBitStreamModeRead) {
		return ( ( bs->nBits == 8 ) ? 1 : 0 );
	} else {
		return (!bs->nBits);
	}
}

static uint32_t bit_mask[] = {0x80, 0x40, 0x20, 0x10, 0x8, 0x4, 0x2, 0x1};
static uint32_t bits_mask[] = {0x0, 0x1, 0x3, 0x7, 0xF, 0x1F, 0x3F, 0x7F};

inline static uint32_t __MLBitStreamReadByte(MLBitStream *bs) 
{
	if (bs->position >= bs->size) {
		bs->error = YES;
		return 0;
	}
	return (uint32_t)bs->data[bs->position++]; 
}

inline static uint8_t __MLBitStreamReadBit(MLBitStream *bs) 
{
	MLAssert(bs->mode == MLBitStreamModeRead); 
	if (bs->nBits == 8) { 
		bs->current = __MLBitStreamReadByte(bs); 
		bs->nBits = 0; 
	} 
	return (uint8_t)(bs->current & bit_mask[bs->nBits++]) ? 1 : 0; 
}

inline static BOOL MLBitStreamError(MLBitStream *bs)
{
	return bs->error;
}

inline static uint64_t MLBitStreamPosition(MLBitStream *bs)
{
	return bs->position;
}

inline static uint32_t MLBitStreamReadInt(MLBitStream *bs, uint32_t nBits)
{
	MLAssert(nBits <= 32);
	uint32_t ret = 0;
	if (nBits + bs->nBits <= 8) {
		bs->nBits += nBits;
		ret = (bs->current >> (8 - bs->nBits) ) & bits_mask[nBits];
		return ret;
	}
	while (nBits -- > 0) {
		ret <<= 1;
		ret |= __MLBitStreamReadBit(bs);
	}
	return ret;
}

inline static uint32_t MLBitStreamPeekInt(MLBitStream *bs, uint32_t nBits)
{
	uint64_t _position;
	uint32_t _current;
	uint32_t _nBits;
	BOOL _error;

	_position = bs->position;
	_current = bs->current;
	_nBits = bs->nBits;
	_error = bs->error;

	uint32_t retval = MLBitStreamReadInt(bs, nBits);

	bs->position = _position;
	bs->current = _current;
	bs->nBits = _nBits;
	bs->error = _error;

	return retval;
}

inline static uint64_t MLBitStreamReadLongInt(MLBitStream *bs, uint32_t nBits)
{
	MLAssert(nBits <= 64);
	uint64_t ret = 0;
	if (nBits + bs->nBits <= 8) {
		bs->nBits += nBits;
		ret = (bs->current >> (8 - bs->nBits) ) & bits_mask[nBits];
		return ret;
	}
	while (nBits -- > 0) {
		ret <<= 1;
		ret |= __MLBitStreamReadBit(bs);
	}
	return ret;
}

inline static uint64_t MLBitStreamPeekLongInt(MLBitStream *bs, uint32_t nBits)
{
	uint64_t _position;
	uint32_t _current;
	uint32_t _nBits;
	BOOL _error;

	_position = bs->position;
	_current = bs->current;
	_nBits = bs->nBits;
	_error = bs->error;


	uint64_t retval = MLBitStreamReadLongInt(bs, nBits);

	bs->position = _position;
	bs->current = _current;
	bs->nBits = _nBits;
	bs->error = _error;

	return retval;
}

inline static uint32_t MLBitStreamReadExpGolomb(MLBitStream *bs)
{
  uint32_t retval = 0;
  uint8_t retvalLen = 1;
  
  if (bs->error) return 0;

  while (!__MLBitStreamReadBit(bs)) {
    retvalLen++;
    if (retvalLen > 32) { 
      bs->error = YES;
      return 0;
    }
  }

  retval |= ( 1 << (--retvalLen));

  while (retvalLen--) {
    if (__MLBitStreamReadBit(bs)) retval |= (1 << retvalLen);
  }

  return retval - 1;
}

inline static uint8_t MLBitStreamReadU8(MLBitStream *bs)
{
	MLAssert(bs->nBits == 8);
	return __MLBitStreamReadByte(bs);
}

inline static uint16_t MLBitStreamReadU16(MLBitStream *bs)
{
	uint32_t retval;
	MLAssert(bs->nBits == 8);
	retval = __MLBitStreamReadByte(bs); retval <<= 8;
	retval |= __MLBitStreamReadByte(bs); 
	return retval;
}

inline static uint32_t MLBitStreamReadU32(MLBitStream *bs)
{
	uint32_t retval;
	MLAssert(bs->nBits == 8);
	retval = __MLBitStreamReadByte(bs); retval <<= 8;
	retval |= __MLBitStreamReadByte(bs); retval <<= 8;
	retval |= __MLBitStreamReadByte(bs); retval <<= 8;
	retval |= __MLBitStreamReadByte(bs); 
	return retval;
}

inline static uint64_t MLBitStreamReadU64(MLBitStream *bs)
{
	uint64_t retval;
	MLAssert(bs->nBits == 8);
	retval = MLBitStreamReadU32(bs); retval <<= 32;
	retval |= MLBitStreamReadU32(bs); 
	return retval;
}

inline static void MLBitStreamReadData(MLBitStream *bs, uint8_t *dest, uint64_t len)
{
	MLAssert(bs->nBits == 8);
	MLAssert(bs->mode == MLBitStreamModeRead);

	if (bs->error) return;
	if (bs->position + len > bs->size) {
		bs->error = YES;
		bs->position = bs->size;
		return;
	}

	memcpy(dest, bs->data + bs->position, len);
	bs->position += len;
}

inline static void __MLBitStreamWriteByte(MLBitStream *bs, uint8_t val) 
{
	MLAssert(bs->mode == MLBitStreamModeWrite);
	if (bs->position == bs->size) {
		if (bs->error) return;
		if (!bs->writeOutOfMemory || !(bs->writeOutOfMemory)(bs, bs->outOfMemoryArg)) {
			bs->error = YES;
			return;
		}
	}
	bs->data[bs->position] = val;
	bs->position ++;
}

inline static void __MLBitStreamWriteBit(MLBitStream *bs, uint32_t bit) 
{
	bs->current <<= 1;
	bs->current |= bit;
	if (++ bs->nBits == 8) {
		bs->nBits = 0;
		__MLBitStreamWriteByte(bs, (uint8_t)bs->current);
		bs->current = 0;
	}
}

inline static void MLBitStreamWriteInt(MLBitStream *bs, int32_t val, int32_t nBits)
{
	MLAssert(nBits < 32);
	val <<= sizeof(int32_t) * 8 - nBits;

	while (--nBits >= 0) {
		__MLBitStreamWriteBit(bs, val < 0);
		val <<= 1;
	}
}

inline static void MLBitStreamWriteLongInt(MLBitStream *bs, int64_t val, int32_t nBits)
{
	MLAssert(nBits < 64);
	val <<= sizeof(int64_t) * 8 - nBits;

	while (--nBits >= 0) {
		__MLBitStreamWriteBit(bs, val < 0);
		val <<= 1;
	}
}

inline static void MLBitStreamWriteU8(MLBitStream *bs, uint8_t val)
{
	MLAssert(!bs->nBits);
	__MLBitStreamWriteByte(bs, val);
}

inline static void MLBitStreamWriteU16(MLBitStream *bs, uint16_t val)
{
	MLAssert(!bs->nBits);
	__MLBitStreamWriteByte(bs, ((val >> 8) & 0xff));
	__MLBitStreamWriteByte(bs, ((val) & 0xff));
}

inline static void MLBitStreamWriteU32(MLBitStream *bs, uint32_t val)
{
	MLAssert(!bs->nBits);
	__MLBitStreamWriteByte(bs, ((val >> 24) & 0xff));
	__MLBitStreamWriteByte(bs, ((val >> 16) & 0xff));
	__MLBitStreamWriteByte(bs, ((val >> 8) & 0xff));
	__MLBitStreamWriteByte(bs, ((val) & 0xff));
}

inline static void MLBitStreamWriteU64(MLBitStream *bs, uint64_t val)
{
	MLAssert(!bs->nBits);
	MLBitStreamWriteU32(bs, ((val >> 32) & 0xFFFFFFFF));
	MLBitStreamWriteU32(bs, ((val) & 0xFFFFFFFF));
}

inline static void MLBitStreamWriteData(MLBitStream *bs, uint8_t *src, uint64_t len)
{
	MLAssert(!bs->nBits);
	MLAssert(bs->mode == MLBitStreamModeWrite);
	if (bs->error) return;

	while (bs->position + len > bs->size && !bs->error) {
		if (!bs->writeOutOfMemory || !(bs->writeOutOfMemory)(bs, bs->outOfMemoryArg)) {
			bs->error = YES;
			return;
		}
	}

	memcpy(bs->data + bs->position, src, len);
	bs->position += len;
}

inline static void MLBitStreamAlign(MLBitStream *bs)
{
	uint8_t res = 8 - bs->nBits;
	if (bs->mode == MLBitStreamModeRead) {
		if (res > 0) {
			MLBitStreamReadInt(bs, res);
		}
	} else {
		if (bs->nBits > 0) {
			MLBitStreamWriteInt(bs, 0, res);
		}
	}
}

#endif
