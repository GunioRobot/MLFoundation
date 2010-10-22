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

#import <MLFoundation/MLCore/MLSessionSet.h>
#import <MLFoundation/MLCore/MLAssert.h>

@interface MLSessionSetEnumerator(private)
- (id)initWithHashTable:(NSHashTable *)table;
@end



@implementation MLSessionSet
- init
{
	return [self initWithCapacity:DEFAULT_SESSION_SET_CAPACITY];
}

- (id)initWithCapacity:(NSUInteger)capacity
{
	if (!(self = [super init])) return nil;

	sessions_ = NSCreateHashTable(NSNonRetainedObjectHashCallBacks, capacity);
	if (!sessions_) {
		[self release];
		return nil;
	}

	return self;
}

- (void)addObject:(id)object
{
	MLAssert(sessions_);
	NSHashInsert(sessions_, object);
}

- (void)removeObject:(id)object
{
	if (sessions_) NSHashRemove(sessions_, object);	
}

- (BOOL)containsObject:(id)anObject
{
	if (sessions_) {
		return !!NSHashGet(sessions_, anObject);
	} else {
		return NO;
	}
}

- (NSString *)description
{
	return NSStringFromHashTable(sessions_);
}

- (NSUInteger)count
{
	return NSCountHashTable(sessions_);
}

- (NSEnumerator *)objectEnumerator
{
	return [[[MLSessionSetEnumerator alloc] initWithHashTable:sessions_] autorelease];
}

- (void)makeObjectsPerformSelector:(SEL)selector
{
	NSHashEnumerator e = NSEnumerateHashTable(sessions_);
	id object;
	while ((object = (id)NSNextHashEnumeratorItem(&e))) {
		[object performSelector:selector];
	}
	NSEndHashTableEnumeration(&e);
}

- (void)dealloc
{
	NSHashTable *sessions = sessions_;
	sessions_ = NULL;

	NSHashEnumerator e = NSEnumerateHashTable(sessions);
	id object;
	while ((object = (id)NSNextHashEnumeratorItem(&e))) {
		[object release];
	}
	NSEndHashTableEnumeration(&e);

	NSFreeHashTable(sessions);

	[super dealloc];

}
@end

@implementation MLSessionSetEnumerator(private)
- (id)initWithHashTable:(NSHashTable *)table
{
	if (!(self = [super init])) return nil;

	hashTable_ = table;
	e_ = NSEnumerateHashTable(hashTable_);
	return self;
}
@end

@implementation MLSessionSetEnumerator
- allObjects
{
	return NSAllHashTableObjects(hashTable_);
}

- nextObject
{
	return NSNextHashEnumeratorItem(&e_);
}

- (void)dealloc
{
	NSEndHashTableEnumeration(&e_);
	[super dealloc];
}
@end
