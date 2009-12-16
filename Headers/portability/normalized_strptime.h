#ifndef __NORMALIZED_STRPTIME_H__
#define __NORMALIZED_STRPTIME_H__

#include <libev/config.h>
#include <time.h>

#ifndef HAVE_STRPTIME
char *strptime(const char *buf, const char *fmt, struct tm *tm);
#endif

#ifndef HAVE_TIMEGM
time_t timegm(struct tm *tm);
#endif

#endif

