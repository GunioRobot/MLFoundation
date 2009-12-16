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

#include <Foundation/Foundation.h>

/** MLFoundation-specific addiotions to NSObject class.
 * (спёрты из GNUStep, в свою очередь они спёрли из smalltalk)
 */
@interface NSObject(MLCategories)
+ (id)notImplemented:(SEL)aSel;
+ (id)subclassResponsibility:(SEL)aSel;
+ (id)shouldNotImplement:(SEL)aSel;

- (id)notImplemented:(SEL)aSel;
- (id)subclassResponsibility:(SEL)aSel;
- (id)shouldNotImplement:(SEL)aSel;
@end

/** MLFoundation-specific additions to NSError class.
 */
@interface NSError(MLCategories)
- initWithDomain:(NSString *)domain code:(NSInteger)code
	localizedDescriptionFormat:(NSString *)fmt,...;

+ errorWithDomain:(NSString *)domain code:(NSInteger)code
	localizedDescriptionFormat:(NSString *)fmt,...;

- (int)errnoCode;
@end

/** Fast [NSError code]. */
NSInteger NSErrorCode(NSError *error);

void initMLCategories();
