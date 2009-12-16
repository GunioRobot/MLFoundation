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
#import <MLFoundation/MLCore/MLSerializable.h>
#import <MLFoundation/MLObject/MLObject.h>

@class MLValue; 

@protocol MLValue <MLObject>
- (void)assign:(MLValue *)otherValue;
- (BOOL)isNull;
@end

/** Объект-значение.
 *
 * Может быть mutable, и может иметь public-члены. Не привязан к внешним ресурсам.
 * Имеет метод assign:, которым присваивается.
 *
 * Подкласс обязуется переопределить методы:
 *
 *  - assign
 *  - copy
 *  - isEqual
 *  - hash
 *
 * Copyright 2009 undev
 */
@interface MLValue : MLObject <MLValue> {
}
/** Действующая через протокол MLSerizableValue типовая имплементация. Инициализирует
 * значение, пытается сделать assign. */
- (id)initFromStream:(id<MLStream>)buf error:(NSError **)error;

/** Присвоить значение другого MLValue. Все входящие в состав другого MLValue объекты должны
 * при этом быть скопированы. Должна быть выполнена проверка типа - можно ли сюда присвоить
 * этот MLValue? Иными словами, является ли otherValue kindOf [self class] ?
 * Если нет, то должен выстрелить MLFail. */
- (void)assign:(MLValue *)otherValue;

/** Типовое копирование через alloc - init - assign. */
- (id)copy;

/** Null для MLObject-based имплементации - unreified состояние. */
- (BOOL)isNull;
@end

