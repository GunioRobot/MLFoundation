#!/usr/bin/env python

import os.path
import sys
import SCons.Tool
from SCons.Script.SConscript import SConsEnvironment

# 0) ============= Instal objc & foundation-program tools everywhere =============
# (TODO - use AddMethod?)

# Semi-clever hack to add scons_tools dir
SCons.Tool.DefaultToolpath.append(str(Dir('scons_tools').srcnode()))

# Unclever hack to add objc to default tools list
tool_list_without_objc = SCons.Tool.__dict__['tool_list']
def tool_list_with_objc(platform, env):
  return tool_list_without_objc(platform, env) + ['objc', 'foundation-program', 'git-version']
SCons.Tool.__dict__['tool_list'] = tool_list_with_objc

# Again unclever hack to add tools to DefaultEnvironment.
DefaultEnvironment().Tool('objc')
DefaultEnvironment().Tool('foundation-program')

DEFAULT_DEBUG=1

# 0) ==================================== Debug hook ================================
def SetupCommandLineDebug(env, default = DEFAULT_DEBUG):
  debug = ARGUMENTS.get('debug')
  if (debug == None):
  	debug = default
  debug = int(debug)

  if debug == 0:
    env.Append(CCFLAGS="-O3 -DNDEBUG")
    env.Append(OBJCFLAGS="-O3 -DNDEBUG")
  else:
    env.Append(CCFLAGS="-g -O0 -Wall -DMLDEBUG=%d" % debug)
    env.Append(OBJCFLAGS="-g -O0 -Wall -DMLDEBUG=%d" % debug)
    if sys.platform != 'darwin':
	  env.Append(_FOUNDATIONDEBUGLIBS = "-lbfd")


SConsEnvironment.SetupCommandLineDebug = SetupCommandLineDebug

# 0.1) =========================== Static linkage hooks =============================
def SetupMLFoundation(env):
  env.Append(LIBPATH=["MLFoundation", "MLFoundation/libpcre"], CPPPATH=["MLFoundation/Headers"], LIBS=["ml-base", "pcre"])
  if sys.platform == 'win32':
    env.Append(CCFLAGS="-DPCRE_STATIC")
    env.Append(OBJCFLAGS="-DPCRE_STATIC")

SConsEnvironment.SetupMLFoundation = SetupMLFoundation

# 0.2) ============================= TCMalloc hook ==================================
def SetupTCMalloc(env):
  if sys.platform == 'darwin':
    env.Append(LIBPATH=["/opt/local/lib"])

  lib_names = ['tcmalloc_minimal']
  conf = Configure(env)
  if conf.CheckLib('tcmalloc_minimal'):
  	return

  print "*" * 80
  print " *  TCMalloc library not found. libc allocator known to fail with libav*,"
  print " * so do not use this build for anything real. "
  print "*" * 80

SConsEnvironment.SetupTCMalloc = SetupTCMalloc

env = Environment()

env.SetupCommandLineDebug()
env.Append(CCFLAGS="-Wno-unused-function", OBJCFLAGS="-Wno-unused-function")

if not sys.platform == 'win32':
  env.Append(CCFLAGS="-Werror", OBJCFLAGS='-Werror')

# 1) === Configure =====
# WARNING: We are ignoring librt option here.

conf = Configure(env, config_h="Headers/libev/config.h")
LIBEV_HEADERS = 'sys/inotify.h sys/epoll.h sys/event.h sys/queue.h port.h poll.h sys/select.h sys/eventfd.h valgrind/valgrind.h '
LIBEV_CFUNCS = 'inotify_init epoll_ctl kqueue port_create poll select eventfd nanosleep '
MLAPP_HEADERS = 'grp.h pwd.h sys/resource.h machine/endian.h endian.h sys/prctl.h execinfo.h bfd.h libiberty.h dlfcn.h link.h objc/runtime.h '
MLAPP_CFUNCS = 'setuid setpriority setrlimit backtrace backtrace_symbols mremap'

PORTABILITY_CFUNCS = 'localtime_r strsep inet_aton strptime timegm '

for header in (LIBEV_HEADERS + MLAPP_HEADERS).split():
  conf.CheckCHeader(header)

for cfunc in (LIBEV_CFUNCS + PORTABILITY_CFUNCS + MLAPP_CFUNCS).split():
  conf.CheckFunc(cfunc)

if not conf.CheckFunc('clock_gettime'):
  clock_gettime_syscall_source = """
#include <syscall.h>
#include <time.h>
int main() {
struct timespec ts; int status = syscall (SYS_clock_gettime, CLOCK_REALTIME, &ts);
}
  """
  if conf.TryLink(clock_gettime_syscall_source, '.c'):
    conf.Define("HAVE_CLOCK_SYSCALL", 1, "use syscall interface for clock_gettime");

# Win32 hardcode
if sys.platform == 'win32':
  conf.Define("EV_USE_SELECT", 1, "use select interface on win32");

env = conf.Finish()

env.Append(CPPPATH=['Headers'])

evCoreEnv = env.Clone()
debug = ARGUMENTS.get('debug')
if (debug != None and int(debug)) or (debug == None and int(DEFAULT_DEBUG)):
	evCoreEnv.Replace(OBJCFLAGS="-O0 -g")
	evCoreEnv.Replace(CCFLAGS="-O0 -g -w")
else:
	evCoreEnv.Replace(OBJCFLAGS="-O3")
	evCoreEnv.Replace(CCFLAGS="-O3 -w")
libevCore = evCoreEnv.Object('Sources/EVBindings/EVCore.m')
backtraceSymbols = evCoreEnv.Object('Sources/MLCore/backtrace_symbols.c')
evCoreEnv.Depends(libevCore, 'libev/ev.c')

libpcre = SConscript('libpcre/SConscript', exports='env')

mlFoundationSources = [ 'Sources/EVBindings/EVLoop.m',
						'Sources/EVBindings/EVWatcher.m',
						'Sources/EVBindings/EVTimerWatcher.m',
						'Sources/EVBindings/EVIoWatcher.m',
						'Sources/EVBindings/EVAsyncWatcher.m',
						'Sources/EVBindings/EVSignalWatcher.m',
						'Sources/EVBindings/EVChildWatcher.m',
						'Sources/EVBindings/EVLaterWatcher.m',
						'Sources/EVBindings/EVCheckWatcher.m',
						'Sources/EVBindings/EVPrepareWatcher.m',
						'Sources/EVBindings/EVStatWatcher.m',
						'Sources/MLCore/MLLogger.m',
						'Sources/MLCore/MLDebug.m',
						'Sources/MLCore/MLCategories.m',
						'Sources/MLCore/MLFoundationErrorDomain.m',
						'Sources/MLCore/MLSessionSet.m',
						'Sources/MLCore/MLReallocationPolicy.m',
						'Sources/MLObject/MLObject.m',
						'Sources/MLObject/MLObjectBulkAllocation.m',
						'Sources/MLObject/MLValue.m',
						'Sources/MLEvLoopActivity.m',
						'Sources/MLStreamFunctions.m',
						'Sources/MLBuffer.m',
						'Sources/MLConnection.m',
						'Sources/MLCoroutine.m',
						'Sources/MLBlockingBufferedEvent.m',
						'Sources/MLTCPAcceptor.m',
						'Sources/MLTCPClientConnection.m',
						'Sources/MLHTTPClient.m',
						'Sources/MLHTTPServerConnection.m',
						'Sources/MLStream.m',
						'Sources/MLApplication.m',
						'Sources/MLMultiWorkerApplication.m',
						'Sources/MLWorkerAcceptor.m',
						'Sources/MLWorkerTunnel.m',
						'Sources/md5.m',
						'JSON/NSObject+SBJSON.m',
						'JSON/NSString+SBJSON.m',
						'JSON/SBJSON.m',
						'JSON/SBJsonBase.m',
						'JSON/SBJsonParser.m',
						'JSON/SBJsonWriter.m',
						'libcoroutine/Coro.c',
						'libcoroutine/PortableUContext.h',
						'portability/normalized_strsep.c',
						'portability/normalized_strptime.c',
						'portability/normalized_writev.m',
						'portability/normalized_localtime_r.c',
						'portability/normalized_networking.m']

env.AlwaysBuild( env.GitVersion('Headers/MLFoundation/version.h.in') )

objPcre = env.Object('objpcre/objpcre.m')
env.Depends(objPcre, [libpcre])

mlBase = env.StaticLibrary('ml-base', [libevCore, backtraceSymbols, mlFoundationSources, objPcre])
env.Depends(mlBase, [libevCore, mlFoundationSources, libpcre, objPcre])
