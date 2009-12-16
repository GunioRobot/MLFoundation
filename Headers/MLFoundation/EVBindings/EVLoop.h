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

#import <Foundation/Foundation.h>

#include <libev/ev-mlf.h>

#define EVLOOP_LOOP(x) ((struct ev_loop *)(x))

/** Обёртка над ev_loop.
 *
 * EVLoop * можно свободно тайпкастить к struct ev_loop *, если не хватает 
 * реализованых методов-обёрток.
 *
 * Default event loop, на которую можно вешать обработчики сигналов, всегда
 * доступна как 
 *
 * @code
 * extern EVLoop *EVReactor;
 * @endcode
 *
 * На неё стоит полагаться только в корневых классах приложения, а в графах
 * объектов использовать протокол <MLEvLoopActivity>, и учить объекты привязывать
 * детей к своему event loop. 
 *
 *
 * Copyright 2009 undev
 */
@interface EVLoop : EVBaseLoop {
}
/** Enter event loop. */
- (void)run;

/** Force leave event loop. */
- (void)stop;

/** ev_now(). */
- (ev_tstamp)now;

/** ev_monotonic_now(). */
- (ev_tstamp)monotonicNow;

/** Notify event loop about fork. */
- (void)forked;
@end

/** Асинхронные сообщения.
 * 
 * @code
 * [[myObject async] errorOccured:anError];
 * @endcode
 *
 * Сообщение errorOccured будет получено на следующем обороте ивентлупа.
 *
 */
@interface NSObject (MLAsyncMessaging)
/** Вернуть трамплин для асинхронного сообщения на EVReactor. */
- async;
/** Вернуть трамплин для асинхронного сообщения на loop. */
- asyncOnLoop:(EVLoop *)loop;
@end

#ifndef EV_OBJC_HIDE_REACTOR
extern EVLoop *EVReactor;
#endif
