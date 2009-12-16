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

#import <MLFoundation/EVBindings/EVStatWatcher.h>
#import <MLFoundation/MLCore/MLAssert.h>

#define self_stat ((ev_stat *)(self))

@implementation EVStatWatcher 

- (id)init
{
	if ((self = [super init])) {
		self_stat->wd = -2;
		self_stat->path = 0;
		self_stat->interval = 0;
	}
	return self;
}

- (void)setPath:(NSString *)path
{
	path_ = path;
	self_stat->path = [path_ UTF8String];
	[path_ retain];
}

- (NSString *)path
{
	return path_;
}

- (void)setInterval:(ev_tstamp)interval
{
	self_stat->interval = interval;
}

- (ev_tstamp)interval
{
	return self_stat->interval;
}

- (void)dealloc
{
	[path_ release];
	[super dealloc];
}

- (void)startOnLoop:(EVLoop *)loop
{
	MLAssert(self_stat->cb);
	ev_stat_start(EVLOOP_LOOP(loop),self_stat);
}

- (void)stopOnLoop:(EVLoop *)loop
{
	MLAssert(self_stat->cb);
	ev_stat_stop(EVLOOP_LOOP(loop),self_stat);
}

- (void)againOnLoop:(EVLoop *)loop
{
	MLAssert(self_stat->cb);
	ev_stat_stat(EVLOOP_LOOP(loop),self_stat);
}
@end
