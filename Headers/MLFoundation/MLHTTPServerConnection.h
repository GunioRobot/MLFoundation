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
#import <MLFoundation/MLConnection.h>
#import <MLFoundation/Protocols/MLHTTPServerConnectionDelegate.h>
#import <MLFoundation/Protocols/MLBufferedEventDelegate.h>
#import <MLFoundation/Protocols/MLActivity.h>

/** Обработчик соединения с HTTP-сервером.
 *
 * HTTP-сервер в приложении устраивается на базе MLHTTPAcceptor таким, например, образом 
 *
 * @code
 * - (void)acceptor:(MLAcceptor *)acceptor receivedConnection:(id)connection
 * {
 *	MyHTTPServerConnectionDelegateImpl *client = 
 *		[[MyHTTPServerConnectionDelegateImpl alloc] init];
 *  
 *  [client setConnection:connection];
 *	
 *	[client start];
 * }
 * @endcode
 *
 * Потенциально может держать внутри очередь запросов (для keepalive и pipelining),
 * но отдаёт их на делегата по-одному. Поэтому для пользователя ведёт себя подобно
 * реюзабельному HTTPResponse.
 *
 * Процесс взаимодействия с пользователем: 
 *
 *  - setConnection:, validateForStart:, start. Начинает обрабатываться первый запрос.
 * 
 *  - Если в запросе попадается какая-то ошибка - отдаётся 500 или 501,
 *    делегат не трогается, соединение тихо разрывается.
 *  - Вызывается receivedRequestWithPath делегата
 *  - Если есть тело запроса и прописан Content-Length / Connection: close, оно читается
 *    делегату в haveNewDataInBuffer: / finishedLoadingBuffer:
 *  - Если было Connection: close , сначала вызывается finishedLoadingBuffer, потом
 *    connectionClosed делегата, и TCP-соединение закрывается.
 *  - от делегата ждут ответа: либо sendResponseWithStatus, либо beginSendResponseWithStatus...
 *  - на sendResponseWithStatus: обработка запроса заканчивается.
 *  - beginSendResponseWithStatus: проверяет, что в хедерах указано либо Connection: close,
 *    либо Content-Transfer-Encoding: chunked; в последнем случае пользователь обязуется
 *    упаковывать в чанки всё сам.
 *  - reponseStream отдаёт поток для отправки ответа.
 *  - на finishSendResponse обработка запроса заканчивается.
 *
 *  - Если TCP-соединение не закрыто (и MLHTTPServerConnection не остановлено, соответственно),
 *    то можно ждать следующего запроса.
 *
 * TODO: Сделать настоящий currentRequestProtocolVersion
 *
 * TODO: Сделать настоящий разбор заголовков запроса
 *
 * TODO: Возможность задавать заголовки ответа.  
 *
 * TODO: По-настоящему определять, есть ли body у запроса, и читать его, если есть.
 *
 * TODO: Всё, связаное с хедерами ответа.
 *       Для ответа потоком проверять, что стоит либо connection: close, либо 
 *       CTE: Chunked (и пользователь обязуется сам поддерживать chunked encoding)
 *
 * Copyright 2009 undev
 */
@interface MLHTTPServerConnection : NSObject <MLBufferedEventDelegate> {
	id<MLHTTPServerConnectionDelegate> delegate_;
	MLConnection *connection_;

	NSString *path_, *method_, *responseProtocol_;
	uint8_t state_;
	uint64_t contentLength_;
	NSMutableDictionary *currentRequestHeaders_;

	NSString *description_;
}
/** Установить полученое от MLTCPAcceptor'а соединение. */ 
- (void)setConnection:(MLConnection *)connection;
/** Underyling TCP-соединение. */
- (MLConnection *)connection;

/** Установить делегата. Делегат может быть в любой момент 
 * но делегат может быть в любой момент изменён - например, если в соединение нужно
 * отдавать поток. */
- (void)setDelegate:(id<MLHTTPServerConnectionDelegate>)delegate;
/** Делегат. */
- (id<MLHTTPServerConnectionDelegate>)delegate;

/** [RW] Sets request timeout. Default no timeout. */
- (void)setTimeout:(ev_tstamp)timeout;
/** Request timeout. */
- (ev_tstamp)timeout;

/** [RO] Sets response timeout. Default no timeout. */
- (void)setWriteTimeout:(ev_tstamp)timeout;
/** Response timeout. */
- (ev_tstamp)writeTimeout;

/** Отправить ответ без тела. */
- (void)sendResponseWithStatus:(NSUInteger)status reason:(NSString *)reason
	headers:(NSDictionary *)headers;

/** Отправить ответ с телом одним куском. Content-Length: выставляется автомагически. */
- (void)sendResponseWithStatus:(NSUInteger)status reason:(NSString *)reason
	headers:(NSDictionary *)headers data:(uint8_t *)data length:(NSUInteger)length;

/** Начать отправлять ответ. Требуется, чтобы в headers: было либо Connection: close
 * (и тогда после finishSendResponse соединение будет закрыто), либо Content-Transfer-Encoding:
 * chunked (и тогда пользователь обязуется сам правильно форматировать чанки), либо 
 * Content-Length (и тогда пользователь обязуется её соблюсти). 
 */
- (void)beginSendResponseWithStatus:(NSUInteger)status reason:(NSString *)reason
	headers:(NSDictionary *)headers;

/** Закончить отправлять ответ. */
- (void)finishSendResponse;

/** Вернуть поток для отправки ответа. */
- (id <MLStream>)responseStream;

/** Поменять протокол ответа с HTTP на что-то другое, например, ICY. */
- (void)setResponseProtocol:(NSString *)string;

/** Начать читать из буфера соединения и обрабатывать запросы. Вызвывается обычно
 * владельцем MLAcceptor'а. */
- (void)start;

/** Прекратить читать из буфера соединения и обрабатывать запросы. Самого соединения не
 * разрывает. Обычно вызывается только при деаллокации. */
- (void)stop;

/** Обрабатываем ли мы сейчас запросы? */
- (BOOL)isStarted;

/** Method for current request. Available only from delegate callbacks. */
- (NSString *)currentRequestMethod;

/** Headers for current request. Available only from delegate callbacks. */
- (NSDictionary *)currentRequestHeaders;

/** Path for current request. Available only from delegate callbacks. */
- (NSString *)currentRequestPath;

/** Protocol version (10 / 11) for current request. Available only from delegate callbacks. */
- (NSUInteger)currentRequestProtocolVersion;

/** Set description string */
- (void)setDescription:(NSString *)description;

@end
