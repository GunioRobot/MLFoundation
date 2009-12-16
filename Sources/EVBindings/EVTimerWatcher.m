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

#import <MLFoundation/EVBindings/EVTimerWatcher.h>
#import <MLFoundation/MLCore/MLAssert.h>

#define self_timer ((ev_timer *)(self))

@implementation EVTimerWatcher 
- (void)setAfter:(ev_tstamp)after
{
	MLAssert(!ev_is_active(self_timer));
	self_timer->at = after;
}

- (ev_tstamp)after
{
	return self_timer->at;
}

- (void)setRepeat:(ev_tstamp)repeat
{
	self_timer->repeat = repeat;
}

- (ev_tstamp)repeat
{
	return self_timer->repeat;
}

- (void)startOnLoop:(EVLoop *)loop
{
	MLAssert(self_timer->cb);
	ev_timer_start(EVLOOP_LOOP(loop),self_timer);
}

- (void)stopOnLoop:(EVLoop *)loop
{
	MLAssert(self_timer->cb);
	ev_timer_stop(EVLOOP_LOOP(loop),self_timer);
}

- (void)againOnLoop:(EVLoop *)loop
{
	MLAssert(self_timer->cb);
	ev_timer_again(EVLOOP_LOOP(loop),self_timer);
}
@end
