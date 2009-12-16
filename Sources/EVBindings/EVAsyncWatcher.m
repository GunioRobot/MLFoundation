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

#import <MLFoundation/EVBindings/EVAsyncWatcher.h>
#import <MLFoundation/MLCore/MLAssert.h>

#define self_async ((ev_async *)(self))

@implementation EVAsyncWatcher 
- init
{
	if (!(self = [super init])) {
		return nil;
	}

	ev_async_init(self_async, NULL); 

	return self;
}

- (void)startOnLoop:(EVLoop *)loop
{
	ev_async_start(EVLOOP_LOOP(loop),self_async);
}

- (void)stopOnLoop:(EVLoop *)loop
{
	ev_async_stop(EVLOOP_LOOP(loop),self_async);
}

- (void)asyncActivateOnLoop:(EVLoop *)loop
{
	MLAssert(ev_is_active(self_async));
	ev_async_send(EVLOOP_LOOP(loop),self_async);
}

- (BOOL)isAsyncPending
{
	return ev_async_pending(self_async);
}
@end

