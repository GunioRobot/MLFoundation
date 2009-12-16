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

#include <Foundation/Foundation.h>

#include <stdio.h>
#include <stdarg.h>
#include <stdint.h>
#include <string.h>

#include <limits.h>
#include <libev/config.h>

#include <portability/normalized_localtime_r.h>
#include <portability/normalized_strsep.h>

/** MLLogger levels. */
enum {
	LOG_UNSET = 32767,
	LOG_FATAL = 100,
	LOG_ERROR = 50,
	LOG_WARNING = 40,
	LOG_ALERT = 20,
	LOG_INFO = 5,
	LOG_DEBUG = 0,
	LOG_VDEBUG = -10,
	LOG_VVDEBUG = -20,
	LOG_VVVDEBUG = -30
};


#define DEFAULT_LOG_LEVEL LOG_ALERT

@class MLPrefixedLogger, MLStdioLogger;

/** Логгер.
 *
 * 	Entry points - два макроса: 
 *
 * 	- MLLog(int level, const char *fmt, ...);
 * 	- MLLogHexdump(int level, uint8_t *data, int len);
 *
 * 	Определены следующие log levels, по убыванию: LOG_FATAL,  LOG_ERROR, LOG_WARNING, 
 * 	LOG_ALERT, LOG_INFO, LOG_DEBUG, LOG_VDEBUG, LOG_VVDEBUG.
 *
 * 	Если ничего не трогать - лог идёт в stderr. 
 * 	Без вызова setLogDirectory открывать именованые логи ( == логи в файл) не дадут.
 * 	Напрямую, впрочем, его лучше не трогать, а использовать методы MLApplication.
 *
 * 	Логгинг в файл устроен так: 
 * 	файлы с логами лежат в одной директории, и называются log_name.log. 
 *
 * 	В составе каждого
 * 	лога может быть несколько префиксованых логов - они идут в тот же файл/stderr но с префиксом
 * 	в начале строки лога.
 *
 *  У каждого объекта может быть свой логгер, см. NSObject(MLLocalLogger) .
 *
 *  Сообщения с LOG_FATAL и выше всегда попадают ещё и в главный лог приложения.
 *
 *  Copyright 2009 undev
 */
@interface MLLogger : NSObject {
}
/** Установить директорию для записи логов. Обычно вызывается один раз, в начале приложения. */
+ (void)setLogDirectory:(NSString *)_log_dir;
/** Установить log level. Обычно вызывается один раз, в начале приложения. */
+ (void)setLogLevel:(int)_log_level;

/** Установить имя, под которым будет писаться глобальный лог. Если не получилось открыть файл
 * на запись - возвращает nil. Обычно выызывается один раз в начале приложения. */
+ (MLLogger *)setLogName:(NSString *)name;
/** Настроить логгер для отфоркнувшегося чайлда. Делает так, что в начале строк лога пишется
 * [pid]. Обычно вызывается один раз после форка. Если что-то не получилось, возвращает nil. */
+ (MLLogger *)setupChildLogger;
/** Создать новый лог в файл. Если не получилось открыть файл на запись - возвращает nil.
 * Обычно используется для создания локальных логгеров. */
+ (MLStdioLogger *)newLoggerWithName:(NSString *)name;
/** Создать новый префиксованый лог внутри глобального. 
 * Обычно используется для создания локальных логгеров. */
+ (MLPrefixedLogger *)newLoggerWithPrefix:(NSString *)prefix;

/** Переоткрыть все логи. */
+ (void)rotate;

/** Бэкенд-метод вывода в лог. Используйте вместо него MLLog. */
- (void)logMessage:(const char *)fmt args:(va_list)ap level:(int)level;

/** Создать новый префиксованый лог внутри этого лог.
 * Обычно используется для создания локальных логгеров. */
- (MLPrefixedLogger *)newLoggerWithPrefix:(NSString *)prefix;
/** Название этого лога. */
- (NSString *)name;
/** Переоткрыть этот лог. */
- (void)rotate;
@end

@interface MLStdioLogger : MLLogger {
	FILE *output;
	NSString *fname;
	NSString *name;

	char *buf;
	int buf_len;
}
- (MLStdioLogger *)initWithFile:(FILE *)_output;
- (MLStdioLogger *)initWithLogName:(NSString *)_name;

- (NSString *)name;
- (void)logMessage:(const char *)fmt args:(va_list)ap level:(int)level;
- (void)rotate;
@end

#define MAX_PREFIX_LENGTH 128

@interface MLPrefixedLogger : MLLogger {
	MLLogger *delegate;
	char prefix[MAX_PREFIX_LENGTH];
	int prefix_len;
	BOOL putColon;

	char *buf;
	int buf_len;
}
- (MLPrefixedLogger *)initWithDelegate:(MLLogger *)_delegate prefix:(NSString *)_prefix;
- (void)logMessage:(const char *)fmt args:(va_list)ap level:(int)level;
- (void)setPutColon:(BOOL)_putColon;
@end

void MLLog2(MLLogger *logger, int level, const char *fmt, ...);
void MLLogVa2(MLLogger *logger, int level, const char *fmt, va_list args);
void MLLogAssertion2(MLLogger *logger, const char *what, char *file, int line, char *condition, ...);
void MLLogHexdump2(MLLogger *logger, int level, uint8_t *data, int size);

extern MLLogger *globalLogger;

const extern MLLogger *__localLogger_;

const extern char *__endOfArgs;

#define HAVE_LOCAL_LOGGER MLLogger *__localLogger_

/** Per-object logging. 
 * 
 * Чтобы им пользоваться, нужно в секции instance variables класса вписать декларацию 
 * HAVE_LOCAL_LOGGER:
 *
 * @code
 * @interface MyObject : NSObject {
 *     HAVE_LOCAL_LOGGER;
 * }
 * @endcode
 * 
 * Без вызова setLogger вывод из этого объекта всё равно пойдёт в глобальный лог.
 *
 * setLogger не ретейнит. Создание и освобождение логгеров оставляется приложению.
 *
 * Для этого есть три вызова:
 * 
 * -# [MLLogger newLoggerWithName:@"name"];
 * -# [MLLogger newLoggerWithPrefix:@"prefix"];
 * -# [someLocalLogger newLoggerWithPrefix:@"prefix"];
 *
 * */
@interface NSObject (MLLocalLogger)
/** Локальный логгер для этого объекта. */
- (MLLogger *)logger;
/** Установить локальный логгер для этого объекта. */
- (void)setLogger:(MLLogger *)logger;
@end

#define MLLogAssertion(ARGS...) do { if (__localLogger_) { MLLogAssertion2((MLLogger *)__localLogger_, ##ARGS, __endOfArgs); } else { MLLogAssertion2(globalLogger, ##ARGS, __endOfArgs); } } while(0)
#define MLLog(ARGS...) do { if (__localLogger_) { MLLog2((MLLogger *)__localLogger_, ##ARGS); } else { MLLog2(globalLogger, ##ARGS); } } while(0)
#define MLLogVa(ARGS...) do { if (__localLogger_) { MLLogVa2((MLLogger *)__localLogger_, ##ARGS); } else { MLLogVa2(globalLogger, ##ARGS); } } while(0)
#define MLLogHexdump(ARGS...) do { if (__localLogger_) { MLLogHexdump2((MLLogger *)__localLogger_, ##ARGS); } else { MLLogHexdump2(globalLogger, ##ARGS); } } while(0)

void MLLogBacktrace2(MLLogger *logger, int level, int skip); 

#define MLLogBacktrace(level) do { if (__localLogger_) { MLLogBacktrace2((MLLogger *)__localLogger_, level, 1); } else { MLLogBacktrace2(globalLogger, level, 1); } } while(0)
