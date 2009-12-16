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

#include <portability/normalized_localtime_r.h>

#include <string.h>

#ifndef HAVE_LOCALTIME_R
// A bit fake implemenation suitable for one-threaded apps
struct tm *localtime_r(const time_t *timep, struct tm *result)
{
  struct tm *t = localtime(timep);
  memcpy(result, localtime(timep), sizeof(*result));
  return result;
}
#endif

