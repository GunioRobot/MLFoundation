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

#import <MLFoundation/EVBindings/EVIoWatcher.h>
#import <MLFoundation/MLCore/MLAssert.h>

#define self_io ((ev_io *)(self))

@implementation EVIoWatcher 
- (id)initForFakeIo
{
	if (!(self = [self init])) return nil;
	
	shouldNeverStart_ = YES;

	return self;
}

- (void)setFd:(int)fd
{
	MLAssert(!ev_is_active(self_io));
	MLAssert(!shouldNeverStart_);
	ev_io_set(self_io, fd, self_io->events);
}

- (int)fd
{
	return self_io->fd;
}

- (void)setEvents:(int)events
{
	MLAssert(!ev_is_active(self_io));
	MLAssert(!shouldNeverStart_);
	ev_io_set(self_io, self_io->fd, events);
}

- (int)events
{
	return self_io->events;
}

- (void)startOnLoop:(EVLoop *)loop
{
	MLAssert(self_io->cb);
	MLAssert(!shouldNeverStart_);
	ev_io_start(EVLOOP_LOOP(loop),self_io);
}

- (void)stopOnLoop:(EVLoop *)loop
{
	MLAssert(self_io->cb);
	ev_io_stop(EVLOOP_LOOP(loop),self_io);
}

- (void)feedToLoop:(EVLoop *)loop withEvents:(int)revents
{
	if (shouldNeverStart_) {
		[super feedToLoop:loop withEvents:revents];
	} else {
		ev_feed_fd_event(EVLOOP_LOOP(loop), self_io->fd, revents);
	}
}
@end
