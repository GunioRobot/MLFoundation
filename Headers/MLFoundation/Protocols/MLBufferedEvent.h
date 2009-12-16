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
#import <MLFoundation/Protocols/MLEvLoopActivity.h>
#import <MLFoundation/Protocols/MLStream.h>
#import <libev/ev-mlf.h>

@protocol MLBufferedEventDelegate;

/** Evented MLStream.
 * 
 * "Обратная сторона" MLStream'а - поток, который наполняется и опустошается какими-либо 
 * внешними событиями. 
 *
 * Построена по образу и подобию libevent'овских buffered events, но на ObjC и
 * быстрее. Является базовым протоколом большей части сетевых класов. 
 *
 * Является MLActivity и должна подчиняться всем её правилам. Предполагается, что start
 * и stop классов, имплементирующих этот протокол, не занимают и не освобождают ресурсов,
 * или делают это прозрачно. Поэтому если намечается reuse с другим fd, надо делать 
 * resetBuffers после stop.
 *
 * В силу того, что получает евенты, является MLEvLoopActivity.
 *
 * Таймауты. Write timeout означает "ивент давно ничего из нас не читал" и 
 * предназначен в основном для генерации keepalive-запросов. Read timeout
 * ожидаемо означает "ивент давно ничего в нас не писал". Интервал таймаутам
 * можно ставить любой, но чем больше интервал - тем меньше затраты на его 
 * обработку.
 *
 * Copyright 2009 undev
 **/
@protocol MLBufferedEvent <MLStream, MLEvLoopActivity>
/** Delegate. */
- (id <MLBufferedEventDelegate>)delegate;
/** [RW] Sets delegate. */
- (void)setDelegate:(id <MLBufferedEventDelegate>)delegate;

/** [RO] Sets read timeout. */
- (void)setReadTimeout:(ev_tstamp)readTimeout;
/** Read timeout. */
- (ev_tstamp)readTimeout;
/** [RO] Sets write timeout. */
- (void)setWriteTimeout:(ev_tstamp)writeTimeout;
/** Write timeout. */
- (ev_tstamp)writeTimeout;

/** [RW] Sets read block size. 4096 by default. */
- (void)setReadSize:(NSUInteger)readSize;
/** Read block size. */
- (NSUInteger)readSize;

/** [RW] Sets input buffer size limit. Unlimited by default. */
- (void)setInputBufferSizeLimit:(NSUInteger)maxSize;
/** Input buffer size limit. */
- (NSUInteger)inputBufferSizeLimit;

/** [RW] Sets output buffer size limit. Unlimited by default. */
- (void)setOutputBufferSizeLimit:(NSUInteger)maxSize;
/** Output buffer size limit. */
- (NSUInteger)outputBufferSizeLimit;

/** Reserves place in input buffer for content with known length. */
- (void)reservePlaceInInputBuffer:(uint64_t)len;

/** Release buffered event after flushing everything from output buffer. */
- (void)flushAndRelease;

/** Если во входном буфере есть какие-либо данные, уведомить об этом делегата
 * повторно вне зависимости от того, появились ли новые данные или нет.
 * Полезно при горячей смене делегата. */
- (void)rescheduleRead;
@end
