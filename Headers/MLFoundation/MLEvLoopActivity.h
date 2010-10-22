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
#import <MLFoundation/Protocols/MLEvLoopActivity.h>

/** Обобщённый класс процесса, управляемого событиями с EVLoop. */
@interface MLEvLoopActivity : NSObject <MLEvLoopActivity> {
	EVLoop *loop_; /*!< Process's event loop. */
}
#if __OBJC2__
@property (assign, nonatomic, readonly) EVLoop *loop;
#endif
@end
