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

#import <MLFoundation/MLStream.h>

#import <MLFoundation/MLCore/MLCategories.h>

#if __OBJC2__
@synthesize inputBuffer = inputBuffer_;
#endif

@implementation MLStream
- (uint64_t)length
{
	[self subclassResponsibility:_cmd];
	return 0;
}

- (uint8_t *)bytes
{
	[self subclassResponsibility:_cmd];
	return NULL;
}

- (BOOL)drainBytes:(uint64_t)n
{
	[self subclassResponsibility:_cmd];
	return NO;
}

- (uint8_t *)reserveBytes:(uint64_t)n
{
	[self subclassResponsibility:_cmd];
	return NULL;
}

- (BOOL)writtenBytes:(uint64_t)m
{
	[self subclassResponsibility:_cmd];
	return NO;
}
@end
