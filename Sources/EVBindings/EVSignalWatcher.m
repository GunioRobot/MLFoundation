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

#import <MLFoundation/EVBindings/EVSignalWatcher.h>
#import <MLFoundation/MLCore/MLAssert.h>

#define self_sig ((ev_signal *)(self))

@implementation EVSignalWatcher 
- (void)setSignalNo:(int)signal
{
	MLAssert(!ev_is_active(self_sig));
	ev_signal_set(self_sig, signal);
}

- (int)signalNo
{
	return self_sig->signum;
}

- (void)startOnLoop:(EVLoop *)loop
{
	MLAssert(self_sig->cb);
	ev_signal_start(EVLOOP_LOOP(loop),self_sig);
}

- (void)stopOnLoop:(EVLoop *)loop
{
	MLAssert(self_sig->cb);
	ev_signal_stop(EVLOOP_LOOP(loop),self_sig);
}

- (void)feedToLoop:(EVLoop *)loop withEvents:(int)revents
{
	ev_feed_signal_event(EVLOOP_LOOP(loop), self_sig->signum);
}
@end
