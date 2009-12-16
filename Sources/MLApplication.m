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

#import <MLFoundation/MLApplication.h>

#import <MLFoundation/MLCore/MLFoundationErrors.h>
#import <MLFoundation/MLCore/MLCategories.h>
#import <MLFoundation/MLCore/MLLogger.h>
#import <MLFoundation/MLCore/MLIdioms.h>
#import <MLFoundation/MLCore/MLAssert.h>
#import <MLFoundation/MLBuffer.h>
#import <JSON/JSON.h>

#import <getopt.h>
#import <stdlib.h>
#import <unistd.h>
#import <fcntl.h>

#ifdef HAVE_GRP_H
#include <grp.h>
#endif
#ifdef HAVE_PWD_H
#include <pwd.h>
#endif
#ifdef HAVE_SYS_SIGNAL_H
#include <sys/signal.h>
#endif
#ifdef HAVE_SYS_RESOURCE_H
#include <sys/resource.h>
#endif
#ifdef HAVE_SYS_PRCTL_H
// Mild IRIX incompatibility :-(
#include <sys/prctl.h>
#endif
#ifdef WIN32
#  undef HAVE_SETUID
#endif

@interface MLApplication (private)
- (NSString *)_camelCaseCommandLineKey:(NSString *)key;
@end

static BOOL coreDumpsEnabled = NO;

BOOL ml_objc_error_handler(id object, int code, const char *fmt, va_list ap)
{
	MLLog(LOG_FATAL, "-------------- FATAL OBJC ERROR %d on object %p:", code, object);
	MLLogVa(LOG_FATAL, fmt, ap);
#if HAVE_MLLOG_BACKTRACE == 1
	MLLogBacktrace(LOG_FATAL);
#endif

	if ([MLApplication coreDumpPath]) {
		MLLog(LOG_FATAL, "Will dump core to %@...", [MLApplication coreDumpPath]);
	}

	MLLog(LOG_FATAL, "Trying to get failed object description: ");
	MLLog(LOG_FATAL, "%@", [object description]);

	abort();
}

@implementation MLApplication
+ (void)load
{
	initMLCategories();
	initSBJSON1();
	initSBJSON2();
}

static void do_daemonize(void) {
#ifndef WIN32
  int fd;
  switch (fork()) {
  case 0:
    break;
  case -1:
    fprintf(stderr, "Error daemonizing (fork): %s\n", strerror(errno));
	abort();
  default:
    _exit(0);
  }

  if (setsid() < 0) {
    fprintf(stderr, "Error demonizing (setsid): %s\n", strerror(errno));
	abort();
  }

  switch (fork()) {
  case 0:
    break;
  case -1:
    fprintf(stderr, "Error daemonizing (fork2): %s\n", strerror(errno));
	abort();
  default:
    _exit(0);
  }

  chdir("/");

  fd = open("/dev/null", O_RDONLY);
  if (fd != 0) {
    dup2(fd, 0);
    close(fd);
  }
  fd = open("/dev/null", O_WRONLY);
  if (fd != 1) {
    dup2(fd, 1);
    close(fd);
  }
  fd = open("/dev/null", O_WRONLY);
  if (fd != 2) {
    dup2(fd, 2);
    close(fd);
  }
#endif
}

static MLApplication *sharedApp = nil;

- init
{
	if (!(self = [super init])) return nil;

	sigInt_ = [[EVSignalWatcher alloc] init];
	MLReleaseSelfAndReturnNilUnless(sigInt_);
	[sigInt_ setTarget:self selector:@selector(loop:watcher:stopSignal:)];
	[sigInt_ setSignalNo: SIGINT];

#if !defined(__NEXT_RUNTIME__)
	objc_set_error_handler(ml_objc_error_handler);
#endif

#ifndef WIN32
	sigQuit_ = [[EVSignalWatcher alloc] init];
	MLReleaseSelfAndReturnNilUnless(sigQuit_);
	[sigQuit_ setTarget:self selector:@selector(loop:watcher:stopSignal:)];
	[sigQuit_ setSignalNo: SIGQUIT];

	sigTerm_ = [[EVSignalWatcher alloc] init];
	MLReleaseSelfAndReturnNilUnless(sigTerm_);
	[sigTerm_ setTarget:self selector:@selector(loop:watcher:stopSignal:)];
	[sigTerm_ setSignalNo: SIGTERM];

	sigHup_ = [[EVSignalWatcher alloc] init];
	MLReleaseSelfAndReturnNilUnless(sigHup_);
	[sigHup_ setTarget:self selector:@selector(loop:watcher:reloadSignal:)];
	[sigHup_ setSignalNo: SIGHUP];

	sigUsr1_ = [[EVSignalWatcher alloc] init];
	MLReleaseSelfAndReturnNilUnless(sigUsr1_);
	[sigUsr1_ setTarget:self selector:@selector(loop:watcher:rotateSignal:)];
	[sigUsr1_ setSignalNo: SIGUSR1];

#if MLDEBUG > 1

#ifndef SIGINFO
#define SIGINFO SIGPWR
#endif
	
	sigInfo_ = [[EVSignalWatcher alloc] init];
	MLReleaseSelfAndReturnNilUnless(sigInfo_);
	[sigInfo_ setTarget:self selector:@selector(loop:watcher:debugDumpSignal:)];
	[sigInfo_ setSignalNo: SIGINFO];
	
#endif

#endif

	argumentsLeft_ = [[NSArray alloc] init];
	MLReleaseSelfAndReturnNilUnless(argumentsLeft_);
	if (!sharedApp)
		sharedApp = self;

	return self;
}

- (NSString *)_camelCaseCommandLineKey:(NSString *)key
{
	NSArray *components = [key componentsSeparatedByString:@"-"];

	if ([components count] == 3) { // нам сюда приходит строка с -- в начале.
		return [components objectAtIndex:2];
	} else {
		int i;
		NSString *retval = [components objectAtIndex:2];
		for (i=3; i<[components count]; i++) {
			char *componentString = (char *)[[components objectAtIndex:i] UTF8String];
			if (islower(componentString[0])) componentString[0] = toupper(componentString[0]);
			retval = [retval stringByAppendingString:
				[NSString stringWithCString:componentString]];
		}
		return retval;
	}
}

- (void)processCommandLine
{
	NSArray *args = [[NSProcessInfo processInfo] arguments];
	NSMutableArray *argsLeft = [NSMutableArray array];
	NSEnumerator *enumerator = [args objectEnumerator];
	id key, nextKey=nil, val;
	BOOL done;

	[enumerator nextObject]; // Skip process name.

	done = ((key = [enumerator nextObject]) == nil) ? YES : NO;

	while (done == NO) {
		if (![key hasPrefix:@"--"]) break;
		key = [self _camelCaseCommandLineKey:key];
		val = [enumerator nextObject];

		if (val == nil) val = @"YES";
		if ([val hasPrefix:@"--"]) {
			nextKey = val;
			val = @"YES";
		}
		if (![self validateValue:&val forKey:key error:&cmdLineError_] &&
			cmdLineError_) break;

		[self setValue:val forKey:key];

		if (nextKey) {
			key = nextKey;
			nextKey = nil;
			continue;
		}
		done = ((key = [enumerator nextObject]) == nil) ? YES : NO;
	}

	while (done == NO) {
		[argsLeft addObject:key];
		done = ((key = [enumerator nextObject]) == nil) ? YES : NO;
	}

	[argumentsLeft_ release];
	argumentsLeft_ = [[NSArray alloc] initWithArray:argsLeft];
}

- (void)setValue:(NSString *)value forUndefinedKey:(NSString *)key
{
	if (cmdLineError_) return;
	cmdLineError_ = [[NSError alloc] initWithDomain:MLFoundationErrorDomain
		code:MLApplicationStartError
		localizedDescriptionFormat:@"Unknown option --%@", key];
}

- (void)reloadApplication
{
}

+ (MLApplication *)sharedApplication
{
	return sharedApp;
}

+ (BOOL)isDaemonizeAvailable
{
#ifdef WIN32
	return NO;
#else
	return YES;
#endif
}

+ (BOOL)isReniceAvailable
{
#ifdef HAVE_SETPRIORITY
	return YES;
#else
	return NO;
#endif
}

+ (BOOL)isSetuidAvailable
{
#ifdef HAVE_SETUID
	return YES;
#else
	return NO;
#endif
}

+ (BOOL)isStackResizeAvailable
{
#if HAVE_SYS_RESOURCE_H == 1 && HAVE_SETRLIMIT == 1
	return YES;
#else
	return NO;
#endif
}

+ (BOOL)isCoreDumpAvailable
{
#if defined(NDEBUG)
	return NO;
#else
#	if (defined(__linux__) && HAVE_SYS_PRCTL_H == 1) || defined(AVAILABLE_MAC_OS_X_VERSION_10_5_AND_LATER)
#		if HAVE_SYS_RESOURCE_H == 1 && HAVE_SETRLIMIT == 1
			return YES;
#		else
			return NO;
#		endif
# 	else
		return NO;
#	endif
#endif
}

+ (NSString *)coreDumpPath
{
	if (!coreDumpsEnabled) return nil;
	return [NSString stringWithFormat:@"/cores/core.%d", getpid()];
}

- (void)usage
{
	if ([self class] == [MLApplication class]) {
		printf("Usage: \n");
		printf("      %s [options]\n", [[[[NSProcessInfo processInfo] arguments] objectAtIndex:0] UTF8String]);
		printf("\n");
	}
	printf("Generic options:\n");
	//		0 	     10        20        30        40        50        60        70         "
	//     "01234567890123456789012345678901234567890123456789012345678901234567890123456789"
	if ([[self class] isSetuidAvailable]) {
	printf("  --changeUser <username>     Start as <username>. Requires root privileges.\n");
	}
	if ([[self class] isReniceAvailable]) {
	printf("  --niceValue <integer>       Renice to <integer>. Requires root privileges.\n");
	}
	if ([[self class] isStackResizeAvailable]) {
	printf("  --stackSize <integer>       Set stack size to <integer> kb. Requires root\n");
	printf("                              privileges.\n");
	}
	printf("  --logDirectory <path>       Write logs to directory <path>.\n"); 
	printf("  --logName <name>            Set main log name. Requires --log-directory.\n"); 
	printf("  --pidFile <part>            Save pid file.\n");
	if ([[self class] isDaemonizeAvailable]) {
	printf("  --daemonize YES             Become daemon. Requires --pid-file,\n");
	printf("                              --log-directory and --log-name. \n");
	}
	if ([[self class] isCoreDumpAvailable]) {
	printf("  --dropCoreDumps YES         Enforce dropping core dump on inconsistencies and\n");
	printf("                              other errors. WARNING: Unsafe when running as root.\n");
	}
	printf("\n");
	exit(0);
}

- (NSArray *)arguments
{
	return argumentsLeft_;
}

- (void)setChangeUser:(NSString *)user
{
	if (runAsUser_ == user) return;
	[runAsUser_ release];
	runAsUser_ = [user retain];
}

- (NSString *)changeUser
{
	return runAsUser_;
}

- (void)setStackSize:(int)stackSize
{
	stackSize_ = stackSize;
}

- (int)stackSize
{
	return stackSize_;
}

- (void)validateStackSize:(NSString **)value error:(NSError **)error
{
	int val;
	NSScanner *s = [NSScanner scannerWithString:*value];
	if (![s scanInt:&val]) {
		*error = [[NSError alloc] initWithDomain:MLFoundationErrorDomain
			code:MLApplicationStartError
			localizedDescriptionFormat:@"Invalid stack size: %@", *value];
	}
}

- (void)setNiceValue:(int)niceValue
{
	niceValue_ = niceValue;
}

- (int)niceValue
{
	return niceValue_;
}

- (void)validateNiceValue:(NSString **)value error:(NSError **)error
{
	int val;
	NSScanner *s = [NSScanner scannerWithString:*value];
	if (![s scanInt:&val]) {
		*error = [[NSError alloc] initWithDomain:MLFoundationErrorDomain
			code:MLApplicationStartError
			localizedDescriptionFormat:@"Invalid nice value: %@", *value];
	}
}

- (void)setPidFile:(NSString *)pidFile
{
	if (pidFile_ == pidFile) return;
	[pidFile_ release];
	pidFile_ = [pidFile retain];
}

- (NSString *)pidFile
{
	return pidFile_;
}

- (void)setDropCoreDumps:(NSNumber *)dropCoreDumps
{
	dropCoreDumps_ = [dropCoreDumps boolValue];
}

- (NSNumber *)dropCoreDumps
{
	return [NSNumber numberWithBool:dropCoreDumps_];
}

- (void)validateDropCoreDumps:(NSString **)value error:(NSError **)error
{
	if (![*value isEqualToString:@"YES"]) {
		*error = [[NSError alloc] initWithDomain:MLFoundationErrorDomain
			code:MLApplicationStartError
			localizedDescriptionFormat:@"Invalid dropCoreDumps value: %@", *value];
	}
}

- (void)setDaemonize:(NSNumber *)daemonize
{
	daemonize_ = [daemonize boolValue];
}

- (NSNumber *)daemonize
{
	return [NSNumber numberWithBool:daemonize_];
}

- (void)validateDaemonize:(NSString **)value error:(NSError **)error
{
	if (![*value isEqualToString:@"YES"]) {
		*error = [[NSError alloc] initWithDomain:MLFoundationErrorDomain
			code:MLApplicationStartError
			localizedDescriptionFormat:@"Invalid daemonize value: %@", *value];
	}
}

- (void)setLogDirectory:(NSString *)logDirectory
{
	if (logDirectory == logDirectory_) return;

	[logDirectory_ release];
	logDirectory_ = [logDirectory retain];
}

- (NSString *)logDirectory
{
	return logDirectory_;
}


- (void)setLogName:(NSString *)logName
{
	if (logName_ == logName) return;
	[logName_ release];
	logName_ = [logName retain];
}

- (NSString *)logName
{
	return logName_;
}

- (BOOL)validateForStart:(NSError **)e
{
	if (cmdLineError_) {
		*e = cmdLineError_;
		return NO;
	}

	// 1) Check our capabilities.
	// 2) Check whether we root for setuid & renice
	// 3) Check whether we have logdir, logname & pidfile for daemonize
	if (daemonize_) {
		if (![MLApplication isDaemonizeAvailable]) {
			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Daemonization is not supported on this platform"];
			return NO;
		}
		if (!pidFile_) {
			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Daemonization requires pid file name."];
			return NO;
		}
		if (!logDirectory_) {
			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Daemonization requires log directory."];
			return NO;
		}
		if (!logName_) {
			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Daemonization requires log name."];
			return NO;
		}
	}

	if (niceValue_) {
		if (![MLApplication isReniceAvailable]) {
			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Renice is not supported on this platform"];
			return NO;
		}
#ifndef WIN32
		if (geteuid()) {
			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Nice value can be changed only when run as root!"];
			return NO;
		}
#endif
		if (niceValue_ < -20 || niceValue_ > 19) {
			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Invalid nice value %d", niceValue_];
			return NO;
		}
	}
	
#ifndef WIN32
	if (runAsUser_) {
		if (![MLApplication isSetuidAvailable]) {
			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Changing user is not supported on this platform"];
			return NO;
		}
		if (geteuid()) {
			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"User can be changed only when run as root!"];
			return NO;
		}
		if (!getpwnam([runAsUser_ UTF8String])) {
			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Invalid or unknown username %@", runAsUser_];
			return NO;
		}
	}
#endif

	// Log name should come with log dir
	if (logName_) {
		if (!logDirectory_) {
			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Log dir is not given."];
			return NO;
		}
	}
	// 4) Check whether log directory & pid file writable 
	BOOL isDirectory;
	if (logDirectory_) {
		[[NSFileManager defaultManager] 
			fileExistsAtPath:logDirectory_ isDirectory:&isDirectory];

		if (!isDirectory || 
			![[NSFileManager defaultManager] isWritableFileAtPath:logDirectory_]) {

			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Log directory %@ is not writable!", logDirectory_];
			return NO;
		}
		NSString *fullLogFileName = [[logDirectory_ stringByAppendingPathComponent:logName_] 
			stringByAppendingPathExtension: @"log"];
		BOOL fileExists = [[NSFileManager defaultManager] 
			fileExistsAtPath:fullLogFileName isDirectory:&isDirectory];

		BOOL fileWritable = [[NSFileManager defaultManager] isWritableFileAtPath:fullLogFileName];
		if ((fileExists && !fileWritable) || (fileExists && isDirectory)) {
			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Unable to open log file for writing.", logDirectory_];
			return NO;
		}
	}


	if (pidFile_) {
		NSString *pidFileDirectory = [pidFile_ stringByDeletingLastPathComponent];
		[[NSFileManager defaultManager] 
			fileExistsAtPath:pidFileDirectory isDirectory:&isDirectory];

		if (!isDirectory || 
			![[NSFileManager defaultManager] isWritableFileAtPath:pidFileDirectory]) {

			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Unable to write pidfile."];
			return NO;
		}
	}

	// Can we change stack rlimit:
	if (stackSize_) {
		if (stackSize_ <= 0) {
			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Invalid stack size %d", stackSize_];
			return NO;
		}
		if (![MLApplication isStackResizeAvailable]) {
			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Stack size changing is not supported on this platform"];
			return NO;
		}
#ifndef WIN32
		if (geteuid()) {
			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Stack size limit can be changed only by root"];
			return NO;
		}
#endif
#if HAVE_SETRLIMIT == 1
		struct rlimit rl;
		if (getrlimit(RLIMIT_STACK, &rl) < 0) {
			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Can't change stack size (getrlimit): %s", 
					strerror(errno)];
			return NO;
		}
		if (rl.rlim_max != RLIM_INFINITY && rl.rlim_max < (stackSize_*1024)) {
			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Can't change stack size to %d: "
					" finite hard rlimit %d", stackSize_, rl.rlim_max];
			return NO;
		}
#endif
	}

	// If we wanna drop core dumps:
	// 1) We have to eiher be notroot or change user. 
	// 2) We should be able to raise core size limit
	if (dropCoreDumps_) {
		if (![MLApplication isCoreDumpAvailable]) {
			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Core dumps is not supported on this platform"];
			return NO;
		}

// Mac OS X gives hard limit zero (?)
#if HAVE_SETRLIMIT == 1
		struct rlimit rl;
		if (getrlimit(RLIMIT_CORE, &rl) < 0) {
			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Can't enable core dumps (getrlimit): %s", 
					strerror(errno)];
			return NO;
		}
# 	if  defined(AVAILABLE_MAC_OS_X_VERSION_10_5_AND_LATER)
		if (daemonize_) {
			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Daemonization with core dumps isnt supported on darwin yet. Sorry."];
			return NO;
		}
		if (rl.rlim_cur != RLIM_INFINITY) {
			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Please, do ulimit -c unlimited from shell and try again."];
			return NO;
		}
# 	endif
#	if  defined(__linux__)
		if (rl.rlim_max != RLIM_INFINITY) {
			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Can't enable core dumps: finite hard rlimit "
					"enforced"];
			return NO;
		}

		// OK, we are on linux and can dump cores (at least in theory).
		// We have to...
		// 1) Check presence of /cores (and don't forget to tell about symlink it to
		//    hard drive with enough place)
		// 2) Check that /cores have access 777
		// 3) Check presence of /proc/sys/kernel/core_uses_pid
		// 4) Check that /proc/sys/kernel/core_uses_pid == "1\n"
		// 5) Check presence of /proc/sys/kernel/core_pattern
		// 6) Check that /proc/sys/kernel/core_pattern == "/cores/core"

		struct stat coresStat;
		if ((stat("/cores", &coresStat) < 0) || !S_ISDIR(coresStat.st_mode)
			|| ((coresStat.st_mode & S_IRWXU) != S_IRWXU) 
			|| ((coresStat.st_mode & S_IRWXG) != S_IRWXG) 
			|| ((coresStat.st_mode & S_IRWXO) != S_IRWXO)) {

			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Can't enable core dumps: make /cores directory "
					"and chmod it 777 (symlink it to big HDD partition if necessary)"];
			return NO;
		}

		static char procFileContent[16];
		FILE *coreUsesPid = fopen("/proc/sys/kernel/core_uses_pid", "rb");
		if (!coreUsesPid) {
			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Can't enable core dumps: /proc/sys/kernel/core_uses_pid not found or unreadable. STRANGE."];
			return NO;
		};
		fgets(procFileContent, 15, coreUsesPid);
		procFileContent[15] = 0;
		fclose(coreUsesPid);

		if (strcmp(procFileContent, "1\n")) {
			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Can't enable core dumps: please perform \"echo '1' > /proc/sys/kernel/core_uses_pid\" as root"];
			return NO;
		}

		FILE *corePattern = fopen("/proc/sys/kernel/core_pattern", "rb");
		if (!corePattern) {
			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Can't enable core dumps: /proc/sys/kernel/core_pattern not found or unreadable. STRANGE."];
			return NO;
		};
		fgets(procFileContent, 15, corePattern);
		procFileContent[15] = 0;
		fclose(corePattern);

		if (strcmp(procFileContent, "/cores/core\n")) {
			if (e) *e = [NSError errorWithDomain:MLFoundationErrorDomain
				code:MLApplicationStartError
				localizedDescriptionFormat:@"Can't enable core dumps: please perform \"echo '/cores/core' > /proc/sys/kernel/core_pattern\" as root"];
			return NO;
		}
#	endif		
#endif
	}
	return YES;
}

- (void)start
{
	if (isStarted_) return;

	FILE *pidf = NULL;

	// 0) Setup logger
	if (logDirectory_) {
		[MLLogger setLogDirectory:logDirectory_];
	}

	if (logName_) {
		if (![MLLogger setLogName:logName_]) {
			fprintf(stderr, "FATAL: failed to open log file\n");
		}
	}
	
#ifdef HAVE_SETPRIORITY
	// 0) Renice if necessary
	if (niceValue_) {
		if (setpriority(PRIO_PROCESS, 0, niceValue_)) {
			fprintf(stderr, "FATAL: failed to setpriority(): %s\n", strerror(errno));
			abort();
		}
	}
#endif

#if HAVE_SETRLIMIT == 1
	if (stackSize_) {
		struct rlimit rl;
		if (getrlimit(RLIMIT_STACK, &rl) < 0) {
			MLFail("FATAL: Can't set stack limit: %s", strerror(errno));
		}
		rl.rlim_cur = stackSize_*1024;
		if (setrlimit(RLIMIT_STACK, &rl) < 0) {
			MLFail("FATAL: Can't set stack limit: %s", strerror(errno));
		}
	}
#endif

#ifdef HAVE_SETUID
	// 1) Setuid if necessary 
	if (runAsUser_) {
		struct passwd *pwd = getpwnam([runAsUser_ UTF8String]);
		if (!pwd) {
			fprintf(stderr, "FATAL: failed to getpwname(): %s\n",strerror(errno));
			abort();
		}
		if (initgroups([runAsUser_ UTF8String], pwd->pw_gid)) {
			fprintf(stderr, "FATAL: failed to initgroups(): %s\n", strerror(errno));
			abort();
		}
		if (setuid(pwd->pw_uid)) {
			fprintf(stderr, "FATAL: failed to setuid(): %s\n", strerror(errno));
			abort();
		}
	}
#endif

// On linux we should explicitly allow core dumps.
#if HAVE_SYS_PRCTL_H == 1
	if (dropCoreDumps_) {
		if (prctl(PR_SET_DUMPABLE, 1,0,0,0) < 0) {
			fprintf(stderr, "FATAL: failed to prctl PR_SET_DUMPABLE: %s\n", strerror(errno));
			abort();
		}
	}
#endif

	// 2) Open pidfile if necessary
	if (pidFile_) {
		pidf = fopen([pidFile_ UTF8String], "wb+");
		if (!pidf) {
			fprintf(stderr, "FATAL: failed to create pid file: %s\n", strerror(errno));
			abort();
		}
	}

	// 3) Daemonize if necessary
	if (daemonize_) do_daemonize();

	// 3.5) Reinit libev
	[EVReactor forked];
	
	// 4) Write pidfile
	if (pidf) {
		fprintf(pidf, "%d", getpid());
		fclose(pidf);
	}

	// 5) Enable core dumps if necessary
	if (dropCoreDumps_) {
		coreDumpsEnabled = YES;
#if HAVE_SETRLIMIT == 1
		struct rlimit rl;
		rl.rlim_cur = RLIM_INFINITY;
		rl.rlim_max = RLIM_INFINITY;
		if (setrlimit(RLIMIT_CORE, &rl) < 0) {
			MLFail("FATAL: Can't enable core dumps: %s", strerror(errno));
		}
#endif
	}


	[sigInt_ startOnLoop:EVReactor];
#ifndef WIN32
	[sigQuit_ startOnLoop:EVReactor];
	[sigTerm_ startOnLoop:EVReactor];
	[sigHup_ startOnLoop:EVReactor];
	[sigUsr1_ startOnLoop:EVReactor];
#if MLDEBUG > 1
	[sigInfo_ startOnLoop:EVReactor];
	ev_unref((struct ev_loop *)EVReactor);
#endif
#endif

	isStarted_ = YES;
}

- (void)run
{
	if (!isStarted_) [self start];
	[EVReactor run];
}

- (void)stop
{
	if (!isStarted_) return;

	[sigInt_ stopOnLoop:EVReactor];
#ifndef WIN32
	[sigQuit_ stopOnLoop:EVReactor];
	[sigTerm_ stopOnLoop:EVReactor];
	[sigHup_ stopOnLoop:EVReactor];
	[sigUsr1_ stopOnLoop:EVReactor];
	// А sigInfo (если он есть) мы тут целенаправленно не останавливаем
	// Пусть висит и отвечает даже тогда когда вроде бы всё
#endif

	if (pidFile_) {
		if (unlink([pidFile_ UTF8String])) {
			MLLog(LOG_ERROR, "ERROR: Failed to remove pid file %@: %s", pidFile_,
				strerror(errno));
		};
	}

	isStarted_ = NO;
}

#if MLDEBUG > 1
- (void)loop:(EVLoop *)loop watcher:(EVWatcher *)w debugDumpSignal:(int)events
{
	[MLBuffer dumpDebugInfo];
}
#endif

- (void)loop:(EVLoop *)loop watcher:(EVWatcher *)w stopSignal:(int)events
{
	MLLog(LOG_INFO, "Signal caught, stopping...");
	[self stop];
}

- (void)loop:(EVLoop *)loop watcher:(EVWatcher *)w rotateSignal:(int)events
{
	[MLLogger rotate];
}

- (void)loop:(EVLoop *)loop watcher:(EVWatcher *)w reloadSignal:(int)events
{
	[MLLogger rotate];
}

- (BOOL)isStarted
{
	return isStarted_;
}

- (void)dealloc
{
	if ([self isStarted]) [self stop];

	[sigInt_ release];
#ifndef WIN32
	[sigQuit_ release];
	[sigTerm_ release];
	[sigHup_ release];
	[sigUsr1_ release];
#endif

	[runAsUser_ release];
	[pidFile_ release];
	[logDirectory_ release];
	[logName_ release];
	[cmdLineError_ release];
	[argumentsLeft_ release];

	[super dealloc];
}
@end
