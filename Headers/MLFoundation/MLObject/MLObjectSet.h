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

/** NSMutableSet-compliant object set.
 * 
 * Базовый протокол множества объектов. Подмножество методов NSMutableSet.
 * 
 * Copyright 2009 undev
 */
@protocol MLObjectSet
/** Добавить объект в множество. */
- (void)addObject:(id)object;
/** Удалить объект из множества. */
- (void)removeObject:(id)object;
/** Количество объектов в множестве. */
- (NSUInteger)count;

/** NSEnumerator множества. */
- (NSEnumerator *)objectEnumerator;

/** Выполнить на каждом объекте селектор без аргументов. */
- (void)makeObjectsPerformSelector:(SEL)selector;
@end
