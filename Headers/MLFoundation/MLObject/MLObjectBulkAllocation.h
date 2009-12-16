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

#import <Foundation/Foundation.h>
#import <MLFoundation/MLObject/MLObject.h>

md *MLObjectBulkAllocWrapped(Class klass, uint32_t capacity, BOOL instantReify);
#define MLObjectBulkAlloc(klass, cnt) ((klass **)MLObjectBulkAllocWrapped([klass class], cnt, NO))
#define MLObjectBulkAllocReify(klass, cnt) ((klass **)MLObjectBulkAllocWrapped([klass class], cnt, YES))

uint32_t MLObjectBulkCapacity(md *objects);

md *MLObjectBulkReallocWrapped(md *bulkAllocatedObjects, uint32_t newCapacity, BOOL instantReify);
#define MLObjectBulkRealloc(klass, objects, cnt) ((klass **)MLObjectBulkReallocWrapped(objects, cnt, NO))
#define MLObjectBulkReallocReify(klass, objects, cnt) ((klass **)MLObjectBulkReallocWrapped(objects, cnt, YES))

void MLObjectBulkFree(md *objects);
