import os.path
import sys
import platform
import SCons.Builder
import SCons.Util
import SCons.Tool

import SCons.Scanner.Prog

objccom = '$OBJC -o $TARGET -c $_CPPINCFLAGS $_OBJCPPINCFLAGS $OBJCFLAGS $SOURCE'
objcscom = '$OBJC -o $TARGET -c -fPIC $_CPPINCFLAGS $_OBJCPPINCFLAGS $OBJCFLAGS $SOURCE'

def generate(env):
  static_obj, shared_obj = SCons.Tool.createObjBuilders(env)

  StaticObjcAction = SCons.Action.Action("$OBJCCOM")
  SharedObjcAction = SCons.Action.Action("$OBJCSCOM")
  
  static_obj.add_action('.m', StaticObjcAction)
  shared_obj.add_action('.m', StaticObjcAction)
  static_obj.add_emitter('.m', SCons.Defaults.StaticObjectEmitter)
  shared_obj.add_emitter('.m', SCons.Defaults.SharedObjectEmitter)

  if sys.platform == 'darwin' and platform.uname()[2] == '10.0.0':
    env['OBJC'] = 'gcc-4.0'
  else:
    env['OBJC'] = 'gcc'

  # What a hack!
  if sys.platform == 'darwin' and platform.uname()[2] == '10.0.0':
    env['CC'] = 'gcc-4.0'

  env['OBJCFLAGS'] = SCons.Util.CLVar('')
  env['OBJCPPPATH'] = []
  env['OBJCCOM'] = SCons.Action.Action(objccom)
  env['OBJCSCOM'] = SCons.Action.Action(objcscom)
  env['_OBJCPPINCFLAGS'] = '${_concat(INCPREFIX, OBJCPPPATH, INCSUFFIX, __env__, RDirs, TARGET, SOURCE)}',

  env.Append(OBJCFLAGS="-fobjc-exceptions")

  if sys.platform != 'darwin':
    env.Append(OBJCFLAGS='-fconstant-string-class=NSConstantString')
    if sys.platform == 'win32':
	  env.Append(OBJCPPPATH = ['/GNUstep/GNUstep/System/Library/Headers/', "/GNUstep/GNUstep/local/include"])
    else:
      env.Append(OBJCPPPATH=['/usr/include/GNUstep'])

def exists(env):
  return env.Detect('objc')

