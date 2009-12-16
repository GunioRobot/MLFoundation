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

/** Клиентское TCP-соединение. 
 *
 * В отличии от MLAcceptor, ошибка при коннекте обрабатывается асинхронно, и сам
 * коннект происходит при старте: 
 * Почти всегда на неудачную попытку коннекта нужно продолжать попытки.
 *
 * Copyright 2009 undev
 * */
@interface MLTCPClientConnection : MLConnection {
@private
	NSError *connectError_;

	NSString *host_;
	uint16_t port_;
	struct sockaddr_in addr_;
}
/** [RO, MANDATORY] Set IP address to connect. */
- (void)setHost:(NSString *)host;
/** IP address to connect. */
- (NSString *)host;

/** [RO, MANDATORY] Set TCP port to connect. */
- (void)setPort:(uint16_t)port;
/** TCP port to connect. */
- (uint16_t)port;
@end

