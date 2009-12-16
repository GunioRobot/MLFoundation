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
#import <MLFoundation/MLBuffer.h>
#import <MLFoundation/MLStream.h>

#define MLS_OPEN(mls) ((struct { @defs( MLStream ) } *) mls)
#define MLB_OPEN(mlb) ((struct { @defs( MLBuffer ) } *) mlb)

#define NSO_OPEN(mlb) ((struct { @defs( NSObject ) } *) mlb)
 
#if MLDEBUG > 1
#define CHECK_ISA(obj, klass) do { MLAssert(NSO_OPEN(obj)->isa == klass); } while(0)
#else
#define CHECK_ISA(obj, klass) 
#endif

#define CHECK_ISA_MLBUFFER(obj) CHECK_ISA(obj, MLBufferClass)

#define MLStreamWillRead(buf) do { \
	if (MLS_OPEN(buf)->isa != MLBufferClass) { \
		buf = MLS_OPEN(buf)->inputBuffer_; \
	} \
} while(0) 

#define MLStreamWillWrite(buf) \
	do { \
		if (MLS_OPEN(buf)->isa != MLBufferClass) { \
			buf = MLS_OPEN(buf)->outputBuffer_; \
		} \
} while(0) 
