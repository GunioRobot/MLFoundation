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
#import <MLFoundation/EVBindings/EVLoop.h>
#import <MLFoundation/EVBindings/EVWatcher.h>
#import <MLFoundation/Protocols/MLActivity.h>

/** Обобщённый процесс, управляемый событиями с EVLoop. */
@protocol MLEvLoopActivity <MLActivity>
/** [RO, MANDATORY] Sets this process event loop. */
- (void)setLoop:(EVLoop *)loop;
/** Event loop this loop. */
- (EVLoop *)loop;

/** Запускает watcher на этой evloop. */
- (void)startWatcher:(EVWatcher *)watcher;

/** Останавливает watcher на этой evloop. */
- (void)stopWatcher:(EVWatcher *)watcher;
@end
