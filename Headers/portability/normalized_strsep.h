#ifndef __NORMALIZED_STRSEP_H__
#define __NORMALIZED_STRSEP_H__

#include <libev/config.h>

#ifdef HAVE_STRSEP
#include <string.h>
#else

#include <stdlib.h>

char *strsep (char **stringp, const char *delim);

#endif

#endif

