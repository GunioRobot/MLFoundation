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
#import <MLFoundation/MLCore/MLAssert.h>
#import <MLFoundation/MLCore/MLStaticMessaging.h>
#import <MLFoundation/MLBuffer.h>
#import <MLFoundation/Protocols/MLStream.h>
#import <MLFoundation/MLStream.h>

#import <MLFoundation/MLStreamFastAccess+Private.h>

inline static uint64_t MLBufferLength(id<MLStream> buf)
{
	CHECK_ISA_MLBUFFER(buf);
#if !__OBJC2__
	return MLB_OPEN(buf)->length_;
#else
	return ((MLBuffer *)buf).length;
#endif
}

inline static uint8_t *MLBufferData(id<MLStream> buf)
{
	CHECK_ISA_MLBUFFER(buf);
#if !__OBJC2__
	return MLB_OPEN(buf)->data_ + MLB_OPEN(buf)->pointer_;
#else
	return ((MLBuffer *)buf).data + ((MLBuffer *)buf).pointer;
#endif
}

inline static BOOL MLBufferDrain(id<MLStream> buf, uint64_t n)
{
	CHECK_ISA_MLBUFFER(buf);
#if !__OBJC2__
	MLAssert((MLB_OPEN(buf)->parentTransaction_ && MLB_OPEN(buf)->transactionKind_ == MLBufferReadTransactionKind) ||
			(!MLB_OPEN(buf)->parentTransaction_ && MLB_OPEN(buf)->transactionKind_ == MLBufferNoTransactionKind));

	if (n == 0) {return MLB_OPEN(buf)->length_ > 0;};

	BOOL retval = (n < MLB_OPEN(buf)->length_);
	n = MIN(n, MLB_OPEN(buf)->length_);

	MLB_OPEN(buf)->pointer_ += n;
	MLB_OPEN(buf)->length_ -= n;

	if (!MLB_OPEN(buf)->length_) MLB_OPEN(buf)->pointer_ = 0;
#else
	MLAssert(YES); // FIXME

	if (n == 0) {return ((MLBuffer *)buf).length > 0;};
	
	BOOL retval = (n < ((MLBuffer *)buf).length);
	n = MIN(n, ((MLBuffer *)buf).length);
	
	((MLBuffer *)buf).pointer += n;
	((MLBuffer *)buf).length -= n;
	
	if (!((MLBuffer *)buf).length) ((MLBuffer *)buf).pointer = 0;	
#endif
	
	return retval;
}

inline static uint64_t MLStreamTransactionOffset(id<MLStream> buf)
{
#if !__OBJC2__
	uint64_t tail = MLB_OPEN(buf)->pointer_ + MLB_OPEN(buf)->length_;
	uint64_t head = MLB_OPEN(buf)->pointer_;

	while (MLB_OPEN(buf)->parentTransaction_) {
		buf = MLB_OPEN(buf)->parentTransaction_;
		head = MLB_OPEN(buf)->pointer_;
	}	
#else
	uint64_t tail = ((MLBuffer *)buf).pointer + ((MLBuffer *)buf).length;
	uint64_t head = ((MLBuffer *)buf).pointer;

	while (((MLBuffer *)buf).parentTransaction) {
		buf = ((MLBuffer *)buf).parentTransaction;
		head = ((MLBuffer *)buf).pointer;
	}
#endif
	return tail - head;
}

inline static uint8_t *MLBufferReserve(id<MLStream> buf, uint64_t n)
{
	CHECK_ISA_MLBUFFER(buf);
#if !__OBJC2__
	MLAssert(MLB_OPEN(buf)->transactionKind_ != MLBufferReadTransactionKind);

	// Return place for new bytes if everything is okay
	int64_t myCapacityLeft = (MLB_OPEN(buf)->capacity_ - (MLB_OPEN(buf)->pointer_ + MLB_OPEN(buf)->length_));

	if (myCapacityLeft >= n) {
		return (MLB_OPEN(buf)->data_ + MLB_OPEN(buf)->pointer_ + 
				MLB_OPEN(buf)->length_);
	}

	if (!MLB_OPEN(buf)->parentTransaction_) {
		return STATICMSG_1A(uint8_t *, MLBuffer, buf, reserveBytes:, n);
	} else {
		// Мы ведём себя так, что здесь мы могли оказаться только если и у parent'а тоже не хватает места.
		id <MLStream> parent = MLB_OPEN(buf)->parentTransaction_;
		
		uint8_t *retval = MLBufferReserve(parent, n + MLB_OPEN(buf)->length_);
		if (!retval) return NULL;
		
		MLB_OPEN(buf)->data_ = MLB_OPEN(parent)->data_;
		MLB_OPEN(buf)->pointer_ = MLB_OPEN(parent)->pointer_ + MLB_OPEN(parent)->length_;
		
		MLB_OPEN(buf)->capacity_ = MLB_OPEN(parent)->capacity_; 
		MLB_OPEN(buf)->maxSize_ = MLB_OPEN(buf)->capacity_;
		
		return retval + MLB_OPEN(buf)->length_;
	}	
#else
	MLAssert(((MLBuffer *)buf).transactionKind != MLBufferReadTransactionKind);
	
	// Return place for new bytes if everything is okay
	int64_t myCapacityLeft = (((MLBuffer *)buf).capacity - (((MLBuffer *)buf).pointer + ((MLBuffer *)buf).length));
	
	if (myCapacityLeft >= n) {
		return (((MLBuffer *)buf).data + ((MLBuffer *)buf).pointer + 
				((MLBuffer *)buf).length);
	}

	if (!((MLBuffer *)buf).parentTransaction) {
		return STATICMSG_1A(uint8_t *, MLBuffer, buf, reserveBytes:, n);
	} else {
		// Мы ведём себя так, что здесь мы могли оказаться только если и у parent'а тоже не хватает места.
		id <MLStream> parent = ((MLBuffer *)buf).parentTransaction;

		uint8_t *retval = MLBufferReserve(parent, n + ((MLBuffer *)buf).length);
		if (!retval) return NULL;

		((MLBuffer *)buf).data = ((MLBuffer *)buf).data;
		((MLBuffer *)buf).pointer = ((MLBuffer *)buf).pointer + ((MLBuffer *)buf).length;

		((MLBuffer *)buf).capacity = ((MLBuffer *)buf).capacity;
		((MLBuffer *)buf).maxSize = ((MLBuffer *)buf).capacity;

		return retval + ((MLBuffer *)buf).length;
	}	
#endif
}

inline static BOOL MLBufferWritten(id<MLStream> buf, uint64_t m)
{
	CHECK_ISA_MLBUFFER(buf);
#if !__OBJC2__
	MLAssert((MLB_OPEN(buf)->parentTransaction_ && MLB_OPEN(buf)->transactionKind_ == MLBufferWriteTransactionKind) ||
			(!MLB_OPEN(buf)->parentTransaction_ && MLB_OPEN(buf)->transactionKind_ == MLBufferNoTransactionKind));

	MLAssert(MLB_OPEN(buf)->pointer_ + 
			 MLB_OPEN(buf)->length_ + 
			 m <= MLB_OPEN(buf)->capacity_);
	
	MLB_OPEN(buf)->length_ += m;
#else
	MLAssert((((MLBuffer *)buf).parentTransaction && ((MLBuffer *)buf).transactionKind == MLBufferWriteTransactionKind) ||
			 (!((MLBuffer *)buf).parentTransaction && ((MLBuffer *)buf).transactionKind == MLBufferNoTransactionKind));

	MLAssert(((MLBuffer *)buf).pointer +
			 ((MLBuffer *)buf).length +
			 m <= ((MLBuffer *)buf).capacity);

	((MLBuffer *)buf).length += m;
#endif
	return YES;
}

inline static BOOL MLBufferAppendBytes(id<MLStream> buf, uint8_t *bytes, uint64_t m)
{
	CHECK_ISA_MLBUFFER(buf);
	uint8_t *place = MLBufferReserve(buf, m);
	if (!place) return NO;
	memcpy(place, bytes, m);
	return MLBufferWritten(buf,m);
}

inline static BOOL MLBufferAppendByte(id<MLStream> buf, uint8_t byte)
{
	CHECK_ISA_MLBUFFER(buf);
	uint8_t *place = MLBufferReserve(buf, 1);
	if (!place) return NO;
	*place = byte;
	return MLBufferWritten(buf,1);
}

inline static uint64_t MLStreamLength(id<MLStream> buf)
{
#if !__OBJC2__
	MLStreamWillRead(buf);
#else
	if (![(NSObject *)buf isMemberOfClass:MLBufferClass]) {
		return MLBufferLength(((MLStream *)buf).inputBuffer);
	}
#endif
	return MLBufferLength(buf);
}

inline static uint8_t *MLStreamData(id<MLStream> buf)
{
#if !__OBJC2__
	MLStreamWillRead(buf);
#else
	if (![(NSObject *)buf isMemberOfClass:MLBufferClass]) {
		return MLBufferData(((MLStream *)buf).inputBuffer);
	}
#endif
	return MLBufferData(buf);
}

inline static BOOL MLStreamDrain(id<MLStream> buf, uint64_t n)
{
#if !__OBJC2__
	MLStreamWillRead(buf);
#else
	if (![(NSObject *)buf isMemberOfClass:MLBufferClass]) {
		return MLBufferDrain(((MLStream *)buf).inputBuffer, n);
	}
#endif
	return MLBufferDrain(buf, n);
}

inline static uint8_t *MLStreamReserve(id<MLStream> buf, uint64_t n)
{
#if !__OBJC2__
	MLStreamWillWrite(buf);
#else
	if (![(NSObject *)buf isMemberOfClass:MLBufferClass]) {
		return MLBufferReserve(((MLStream *)buf).outputBuffer, n);
	}
#endif
	return MLBufferReserve(buf, n);
}

inline static BOOL MLStreamWritten(id<MLStream> buf, uint64_t m)
{
	id __original_event = (id)buf;
#if !__OBJC2__
	MLStreamWillWrite(buf);

	MLBufferWritten(buf,m);


	if (MLS_OPEN(__original_event)->isa != MLBufferClass) {
		if (MLS_OPEN(__original_event)->writeCallBack_) {
			(MLS_OPEN(__original_event)->writeCallBack_)(__original_event);
		}
	}
#else
	MLBuffer *buf1;
	if (![(NSObject *)buf isMemberOfClass:MLBufferClass]) {
		buf1 = ((MLStream *)buf).outputBuffer;
	} else {
		buf1 = (MLBuffer *)buf;
	}
	MLBufferWritten(buf1, m);

	if (![__original_event isMemberOfClass:MLBufferClass]) {
		if (((MLStream *)__original_event).writeCallBack) {
			(((MLStream *)__original_event).writeCallBack)(__original_event);
		}
	}	
#endif
	return YES;
}

inline static MLBuffer *MLStreamExtractData(id<MLStream> buf1)
{
#if !__OBJC2__
	MLStreamWillRead(buf1);
	MLBuffer *buf2 = [[MLBuffer new] autorelease];

	struct { @defs( MLBuffer ) } temp;
	memcpy(&temp, buf1, sizeof(temp));
	memcpy(buf1, buf2, sizeof(temp));
	memcpy(buf2, &temp, sizeof(temp));

	return buf2;
#else
	MLBuffer *ret;
	if (![(NSObject *)buf1 isMemberOfClass:[MLBuffer class]]) {
		ret = [((MLStream *)buf1).inputBuffer copy];
		[((MLStream *)buf1).inputBuffer reset];
	} else {
		ret = (MLBuffer *)buf1;
	}
	return ret;
#endif
}
