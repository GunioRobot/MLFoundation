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
#import <MLFoundation/MLObject/MLValue.h>
#import <MLFoundation/MLCore/MLSerializable.h>

@protocol MLSerializableValue <MLValue>
/** Развернуть объект из потока. Обязан возвращать не-nil при любой ощибке. В случае
 * ошибки состояние объекта не определено, состояние потока не меняется. */
- (NSError *)assignFromStream:(id<MLStream>)buf;

/** Скинуть объект в поток. Обязан возвращать не-nil при любой ощибке. В случае ошибки обязан
 * не менять состояние потока. */
- (NSError *)dumpToStream:(id<MLStream>)buf;
@end
