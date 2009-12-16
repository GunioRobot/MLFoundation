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

#error This file for documenting purposes only!

/** @defgroup mlstream_transactions MLStream transactional read/write functions.
 *
 * Функции транзакционного чтения/записи из MLStream. 
 * Нужны для сериализации и десериализации. Вложенные транзакции разрешаются.
 *
 * Контекст транзакции - такой же MLStream, из которого можно читать и/или писать
 * (писать в MLStream транзакции чтения, впрочем, нельзя; читать из MLStream'а
 * транзакции записи можно - то, что уже записано). Drain'ы в случае чтения или
 * reserve/written в случае записи не попадают в родительский MLStream до коммита.
 *
 * Тем не менее, Reserve'ы на контекст транзакции так же инвалидируют ссылки на
 * данные в основном буфере.
 *
 * Контексты транзакций размещаются на стеке, со всеми вытекающими:
 *
 * - они существуют только до выхода из функции
 * - их не обязательно релизить
 *
 * TODO FIXME ATTENTION:
 * Если 
 *  - транзакция - на запись
 *  - она открыта не на MLBuffer, а именно на каком-то MLStream
 *
 * то в момент коммита write callback не будет вызван. Quick workaround - 
 * MLStreamWritten(... , 0);
 *
 * Copyright 2009 undev
 * @{
 */

/** Открывает транзакцию на чтение из потока. 
 * Возвращает контекст транзакции, который ведёт себя как MLStream. */
id<MLStream> MLStreamBeginReadTransaction(id<MLStream> stream);

/** Открывает транзакцию на запись в поток. Если initialReserve > 0, то сначала под 
 * запись будет выделено initialReserve байт. 
 * Возвращает контекст транзакции, который ведёт себя как MLStream. */
id<MLStream> MLStreamBeginWriteTransaction(id<MLStream> stream, int initialReserve);

/** Откатывает транзакцию. Сами данные остаются записанные, но родительский 
 * буфер не меняются (Тем не менее, если запись какая-то была, указатели
 * на него инвалидированы). Аргумент - контекст транзакции. */
void MLStreamRollbackTransaction(id<MLStream> transactionContext);

/** Закрывает транзакцию. Аргумент - контекст транзакции. */
void MLStreamCommitTransaction(id<MLStream> transactionContext);

/*@}*/

