#ifndef __NORMALIZED_LOCALTIME_R__
#define __NORMALIZED_LOCALTIME_R__

#include <time.h>
#include <libev/config.h>

#ifndef HAVE_LOCALTIME_R
struct tm *localtime_r(const time_t *timep, struct tm *result);
#endif

#endif

