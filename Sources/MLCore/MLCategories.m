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
#import <MLFoundation/MLCore/MLAssert.h>
#import <MLFoundation/MLCore/MLCategories.h>

#import <portability/normalized_networking.h>

#include <stdarg.h>

@class NSError;
@class NSObject;

@implementation NSObject (MLCategories)
+ (id)notImplemented: (SEL)aSel
{
	MLFail("Method %s is not implemented in %s",
		aSel ? [NSStringFromSelector(aSel) UTF8String] : "(null)",
		[[self className] UTF8String]);
  return nil;
}

+ (id)shouldNotImplement: (SEL)aSel
{
	MLFail("%s should not implement %s",
		[[self className] UTF8String],
		aSel ? [NSStringFromSelector(aSel) UTF8String] : "(null)");

  return nil;
}

+ (id)subclassResponsibility: (SEL)aSel
{
	MLFail("Subclass of %s should override %s",
		[[self className] UTF8String],
		aSel ? [NSStringFromSelector(aSel) UTF8String] : "(null)");

  return nil;
}
- (id)notImplemented: (SEL)aSel
{
	MLFail("Method %s is not implemented in %s",
		aSel ? [NSStringFromSelector(aSel) UTF8String] : "(null)",
		[[[self class] className] UTF8String]);
  return nil;
}

- (id)shouldNotImplement: (SEL)aSel
{
	MLFail("%s should not implement %s",
		[[[self class] className] UTF8String],
		aSel ? [NSStringFromSelector(aSel) UTF8String] : "(null)");

  return nil;
}

- (id)subclassResponsibility: (SEL)aSel
{
	MLFail("Subclass of %s should override %s",
		[[[self class] className] UTF8String],
		aSel ? [NSStringFromSelector(aSel) UTF8String] : "(null)");

  return nil;
}
@end

@implementation NSError (MLCategories)
+ errorWithDomain:(NSString *)domain code:(NSInteger)code
	localizedDescriptionFormat:(NSString *)fmt,...
{
	va_list ap;

	va_start(ap, fmt);
	NSString *errorDescription = [[[NSString alloc] initWithFormat:fmt arguments:ap] 
								 autorelease];
	va_end(ap);

	return [self errorWithDomain:domain code:code 
				userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
										errorDescription, NSLocalizedDescriptionKey,
										[NSNumber numberWithInt:ev_last_error()], @"errno",
										nil]];
}

- initWithDomain:(NSString *)domain code:(NSInteger)code
	localizedDescriptionFormat:(NSString *)fmt,...
{
	va_list ap;

	va_start(ap, fmt);
	NSString *errorDescription = [[[NSString alloc] initWithFormat:fmt arguments:ap] 
								 autorelease];
	va_end(ap);

	return [self initWithDomain:domain code:code 
				userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
										errorDescription, NSLocalizedDescriptionKey,
										[NSNumber numberWithInt:ev_last_error()], @"errno",
										nil]];
}

- (int)errnoCode
{
	NSNumber *errnoCode = [[self userInfo] objectForKey:@"errno"];
	if (errnoCode) {
		return [errnoCode intValue];
	} else {
		return 0;
	}
}
@end

typedef NSInteger (*NSErrorCodeIMP)(id, SEL);

NSInteger NSErrorCode(NSError *error)
{
	static SEL selector = NULL;
	static NSErrorCodeIMP impl = NULL;
	if (!error) return 0;
	if (!selector) selector = @selector(code);
	if (!impl) impl = (NSErrorCodeIMP)[NSError instanceMethodForSelector:selector];
	return (*impl)(error, selector);
}

/* Hack to work around there optimizing linkers. */
void initMLCategories()
{
}
