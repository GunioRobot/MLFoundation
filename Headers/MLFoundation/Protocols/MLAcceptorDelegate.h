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

@protocol MLAcceptor, MLBufferedEvent;

/** Клиент MLAcceptor'a.
 *
 * Как правило, владеющий акцептором сервер. 
 */
@protocol MLAcceptorDelegate
/** Акцептор получил новое соединение.
 * connection здесь готов к запуску, но не запущен и не имеет делегата. Преполагается, что клиент
 * акцептора создаст со своей стороный ответственный за обработку соединения объект-сессию,
 * и отдаст соединение ему во владение, иначе после коллбэка соединение будет закрыто.
 *
 * Ещё раз: connectionToRetain должен быть поретейнен.
 *
 * Какого именно класса connectionToRetain будет - зависит от конкретного класса Acceptor'а.
 *
 * Copyright 2009 undev
 */
- (void)acceptor:(id<MLAcceptor>)acceptor receivedConnection:(id<MLBufferedEvent>)connectionToRetain;

/** Случилась ошибка. Акцептор остановлен. */
- (void)acceptor:(id<MLAcceptor>)acceptor error:(NSError *)details;
@end
