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

#import <MLFoundation/MLObject/MLValue.h>
#import <MLFoundation/MLObject/MLSerializableValue.h>

#import <MLFoundation/MLCore/MLCategories.h>

@implementation MLValue
- (id)initFromStream:(id<MLStream>)buf error:(NSError **)error
{
	if (!(self = [self init])) return nil;

	*error = [(id<MLSerializableValue>)self assignFromStream:buf];	
	if (*error) {
		[self release];
		return nil;
	}

	return self;
}

- (void)assign:(MLValue *)otherValue
{
	[self subclassResponsibility:_cmd];
}

- (BOOL)isEqual:(id)anObject
{
	[self subclassResponsibility:_cmd];
	return NO;
}

- (BOOL)isNull
{
	return (![self isLifecycleExtended] || [self isReified]);
}

- (id)copy
{
	id retval = [[[self class] alloc] init];
	[retval assign:self];
	return retval;
}
@end
