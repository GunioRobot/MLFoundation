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
#import <MLFoundation/Protocols/MLAcceptor.h>
#import <MLFoundation/Protocols/MLAcceptorDelegate.h>
#import <MLFoundation/Protocols/MLMasterLink.h>
#import <MLFoundation/MLEvLoopActivity.h>

@interface MLWorkerAcceptor : MLEvLoopActivity <MLAcceptor, MLMasterLink> {
	EVIoWatcher *ioWatcher_;
	id <MLAcceptorDelegate> delegate_;
}
/** Инициализирует акцептор на fd. fd должен быть AF_UNIX SOCK_DGRAM. Другой конец fd
 * должен быть воткнут в MLWorkerTunnel. */
- (id)initWithFd:(int)fd;

/** Тихо закрыться после форка. */
- (void)dropAfterFork;

- (void)acceptNewConnection:(int)connfd;

// Пересылает в мастер количество соединений.
- (void)updateConnectionCount:(uint32_t)connectionCount;
@end
