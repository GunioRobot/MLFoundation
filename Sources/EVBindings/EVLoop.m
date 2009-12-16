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

#import <MLFoundation/EVBindings/EVLoop.h>
#import <MLFoundation/MLCore/MLLogger.h>
#import <MLFoundation/MLCore/MLAssert.h>
#import <MLFoundation/EVBindings/EVLaterWatcher.h>

// XXX FIXME - зависимость изнаружи.
#import <MLFoundation/MLCoroutine.h>

#include <stdlib.h>

EVLoop *EVReactor = NULL;

#define self_loop ((struct ev_loop *)(self))

@interface EVLoop (MLAsyncMessagePassing)
- (void)addAsyncInvocation:(NSInvocation *)anInvocation;
@end

@interface MLAsyncTrampoline : NSProxy {
@public
	id target_;
	EVLoop *loop_;
}
@end

static MLAsyncTrampoline *SharedAsyncTrampoline = nil;

@interface EVLoop (MLCoroutine)
/** Enter event loop in current coroutine. */
- (void)runInCurrentCoroutine;
@end

@implementation EVLoop
static void ev_syserror(const char *msg)
{
	MLFail("libev fatal error: %s", msg);
}

void destroy_shared_reactor(void)
{
	[EVLoop destroyDefaultEventLoop];

	[SharedAsyncTrampoline release];

	EVReactor = NULL;

#ifdef WIN32
	WSACleanup();
#endif
}

+ (void)load
{
#ifdef WIN32
	WORD wVersionRequested = MAKEWORD(2,2);
	WSADATA wsaData;
	if (WSAStartup(wVersionRequested, &wsaData)) {
		WSACleanup();
		MLFail("FATAL: Unable to init winsock, exiting");
	}
#endif

	ev_set_syserr_cb(ev_syserror);

	EVReactor = [EVLoop defaultEventLoop];
	MLFailUnless(EVReactor, "FATAL: Unable to initialize libev shared reactor!");

	SharedAsyncTrampoline = [MLAsyncTrampoline alloc];
	MLFailUnless(SharedAsyncTrampoline, "FATAL: Unable to initialize shared asynchronous messaging trampoline!");

	atexit(destroy_shared_reactor);
}

- init
{
	if (!(self = [super init])) return nil;

	// We are not in zone!
	userData_ = (id)calloc(3, sizeof(id));
	if (!userData_) {
		[self dealloc];
		return nil;
	}
#define asyncInvocationsWatcher_ (((id *)userData_)[0])
#define asyncInvocationsExecuting_ (((id *)userData_)[1])
#define asyncInvocationsQueue_ (((id *)userData_)[2])
	asyncInvocationsExecuting_ = [[NSMutableArray alloc] initWithCapacity: 1024];
	if (!asyncInvocationsExecuting_) {
		[self dealloc];
		return nil;
	}
	asyncInvocationsQueue_ = [[NSMutableArray alloc] initWithCapacity: 1024];
	if (!asyncInvocationsQueue_) {
		[self dealloc];
		return nil;
	}
	asyncInvocationsWatcher_ = [[EVLaterWatcher alloc] init];
	if (!asyncInvocationsWatcher_) {
		[self dealloc];
		return nil;
	}

	[(EVLaterWatcher *)asyncInvocationsWatcher_ setTarget:self selector:@selector(performAsyncInvocations)];

	return self;
}

- (void)performAsyncInvocations
{
	[asyncInvocationsExecuting_ addObjectsFromArray:asyncInvocationsQueue_];
	[asyncInvocationsQueue_ removeAllObjects];

	while ([asyncInvocationsExecuting_ count] > 0) {
		NSInvocation *invocation = [[[asyncInvocationsExecuting_ objectAtIndex:0] retain] autorelease];
		[asyncInvocationsExecuting_ removeObjectAtIndex:0];
		[invocation invoke];
	}

	if (![(EVLaterWatcher *) asyncInvocationsWatcher_ isPending]) {
		[(EVLaterWatcher *)asyncInvocationsWatcher_ stopOnLoop:self];
	}
}

- (void)addAsyncInvocation:(NSInvocation *)anInvocation
{
	[anInvocation retainArguments];
	MLAssert([[anInvocation methodSignature] methodReturnLength] == 0);
	MLAssert(!strcmp([[anInvocation methodSignature] methodReturnType], "v"));

	[asyncInvocationsQueue_ addObject:anInvocation];

	if (![(EVLaterWatcher *) asyncInvocationsWatcher_ isActive]) {
		[(EVLaterWatcher *)asyncInvocationsWatcher_ startOnLoop:self];
	}

	[(EVLaterWatcher *)asyncInvocationsWatcher_ feedLaterToLoop:self withEvents:EV_ASYNC];
}

- (void)forked
{
	if (EVReactor == self) {
		ev_default_fork();
	} else {
		ev_loop_fork((struct ev_loop *)self);
	}
}

- (void)runInCurrentCoroutine
{
	ev_loop(self_loop,0);
}

- (void)run
{
#ifdef WIN32
	[self runInCurrentCoroutine];
	return;
#endif
	if ([MLCoroutine main] == [MLCoroutine current]) {
		MLCoroutine *reactorCoro = [MLCoroutine new];
		[reactorCoro startEventLoopFromMainCoro:self];
	} else {
		[self runInCurrentCoroutine];
	}
}

- (ev_tstamp)now
{
	return ev_now(self_loop);
}

- (ev_tstamp)monotonicNow
{
	return ev_monotonic_now(self_loop);
}

- (void)stop
{
	ev_unloop(self_loop, EVUNLOOP_ALL);
}

- (void)dealloc
{
	if (userData_) {
		[(NSObject *)asyncInvocationsQueue_ release];
		[(NSObject *)asyncInvocationsExecuting_ release];
		[(EVLaterWatcher *)asyncInvocationsWatcher_ stopOnLoop:self];
		[(NSObject *)asyncInvocationsWatcher_ release];
		free(userData_);
#undef asyncInvocationsExecuting_
#undef asyncInvocationsQueue_
#undef asyncInvocationsWatcher_
	}
	[super dealloc];
}
@end

@implementation MLAsyncTrampoline 
- (void)forwardInvocation:(NSInvocation *)invocation
{
	[invocation setTarget:target_];
	[loop_ addAsyncInvocation:invocation];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel
{
	return [target_ methodSignatureForSelector:sel];
}
@end

@implementation NSObject (MLAsyncMessaging)
- async
{
	SharedAsyncTrampoline->loop_ = EVReactor;
	SharedAsyncTrampoline->target_ = self;
	return SharedAsyncTrampoline;
}

- asyncOnLoop:(EVLoop *)loop
{
	SharedAsyncTrampoline->loop_ = loop;
	SharedAsyncTrampoline->target_ = self;
	return SharedAsyncTrampoline;
}
@end
