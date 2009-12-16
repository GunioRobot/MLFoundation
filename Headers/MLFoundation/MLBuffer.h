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
#import <MLFoundation/Protocols/MLStream.h>
#import <MLFoundation/MLObject/MLObject.h>

enum {
	MLBufferNoTransactionKind = 0,
	MLBufferReadTransactionKind,
	MLBufferWriteTransactionKind
};

/** MLStream-compliant буфер.
 *
 * Интерфейс его похож на FIFO, который предоставляет доступ к своим 
 * внутренностям и не имеет решительно никакой защиты от дурака.
 * Лучше всего этот буфер работает, если периодически вычитывать его целиком.
 *
 * Читать/писать в него можно только функциями быстрого доступа. 
 * ( \ref mlbuffer_fastaccess ). Подробности поведения буфера описаны там же.
 *
 * По операциям чтения/записи совместим с MLStream, то есть все MLStreamXXX, 
 * от FastAccess до Functions к нему применимы.
 *
 * Copyright 2009 undev
 */
@interface MLBuffer : MLObject <MLStream> {
@private
	uint8_t *data_;
	BOOL freeWhenDone_, mmapAllocated_;

	uint64_t capacity_, maxSize_;
	uint64_t pointer_, length_;

	uint16_t reallocationsCount_, memoryMovesCount_;

	// Transactional context
	MLBuffer *parentTransaction_;
	uint8_t transactionKind_;

#if MLDEBUG > 1
	NSArray *allocationTrace_;
	NSArray *lastReallocationTrace_;
#endif
}
/** Init buffer with given capacity. */
- (id)initBufferWithCapacity:(uint64_t)capacity;

/** Init with contents of given file. Fails if can not open file. */
- (id)initWithContentsOfFile:(NSString *)fname;

/** Init with preallocated area. При этом память при разрушении буфера не освобождается. */
- (id)initWithPreallocated:(uint8_t *)bytes size:(uint64_t)size capacity:(uint64_t)capacity;

/** Init with contents of file using mmap(). */
- (id)initMappingFile:(NSString *)fname;

/** Dumps contents to given file */
- (BOOL)dumpToFile:(NSString *)fname;

/** Buffer capacity. */
- (uint64_t)maxSize;

/** Max buffer size. */
- (uint64_t)capacity;
/** Set max buffer size.
 *  Может быть изменён в любое время. Если он указан и больше 0, то на попытку
 *  выйти за его пределы MLBufferReserve вернёт NULL.
 *  Само по себе изменение maxSize не меняет объёма занятой памяти, оно 
 *  только ограничивает MLBufferReserve.
 */
- (void)setMaxSize:(uint64_t)maxSize; 

/** Returns how many Reserve calls resulted in data block reallocation. */
- (uint16_t)reallocationsCount;
/** Returns how many Reserve calls resulted in buffer data rearragnement. */
- (uint16_t)memoryMovesCount;

/** Clear buffer. */
- (void)reset;
/** Clear buffer and change its capacity. */

#if MLDEBUG > 1
/** Dump debug info to log. */
+ (void)dumpDebugInfo;
#endif
@end

extern Class MLBufferClass;

