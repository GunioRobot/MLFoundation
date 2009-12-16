import os.path
import sys
import SCons.Builder
import SCons.Util
import SCons.Tool

import SCons.Scanner.Prog


foundationlinkcom = '$LINK -o $TARGET $LINKFLAGS $_FOUNDATIONDEBUGLIBS $SOURCES $_LIBDIRFLAGS $_LIBFLAGS $_FOUNDATIONLIBFLAGS $_FOUNDATIONFRAMEWORKSFLAGS $_FRAMEWORKPATH $_FRAMEWORKS $_FRAMEWORKSFLAGS'

def generate(env):
  FoundationLinkAction = SCons.Action.Action(foundationlinkcom)

  env['FOUNDATIONLIBS'] = []
  env['FOUNDATIONFRAMEWORKS'] = []
  env['_FOUNDATIONDEBUGLIBS'] = ""

  env['_FOUNDATIONLIBFLAGS']='${_stripixes(LIBLINKPREFIX, FOUNDATIONLIBS, LIBLINKSUFFIX, LIBPREFIXES, LIBSUFFIXES, __env__)}'
  env['_FOUNDATIONFRAMEWORKSFLAGS'] = '${_concat("-framework ", FOUNDATIONFRAMEWORKS, "", __env__)}'

  ObjcLinkAction = SCons.Action.Action('$OBJCLINKCOM')

  if sys.platform == 'darwin':
    env.Append(FOUNDATIONFRAMEWORKS=['Foundation'])
  else:
    if sys.platform == 'win32':
		env.Append(LIBPATH=["/GNUstep/GNUstep/System/Library/Libraries"])
		env.Append(FOUNDATIONLIBS=["kernel32", "user32", "ws2_32"])
    env.Append(FOUNDATIONLIBS=['objc', 'gnustep-base'])

  env['BUILDERS']['FoundationProgram'] = SCons.Builder.Builder(action = FoundationLinkAction,
                          emitter = '$PROGEMITTER',
                          prefix = '$PROGPREFIX',
                          suffix = '$PROGSUFFIX',
                          src_suffix = '$OBJSUFFIX',
                          src_builder = 'Object',
                          target_scanner = SCons.Scanner.Prog.ProgramScanner())
  
def exists(env):
  return env.Detect('foundation-program')

