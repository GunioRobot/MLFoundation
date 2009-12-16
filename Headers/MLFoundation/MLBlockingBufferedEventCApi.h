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

#ifndef __ML_BLOCKING_BUFFERED_EVENT_C_API__
#define __ML_BLOCKING_BUFFERED_EVENT_C_API__

#include "MLBlockingBufferedEventEvents.h"

typedef void *be_fd;

ssize_t be_read(be_fd fd, void *buf, size_t count);

ssize_t be_write(be_fd fd, const void *buf, size_t count);

int be_close(be_fd fd); 

int be_wait_event(be_fd fd);

int be_signal_pending(be_fd fd);

const char *be_last_error(be_fd fd);

#endif
