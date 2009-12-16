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

/** @page page2 Buildsystem
 *
 * Мы в стадии глубокого девелопмента, поэтому мы - не shared library, а мы чекаутимся субмодулем 
 * прямо в корень дерева git-репозитария. Силовым порядком мы используем scons. Чтобы всё 
 * работало, в самое начало toplevel SConstruct file нужно вписать:
 *
 * @code
 * SConscript('MLFoundation/SConscript', variant_dir='build/MLFoundation')
 * @endcode
 *
 * Это научит scons собирать objc-шные исходники под Linux и OS X и добавит билдер 
 * FoundationProgram. Использовать это в своём SConscript нужно так. 
 *
 * @code
 * env = Environment()
 * env.SetupCommandLineDebug(default=2) // Не обязательно. Устанавливает уровень отладки в 
 *                                      // соответствии с ключом командной строки debug. 
 *                                      // 2 - значение по умолчанию.
 * env.SetupTCMalloc()          // Не обязательно. Пытается найти и подключить библиотеку 
 *                              // tcmalloc_minimal, а если не получается - выводит предупреждение.
 * env.SetupMLFoundation()      // Обязательно. Настраивает линковку с MLFoundation.
 *
 * env.FoundationProgram('borellus', ['Classes/Manager.m', 'borellus.m'])
 * @endcode
 *
 * Подключать в своих исходниках её нужно так:
 *
 * @code
 * #import <MLFoundation/MLFoundation.h>
 * @endcode
 *
 * 	\section mp_debuglevels Debug levels
 *
 * env.SetupCommandLineDebug даёт возможность выставить в командной строке уровень 
 * отладки: scons debug=<level>. Используются 3 уровня:
 *
 * - 0: оптимизированный билд. NDEBUG, O3, никакой отладочной информации, MLAssert не работает.
 * - 1: работают ассерты, O0, -g. Определяется макрос DEBUG=1
 * - 2: определяется макрос DEBUG=2. Включается отладочный режим libev, отчего часто вылезают 
 *   	наружу причины странных багов.
 *
 *  \section mp_tcmalloc TCMalloc
 * 
 * env.SetupTCMalloc ищет, и, если найдёт, подключает tcmalloc_minimal. Зачем? Без него под 
 * линуксом в наших условиях не работает libav. Почему не полный tcmalloc? Потому что он сам не 
 * работает в наших условиях под линуксом; потому, что heap checker не работает под макосью; 
 * потому, что мы пока не приручили профилировщик. (TODO однако)
 *
 * Ещё замечено, что с tcmalloc под линуксом не дружит valgrind (версии 3.3.1; может быть, 
 * дело в этом). Вся память освобождается при выходе и никаких утечек не видно.
 *
 *  \section mp_gitversion Bonus: git build version.
 *
 * Предлагается помечать версии тегами вида v0.0. Для того чтобы из этого получать версии 
 * вида 0.2[-1-g5a524ff[-m]] (0.2 - последняя тегированая версия, 1 - количество коммитов с того 
 * тега, g5a524ff - sha1 актуального коммита, m - наличие незакоммиченых изменений), нужно:
 *
 * - Создать где-нибудь файл шаблона, например, src/Classes/version.h.in такого содержания:
 *
 * @code
 * #ifndef MY_PROGRAM_VERSION
 * #define MY_PROGRAM_VERSION "%(GIT_VERSION)s"
 * #endif
 * @endcode
 *
 * - Дописать для build environment в SConscript:
 *
 * @code
 * env.AlwaysBuild( env.GitVersion('src/Classes/version.h.in') )
 * @endcode
 *
 * На выходе это даст файл src/Classes/version.h. Этим способом можно генерить не только 
 * .h-ники, но и любые файлы с подстановкой GIT_VERSION. 
 *
 * Copyright 2009 undev
 */

#error "This file is for documentation only!"
