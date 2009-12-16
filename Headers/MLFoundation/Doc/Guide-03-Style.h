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

/** @page page3 Coding style guide
 *
 * \section sg_formatting Formatting
 *
 * -# Tabs, no spaces. Обычно считается, что ширина таба 4.
 * -# Общий brace style: The One True Brace Style, он же 1TBS, он же OTBS.
 * -# Расстановку скобок в методах см. Methods ниже
 * -# В statements обязательны фигурные скобки - открывающая на той же строке, 
 *    финальная закрывающая на отдельной.
 *
 *  Пример:
 *
 *  @code
 *  int main(int argc, char *argv[])
 *  {
 *      while (x == y) {
 *          something();
 *          if (some_error) {
 *              do_correct();
 *          } else {
 *              continue_as_usual();
 *          }
 *      }
 *      finalthing();
 *  }
 *  @endcode
 *
 * \section sg_methods Methods
 *
 * -# Название функции начинается с новой строки, тип {+|-} является первым 
 *    символом, за которым следует пробел.
 * -# Тип возвращаемого значения от следующий за ним метки пробелом не отделяется.
 * -# В случае указателя звёздочка ставится через пробел после имени типа.
 * -# Метка, тип, значения и имя переменной пробелами не разделяются.
 * -# Фигурные скобки, охватывающие тело функции, начинаются на отдельных строках
 *    на том же уровне выравнивания, что и объявление функции.
 * -# После закрывающей скобки ставится пустая линия.
 *
 *  Пример:
 *
 *  @code
 *  - (void)performFunctionCallWith:(RTMPObject *)anObject
 *  {
 *  }
 *  @endcode
 *
 * \section sg_ivars Instance Variables и тела интерфейсов.
 *
 * -# Название instance variable заканчивается на подчёркивание.
 * -# Название instance variable должно быть в camelCase и маленькой буквы.
 * -# Принадлежность переменных - \@private / \@protected / \@public должна быть
 *    явно объявлена, и быть табом левее объявлений переменных.
 * -# Фигурная скобка, открывающая описание instance variables, ставится на той же строке.
 * -# Фигурная скобка, закрывающая описание instance variables, ставится на отдельной строке.
 * -# Соглашение на определение описаний методов - такое же, как на определение заголовков тел.
 *
 *  Пример:
 *
 *  @code
 *  @interface MLBufferedEvent : MLEvLoopActivity {
 *  @protected
 *      id <MLBufferedEventDelegate>delegate_;
 *  @private
 *      IMP delegateNewData_, delegateWritten_;
 *  }
 *  - (void)setReadTimeout:(ev_tstamp)readTimeout;
 *  @endcode
 *
 * \section sg_mem_mgmt Memory management
 *
 * -# Для графов объектов применять конвенционные cocoa reference counting. 
 * -# По умолчанию, если явно не указано обратного, все объекты, переданые в коллбэках,
 *    монопольно принадлежат тому, кто их передал. Если кто-то хочет их сохранить, он
 *    должен их копировать.
 * -# При ошибке в конструкторе объект должен быть сразу же освобождён до возврата nil.
 *    Для этого есть макрос MLReleaseSelfAndReturnNilUnless(x).
 * 
 * \section sg_err_mgmt Error management
 *
 * -# Агрессивная проверка inner consistency при помощи макросов:
 *   -# MLAssert(condition[, fmt, ...])
 *   -# MLFailIf(condition[, fmt, ...])
 *   -# MLFailUnless(condition[, fmt, ...])
 *   -# MLFail(fmt[, ...])
 * -# MLAssert использовать для тех вещей, которые могут быть испорчены только программистом
 * -# Для всего, что как-то связано с внешними данными, использовать MLFail*
 * -# Помнить, что MLAssert не срабатывает c debug=0, а MLFailIf/Unless - срабатывает.
 * -# Пользователь должен получать внятные развёрнутые описания ошибок во входных данных.
 *    Механизм - NSError.
 *
 * \section sg_vartypes Data types
 *
 * -# Абстрактные данные - uint8_t *
 * -# Время - ev_tstamp
 * -# Сокет - int
 * -# Сигнал - int
 * -# никаких NSUInteger - int и <stdint.h>
 *
 * \section Objective-C 
 *
 * -# Помнить о том, что nil сжирает все селекторы без разбору и пользоваться этим.
 *
 * Copyright 2009 undev
 */

#error "This file is for documentation only!"
