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

/** MLBytesFIFO-compliant поток.
 *
 * Предназначен для потокового взаимодействия с внешней сущностью.
 *
 * В отличии от NSStream / CFStream мы не разделяем Input stream и Output stream,
 * все наши потоки в большинстве своём двунаправленные. Вместо этого у них есть ряд булевых
 * флагов - haveInput, haveOutput и другие.
 *
 * Поскольку отправляет делегату всеразличные события, является MLActivity (TODO - MLActor).
 * В остановленном состоянии делегата не трогает.
 *
 * Таймауты. Write timeout означает "мы давно ничего не отдавали внешней сущности" и 
 * предназначен в основном для генерации keepalive-запросов. Read timeout
 * ожидаемо означает "мы давно ничего не получали от внешней сущности". Интервал таймаутам
 * можно ставить любой, но чем больше интервал - тем меньше затраты на его 
 * обработку.
 * Когда вызываются коллбэки? Это зависит от ватермарков.
 *
 * - streamHasData будет вызываться, когда на входе потока есть байтов не меньше, чем
 *                 read watermark. Особый случай, когда read watermark == 0: в этом
 *                 случае streamHasData будет вызываться после каждой операции чтения
 *                 (как в старом MLBufferedEvent).
 * - streamHasBytes будет вызываться, когда в выходе потока есть байтов не больше, чем
 *   				write watermark. Особый случай, когда write watermark == 0: 
 *   				в этом случае streamHasSpace будет вызываться после всякой операции
 *   				записи.
 *
 */
@protocol MLStream <MLBytesFIFO, MLActivity>
/** [RW] Установить делегата. */
- (void)setDelegate:(id)delegate;
/** Делегат. */
- (id)delegate;

/** У этого потока есть ввод. Будет вызываться streamHasBytes: у делегата, разрешается
 * вызывать методы чтения.  */
- (BOOL)haveInput;

/** У этого потока есть вывод. Будет вызываться streamHasSpace: у делегата, разрешается
 * использовать методы записи. */
- (BOOL)haveOutput;

/** Этот поток умеет следить за временем. По таймауту будет вызываться stream:timedOut:
 * у делегата, разрешается делать setReadTimeout/setWriteTimeout. Точную семантику
 * таймаутов смотри в MLStreamDelegate. */
- (BOOL)haveTimeouts;

/** Этот поток умеет умеет вызывать делегата по ватермарку. Если NO, то поток всегда будет 
 * вести себя как с watermarks 0. */
- (BOOL)haveWatermarks;

/** [RW] Sets read timeout. */
- (void)setReadTimeout:(ev_tstamp)readTimeout;
/** Read timeout. */
- (ev_tstamp)readTimeout;

/** [RW] Sets write timeout. */
- (void)setWriteTimeout:(ev_tstamp)writeTimeout;
/** Write timeout. */
- (ev_tstamp)writeTimeout;

/** [RW] Установить read watermark. По умолчанию 1. */
- (void)setReadWatermark:(int64_t)readWatermark;
/** Read watermark. */
- (int64_t)readWatermark;

/** Установить write watermark. По умолчанию 0. */
- (void)setWriteWatermark:(int64_t)writeWatermark;
/** Write watermark. */
- (int64_t)writeWatermark;

/** Подсказать потоку предполагаемый объём входных данных. Метод только для оптимизации
 * выделения памяти, и не факт. что поток им воспользуется. */
- (void)hintInputSize:(uint64_t)hint;

/** Закрывает поток. После этого вызова указатель на поток становится невалидным. 
 * Внутри вызывает тот же closeWithError, только формирует generic ошибку сам. */
- (void)close;

/** Закрывает поток, сообщив потоку об ошибке. После этого вызова указатель на поток 
 * становится невалидным. */
- (void)closeWithError:(NSError *)error;
@end

