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

#include <portability/normalized_networking.h>

#include <stdlib.h>

BOOL ev_set_nonblock(NSSocketNativeHandle fd)
{
#ifdef WIN32
  int flags = 1;

  if (ioctlsocket(fd, FIONBIO, &flags) != 0) {
      return NO;
  }
#else
  int flags;

  if ((flags = fcntl(fd, F_GETFL, 0)) < 0)  { 
      return NO;
  } 
  
  if (fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0)  { 
      return NO;
  }                        
#endif
  return YES;
}

int ev_last_error()
{
#ifdef WIN32
	errno = WSAGetLastError();
#endif
	return errno;
}

#ifndef HAVE_INET_ATON
int inet_aton(const char *cp, struct in_addr *pin)
{
  unsigned long rv = inet_addr(cp);
  if (rv == INADDR_NONE) return 0;
  pin->S_un.S_addr = rv;
  return 1;
}
#endif
