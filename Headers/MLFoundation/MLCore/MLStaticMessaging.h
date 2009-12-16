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

#define STATIC_SELIMP(slctr, klass) \
	static SEL __selector = NULL; \
	if (!__selector) __selector = @selector(slctr); \
	static IMP __imp = NULL; \
	if (!__imp) __imp = [[klass class] instanceMethodForSelector:__selector];

#define RETTYPE_IMP(rettype, imp) (rettype)((rettype (*)(id, SEL, ...)) imp)
	

#define STATICMSG(rettype, klass, instance, slctr) \
	({ \
		STATIC_SELIMP(slctr, klass); \
		RETTYPE_IMP(rettype, __imp)(instance, __selector); \
	})

#define STATICMSG_1A(rettype, klass, instance, slctr, a1) \
	({ \
		STATIC_SELIMP(slctr, klass); \
		RETTYPE_IMP(rettype, __imp)(instance, __selector, a1); \
	})

#define STATICMSG_2A(rettype, klass, instance, slctr, a1, a2) \
	({ \
		STATIC_SELIMP(slctr, klass); \
		RETTYPE_IMP(rettype, __imp)(instance, __selector, a1, a2); \
	})

