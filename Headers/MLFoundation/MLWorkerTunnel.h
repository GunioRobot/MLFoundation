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
#import <MLFoundation/Protocols/MLActivity.h>
#import <MLFoundation/MLEvLoopActivity.h>
#import <MLFoundation/MLConnection.h>
#import <MLFoundation/MLWorkerAcceptor.h>

/** Туннель к воркеру.
 *
 * TODO пространный дескрипшн.
 *
 * Copyright 2009 undev
 */
@interface MLWorkerTunnel : MLEvLoopActivity {
	EVIoWatcher *ioWatcher_;
	uint32_t connectionsCount_;
}
/** Создаёт сокетпару с акцептором на одном конце и туннелем к нему на другом. Всегда
 * обnilяет *tunnel и *acceptor. Возвращает NO если не получилось. И tunnel, и acceptor
 * не авторелизнуты.
 **/
+ (BOOL)createWorkerTunnel:(MLWorkerTunnel **)tunnel andAcceptor:(MLWorkerAcceptor **)acceptor;

/** Инициализирует туннель на fd. fd должен быть AF_UNIX SOCK_DGRAM. Другой конец fd
 * должен быть воткнут в MLWorkerAcceptor. */
- (id)initWithFd:(int)fd;

/** Передать воркеру соединение. Это должен быть MLConnection или подкласс. id здесь от
 * несогласованности с интерфейсом акцептора. (TODO!) */
- (void)passConnection:(id)connection;

/** Возвращет double со степенью занятости этого воркера (от 0 до double max). */
- (double)business;

/** Тихо закрыться после форка. */
- (void)dropAfterFork;
@end
