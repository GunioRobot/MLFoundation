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

#define DEFAULT_SESSION_SET_CAPACITY 64

@class MLSessionSet;

@interface MLSessionSetEnumerator : NSEnumerator {
	MLSessionSet *set_;
	NSHashEnumerator e_;
}
- initWithSessionSet:(MLSessionSet *)set;
@end

/** Неретейнящий массив для обслуживания списка сессий/соединений.
 *
 * Класс для хранения списка соединений без привлечения autoreleasepool.
 * addObject и removeObject не приводят к retain/release , но деаллокация
 * приводит к release всего.
 *
 * Нужен для того, чтобы держать список соединений с сервером и оборвать
 * их разом во время деаллокации сервера. Предполагается, что addObject
 * будет вызываться из конструктора соединения, а removeObject - из
 * деаллокатора соединения.
 *
 * Copyright 2009 undev
 */
@interface MLSessionSet : NSObject {
@private
	NSHashTable *sessions_;
}
/** Создать список сессий с заданым начальным объёмом. */
- initWithCapacity:(unsigned int)capacity;

/** Добавить сессию в список. */
- (void)addObject:(id)object;
/** Удалить сессию из списка. */
- (void)removeObject:(id)object;

/** Есть ли такая сессия? */
- (BOOL)containsObject:(id)anObject;

/** Количество сессий в списке. */
- (NSUInteger)count;

/** NSEnumerator списка. */
- (NSEnumerator *)objectEnumerator;

/** Выполнить на каждом объекте селектор без аргументов. */
- (void)makeObjectsPerformSelector:(SEL)selector;
@end
