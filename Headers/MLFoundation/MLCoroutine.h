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

#include <Foundation/Foundation.h>
#import <libcoroutine/Coro.h>
#import <MLFoundation/EVBindings/EVLoop.h>

/** Ко-программа. 
 *
 * 	Простая обвязка для libcoroutine.
 *
 **/
@interface MLCoroutine : NSObject {
@public
	Coro *coro_;
@private
	BOOL started_;
}
/** Работающая сейчас копрограмма. */
+ (MLCoroutine *)current;

/** Копрограмма, в которой был запущен main. */
+ (MLCoroutine *)main;

/** Работает ли эта копрограмма сейчас? */
- (BOOL)isCurrent;

/** Запущена ли эта копрограмма? */
- (BOOL)isStarted;

/** Надо ли перезапустить эту копрограмму, потому что место на её стеке почти кончилось? */
- (BOOL)stackSpaceAlmostGone;

/** Запустить event loop в этой копрограмме и уйти в неё. */
- (void)runEventLoop:(EVLoop *)loop;

/** Продолжить выполнение этой копрограммы. */
- (void)resume;

// Semi-private интерфейс запуска реактора
- (void)startEventLoopFromMainCoro:(EVLoop *)loop;
@end
