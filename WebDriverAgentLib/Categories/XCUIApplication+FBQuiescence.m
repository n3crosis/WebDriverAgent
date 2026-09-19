/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "XCUIApplication+FBQuiescence.h"

#import <objc/runtime.h>

#import "FBConfiguration.h"
#import "XCUIApplicationImpl.h"
#import "XCUIApplicationProcess.h"
#import "XCUIApplicationProcess+FBQuiescence.h"

static void (*original_waitForQuiescence)(id, SEL);
static void (*original_waitForQuiescenceAsPreEvent)(id, SEL, BOOL);

static BOOL fb_quiescenceChecksDisabled(void)
{
  return FBConfiguration.sharedInstance.waitForIdleTimeout < DBL_EPSILON;
}

static void swizzledWaitForQuiescence(id self, SEL _cmd)
{
  if (fb_quiescenceChecksDisabled()) {
    return;
  }
  original_waitForQuiescence(self, _cmd);
}

static void swizzledWaitForQuiescenceAsPreEvent(id self, SEL _cmd, BOOL isPreEvent)
{
  if (fb_quiescenceChecksDisabled()) {
    return;
  }
  original_waitForQuiescenceAsPreEvent(self, _cmd, isPreEvent);
}

@implementation XCUIApplication (FBQuiescence)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-load-method"
#pragma clang diagnostic ignored "-Wcast-function-type-strict"

+ (void)load
{
  Method method = class_getInstanceMethod(self.class, NSSelectorFromString(@"_waitForQuiescence"));
  if (nil != method) {
    original_waitForQuiescence = (void (*)(id, SEL)) method_setImplementation(method, (IMP)swizzledWaitForQuiescence);
  }
  method = class_getInstanceMethod(self.class, NSSelectorFromString(@"_waitForQuiescenceAsPreEvent:"));
  if (nil != method) {
    original_waitForQuiescenceAsPreEvent = (void (*)(id, SEL, BOOL)) method_setImplementation(method, (IMP)swizzledWaitForQuiescenceAsPreEvent);
  }
}

#pragma clang diagnostic pop

- (BOOL)fb_shouldWaitForQuiescence
{
  return [[self applicationImpl] currentProcess].fb_shouldWaitForQuiescence.boolValue;
}

- (void)setFb_shouldWaitForQuiescence:(BOOL)value
{
  [[self applicationImpl] currentProcess].fb_shouldWaitForQuiescence = @(value);
}

@end
