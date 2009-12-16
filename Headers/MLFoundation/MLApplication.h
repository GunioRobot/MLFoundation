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

#import <libev/config.h>

#import <MLFoundation/EVBindings/EVSignalWatcher.h>
#import <MLFoundation/EVBindings/EVLoop.h>

#import <MLFoundation/Protocols/MLActivity.h>


#define MAX_OPTIONS 128

/** Абстрактный класс приложения.
 *
 * Умеет:
 *
 *  - Демонизацию
 *  - пид-файл
 *  - setuid
 *  - self-renice
 *  - stack size limit
 *
 * Как использовать: унаследовать со своими validateForStart: , 
 * start, stop. [super start] нужно вызывать в начале метода.
 * Как и с любыми другими start / stop, в начале должны быть guards:
 * if ([self isStarted]) return; в start и if (![self isStarted]) return; в stop.
 *
 * Как использовать command-line options: во-первых, перегрузить usage, чтобы он 
 * выводил новые опции. Во-вторых, подкласс должен понимать и валидировать опции по
 * key-value coding (включая key-value validation).
 *
 * Разбираются опции командной строки в processCommandLine (который нужно вызывать руками),
 * ошибки по ним возвращаются точно так же
 * как и все остальные - в validateForStart. --option-name автоматически преобразуется в 
 * optionName.
 *
 * В main пользоваться почти так же, как и любой другой activity. Инициализировать, 
 * засетапить, и, если всё хорошо, вызвать run. После останова вызывать release.
 * Примерно так:
 *
 * @code
 * #import <MLFoundation/MLFoundation.h>
 * 
 * int main(int argc, char *argv[])
 * {
 * 	NSAutoreleasePool *pool = [NSAutoreleasePool new];
 * 
 * 	MyApplication *app = [[MyApplication alloc] init];
 * 
 * 	[app processCommandLine];
 * 	// Всяческая настройка app
 * 	
 * 	NSError *startError;
 * 	if (![app validateForStart:&startError]) {
 * 		MLLog(LOG_FATAL, "FATAL: Unable to start application:\n%@", startError);
 * 		[app usage];
 * 		[app release];
 * 		[pool release];
 * 		return 1;
 * 	}
 * 
 * 	[app run];
 * 	[app release];
 * 	return 0;
 * }
 * 
 * @endcode
 *
 * Прямой вызов start запрещён.
 *
 * Предполагается, что метод stop останавливает и прекращает всю вызванную 
 * приложением активность. В это входит и обрывание всех открытых подключений.
 *
 * Copyright 2009 undev
 */
@interface MLApplication : NSObject <MLActivity> {
	EVSignalWatcher *sigInt_, *sigQuit_, *sigTerm_, *sigHup_, *sigUsr1_;
#if MLDEBUG > 1
	EVSignalWatcher *sigInfo_;
#endif
	BOOL isStarted_; 
@private

	NSString *runAsUser_;
	int niceValue_;
	int stackSize_;
	NSString *pidFile_;

	NSString *logDirectory_;
	NSString *logName_;
	BOOL daemonize_;
	BOOL dropCoreDumps_;

	NSError *cmdLineError_;
	NSArray *argumentsLeft_;
}
/** Первый инстанциированный объект */
+ (MLApplication *)sharedApplication;
/** Доступна ли в этой сборке демонизация. */
+ (BOOL)isDaemonizeAvailable;
/** Доступен ли в этой сборке смена приоритета. */
+ (BOOL)isReniceAvailable;
/** Доступна ли в этой сборке смена пользователя. */
+ (BOOL)isSetuidAvailable;
/** Доступен ли в этой сборке сброс корки. */
+ (BOOL)isCoreDumpAvailable;
/** Доступно ли в этой сборке изменение размера стека. */
+ (BOOL)isStackResizeAvailable;

/** Путь до core dump (если core dumps включены). */
+ (NSString *)coreDumpPath;

/** Обработать командную строку. По умолчанию этот метод разбирает --keys и 
 * записывает arguments, так что при подклассинге его можно оверрайдить для использования
 * позиционных аргументов из [self arguments], вызвав [super processCommandLine] в начале.*/
- (void)processCommandLine;

/** Метод вызовется по SIGHUP-у. Если приложение мультиворкерное, то только в мастере. 
    Если хочется перечитать конфиг, это именно то место */
- (void)reloadApplication;

/** Вывести в stdout поддерживаемые MLApplication флаги, шириной 80 символов
 * 	80 символов. Предполагается, что метод usage подкласса вызовет этот метод в конце
 * 	себя. Этот метод не возвращается. */
- (void)usage;

/** То, что осталось от командной строки после парсинга опций (то есть все аргументы, начиная с 
 * первого не начинающегося на --) */
- (NSArray *)arguments;

/** Установить имя пользователя, под которым запускаться. */
- (void)setChangeUser:(NSString *)user;
- (NSString *)changeUser;

/** Установить размер стека. */
- (void)setStackSize:(int)stackSize;
- (int)stackSize;

/** Установить приоритет, с которым запускаться. */
- (void)setNiceValue:(int)niceValue;
- (int)niceValue;

/** Установить местоположение пид-файла. */
- (void)setPidFile:(NSString *)pidFile;
- (NSString *)pidFile;

/** Демонизироваться или нет.*/
- (void)setDaemonize:(NSNumber *)daemonize;
- (NSNumber *)daemonize;

/** Бросать корки или нет. */
- (void)setDropCoreDumps:(NSNumber *)dropCoreDumps;
- (NSNumber *)dropCoreDumps;

/** Установить директорию для записи логов. */
- (void)setLogDirectory:(NSString *)logDirectory;
- (NSString *)logDirectory;

/** Установить имя основного лога. */
- (void)setLogName:(NSString *)logName;
- (NSString *)logName;

/** Запустить приложение. */
- (void)run;

/** Метод вызывающийся по SIGHUP */
- (void)loop:(EVLoop *)loop watcher:(EVWatcher *)w reloadSignal:(int)events;

/** Метод вызывающийся по SIGUSR1 */
- (void)loop:(EVLoop *)loop watcher:(EVWatcher *)w rotateSignal:(int)events;

/** Метод вызывающийся по SIGTERM */
- (void)loop:(EVLoop *)loop watcher:(EVWatcher *)w stopSignal:(int)events;
@end

