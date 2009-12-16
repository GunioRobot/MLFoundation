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
#include <MLFoundation/EVBindings/EVLoop.h>

/** Обёртка над ev_watcher.
 *
 * Напрямую сбриджена с ним, то есть можно применять его так:
 *
 * @code
 * EVLoop *loop;
 * EVTimerWatcher *watcher;
 * ev_timer_start((struct ev_loop *)loop, (struct ev_timer_watcher *)watcher);
 * @endcode
 *
 * В этот класс вынесены общие для всех Watcher'ов настройки и методы.
 * Частные же разложены по подклассам:
 *
 * - EVIoWatcher
 * - EVTimerWatcher
 * - EVSignalWatcher
 * - EVAsyncWatcher
 * - Другие - to be done
 *
 * Оверхед от коллбэков внутрь objc заключается всего лишь в укладывании двух дополнительных 
 * параметров на стек и одного switch. :-) Ценой этого являются две вещи:
 *
 * - после того, как выставлен коллбэк, его нельзя трогать всяким method swizzling, class posing и прочими 
 *   затейливыми способами. Вообще, пользуясь этими биндингами вы фактически обязуетесь не менять единожды
 *   установившиеся отношения isa, селектора и его IMP-а.
 *
 * Ещё: большинство вызовов требуют явного указания EVLoop, на которой всё происходит. Ответственность
 * за правильное её указание всецело лежит на программисте. Как правило, EVLoop сохраняется в 
 * контексте MLEvLoopActivity.
 *
 * Copyright 2009 undev
 */ 
@interface EVWatcher : EVBaseWatcher {
}
/** Устанавливает коллбэк watcher'a.
 *
 * Сигнатура коллбэка должна быть одной из четырёх:
 *
 * - :(EVLoop*):(EVWatcher*):(int)event 
 * - :(EVWatcher*):(int)event 
 * - :(int)event 
 * - (без аргументов)
 *
 *  Иначе всё сломается.
 *
 */
- (void)setTarget:(id)target selector:(SEL)selector;
/** Callback target. */
- (id)target;
/** Callback selector. */
- (SEL)selector;

/** Активирует watcher на указаной loop. Он начинает получать свои события и дёргать коллбэки.
 * Watcher не может быть активирован несколько раз, и, как следствие, может быть активен только 
 * на одной event loop.
 */
- (void)startOnLoop:(EVLoop *)loop;
/** Снимает watcher с указаной loop. */
- (void)stopOnLoop:(EVLoop *)loop;

/** Активен ли этот watcher? */
- (BOOL)isActive;
/** Есть ли для этого watcher сейчас события? */
- (BOOL)isPending;

/** Приоритет watcher'а. Подробнее см. инструкцию к libev. */
- (int)priority;
/** Установить приоритет watcher'а. Подробнее см. инструкцию к libev. */
- (void)setPriority:(int)priority;

/** Разбудить этот ватчер с указаными revents. */
- (void)feedToLoop:(EVLoop *)loop withEvents:(int)revents;

/** Принудительно разбудить этот watcher на loop с указаными revents. */
- (void)invokeOnLoop:(EVLoop *)loop withEvents:(int)revents;

/** Принудительно снять активный ивент с этого watcher'а на loop. */
- (void)clearPendingOnLoop:(EVLoop *)loop;
@end
