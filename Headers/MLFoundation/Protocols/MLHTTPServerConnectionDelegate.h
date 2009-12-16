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
#import <MLFoundation/Protocols/MLStream.h>

@class MLHTTPServerConnection;

/** Делегат соединения с HTTP-сервером.
 * 
 * Если в receivedConnection: haveBody было true, то до finishedLoadingBuffer
 * отправлять ответ нельзя.
 *
 * Copyright 2009 undev
 */
@protocol MLHTTPServerConnectionDelegate
/** Получен новый запрос. Заголовки можно получить по необходимости через 
 * [connection currentRequestHeaders]. 
 *
 * Если haveBody == YES, то за этим вызовом последует ноль или несколько 
 * httpConnection:haveNewDataInBuffer: и один вызов httpConnection:finishedLoadingBuffer:
 * сообщающих о загрузке тела запроса. 
 *
 * Если же haveBody == NO, можно отправлять ответ.
 *
 **/
- (void)httpConnection:(MLHTTPServerConnection *)connection receivedRequestWithBody:(BOOL)haveBody;

/** В буфере появилась новая часть тела запроса. */
- (void)httpConnection:(MLHTTPServerConnection *)client 
	haveNewDataInBuffer:(id<MLStream>)buffer;
/** В буфер прочитано всё тело запроса. Можно отправлять ответ. */
- (void)httpConnection:(MLHTTPServerConnection *)client 
	finishedLoadingBuffer:(id<MLStream>)buffer;

/** Клиент отключился, TCP-соединение закрыто. Пока не дадут нового MLConnection,
 * новых запросов не будет; если был открыт канал на отсылку body, он закрыт. */
- (void)httpConnectionClosed:(MLHTTPServerConnection *)connection;
/** На TCP-соединении произошла ошибка, оно закрыто. Пока не дадут нового MLConnection,
 * новых запросов не будет; если был открыт канал на отсылку body, oн закрыт. */
- (void)httpConnection:(MLHTTPServerConnection *)connection closedWithError:(NSError *)error;
@end
