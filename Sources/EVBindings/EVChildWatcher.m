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

#import <MLFoundation/EVBindings/EVChildWatcher.h>
#import <MLFoundation/MLCore/MLAssert.h>

#define self_chl ((ev_child *)(self))

@implementation EVChildWatcher
- (void)setPID:(pid_t)pid
{
	MLAssert(!ev_is_active(self_chl));
	ev_child_init(self_chl, self_chl->cb, pid, 0);
}

- (int)pid
{
	if (self_chl->pid > 0) return self_chl->pid;
	return self_chl->rpid;
}

- (void)startOnLoop:(EVLoop *)loop
{
	MLAssert(self_chl->cb);
	ev_child_start(EVLOOP_LOOP(loop), self_chl);
}

- (void)stopOnLoop:(EVLoop *)loop
{
	MLAssert(self_chl->cb);
	ev_child_stop (EVLOOP_LOOP(loop), self_chl);
}
@end
