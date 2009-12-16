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

#import <MLFoundation/MLCoroutine.h>

#import <MLFoundation/MLCore/MLAssert.h>

static MLCoroutine *mainCoroutine = nil, *currentCoroutine = nil;

static MLCoroutine *lastReactorCoro = nil;

@interface MLCoroutine (private)
- (id)initMainCoroutine;
@end

@implementation MLCoroutine
+ (void)load
{
	mainCoroutine = [[MLCoroutine alloc] initMainCoroutine];
	MLAssert(mainCoroutine);
	currentCoroutine = mainCoroutine;
}

+ (MLCoroutine *)current
{
	return currentCoroutine;
}

+ (MLCoroutine *)main
{
	return mainCoroutine;
}

- (id)initMainCoroutine
{
	if (!(self = [self init])) return nil;

	Coro_initializeMainCoro(coro_);
	started_ = YES;

	return self;
}

- (id)init
{
	if (!(self = [super init])) return nil;

	coro_ = Coro_new();

	return self;
}

- (BOOL)isCurrent
{
	return self == currentCoroutine;
}

- (BOOL)isStarted
{
	return started_;
}

- (BOOL)stackSpaceAlmostGone
{
	return Coro_stackSpaceAlmostGone(coro_);
}

static void EventLoopTrampoline(EVLoop *loop)
{
	MLCoroutine *current = currentCoroutine;
	[loop run];
	
	lastReactorCoro = current;
	// Мы вышли из ивентлупа - значит, надо возвращаться домой, в главную копрограму.
	[mainCoroutine resume];
}

- (void)runEventLoop:(EVLoop *)loop
{
	MLAssert(!started_);
	started_ = YES;

	MLCoroutine *current = currentCoroutine;
	currentCoroutine = self;

	Coro_startCoro_(current->coro_, coro_, loop, (CoroStartCallback *)EventLoopTrampoline);
}

- (void)startEventLoopFromMainCoro:(EVLoop *)loop
{
	[self runEventLoop:loop];

	MLAssert(lastReactorCoro);
	[lastReactorCoro release];
}

- (void)resume
{
	MLAssert(started_);

	MLCoroutine *current = currentCoroutine;
	currentCoroutine = self;
	Coro_switchTo_(current->coro_, coro_);
	currentCoroutine = current;
	
}

- (void)dealloc
{
	MLAssert(mainCoroutine != self);
	MLAssert(currentCoroutine != self);

	if (coro_) Coro_free(coro_);
	[super dealloc];
}
@end
