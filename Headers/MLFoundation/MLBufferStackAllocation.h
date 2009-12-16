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
#import <MLFoundation/MLStreamFastAccess.h>

/* Набор макросов для MLBuffer'ов на стеке. TODO: FIXDOC! */

/** Выделяет на стеке новый пустой буфер размера size. */
#define MLLocalBufferNew(__size) \
({ \
	uint8_t *data = MLObject_alloca(__size); \
	[MLObjectStackAlloc(MLBuffer) initWithPreallocated:data size:(uint64_t)0 capacity:(uint64_t)__size]; \
})

/** Выделяет на стеке новый буфер, оборачивающий size байт с bytes. Буфер рождается с length == capacity == maxSize. */
#define MLWrapBufferNew(__data, __size) \
({ \
	[MLObjectStackAlloc(MLBuffer) initWithPreallocated:__data size:(uint64_t)__size capacity:(uint64_t)__size]; \
})
