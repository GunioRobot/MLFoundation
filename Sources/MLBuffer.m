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

#define _GNU_SOURCE

#import <MLFoundation/MLBuffer.h>

#import <MLFoundation/MLCore/MLLogger.h>
#import <MLFoundation/MLCore/MLIdioms.h>
#import <MLFoundation/MLCore/MLDebug.h>
#import <MLFoundation/MLCore/MLAssert.h>
#import <MLFoundation/MLCore/MLSessionSet.h>

#import <MLFoundation/MLStreamFastAccess.h>
#import <MLFoundation/MLStreamFastAccess+Private.h>

#import <libev/config.h>

#import <unistd.h>
#import <sys/mman.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

Class MLBufferClass;

static int PageSize = 4096; // Должно быть степенью двойки... И совпадать с getpagesize().
							// Если не совпадает и getpagesize() не есть степень двойки -
							// надо переделывать округление до размера страницы ниже.
#define MMAP_THRESHOLD (PageSize * 256)

#if MLDEBUG > 1
static MLSessionSet *AllBuffers = nil;

@interface MLBuffer (debug)
- (NSString *)debugDescription;
- (NSArray *)allocationTrace;
- (NSArray *)lastReallocationTrace;
@end

#endif

@implementation MLBuffer
static inline BOOL MLBufferAllocCapacity(MLBuffer *buf, uint64_t size)
{
	// Округляем до размера страницы
	if ((size & ~(PageSize - 1)) != size) 
		size = PageSize + (size & ~(PageSize -1));
	
	MLB_OPEN(buf)->capacity_ = size;

	if (size < MMAP_THRESHOLD) {
		MLB_OPEN(buf)->data_ = malloc(size);
		MLB_OPEN(buf)->mmapAllocated_ = NO;
	} else {
		MLB_OPEN(buf)->data_ = mmap(0, size, PROT_READ | PROT_WRITE, 
			MAP_ANON| MAP_PRIVATE, 0, 0);
		MLAssert(MLB_OPEN(buf)->data_ != MAP_FAILED);
		MLB_OPEN(buf)->mmapAllocated_ = YES;
	}
	return YES;
}

static inline BOOL MLBufferReallocCapacity(MLBuffer *buf, uint64_t size)
{
	if (size <= MLB_OPEN(buf)->capacity_) return YES;

	MLAssert(size);

	uint64_t newCapacity = (MLB_OPEN(buf)->capacity_) << 1;
	while (newCapacity < (MLB_OPEN(buf)->length_ + size)) newCapacity <<= 1;

	// 3 случая: 1) realloc из malloc в malloc 2) realloc из malloc в mmap 3) mremap :)
	MLB_OPEN(buf)->reallocationsCount_++;

#if MLDEBUG > 1
	[MLB_OPEN(buf)->lastReallocationTrace_ release];
	MLB_OPEN(buf)->lastReallocationTrace_ = [MLRawBacktrace() retain];
#endif
	
	if (!MLB_OPEN(buf)->mmapAllocated_ && newCapacity < MMAP_THRESHOLD) {
		MLLog(LOG_VVDEBUG, "%p reallocating malloc %lld -> malloc %lld", buf, MLB_OPEN(buf)->capacity_, newCapacity);

		MLB_OPEN(buf)->data_ = realloc(MLB_OPEN(buf)->data_, newCapacity);
		MLAssert(MLB_OPEN(buf)->data_);
		MLB_OPEN(buf)->capacity_ = newCapacity;

		return YES;
	} 

	if (!MLB_OPEN(buf)->mmapAllocated_ && newCapacity >= MMAP_THRESHOLD) {
		MLLog(LOG_VVDEBUG, "%p reallocating malloc %lld -> mmap %lld", buf, MLB_OPEN(buf)->capacity_, newCapacity);

		uint8_t *oldData = MLB_OPEN(buf)->data_;
		uint64_t oldLength = MLB_OPEN(buf)->capacity_;

		MLBufferAllocCapacity(buf, newCapacity);
		memcpy(MLB_OPEN(buf)->data_, oldData, oldLength);

		free(oldData);

		MLB_OPEN(buf)->capacity_ = newCapacity;
		MLB_OPEN(buf)->mmapAllocated_ = YES;
		return YES;
	}

	// mremap
	MLLog(LOG_VVDEBUG, "%p reallocating mmap %lld -> mmap %lld", buf, MLB_OPEN(buf)->capacity_, newCapacity);
#if HAVE_MREMAP
	MLB_OPEN(buf)->data_ = mremap(MLB_OPEN(buf)->data_, MLB_OPEN(buf)->capacity_, newCapacity, MREMAP_MAYMOVE);
	MLAssert(MLB_OPEN(buf)->data_ != MAP_FAILED);
#else
	// Naive test implementaiton
	uint8_t *oldData = MLB_OPEN(buf)->data_;
	uint64_t oldLength = MLB_OPEN(buf)->capacity_;


	MLBufferAllocCapacity(buf, newCapacity);
	memcpy(MLB_OPEN(buf)->data_, oldData, oldLength);

	int rv = munmap(oldData, oldLength);
	MLAssert(rv == 0);
#endif
	MLB_OPEN(buf)->capacity_ = newCapacity;

	return YES;
}

static inline void MLBufferFreeCapacity(MLBuffer *buf)
{
	if (MLB_OPEN(buf)->mmapAllocated_) {
		int rv = munmap(MLB_OPEN(buf)->data_, MLB_OPEN(buf)->capacity_);
		MLAssert(rv == 0);
	} else {
		free(MLB_OPEN(buf)->data_);
	}
}

+ (void)load
{
	MLBufferClass = [MLBuffer class];
	if (!MLBufferClass) MLFail("Unable to get MLBuffer class! :-/");
	
	MLAssert(PageSize == getpagesize());
}

- (id)init
{
	return [self initBufferWithCapacity:2 * PageSize];
}

- (id)initBufferWithCapacity:(uint64_t)capacity 
{
	MLAssert(capacity);
	if (!(self = [super init])) return nil;

	maxSize_ = 0;

	pointer_ = 0;
	length_= 0;

	BOOL rv = MLBufferAllocCapacity(self, capacity);
	MLReleaseSelfAndReturnNilUnless(rv);
	freeWhenDone_ = YES;

	reallocationsCount_ = 0;
	memoryMovesCount_ = 0;

#if MLDEBUG > 1
	if (!AllBuffers) {
		AllBuffers = [MLSessionSet new]; // Never released.
		MLAssert(AllBuffers, "Unable to allocate set for all buffers!");
	}
	[AllBuffers addObject:self];
	allocationTrace_ = [MLRawBacktrace() retain];
#endif

	return self;
}

- (id)initWithContentsOfFile:(NSString *)fname
{
	if (!(self = [self init])) return nil;

	FILE *f = fopen([fname UTF8String], "rb");
	MLReleaseSelfAndReturnNilUnless(f);
	fseek(f, 0, SEEK_END); 
	uint32_t fsize = ftell(f);
	fseek(f, 0, SEEK_SET); 

	uint8_t *place = [self reserveBytes: fsize];
	MLReleaseSelfAndReturnNilUnless(place);
	fread(place, fsize, 1, f);
	[self writtenBytes: fsize];
	fclose(f);

	return self;	
}

- (id)initMappingFile:(NSString *)fname
{
	if (!(self = [super init])) return nil;

	int fd = open([fname UTF8String], O_RDONLY);
	MLReleaseSelfAndReturnNilUnless(fd >= 0);

	off_t fileLength = lseek(fd, 0, SEEK_END);
	MLReleaseSelfAndReturnNilUnless(fileLength > 0);

	data_ = mmap(0, fileLength, PROT_READ, MAP_PRIVATE, fd, 0);
	if (data_ == MAP_FAILED) {
		data_ = NULL;
		[self release];
		return nil;
	}
	close(fd);
	mmapAllocated_ = YES;
	freeWhenDone_ = YES;

	capacity_ = fileLength;
	maxSize_ = fileLength;

	pointer_ = 0;
	length_ = fileLength;

	return self;
}

- (id)initWithPreallocated:(uint8_t *)bytes size:(uint64_t)size capacity:(uint64_t)capacity
{
	MLAssert(size <= capacity);
	if (!(self = [super init])) return nil;

	capacity_ = capacity;
	maxSize_ = capacity;

	pointer_ = 0;
	length_= size;

	data_ = bytes;
	freeWhenDone_ = NO;

	reallocationsCount_ = 0;
	memoryMovesCount_ = 0;

	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<MLBuffer: 0x%x, %lld/%lld>", self, length_, capacity_];
}

#if MLDEBUG > 1
- (NSString *)debugDescription
{
	return [NSString stringWithFormat:@"0x%x: +%lld %lld/%lld(%lld), R:%d M:%d  MMAP:%d", self, pointer_, length_, capacity_, maxSize_, reallocationsCount_, memoryMovesCount_, mmapAllocated_];
}
- (NSArray *)allocationTrace
{
	return allocationTrace_;
}

- (NSArray *)lastReallocationTrace
{
	return lastReallocationTrace_;
}
#endif

// MLReadableBuffer:
- (uint8_t *)bytes
{
	return data_ + pointer_;
}

- (uint64_t)  length
{
	return length_;
}

- (BOOL)     drainBytes:(uint64_t)count
{
	return MLStreamDrain(self, count);
}

- (NSData *) dataNoCopy
{
	return [NSData dataWithBytesNoCopy:(data_ + pointer_) length:length_ freeWhenDone:NO];
}

- (NSData *) data
{
	return [NSData dataWithBytes:(data_ + pointer_) length:length_];
}

- (uint8_t *)reserveBytes:(uint64_t)count
{
	// Return place for new bytes if everything is okay
	if (pointer_ + length_ + count <= capacity_) {
		return (data_ + pointer_ + length_);
	}

	// Next, try to move pointer to zero
	if (pointer_ > 0) {
		memmove(data_, data_ + pointer_, length_);
		pointer_ = 0;
		memoryMovesCount_++;
	}

	// Pointer is zero here. At last try to reallocate memory.
	if (length_ + count > capacity_) {
		if (maxSize_ && length_ + count > maxSize_) return NULL;

		MLAssert(freeWhenDone_); // Не мы её выделяли - не нам её перемещать, right?
								 // Тем более что при текущем устройстве конструкторов такое невозможно.

		BOOL rv = MLBufferReallocCapacity(self, (uint64_t) length_ + count);
		MLAssert(rv);
	}

	return (data_ + length_);
}

- (BOOL)     writtenBytes:(uint64_t)count
{
	return MLStreamWritten(self, count);
}

- (uint16_t)reallocationsCount
{
	return reallocationsCount_;
}

- (uint16_t)memoryMovesCount
{
	return memoryMovesCount_;
}

- (uint64_t)maxSize
{
	return maxSize_;
}

- (uint64_t)capacity
{
	return capacity_;
}

- (void)setMaxSize:(uint64_t)maxSize
{
	maxSize_ = maxSize;
}

- (void)reset
{
	pointer_ = 0;
	length_ = 0;
	memoryMovesCount_ = 0;
	reallocationsCount_ = 0;
}

- (void)dealloc
{
	if (data_ && freeWhenDone_) MLBufferFreeCapacity(self);
#if MLDEBUG > 1
	[AllBuffers removeObject:self];
	[allocationTrace_ release];
	[lastReallocationTrace_ release];
#endif
	[super dealloc];
}

- (BOOL) dumpToFile:(NSString *)fname
{

	FILE *f = fopen([fname UTF8String], "wb");
	BOOL res = YES;
	if (!f)
		return NO;

	if (data_)
		res = (fwrite(data_, 1, length_, f) == length_);
	fclose(f);

	return res;
}

#if MLDEBUG > 1
+ (void)dumpDebugInfo
{
	MLLog(LOG_DEBUG, " ===== BEGIN MLBUFFER DEBUG DUMP ==== ");
	NSEnumerator *e = [AllBuffers objectEnumerator];
	MLBuffer *b = nil;
	int j;
	while ((b = [e nextObject])) {
		if ([b capacity] <= (8 * 1024 * 1024)) continue;

		MLLog(LOG_DEBUG, "%@", [b debugDescription]);
		NSArray *trace;
		trace = [b allocationTrace];

		if (trace) {
			MLLog(LOG_DEBUG, "Allocation trace:");
			trace = MLSymbolizeRawBacktrace(trace);
			for (j = 1; j < [trace count] ; j++) {
				MLLog(LOG_DEBUG, "  %@", [trace objectAtIndex:j]);
			}
		} else {
			MLLog(LOG_DEBUG, "Allocation trace unknown!");
		}

		trace = [b lastReallocationTrace];
		if (trace) {
			MLLog(LOG_DEBUG, "Last reallocation trace:");
			trace = MLSymbolizeRawBacktrace(trace);
			for (j = 1; j < [trace count] ; j++) {
				MLLog(LOG_DEBUG, "  %@", [trace objectAtIndex:j]);
			}
		} else {
			MLLog(LOG_DEBUG, "Last reallocation trace unknown!");
		}
		MLLog(LOG_INFO, "------------------------------------------- ");
	}
	MLLog(LOG_DEBUG, " ===== END MLBUFFER DEBUG DUMP ==== ");
}
#endif

@end
