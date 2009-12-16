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

#include <stdio.h>
#include <stdarg.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>

#include <limits.h>
#include <time.h>

#import <MLFoundation/EVBindings/EVLoop.h>
#import <MLFoundation/MLCore/MLLogger.h>
#import <MLFoundation/MLCore/MLSessionSet.h>
#import <MLFoundation/MLCore/MLDebug.h>

#import <MLFoundation/MLCore/MLCategories.h>
#import <MLFoundation/MLCore/MLIdioms.h>


static int log_level = DEFAULT_LOG_LEVEL;
static NSString *log_dir = nil;

MLLogger *globalLogger = nil;
const MLLogger *__localLogger_ = nil;

const char *__endOfArgs = "";

static MLSessionSet *loggers = nil;

@implementation MLLogger
static void destroy_global_logger(void)
{
	if ([loggers count] > 2) {
		MLLog(LOG_WARNING, 
			"WARNING: Undestroyed loggers found at teardown. Check your memory management!");
		MLLog(LOG_DEBUG,
			"Loggers: %@", loggers);
	} else {
		[globalLogger release];
		globalLogger = nil;

		[loggers release];
		loggers = nil;
	}
}

+ (void)load
{
	loggers = [[MLSessionSet alloc] initWithCapacity:256];

	globalLogger = [[MLStdioLogger alloc] initWithFile:stderr];

	atexit(destroy_global_logger);
}

+ (MLLogger *)setLogName:(NSString *)_name
{
	if (_name == [globalLogger name]) return globalLogger;
	MLLogger *newGlobalLogger = [[MLStdioLogger alloc] initWithLogName:_name];
	if (newGlobalLogger) {
		[globalLogger release];
		globalLogger = newGlobalLogger;
		return globalLogger;
	} else {
		return nil;
	}
}

+ (MLLogger *)setupChildLogger
{
	if (!globalLogger) return nil;
	NSString *pidPrefix = [NSString stringWithFormat:@"[%d]", getpid()];
	MLPrefixedLogger *newGlobalLogger = [[MLPrefixedLogger alloc] initWithDelegate:globalLogger
		prefix:pidPrefix];

	if (newGlobalLogger) {
		[newGlobalLogger setPutColon:NO];
		[globalLogger release];
		globalLogger = newGlobalLogger;
		return globalLogger;
	} else {
		return nil;
	}
}

+ (void)setLogDirectory:(NSString *)_log_dir
{
	if (log_dir == _log_dir) return;
	[log_dir release];
	log_dir = [_log_dir retain];
}

+ (MLStdioLogger *)newLoggerWithName:(NSString *)name
{
	return [[MLStdioLogger alloc] initWithLogName:name];
}

+ (void)setLogLevel:(int)_log_level
{
	log_level = _log_level;
}

+ (void)rotate
{
	[loggers makeObjectsPerformSelector:@selector(rotate)];
}

- (MLLogger *)init
{
	if (![super init]) return nil;

	[loggers addObject:self];

	return self;
}

- (void)logMessage:(const char *)fmt args:(va_list)ap level:(int)level
{ 
	[self subclassResponsibility:_cmd];
}

+ (MLPrefixedLogger *)newLoggerWithPrefix:(NSString *)prefix
{
	return [[MLPrefixedLogger alloc] initWithDelegate:globalLogger prefix:prefix];
}

- (MLPrefixedLogger *)newLoggerWithPrefix:(NSString *)prefix
{
	return [[MLPrefixedLogger alloc] initWithDelegate:self prefix:prefix];
}

- (void)rotate
{
	MLLog2(self, LOG_INFO, "INFO: Rotating...");
}

- (NSString *)name
{
	return nil;
}

- (void)dealloc
{
	[loggers removeObject:self];

	[super dealloc];
}
@end

@implementation MLStdioLogger
- (id)init
{
	if (!(self = (MLStdioLogger *)[super init])) return nil;

	buf_len = 1024;
	buf = malloc(1024);

	return self;
}

- (MLStdioLogger *)initWithFile:(FILE *)_output
{
	if (!(self = [self init])) return nil;  
	fname = [@"" retain];
	name = [@"" retain];
	output = _output;  
	return self;
}

- (MLStdioLogger *)initWithLogName:(NSString *)_name
{
	if (!(self = [self init])) return nil;  

	MLReleaseSelfAndReturnNilUnless(log_dir);

	name = [_name retain];

	fname = [[[log_dir stringByAppendingPathComponent:_name] 
		stringByAppendingPathExtension:@"log"] retain];

	output = fopen([fname UTF8String], "ab");
	MLReleaseSelfAndReturnNilUnless(output);

	return self;
}

- (void)logMessage:(const char *)fmt args:(va_list)ap level:(int)level
{
	char time_buf[256];
	time_t now_time_t;
	struct tm now_tm;

	if (output && level >= log_level) {
		now_time_t = (time_t) [EVReactor now];
		localtime_r(&now_time_t, &now_tm);
#ifndef WIN32
		strftime(time_buf, 256, "%b %e %T ", &now_tm);
#else
		strftime(time_buf, 256, "%b %d %H:%M:%S ", &now_tm);
#endif

		int new_fmt_len = strlen(fmt) + 2 + strlen(time_buf);
		if (new_fmt_len > buf_len) {
			buf_len = new_fmt_len;
			buf = realloc(buf, new_fmt_len + 10);
		}
		snprintf(buf, buf_len, "%s%s\n", time_buf, fmt);
		vfprintf(output, buf, ap);
		fflush(output);
	}
}

- (NSString *)name
{
	return name;
}

- (void)rotate
{
	[super rotate];
	if (output && output != stderr && output != stdout) {
		fclose(output);
		output = fopen([fname UTF8String], "ab");
	}
}

- (void)dealloc
{
	if (output && output != stderr && output != stdout) {
		fclose(output);
	}

	if (buf) free(buf);

	[name release];
	[fname release];
	[super dealloc];
}
@end

@implementation MLPrefixedLogger
- (MLPrefixedLogger *)initWithDelegate:(MLLogger *)_delegate prefix:(NSString *)_prefix
{
	delegate = _delegate;
	if (![super init]) return nil;

	prefix_len = [_prefix lengthOfBytesUsingEncoding: NSASCIIStringEncoding];
	[_prefix getCString:prefix maxLength:MAX_PREFIX_LENGTH-1 encoding:NSASCIIStringEncoding];

	buf_len = 1024;
	buf = malloc(1024);
	putColon = YES;

	[delegate retain];

	return self;
}

- (void)logMessage:(const char *)fmt args:(va_list)ap level:(int)level
{
	int new_fmt_len = strlen(fmt) + 2 + prefix_len;
	if (strlen(fmt) + 2 + prefix_len > buf_len) {
		buf_len = new_fmt_len;
		buf = realloc(buf, new_fmt_len + 10);
	}
	strcpy(buf, prefix);
	if (putColon) {
		strcat(buf, ": ");
	} else {
		strcat(buf, " ");
	}
	strcat(buf, fmt);
	[delegate logMessage:buf args:ap level:level];
}

- (void)setPutColon:(BOOL)_putColon
{
	putColon = _putColon;
}

- (void)dealloc
{
	  free(buf);
	  [delegate release];
	  [super dealloc];
}
@end

@implementation NSObject (MLLocalLogger)
- (MLLogger *)logger
{
	return [self valueForKey:@"__localLogger_"];
}

- (void)setLogger:(MLLogger *)logger
{
	[self setValue:logger forKey:@"__localLogger_"];
	[logger release];
}
@end

void MLLogAssertion2(MLLogger *logger, const char *what, char *file, int line, char *condition, ...) 
{
	va_list arg_ptr;

	if (!logger) return;

	va_start(arg_ptr, condition);

	char *format = va_arg(arg_ptr, char *);
	NSString *reason = format ? 
		[[NSString alloc] initWithFormat:[NSString stringWithCString:format] arguments:arg_ptr] : 
		[[NSString alloc] initWithUTF8String:condition];

	MLLog2(logger, LOG_FATAL, "%s failed at %s:%d (%s)", what, file, line, [reason UTF8String]);

#if HAVE_MLLOG_BACKTRACE == 1
	MLLogBacktrace2(logger, LOG_FATAL, 2);
#endif

	[reason release];

	va_end(arg_ptr);
}

void MLLogVa2(MLLogger *logger, int level, const char *fmt, va_list arg_ptr)
{
	if (!logger) return;

	if (!strstr(fmt, "%@")) {
		[logger logMessage:fmt args:arg_ptr level:level];
	} else {
		NSString *s_fmt = [[[NSString alloc] initWithCString:fmt] autorelease];
		NSString *s = [[[NSString alloc] initWithFormat:s_fmt arguments:arg_ptr] autorelease];

		MLLog2(logger, level, "%s", [s UTF8String]);
	}
}

void MLLog2(MLLogger *logger, int level, const char *fmt, ...) {
	va_list arg_ptr;

	if (!logger) return;

	va_start(arg_ptr, fmt);

	MLLogVa2(logger, level, fmt, arg_ptr);

	va_end(arg_ptr);
}

#define HEXDUMP_COLUMNS 16

void MLLogHexdump2(MLLogger *logger, int level, uint8_t *data, int size) {
	if (level < log_level) return;
	char buffer[10+HEXDUMP_COLUMNS*4];
	char octet_buffer[4];

	int i,j;
	for (i=0; i<size; i+=HEXDUMP_COLUMNS) {
		sprintf(buffer, "%03x: ", i);
		for (j=i; j<i+16; j++) {
			if (j<size) {
				sprintf(octet_buffer, "%02x ", data[j]);
			} else {
				sprintf(octet_buffer, "   ");
			}
			strcat(buffer, octet_buffer);
		}
		for (j=i; j<i+16; j++) {
			if (j<size) {
				if (data[j]>=0x20 && data[j]<0x80) {
					octet_buffer[0] = data[j];
					octet_buffer[1] = '\0';
				} else {
					sprintf(octet_buffer, ".");
				}
			} else {
				sprintf(octet_buffer, " ");
			}
			strcat(buffer, octet_buffer);
		}
		MLLog2(logger, level,"%s", buffer);
	}
}

void MLLogBacktrace2(MLLogger *logger, int level, int skip) {
	int j;

	NSArray *backtrace = MLBacktrace();

	if (!backtrace) {
		MLLog2(logger, level, "Error getting backtrace: %s", strerror(errno));
	} else {
		MLLog2(logger, level, "BACKTRACE:");
		for (j = skip; j < [backtrace count] ; j++) {
			MLLog2(logger, level, "%@", [backtrace objectAtIndex:j]);
		}
		MLLog2(logger, level, "-------------------------");
	}
}
