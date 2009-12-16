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

#import <MLFoundation/MLMultiWorkerApplication.h>

#import <MLFoundation/MLCore/MLLogger.h>
#import <MLFoundation/MLCore/MLAssert.h>
#import <MLFoundation/MLCore/MLIdioms.h>
#import <MLFoundation/MLCore/MLCategories.h>

#import <MLFoundation/MLConnection.h>

#import <unistd.h>
#import <float.h>

@interface MLMultiWorkerApplication(private)
- (void)addWorkerTunnel:(MLWorkerTunnel *)worker forPid:(pid_t)pid;
- (void)resumeAsParentOf:(pid_t)child withTunnel:(MLWorkerTunnel *)tunnel;
- (BOOL)forkChild;
@end

@implementation MLMultiWorkerApplication
- (id)init
{
	if ((self = [super init]) == nil)
		return nil;

	workers_ = [NSMutableDictionary new];

	sigChild_ = [[EVChildWatcher alloc] init];
	MLReleaseSelfAndReturnNilUnless(sigChild_);
	[sigChild_ setPID:0];
	[sigChild_ setTarget:self selector:@selector(loop:watcher:childSignal:)];

	workersCount_ = 1;
	return self;
}

- (void)pidExited:(NSNumber *)pid
{
	// noop
}

- (void)loop:(EVLoop *)loop watcher:(EVChildWatcher *)w childSignal:(int)events
{
	id worker;
	NSNumber *pid;

	pid = [NSNumber numberWithInt:[w pid]];
	worker = [workers_ objectForKey:pid];
	if (worker) {
		MLLog(LOG_INFO, "worker %@ quit", worker);
		[worker stop];
		[workers_ removeObjectForKey:pid];
		[w stopOnLoop:EVReactor];
		[self forkChild];
		[w startOnLoop:EVReactor];
	} else {
		worker = [oldWorkers_ objectForKey:pid];
		MLLog(LOG_INFO, "old worker %@ quit", worker);
		[worker stop];
		[oldWorkers_ removeObjectForKey:pid];
	}
	[self pidExited:pid];
}

- (void)loop:(EVLoop *)loop watcher:(EVWatcher *)w rotateSignal:(int)events
{
	[super loop:loop watcher:w rotateSignal:events];
	[[workers_ allValues] makeObjectsPerformSelector:@selector(logrotate)];
}

/* В родительском процессе SIGHUP рассылает по всем детям сообщение graceful и перекладывает их
в список детей на отмирание*/
- (void)loop:(EVLoop *)loop watcher:(EVWatcher *)w reloadSignal:(int)events
{
	[super loop:loop watcher:w reloadSignal:events];
	[[workers_ allValues] makeObjectsPerformSelector:@selector(graceful)];

	if (!oldWorkers_) {
		oldWorkers_ = [[NSMutableDictionary alloc] init];
	}
	[oldWorkers_ addEntriesFromDictionary:workers_];
	[workers_ removeAllObjects];
	//Теперь после откладывания старых воркеров в сторонку, можно смело перечитывать конфиг или делать что-то ещё
	[self reloadApplication];
	
	[self startWorkers];
}

/* В дочернем процессе SIGHUP аналогичен команде graceful туннеля */
- (void)loop:(EVLoop *)loop watcher:(EVWatcher *)w reloadSignalInChild:(int)events
{
	[self gracefulInChild];
}

- (void)loop:(EVLoop *)loop watcher:(EVWatcher *)w rotateSignalInChild:(int)events
{
	[MLLogger rotate];
}


- (void)start
{
	if ([self isStarted]) return;
	[super start];

	[self startWorkers];
}

- (void)startWorkers
{
	int i;
	for (i = 0; i < workersCount_;  i++) {
		if ([self forkChild]) {
			return;
		}
	}
	[[workers_ allValues] makeObjectsPerformSelector:@selector(start)];
	if (workersCount_ > 0) [sigChild_ startOnLoop:EVReactor];
}

- (void)run
{
	if (![self isStarted]) [self start];
	// Special case...
	if (workersCount_ == 0) {
		MLWorkerTunnel *tunnel;
		MLWorkerAcceptor *acceptor;

		if (![MLWorkerTunnel createWorkerTunnel:&tunnel andAcceptor:&acceptor]) {
			MLFail("Failed to create worker tunnel & acceptor!");
		}

		[tunnel setLoop:EVReactor];
		[acceptor setLoop:EVReactor];

		[self resumeAsParentOf:getpid() withTunnel:tunnel];

		// Вот тут мы уйдём в ранлуп.
		[self runChildWithAcceptor:acceptor];

		[acceptor release];
		[tunnel release];
	}  else {
		[EVReactor run];	
	}
}

- (void)stop
{
	if (![self isStarted])
		return;

	if (workersCount_ > 0) [sigChild_ stopOnLoop:EVReactor];
	[sigHup_ stopOnLoop:EVReactor];
	[sigUsr1_ stopOnLoop:EVReactor];
	
	[[workers_ allValues] makeObjectsPerformSelector:@selector(stop)];
	// XXX FIXME очередной хак с dropAfterFork...
	[[workers_ allValues] makeObjectsPerformSelector:@selector(dropAfterFork)];

	[super stop];
}

- (void)resumeAsParentOf:(pid_t) child withTunnel:(MLWorkerTunnel *)tunnel
{
	MLLog(LOG_INFO, "child %d : %@", child, tunnel);
	[self addWorkerTunnel:tunnel forPid:child];
	[tunnel start];
}

- (void)willBecomeChild
{
	[[workers_ allValues] makeObjectsPerformSelector: @selector(dropAfterFork)];
	[self setPidFile: nil];
	[MLLogger setupChildLogger];
	[self stop];
	[self installChildrenSignalHandlers];
}

- (void)installChildrenSignalHandlers
{
	[sigHup_ release];
	sigHup_ = [[EVSignalWatcher alloc] init];
	[sigHup_ setTarget:self selector:@selector(loop:watcher:reloadSignalInChild:)];
	[sigHup_ setSignalNo: SIGHUP];
	[sigHup_ startOnLoop:EVReactor];
	

	[sigUsr1_ release];
	sigUsr1_ = [[EVSignalWatcher alloc] init];
	[sigUsr1_ setTarget:self selector:@selector(loop:watcher:rotateSignalInChild:)];
	[sigUsr1_ setSignalNo: SIGUSR1];
	[sigUsr1_ startOnLoop:EVReactor];
}

- (void)gracefulInChild
{
	[self subclassResponsibility:_cmd];
}


- (void)runChildWithAcceptor:(MLWorkerAcceptor *)acceptor
{
	[self subclassResponsibility:_cmd];
}

- (BOOL)forkChild
{
	MLWorkerTunnel *tunnel;
	MLWorkerAcceptor *acceptor;

	if (![MLWorkerTunnel createWorkerTunnel:&tunnel andAcceptor:&acceptor]) {
		MLFail("Failed to create worker tunnel & acceptor!");
	}

	[tunnel setLoop:EVReactor];
	[acceptor setLoop:EVReactor];

	pid_t child = -1;

	child = fork();
	if (child < 0) {
		MLFail("Fork() failed!");
	}

	if (child == 0) {
		// Тут надо аккуратно выпиздить всё с ранлупа, не трогая то, что
		// висит на сокетпарах, ибо они склонированы с родителей.
		[EVReactor forked];
		[self willBecomeChild];

		[tunnel dropAfterFork];
		[tunnel release];

		[self runChildWithAcceptor:acceptor];

		// Ага, чайлд отработал.
		[acceptor release];

		MLLog(LOG_INFO, "Bye!");

		exit(0);

	}  else {
		[acceptor dropAfterFork];
		[acceptor release];

		[self resumeAsParentOf:child withTunnel:tunnel];
	}

	return (child == 0);
}

- (void)dealloc
{
	[workers_ release];
	[oldWorkers_ release];
	[sigChild_ release];
	[super dealloc];
}

- (void)setWorkersCount:(int)workersCount
{
	workersCount_ = workersCount;
	if (workersCount_ < 0) {
		MLLog(LOG_ERROR, "bad workers count: %d, falling back to 2", workersCount);
		workersCount_ = 2;
	}
	if (workersCount_ == 0) {
		MLLog(LOG_DEBUG, "DEBUG: Starting in master-only mode.");
	}
}


- (void)setWorkers:(NSString *) workersCountString
{
	[self setWorkersCount:[workersCountString intValue]];
}

- (void)addWorkerTunnel:(MLWorkerTunnel *)worker forPid:(pid_t)pid
{
	[workers_ setObject:worker forKey:[NSNumber numberWithInt:pid]];
}

- (void)usage
{
	//		0 	     10        20        30        40        50        60        70         "
	//     "01234567890123456789012345678901234567890123456789012345678901234567890123456789"
	printf("Multiworker options\n");
	printf("  --workers <number>          Set number of worker processes (defaults to 2)\n");
	printf("                              ( --workers 0 is a special case: master and one\n");
	printf("                              worker runs in one process for debugging purposes)\n");
	printf("\n");
	[super usage];
}

- (MLWorkerTunnel *)spareWorker
{
	NSEnumerator *e;
	MLWorkerTunnel	*o;
	double		last = DBL_MAX;
	MLWorkerTunnel *bestFit = nil;

	e = [workers_ objectEnumerator];
	while ((o = [e nextObject])) {
		if (!bestFit || ([o business] < last)) {
			last = [o business];
			bestFit = o;
		}
	}
	MLLog(LOG_INFO, "selected %@ with business %f", bestFit, [bestFit business]);

	return bestFit;
}

@end
