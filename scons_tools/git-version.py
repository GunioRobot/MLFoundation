import os.path
import re
import sys
import SCons.Builder
import SCons.Util
import SCons.Tool


def generate(env):
  def build_git_version_header(target, source, env):
    def find_git_dir(dir):
      if os.path.exists(os.path.join(dir, '.git')):
        return os.path.join(dir, '.git')
      if not dir or os.path.split(dir)[0] == dir:
        return ''
      return find_git_dir(os.path.split(dir)[0])

    for a_target, a_source in zip(target, source):
      git_version = ''
      git_dir = find_git_dir(os.path.dirname(str(a_source.srcnode())))
      if (git_dir):
        git_cmd = 'git --git-dir=%s ' % (git_dir)
        git_version=os.popen(git_cmd + 'describe --abbrev=7 HEAD 2> /dev/null').read().strip()

        if re.search("^v[0-9]", git_version):
          os.system(git_cmd + 'update-index -q --refresh')
          changes = os.popen(git_cmd + 'diff-index --name-only HEAD').read().strip()
          if changes:
            git_version = git_version + '-m'
        
      if not git_version:
        git_version = 'unknown'

      conf_h_defines = {
        'GIT_VERSION' : git_version
      }

      config_h = file(str(a_target), 'w')
      config_h_in = file(str(a_source), 'r')
      config_h.write(config_h_in.read() % conf_h_defines)
      config_h_in.close()
      config_h.close()

  env['BUILDERS']['GitVersion'] = SCons.Builder.Builder(action = build_git_version_header,
                              src_suffix = '.in')

def exists(env):
  return env.Detect('git-version')
