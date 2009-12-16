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

#import <MLFoundation/EVBindings/EVWatcher.h>

/** Обёртка над ev_timer.
 * Настоятельно рекомендуется прочитать документацию к libev в части be smart about timeouts.
 * В особенности про ev_timer_again(). */
@interface EVTimerWatcher : EVWatcher {
}
/** Установить время до первого срабатывания. */
- (void)setAfter:(ev_tstamp)after;
/** Время до первого срабатывания. */
- (ev_tstamp)after;

/** Установить интервал повторных срабатываний. */
- (void)setRepeat:(ev_tstamp)repeat;
/** Интервал повторных срабатываний. */
- (ev_tstamp)repeat;

/** ev_timer_again(), подробности в документации к libev. */
- (void)againOnLoop:(EVLoop *)loop;
@end
