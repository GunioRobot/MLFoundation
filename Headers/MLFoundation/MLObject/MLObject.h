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

// Suppress warnings on OSX
#undef OBJC2_UNAVAILABLE
#define OBJC2_UNAVAILABLE

#import <Foundation/Foundation.h>
#import <libev/config.h>
#import <stdint.h>

#import <MLFoundation/MLObject/MLStackAllocator.h>

#if HAVE_OBJC_RUNTIME_H
#	import <objc/runtime.h>
#else
#	import <objc/objc.h>
#endif

@class MLObject;
typedef MLObject *md;

@protocol MLObject <NSObject>
+ (md)allocReified:(BOOL)reificationMark;
- (BOOL)isLifecycleExtended;
- (BOOL)isReified;
- (void)reify;
- (void)dealloc;
- (void)finalize;
@end

enum {
	MLObjectHeapAllocation = 0, // Heap allocation class MUST be 0
	MLObjectStackAllocation = 1,
	MLObjectBulkAllocation = 2
};

typedef int MLObjectAllocationClass;

/** Расширения NSObject.
 *
 * TODO: allocation ownership
 *
 * TODO: DOC: 
 *  - классы аллокации
 *  - extended lifecycle
 *  - pools
 *
 * TODO: методы для аллокации на куче с extended lifecycle
 *
 * TODO2:
 *  - все вызовы не@synchronized :)
 *
 *  allocPrefs_ layout:
 *  - 4 bits - alocation class
 *  - 1 bit - extended lifecycle
 *  - 3 bits - reserved
 *  - 24 bits - retainCount.
 *
 * Copyright 2009 undev
 */
@interface MLObject : NSObject <MLObject> {
	void *allocOwner_;
	uint32_t allocPrefs_;
}
/** Возвращает класс аллокации этого объекта. */
- (MLObjectAllocationClass)allocationClass;

/** Работает ли для этого объект extended lifecycle? */
- (BOOL)isLifecycleExtended;

/** Инициализирует объект, включая extended lifecycle. */
+ (md)allocReified:(BOOL)reificationMark;

/** Живой ли этот объект? */
- (BOOL)isReified;

/** Оживить не-reified объект. */
- (void)reify;

/** Превратить объект обратно в неживой. */
- (void)dealloc;

/** Убрать этот объект вместе с памятью. */
- (void)finalize;
@end

@interface MLObject (StackAllocationCallbacks)
/** Инициализирует под объект выделенную на стеке область. Используется как нотификация
 * от аллоцирующего макроса. Поддержка должна быть вынесена на уровень компилятора. */
+ (md)allocatedOnStack:(md)obj;

/** Инициализирует под объект выделенную на стеке область, включая extended 
 * lifecycle.  Используется как нотификация от аллоцирующего макроса. 
 * Поддержка должна быть вынесена на уровень компилятора. */
+ (md)allocatedOnStack:(md)obj reified:(BOOL)reificationMark;
@end

#define MLObject_instance_size(klass) (((Class)[klass class])->instance_size)

// Stack allocation:
#define MLObjectStackAlloc(klass) \
	(klass *)[[klass class] allocatedOnStack:MLStack_alloca(MLObject_instance_size(klass))]

#define MLObjectStackAllocReified(klass,isReified) \
	(klass *)[[klass class] allocatedOnStack:MLStack_alloca(MLObject_instance_size(klass)) \
	reified:isReified]
