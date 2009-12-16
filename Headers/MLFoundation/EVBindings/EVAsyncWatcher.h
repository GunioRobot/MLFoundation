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

/** Обёртка над ev_async. */ 
@interface EVAsyncWatcher : EVWatcher {
}
/** Вызвать его из другого треда (или обработчика сигнала). */
- (void)asyncActivateOnLoop:(EVLoop *)loop;

/** Вызван ли он из другого треда (или обработчика сигнала)? */
- (BOOL)isAsyncPending;
@end

