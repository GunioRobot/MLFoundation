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

#ifndef __EV_MLF_H__
#define __EV_MLF_H__

#include <Foundation/Foundation.h>
#include <assert.h>

#define EV_MULTIPLICITY 1
#define EV_OBJC_BRIDGING 1
#define EV_CONFIG_H <libev/config.h>

typedef void (*CB_5IMP)(id, SEL, void *, void *, int); 
typedef void (*CB_4IMP)(id, SEL, void *, int); 
typedef void (*CB_3IMP)(id, SEL, int); 
typedef void (*CB_2IMP)(id, SEL); 

#define EV_CB_DECLARE(type) \
	id target; \
	SEL sel; \
	int argCount; \
	CB_5IMP cb;

#define ev_set_cb(ev,cb_) do { \
	(ev)->target = NULL; \
	(ev)->argCount = 5; \
	(ev)->cb = (CB_5IMP) cb_; \
} while(0) 

#define ev_set_objc_cb(ev, target_, sel_) do { \
	(ev)->target = target_; \
	(ev)->sel= sel_; \
	NSMethodSignature *selSig_ = [target_ methodSignatureForSelector:sel_]; \
	(ev)->argCount = [selSig_ numberOfArguments]; \
	switch ((ev)->argCount) { \
	case 2: \
		break; \
	case 3: \
		assert(!strcmp([selSig_ getArgumentTypeAtIndex:2], "i")); \
		break; \
	case 4: \
		assert(!strcmp([selSig_ getArgumentTypeAtIndex:2], "@")); \
		assert(!strcmp([selSig_ getArgumentTypeAtIndex:3], "i")); \
		break; \
	case 5: \
		assert(!strcmp([selSig_ getArgumentTypeAtIndex:2], "@")); \
		assert(!strcmp([selSig_ getArgumentTypeAtIndex:3], "@")); \
		assert(!strcmp([selSig_ getArgumentTypeAtIndex:4], "i")); \
		break; \
	default:  \
		assert((ev)->argCount >= 2 && (ev)->argCount <= 5); \
		abort(); \
	} \
	(ev)->cb = (CB_5IMP)[target_ methodForSelector:sel_]; \
	assert((ev)->cb); \
} while(0)

/*
 * EV_OBJC_BRIDGING requires changing callback signature, hence it 
 * requires changing internal libev callbacks signatures too.
 *
 * callbacks can be set by funcs ev_init, ev_set_cb, ev_TYPE_init.
 * now libev uses 9 internal callbacks:
 * pipecb (+ 1 direct call)
 * once_cb_io
 * once_cb_to
 * childcb
 * infy_cb
 * stat_timer_cb (+forward decl. +1 direct call)
 * embed_io_cb
 * embed_prepare_cb
 * embed_fork_cb
 *
 * plus one commented out:
 *
 * embed_idle_cb
 */

#define EV_CB_INVOKE(watcher,revents) do { \
	switch ((watcher)->argCount) { \
	case 2: \
		((CB_2IMP)((watcher)->cb))((watcher)->target, (watcher)->sel); \
		break; \
	case 3: \
		((CB_3IMP)((watcher)->cb))((watcher)->target, (watcher)->sel, (revents)); \
		break; \
	case 4: \
		((CB_4IMP)((watcher)->cb))((watcher)->target, (watcher)->sel, (watcher), (revents)); \
		break; \
	case 5: \
		((watcher)->cb)((watcher)->target, (watcher)->sel, loop, (watcher), (revents)); \
		break; \
	default:  \
		assert(((watcher)->argCount >= 2) && ((watcher)->argCount <= 5)); \
		abort(); \
	} \
} while(0)

#define EV_COMMON

#include "../../libev/ev.h"

/** Низкоуровневая обёртка для хранения ev_any_watcher. */
@interface EVBaseWatcher : NSObject {
@private
	uint8_t opaque_data[sizeof(union ev_any_watcher) - sizeof(Class)];
}
@end

/** Низкоуровневая обертка для хранения ev_loop и грубой адаптации её к cocoa memory management.
 * Подклассы обязаны не добавлять instance variables, а пользоваться, если надо, userData_. */
@interface EVBaseLoop : NSObject {
	id userData_;
}
/** ev_default_loop(0). */
+ defaultEventLoop;
/** ev_default_destroy(). */
+ (void)destroyDefaultEventLoop;
/** ev_loop_new(0). */
+ alloc;
/** ev_loop_destroy(). */
- (void)dealloc;
/** no-op. */
- retain;
/** no-op. */
- (void)release;
/** returns UINT_MAX. */
- (NSUInteger)retainCount;
@end

#endif
