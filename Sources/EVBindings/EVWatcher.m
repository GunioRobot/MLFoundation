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

#import <MLFoundation/EVBindings/EVWatcher.h>
#import <MLFoundation/MLCore/MLCategories.h>
#import <MLFoundation/MLCore/MLAssert.h>

#define self_watcher ((struct ev_watcher *)self)
   
@implementation EVWatcher
- init
{
	if (!(self = [super init])) {
		return nil;
	}

	ev_init(self_watcher, NULL); 

	return self;
}

- (void)setTarget:(id)target selector:(SEL)selector
{
	MLAssert(![self isActive]);
	ev_set_objc_cb(self_watcher, target, selector);
}

- (id)target
{
	return self_watcher->target;
}

- (SEL)selector
{
	return self_watcher->sel;
}

- (void)startOnLoop:(EVLoop *)loop
{
	[self subclassResponsibility:_cmd];
}

- (void)stopOnLoop:(EVLoop *)loop
{
	[self subclassResponsibility:_cmd];
}

- (BOOL)isActive
{
	return ev_is_active(self_watcher);
}

- (BOOL)isPending
{
	return ev_is_pending(self_watcher);
}

- (int)priority
{
	return ev_priority(self_watcher);
}

- (void)setPriority:(int)priority
{
	MLAssert(priority <= EV_MAXPRI);
	MLAssert(priority >= EV_MINPRI);
	ev_set_priority(self_watcher, priority);
}

- (void)invokeOnLoop:(EVLoop *)loop withEvents:(int)revents
{
	ev_invoke(EVLOOP_LOOP(loop), self_watcher, revents);
}

- (void)feedToLoop:(EVLoop *)loop withEvents:(int)revents
{
	ev_feed_event(EVLOOP_LOOP(loop), self_watcher, revents);
}

- (void)clearPendingOnLoop:(EVLoop *)loop
{
	ev_clear_pending(EVLOOP_LOOP(loop), self_watcher);
}

- (void)dealloc
{
	MLAssert(![self isActive]);
	MLAssert(![self isPending]);
	[super dealloc];
}
@end
