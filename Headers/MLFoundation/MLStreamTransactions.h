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
#import <MLFoundation/MLBufferStackAllocation.h>
#import <MLFoundation/Protocols/MLStream.h>
#import <MLFoundation/MLStream.h>

#import <MLFoundation/MLStreamFastAccess+Private.h>

#define MLStreamBeginReadTransaction(___stream) ({ \
	/* Check no transaction opened already. */ \
  id __stream = ___stream; \
	MLStreamWillRead(__stream); \
	MLAssert((MLB_OPEN(__stream)->parentTransaction_ && MLB_OPEN(__stream)->transactionKind_ == MLBufferReadTransactionKind) || \
			(!MLB_OPEN(__stream)->parentTransaction_ && MLB_OPEN(__stream)->transactionKind_ == MLBufferNoTransactionKind)); \
	MLAssert(MLB_OPEN(__stream)->transactionKind_ == MLBufferNoTransactionKind); \
	MLBuffer *retval = MLWrapBufferNew( MLBufferData(__stream), MLBufferLength(__stream) );\
	MLB_OPEN(retval)->parentTransaction_ = (MLBuffer *)__stream; \
	MLB_OPEN(__stream)->transactionKind_ = MLBufferReadTransactionKind; \
	MLB_OPEN(retval)->transactionKind_ = MLBufferReadTransactionKind; \
	retval; \
})

/** Открывает транзакцию на запись в поток. */
#define MLStreamBeginWriteTransaction(___stream, __ir) ({ \
	/* Check no transaction opened already. */ \
  id __stream = ___stream; \
	MLStreamWillWrite(__stream); \
	MLAssert((MLB_OPEN(__stream)->parentTransaction_ && MLB_OPEN(__stream)->transactionKind_ == MLBufferWriteTransactionKind) || \
			(!MLB_OPEN(__stream)->parentTransaction_ && MLB_OPEN(__stream)->transactionKind_ == MLBufferNoTransactionKind)); \
	int initialReserve = 16; \
	if (__ir > 0) initialReserve = __ir; \
	MLBufferReserve(__stream, initialReserve); \
	MLBuffer *retval = MLWrapBufferNew( MLB_OPEN(__stream)->data_, MLB_OPEN(__stream)->capacity_ );\
	MLB_OPEN(retval)->length_ = 0; \
	MLB_OPEN(retval)->pointer_ = MLB_OPEN(__stream)->pointer_ + MLB_OPEN(__stream)->length_; \
	MLB_OPEN(retval)->parentTransaction_ = (MLBuffer *)__stream; \
	MLB_OPEN(__stream)->transactionKind_ = MLBufferWriteTransactionKind; \
	MLB_OPEN(retval)->transactionKind_ = MLBufferWriteTransactionKind; \
	retval; \
})

#define MLStreamRollbackTransaction(__stream) do { \
	CHECK_ISA_MLBUFFER(__stream); \
	MLAssert(MLB_OPEN(__stream)->transactionKind_ != MLBufferNoTransactionKind); \
	MLAssert(MLB_OPEN(__stream)->parentTransaction_); \
	if (!MLB_OPEN(MLB_OPEN(__stream)->parentTransaction_)->parentTransaction_) {\
		MLB_OPEN(MLB_OPEN(__stream)->parentTransaction_)->transactionKind_ = MLBufferNoTransactionKind; \
	} \
	MLB_OPEN(__stream)->parentTransaction_ = nil; \
	MLB_OPEN(__stream)->transactionKind_ = MLBufferNoTransactionKind; \
} while(0)

#define MLStreamCommitTransaction(__stream) do { \
	CHECK_ISA_MLBUFFER(__stream); \
	MLAssert(MLB_OPEN(__stream)->transactionKind_ != MLBufferNoTransactionKind); \
	MLAssert(MLB_OPEN(__stream)->parentTransaction_); \
	if (MLB_OPEN(__stream)->transactionKind_ == MLBufferReadTransactionKind) {\
		int64_t pointerSurplus = MLB_OPEN(__stream)->pointer_ - MLB_OPEN(MLB_OPEN(__stream)->parentTransaction_)->pointer_; /* оно же lengthSlack */ \
		MLAssert(pointerSurplus >= 0); \
		id parent = MLB_OPEN(__stream)->parentTransaction_; \
		MLStreamRollbackTransaction(__stream); \
		MLBufferDrain(parent, pointerSurplus); \
	} else if (MLB_OPEN(__stream)->transactionKind_ == MLBufferWriteTransactionKind) { \
		int64_t lengthSurplus = MLB_OPEN(__stream)->length_; \
		MLAssert(lengthSurplus >= 0); \
		id parent = MLB_OPEN(__stream)->parentTransaction_; \
		MLStreamRollbackTransaction(__stream); \
		MLBufferWritten(parent, lengthSurplus); \
	} else { \
		MLFail("Unknown MLStream transaction kind"); \
	} \
} while(0)


