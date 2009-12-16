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

#import <MLFoundation/MLEvLoopActivity.h>

#import <MLFoundation/MLCore/MLCategories.h>
#import <MLFoundation/MLCore/MLAssert.h>

@implementation MLEvLoopActivity
- (void)setLoop:(EVLoop *)loop
{
	loop_ = loop;
}

- (EVLoop *)loop
{
	return loop_;
}

- (BOOL)validateForStart:(NSError **)error
{
	MLAssert(loop_);
	return YES;
}

- (void)startWatcher:(EVWatcher *)watcher
{
	[watcher startOnLoop:loop_];
}

- (void)stopWatcher:(EVWatcher *)watcher
{
	[watcher stopOnLoop:loop_];
}

- (void)start
{
	[self subclassResponsibility:_cmd];
}

- (void)stop
{
	[self subclassResponsibility:_cmd];
}

- (BOOL)isStarted
{
	[self subclassResponsibility:_cmd];

	return NO; // dead code 
}
@end
