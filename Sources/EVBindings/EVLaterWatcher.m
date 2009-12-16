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

#import <MLFoundation/EVBindings/EVLaterWatcher.h>
#import <MLFoundation/MLCore/MLAssert.h>

#define self_lat ((ev_later *)(self))

@implementation EVLaterWatcher 
- init
{
	if (!(self = [super init])) {
		return nil;
	}

	ev_later_init(self_lat, NULL); 

	return self;
}

- (void)startOnLoop:(EVLoop *)loop
{
	MLAssert(self_lat->cb);
	ev_later_start(EVLOOP_LOOP(loop),self_lat);
}

- (void)stopOnLoop:(EVLoop *)loop
{
	MLAssert(self_lat->cb);
	ev_later_stop(EVLOOP_LOOP(loop),self_lat);
}

- (BOOL)isPending
{
	return ev_is_pending(self_lat) || ev_later_pending(self_lat);
}

- (void)feedLaterToLoop:(EVLoop *)loop withEvents:(int)revents
{
	ev_later_feed(EVLOOP_LOOP(loop), self_lat, revents);
}

- (void)clearPendingOnLoop:(EVLoop *)loop
{
	ev_later_clear_pending(EVLOOP_LOOP(loop), self_lat);
}
@end
