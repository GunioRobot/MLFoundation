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

#define _GNU_SOURCE 1

#import <MLFoundation/MLCore/MLDebug.h>

#import "backtrace_symbols.h"

#if HAVE_EXECINFO_H == 1
#include <execinfo.h>
#endif

#if HAVE_BACKTRACE_SYMBOLS2 == 1
#include <bfd.h>
#include <libiberty.h>
#include <dlfcn.h>
#include <link.h>

struct file_match {
	void *address;
	int stophere;
};

static int find_matching_file(struct dl_phdr_info *info,
		size_t size, void *data)
{
	struct file_match *match = data;
	/* This code is modeled from Gfind_proc_info-lsb.c:callback() from libunwind */
	long n;
	const ElfW(Phdr) *phdr;
	ElfW(Addr) load_base = info->dlpi_addr;
	phdr = info->dlpi_phdr;
	for (n = info->dlpi_phnum; --n >= 0; phdr++) {
		if (phdr->p_type == PT_LOAD) {
			ElfW(Addr) vaddr = phdr->p_vaddr + load_base;
			if (match->address >= (void *)vaddr && match->address < (void *)vaddr + phdr->p_memsz) {
				if (strstr(info->dlpi_name, "avcall")) {
					match->stophere = 1;
				}
			}
		}
	}
	return 0;
}
#endif

static int should_i_stop_backtrace_here(void **buf, int nptrs)
{
	int rv = 0;
#if HAVE_BACKTRACE_SYMBOLS2 == 1
	struct file_match match = { .address = buf[nptrs-1], .stophere = 0 };
	dl_iterate_phdr(find_matching_file, &match);
	rv = match.stophere;
#endif
	return rv;
}

NSArray *MLBacktrace()
{
	return MLSymbolizeRawBacktrace(MLRawBacktrace());
}

NSArray *MLRawBacktrace()
{
#if HAVE_EXECINFO_H == 1 && HAVE_BACKTRACE == 1 && HAVE_BACKTRACE_SYMBOLS == 1
	int max_depth, j, nptrs;
	void *buffer[128];

	max_depth = 1;

	while (max_depth < 128) {
		nptrs = backtrace(buffer, max_depth);
		if (nptrs <= 0) return nil;

		if (nptrs < max_depth) break;

		if (should_i_stop_backtrace_here(buffer, nptrs)) break;

		max_depth++;
	}

	NSNumber *nsnumbers[128];
#define FRAMESKIP 1
	for (j=FRAMESKIP; j<nptrs; j++) {
		nsnumbers[j-FRAMESKIP] = [NSString stringWithFormat:@"%p", buffer[j]];
	}

	return [NSArray arrayWithObjects:nsnumbers count:nptrs-FRAMESKIP];

#else
	return nil;
#endif
}


NSArray *MLSymbolizeRawBacktrace(NSArray *rawBacktrace)
{
	void *buffer[128];
	char **strings;
	NSString *nsstrings[128];
	int nptrs = [rawBacktrace count];
	int i,j;

	if (!rawBacktrace) return nil;

	for (i=0; i< nptrs; i++) {
		sscanf([[rawBacktrace objectAtIndex:i] UTF8String], "%p", &buffer[i]);
	}

#if HAVE_BACKTRACE_SYMBOLS2 == 1
	strings = backtrace_symbols2(buffer, nptrs);
#else
	strings = backtrace_symbols(buffer, nptrs);
#endif
	if (!strings) return nil;

#define FRAMESKIP 1
	for (j=FRAMESKIP; j<nptrs; j++) {
		nsstrings[j-FRAMESKIP] = [NSString stringWithUTF8String:strings[j]];
	}

	free(strings);

	return [NSArray arrayWithObjects:nsstrings count:nptrs-FRAMESKIP];


}
