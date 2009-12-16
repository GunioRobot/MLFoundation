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
#import <MLFoundation/EVBindings/EVChildWatcher.h>
#import <MLFoundation/MLApplication.h>
#import <MLFoundation/MLWorkerAcceptor.h>
#import <MLFoundation/MLWorkerTunnel.h>

/** Абстрактный класс многопроцессового приложения.
 *
 * Используется для написания SMP-aware серверов. 
 *
 * Предполагается, что мастер-процесс только принимает входящие соединения, а вся
 * работа ложится на воркеров. 
 *
 * TODO: Cхема в высшей степени ограничена.
 * 
 * Copyright 2009 undev
 **/
@interface MLMultiWorkerApplication : MLApplication {
	int workersCount_;
	NSMutableDictionary	*workers_;
	NSMutableDictionary	*oldWorkers_;

	EVChildWatcher *sigChild_;
}
/** Выставляет количество процессов-обработчиков. Совместимо с MLApplication */
- (void)setWorkers:(NSString *)workersCountString;

/** Вызывается после форка для корректной остановки всяких вотчеров.
 * Субклассы, которые добавили на event loop свои watcher-ы
 *  должны переопределить этот метод, и в конце вызвать [super willBecomeChild].
 */
- (void)willBecomeChild;

/** Вызывается после форка в дочернем процессе, и запускает логику рабочего
 * процесса.
 *
 * Должен уходить в ранлуп, а после него возврата из ранлупа чистить память и делать return.
 *
 */
- (void)runChildWithAcceptor:(MLWorkerAcceptor *)mediator;

/** Запускает нужное количество воркеров. Вызывается как из init-а, так и из обработчика SIGHUP-а*/
- (void)startWorkers;

/** В дочернем процессе надо выставить правильные обработчики сигналов */
- (void)installChildrenSignalHandlers;

/** Этот метод вызывается только в дочерних процессах. Он должен быть перекрыт в наследнике и означает,
что в этот процесс уже не прийдут никакие соединения и он должен выйти после последнего ребенка */
- (void)gracefulInChild;

/* В воркере SIGHUP и SIGUSR1 ведет себя по-другому, нежели в мастере */
- (void)loop:(EVLoop *)loop watcher:(EVWatcher *)w reloadSignalInChild:(int)events;
- (void)loop:(EVLoop *)loop watcher:(EVWatcher *)w rotateSignalInChild:(int)events;

/**
 * Возвращает туннель к самому свободному воркеру.
 * TODO отрефакторить во что-то более человечное. */
- (MLWorkerTunnel *)spareWorker;

/** Метод для субклассов, расказывает о смерти пида */
- (void)pidExited:(NSNumber *)pid;
@end
