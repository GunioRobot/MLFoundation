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

#import <MLFoundation/MLStream/MLStream.h>

/** Потребитель MLStream'а.
 *
 * Получает от MLStream'а сообщения о случившихся событиях.
 *
 * Не все MLStream'ы одинаковы. Поэтому это - неформальный протокол. MLStream 
 * на setDelegate обязан проверять, какие методы делегат поддерживает
 * и не трогать остальные.
 *
 * MLStream позволяет останавливать или релизить себя из всех коллбэков.
 *
 */
@interface NSObject (MLStreamDelegate)
/** Количество данных во входном буфера потока превысило read watermark.
 * Вызывается только для MLStreams с haveInput. */
- (void)streamHasBytes:(id <MLStream>)stream;
/** Количество данных в выходном буфере потока опустилось ниже write watermark.
 * Вызывается только для MLStreams с haveOutput. */
- (void)streamHasSpace:(id <MLStream>)stream;

/** Случилась ошибка. Stream остановлен. Единственный обязательный метод. */
- (void)stream:(id <MLStream>)stream error:(NSError *)details;

/** Сработал таймаут. Вызывается только для MLStreams с haveTimeout.
 * what - код, являющийся OR'ом: 
 *
 * - EV_READ - таймаут чтения. Означает, что в поток давно ничего не получал
 *   		   снаружи (например, из сети).
 * - EV_WRITE - таймаут записи. Означает, что поток давно ничего не отправлял
 *   			в сеть. Это могло случиться как из-за того, что по ту сторону
 *   			потока никто не читает, так и из-за того, что с этой стороны
 *   			в поток никто не пишет. Это нужно отслеживать самостоятельно.
 *
 * Если этот метод не определён, то при таймауте Stream будет останавливаться
 * и вызываться stream:error:.
 *
 **/
- (void)stream:(id <MLStream>)stream timedOut:(int)what;
@end

