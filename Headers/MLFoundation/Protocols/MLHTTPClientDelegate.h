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

@class MLHTTPClient, MLBuffer;

/** Делегат HTTP-клиента.
 *
 *  Если в receivedResponseWithStatus haveBody == NO, то запрос обработан и клиент stopped.
 *  Иначе вызывается 0+ haveNewDataInBuffer и 1 finishedLoadingbuffer:
 *
 * 	Делегату разрешается делать с буфером всё, что угодно. Между вызовами 
 * 	haveNewDataInBuffer и finishedLoading/failedWithError HTTP-клиент будет
 * 	делать в буфер только Reserve & Written.
 *
 * Copyright 2009 undev
 */
@protocol MLHTTPClientDelegate
/** Получены все заголовки ответа и статус. Делегат может получить их через методы клиента. */ 
- (void)httpClient:(MLHTTPClient *)client receivedResponseWithBody:(BOOL)haveBody;

/** В буфере появилась новая часть тела ответа. */
- (void)httpClient:(MLHTTPClient *)client haveNewDataInBuffer:(id<MLStream>)buffer;
/** В буфер прочитан весь ответ. HTTPClient остановлен. */
- (void)httpClient:(MLHTTPClient *)client finishedLoadingBuffer:(id<MLStream>)buffer;

/** Случилась ошибка. Клиент остановлен. */
- (void)httpClient:(MLHTTPClient *)client failedWithError:(NSError *)error;
@end
