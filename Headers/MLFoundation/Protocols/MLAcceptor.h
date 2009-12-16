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
#import <MLFoundation/Protocols/MLActivity.h>

@protocol MLAcceptorDelegate;

/** Абстрактный акцептор.
 *
 * Обёртка для listen и accept(). Ждёт соединений на чём-то и передаёт их MLAcceptorDelegate.
 *
 * В библиотеке существуют три класса, имплмементирующих этот интерфейс:
 *
 * - MLTCPAcceptor, принимающий соединения на TCP-сокете.
 * - MLStreamTransportAcceptor, принимающий соединения по Stream Transport-у внутри воркера
 *   							многопроцессового приложения.
 *
 * Copyright 2009 undev
 */
@protocol MLAcceptor <MLActivity>
/** [RW] Установить делегата. */
- (void)setDelegate:(id <MLAcceptorDelegate>)delegate;
/** Делегат. */
- (id <MLAcceptorDelegate>)delegate;

/** Закрыть ненужный акцептор в чайлде после форка. После этого приходит в негодность и может
 * быть только released. */
- (void)dropAfterFork;
@end
