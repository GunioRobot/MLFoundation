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
#import <MLFoundation/EVBindings/EVIoWatcher.h>
#import <MLFoundation/MLEvLoopActivity.h>
#import <MLFoundation/Protocols/MLAcceptor.h>
#import <MLFoundation/Protocols/MLAcceptorDelegate.h>

/** TCP - акцептор.
 *
 * Отдаёт делегату MLConnection.
 *
 * Copyright 2009 undev
 */
@interface MLTCPAcceptor : MLEvLoopActivity <MLAcceptor> {
@private
	id <MLAcceptorDelegate> delegate_;
	EVIoWatcher *acceptWatcher_;
	uint16_t port_;
	NSError *bindError_;
}
/** [RO, MANDATORY] Установить порт, на котором будет слушать акцептор. */
- (void)setPort:(uint16_t)port;
/** Порт, на котором слушает акцептор. */
- (uint16_t)port;
@end
