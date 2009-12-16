#!/usr/bin/env python

SConscript('SConscript', variant_dir='build')

env = Environment();
env.Tool('doxygen');
env.AlwaysBuild( env.GitVersion('Doxyfile') )
env.Doxygen('Doxyfile')

