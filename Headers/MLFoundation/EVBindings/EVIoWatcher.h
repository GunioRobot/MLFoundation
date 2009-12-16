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

/** Обёртка над ev_io. */
@interface EVIoWatcher : EVWatcher {
@private
	BOOL shouldNeverStart_;
}
/** Создать обёртку над ev_io для фейкового ввода-вывода, не привязанного к сокету и только для feedToLoop. */
- (id)initForFakeIo;
/** Установить файловый дескриптор, за событиями на котором следить. */
- (void)setFd:(int)fd;
/** Файловый дескриптор, за событиями на котором следит ватчер. */
- (int)fd;

/** Установить события, за которыми следить: EV_READ | EV_WRITE .*/
- (void)setEvents:(int)events;
/** События, за которыми следит ватчер. */
- (int)events;
@end
