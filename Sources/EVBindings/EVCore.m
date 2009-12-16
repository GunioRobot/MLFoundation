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

#include <libev/ev-mlf.h>
#include <MLFoundation/MLCore/MLIdioms.h>
#ifndef UINT_MAX
#  define UINT_MAX 4294967295
#endif


static id autoreleasePoolClass = NULL;
static IMP autoreleasePoolNew = NULL;
static IMP autoreleasePoolRelease = NULL;
static IMP autoreleasePoolDrain = NULL;

#define EV_USE_AUTORELEASEPOOL 1

#define EV_AUTORELEASEPOOL_NEW(x) x = \
	(*autoreleasePoolNew)(autoreleasePoolClass, @selector(new))
#define EV_AUTORELEASEPOOL_RELEASE(x) (*autoreleasePoolRelease)(x, @selector(release)); (x)=nil

#if defined(__NEXT_RUNTIME__) 
#	define EV_AUTORELEASEPOOL_DRAIN(x) do { \
	(*autoreleasePoolRelease)((x), @selector(release)); \
	(x) = (*autoreleasePoolNew)(autoreleasePoolClass, @selector(new)); \
} while(0)
#elif defined(GS_API_VERSION)
#	define EV_AUTORELEASEPOOL_DRAIN(x) do { \
	(*autoreleasePoolDrain)((x), @selector(emptyPool)); \
} while(0)
#else
#	error "Unsupported objc foundation lib!"
#endif

#include "../libev/ev.c"

@implementation EVBaseWatcher
@end

static EVBaseLoop *defaultEventLoop = NULL;

@implementation EVBaseLoop 
+ (void)load
{
	autoreleasePoolClass = [NSAutoreleasePool class];
	autoreleasePoolNew = [[NSAutoreleasePool class] methodForSelector:@selector(new)];
	autoreleasePoolDrain = [[NSAutoreleasePool class] 
		instanceMethodForSelector:@selector(emptyPool)];
	autoreleasePoolRelease = [[NSAutoreleasePool class] 
		instanceMethodForSelector:@selector(release)];
}

+ defaultEventLoop
{
	if (!defaultEventLoop) {
		struct ev_loop *l = ev_default_loop(0);
		l->isa = [self class];
		defaultEventLoop = (id)l;
	}
	return [defaultEventLoop init];
}

+ (void)destroyDefaultEventLoop
{
	[defaultEventLoop dealloc];
}

+ alloc
{
	struct ev_loop *l = ev_loop_new(0);
	l->isa = [self class];
	return (id)l;
}

+ allocWithZone:(NSZone *)zone
{
	return [self alloc];
}

- retain
{
	return self;
}

- (void)release
{
}

- (NSUInteger)retainCount
{
	return UINT_MAX;
}

- (void)dealloc
{
	if (ev_is_default_loop((struct ev_loop *)self)) {
		ev_default_destroy();
		defaultEventLoop = NULL;
	} else {
		ev_loop_destroy((struct ev_loop *)self);
	}
	MLNoSuperDealloc();
}
@end
