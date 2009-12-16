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

#import <MLFoundation/MLObject/MLObject.h>

#import <MLFoundation/MLCore/MLAssert.h>
#import <MLFoundation/MLCore/MLCategories.h>
#import <MLFoundation/MLCore/MLIdioms.h>


#define MLO_OPEN(mlo) ((struct { @defs( MLObject ) } *) mlo)
#define MLO_AP(mlo) (MLO_OPEN(mlo)->allocPrefs_)

#define MLObjectAllocClassGet(o) (MLO_AP(o) & 0x0f)
#define MLObjectAllocClassSet(o,val) do { MLO_AP(o) = (MLO_AP(o) & 0xfffffff0) | (val & 0x0f); } while (0)

#define MLObjectLCExtGet(o) ((MLO_AP(o) & 0x10) >> 4)
#define MLObjectLCExtSet(o,val) do { MLO_AP(o) = (MLO_AP(o) & 0xffffffef) | ((val & 0x01) << 4); } while(0)

#define MLObjectRetainCountGet(o) (MLO_AP(o) >> 8)
#define MLObjectRetainCountSet(o,val) do { MLO_AP(o) = (MLO_AP(o) & 0xff) | ((val & 0xffffff) << 8); } while(0)

#define MLObjectRetainCountInc(o) do { MLObjectRetainCountSet(o, (MLObjectRetainCountGet(o) + 1)); } while(0)
#define MLObjectRetainCountDec(o) do { MLObjectRetainCountSet(o, (MLObjectRetainCountGet(o) - 1)); } while(0)

#define MLObjectUseNativeRetainCount(o) (!MLObjectLCExtGet((o)) && (MLObjectAllocClassGet((o)) == MLObjectHeapAllocation))


@implementation MLObject
+ (md)allocReified:(BOOL)reificationMark
{
	md retval = (md)[super alloc];

	MLObjectLCExtSet(retval, YES);
	// Здесь класс аллокации известен заранее.
	if (reificationMark) MLObjectRetainCountSet(retval, 1);

	return retval;
}

+ (md)allocatedOnStack:(md)obj
{
	memset(obj, 0, MLObject_instance_size(self));
	MLO_OPEN(obj)->isa = self;
	MLObjectAllocClassSet(obj, MLObjectStackAllocation);
	// Здесь класс аллокации известен заранее.
	MLObjectRetainCountSet(obj, 1);
	return obj;
}

+ (md)allocatedOnStack:(md)obj reified:(BOOL)reificationMark
{
	obj = [self allocatedOnStack:obj];
	MLObjectLCExtSet(obj, YES);
	// Здесь класс аллокации известен заранее.
	if (!reificationMark) MLObjectRetainCountSet(obj, 0);
	return obj;
}

+ (void)bulkAllocated:(md)obj
{
	MLO_OPEN(obj)->isa = self;
	MLObjectAllocClassSet(obj, MLObjectBulkAllocation);
	// Bulk всегда с lifecycle extensions.
	MLObjectLCExtSet(obj, YES);
}

+ (id)allocWithZone:(NSZone *)zone
{
	[self notImplemented:_cmd];
	return nil;
}

+ (id) alloc
{
  return [super allocWithZone: NSDefaultMallocZone()];
}

- (id)copyWithZone:(NSZone *)zone
{
	[self notImplemented:_cmd];
	return nil;
}

- (id)copy
{
	return self;
}

- (NSZone *)zone
{
	[self notImplemented:_cmd];
	return NULL;
}

- (id)init
{
	MLAssert(!MLObjectLCExtGet(self) || [self retainCount] > 0, 
		"Trying to init unreified object with LC enabled!");
	return [super init];
}

- (BOOL)isReified
{
	return ([self retainCount] > 0);
}

- (void)reify
{
	MLAssert(MLObjectLCExtGet(self), "Extended lifecycle for object disabled!");
	MLAssert(!MLObjectRetainCountGet(self), "Trying to reify already reified object!");

	MLObjectRetainCountSet(self, 1);
}

- (id)retain
{
	MLAssert(!MLObjectLCExtGet(self) || [self retainCount] > 0, 
		"Trying to retain unreified object with LC enabled!");

	if (MLObjectUseNativeRetainCount(self)) {
		return [super retain];
	} else {
		MLObjectRetainCountInc(self);
		return self;
	}
}

- (void)release
{
	if (MLObjectUseNativeRetainCount(self)) {
		[super release];
	} else {
		MLAssert([self retainCount] > 0, "Releasing destroyed object!");
		MLObjectRetainCountDec(self);
		if (MLObjectRetainCountGet(self) == 0) [self dealloc];
	}
}


- (unsigned int)retainCount
{
	if (MLObjectUseNativeRetainCount(self)) {
		return [super retainCount];
	} else {
		return MLObjectRetainCountGet(self);
	}
}

- (MLObjectAllocationClass)allocationClass
{
	return MLObjectAllocClassGet(self);
}

- (BOOL)isLifecycleExtended
{
	return MLObjectLCExtGet(self);
}

- (void)finalize
{
	if (MLObjectLCExtGet(self) && MLObjectRetainCountGet(self) > 0) {
		[self dealloc];
	}

	switch (MLObjectAllocClassGet(self)) {
	case MLObjectHeapAllocation:
		[super dealloc];
		break;
	case MLObjectStackAllocation:
		memset(self, 0, MLObject_instance_size([self class]));
		break;
	case MLObjectBulkAllocation:
		/* Do nothing. */
		break;
	default:
		MLFail("Unknown allocation class %d!", MLObjectAllocClassGet(self));
	}
}

- (void)dealloc
{
	if (!MLObjectLCExtGet(self)) {
		[self finalize];
	} else {
		// LCExt включен, значит мы используем этот retainCount.
		// unreify us :)
		MLObjectRetainCountSet(self, 0);
		MLNoSuperDealloc();
	}
}
@end
