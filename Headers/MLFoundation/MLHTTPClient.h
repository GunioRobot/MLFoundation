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
#import <MLFoundation/Protocols/MLBufferedEventDelegate.h>
#import <MLFoundation/Protocols/MLHTTPClientDelegate.h>
#import <MLFoundation/MLTCPClientConnection.h>
#import <MLFoundation/MLEvLoopActivity.h>

/** HTTP-клиент.
 *
 * Оптимизирован для "много запросов на один хост:порт". 
 * В один момент времени исполняет один запрос (то есть не умеет pipelining),
 * поэтому для пользователя ведёт себя подобно реюзабельному HTTPResponse.
 *
 * Не является MLActivity, все свои ошибки сообщает асинхронно.
 *
 * Последовательность работы такова: 
 *  
 *  - init / setEvLoop
 *
 *  - Отправка запроса. Выполняется тремя методами в зависимости от тела запроса:
 *    - Если у запроса нет тела, то вызвать sendRequestWithMethod:url:headers:
 *      и ждать ответа.
 *    - Если тело запроса доступно прямо сейчас и в виде блока данных, то вызвать
 *      sendRequestWithMethod:url:headers:data:length: и ждать ответа.
 *    - Если тело имеет место быть только в виде потока, то вызвать beginSendRequestWithMethod:
 *      url:headers:, взять requestStream и писать, пока не надоест.
 *      Потом взывать finishSendRequest и ждать ответа.
 *   - Ожидание ответа.
 *   - На делегате вызывается receivedResponseWithBody:. Если haveBody == NO, то всё, 
 *     ответ получен.
 *   - Если haveBody == YES, то на делегате ноль или несколько раз дёргается 
 *     haveNewDataInBuffer, и в финале дёргается finishedLoadingBuffer. Ответ получен.
 *
 *  Правильность переданной url тоже лежит на совести клиента.
 *
 *  После того, как ответ получен, можно начинать новый запрос. 
 *  Покуда это возможно и покуда хост и порт не меняются, клиент будет пытаться держать 
 *  соединение открытым.
 *
 *  ! Это, к сожалению, только планы API, большей частью пока Not implemented. Мы работаем.
 *
 * TODO: Сделать настоящий currentResponseProtocolVersion
 *
 * TODO: Сделать настоящий currentResponseReason
 *
 * TODO: Сделать настоящий ленивый разбор загловков.
 *
 * TODO: Возможность задавать заголовки запроса. (а не игнорировать)
 *
 * TODO: По-настоящему определять, есть ли body у ответа.
 *
 * TODO: Проверять, что урла http://
 *
 * TODO: Всё, связанное с проверкой хедеров запроса. Чтобы сама собой ставилась 
 * 		 Content-Length [в методе который sendReq:...data:len: ], 
 * 		 требовалась бы Connection: close  / CTE Chunked / Content-Lentgth
 * 		 [ в start ]
 * 			
 * TODO: Пока позволяет HTTP/1.1, не разрывать соединения. Уметь определять длину
 * 	     ответа из Content-Length, а если нет ни Content-Legth, ни Connection: close,
 * 	     ругаться. Принудительно закрывать соединение только если поменялся host и/или port
 * 	     на sendRequest
 *
 * Copyright 2009 undev
 */
@interface MLHTTPClient : NSObject <MLBufferedEventDelegate> {
@private
	BOOL isStarted_;
	id<MLHTTPClientDelegate> delegate_;
	MLTCPClientConnection *conn_;

	NSURL *url_;
	NSString *method_;
	NSDictionary *requestHeaders_;
	NSUInteger status_;
	uint64_t contentLength_;
	uint8_t state_;
}
/** [RW] Set delegate. */
- (void)setDelegate:(id<MLHTTPClientDelegate>)delegate;
/** Delegate. */
- (id<MLHTTPClientDelegate>)delegate;

/** [RO, MANDATORY] Sets this client event loop. */
- (void)setLoop:(EVLoop *)loop;
/** Event loop of this client. */
- (EVLoop *)loop;

/** [RO] Sets request timeout. Default no timeout. */
- (void)setTimeout:(ev_tstamp)timeout;
/** Request timeout. */
- (ev_tstamp)timeout;

/** [RW] Sets read block size. 4096 by default. */
- (void)setReadSize:(NSUInteger)readSize;
/** Read block size. */
- (NSUInteger)readSize;

/** [RO] Sets response timeout. Default no timeout. */
- (void)setWriteTimeout:(ev_tstamp)timeout;
/** Response timeout. */
- (ev_tstamp)writeTimeout;

/** Отправить запрос без тела методом method на url. Клиент переходит в состояние 
 * ожидания ответа. */
- (void)sendRequestWithMethod:(NSString *)method url:(NSURL *)url 
		headers:(NSDictionary *)headers;

/** Отправить запрос с телом одним куском. Content-Length: выставляется автомагически. */
- (void)sendRequestWithMethod:(NSString *)method url:(NSURL *)url
	headers:(NSDictionary *)headers data:(uint8_t *)data length:(NSUInteger)length;

/** Начать отправлять запрос. Требуется, чтобы в headers: было либо Connection: close
 * (и тогда после finishSendRequest соединение будет закрыто), либо Content-Transfer-Encoding:
 * chunked (и тогда пользователь обязуется сам правильно форматировать чанки), либо 
 * Content-Length (и тогда пользователь сам обязуется её соблюдать). 
 *
 * Если в ходе запуска запроса возникла какая-либо ошибка, она сообщается асинхронно,
 * а возвращается NULL.
 **/
- (void)beginSendRequestWithMethod:(NSString *)method url:(NSURL *)url
	headers:(NSDictionary *)headers;

/** Вернуть поток для отправки запросов. */
- (id <MLStream>)requestStream;

/** Закончить отправлять запрос. */
- (void)finishSendRequest;

/** Отменить всё, связанное с текущим запросом. Разрывает соединение. */
- (void)cancelCurrentRequest;

/** Занимается ли сейчас клиент выполнением запроса? */
- (BOOL)isStarted;

/** Headers for current response. Available only from delegate callbacks. */
- (NSDictionary *)currentResponseHeaders;

/** Status for current response. Available only from delegate callbacks. */
- (NSUInteger)currentResponseStatus;

/** Status reason for current response. Available only from delegate callbacks. */
- (NSString *)currentResponseReason;

/** Content-Length for current response. Available only from delegate callback and only if given. */
- (uint64_t)currentResponseContentLength;

/** Protocol version (10 / 11) for current response. Available only from delegate callbacks. */
- (NSUInteger)currentResponseProtocolVersion;
@end
