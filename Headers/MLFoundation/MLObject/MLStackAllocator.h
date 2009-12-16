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

// Набор макросов для выделения выровненой памяти на стеке через alloca()

#define MLStack_alignment ( 2 * sizeof(size_t) )
#define MLStack_alignextra (MLStack_alignment - 1)
#define MLStack_alignmask  (MLStack_alignment - 1)
#define MLStack_misalignment(__p) ( (uintptr_t)__p & MLStack_alignmask )
#define MLStack_aligned_pointer(__p) (__p + (MLStack_alignment - MLStack_misalignment(__p)))

#define MLStack_alloca(__size) (MLStack_aligned_pointer(alloca(__size + MLStack_alignextra)))
