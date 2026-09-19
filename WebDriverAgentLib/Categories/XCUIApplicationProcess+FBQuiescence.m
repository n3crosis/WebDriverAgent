/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "XCUIApplicationProcess+FBQuiescence.h"

#import <objc/runtime.h>

#import "FBConfiguration.h"
#import "FBExceptions.h"
#import "FBLogger.h"
#import "FBSettings.h"
#import "FBXCAXClientProxy.h"

static void (*original_waitForQuiescenceIncludingAnimationsIdle)(id, SEL, BOOL);
static void (*original_waitForQuiescenceIncludingAnimationsIdlePreEvent)(id, SEL, BOOL, BOOL);
static void (*original_waitForQuiescenceIncludingAnimationsIdleUsingActivity)(id, SEL, BOOL, BOOL, BOOL);
static BOOL (*original_shouldSkipPreEventQuiescence)(id, SEL);
static BOOL (*original_shouldSkipPostEventQuiescence)(id, SEL);
static void (*original_waitForQuiescenceOnAllForegroundApplicationsAsPreEvent)(id, SEL, BOOL);

static BOOL fb_quiescenceChecksDisabled(id process)
{
  return ![[process fb_shouldWaitForQuiescence] boolValue]
    || FBConfiguration.sharedInstance.waitForIdleTimeout < DBL_EPSILON;
}

static void swizzledWaitForQuiescenceIncludingAnimationsIdle(id self, SEL _cmd, BOOL includingAnimations)
{
  NSString *bundleId = [self bundleID];
  if (fb_quiescenceChecksDisabled(self)) {
    [FBLogger logFmt:@"Quiescence checks are disabled for %@ application. Making it to believe it is idling",
     bundleId];
    return;
  }

  NSTimeInterval desiredTimeout = FBConfiguration.sharedInstance.waitForIdleTimeout;
  [FBLogger logFmt:@"Waiting up to %@s until %@ is in idle state (%@ animations)",
   @(desiredTimeout), bundleId, includingAnimations ? @"including" : @"excluding"];
  [FBXCAXClientProxy withApplicationStateTimeout:desiredTimeout do:^{
    original_waitForQuiescenceIncludingAnimationsIdle(self, _cmd, includingAnimations);
  }];
}

static void swizzledWaitForQuiescenceIncludingAnimationsIdlePreEvent(id self, SEL _cmd, BOOL includingAnimations, BOOL isPreEvent)
{
  NSString *bundleId = [self bundleID];
  if (fb_quiescenceChecksDisabled(self)) {
    [FBLogger logFmt:@"Quiescence checks are disabled for %@ application. Making it to believe it is idling",
     bundleId];
    return;
  }

  NSTimeInterval desiredTimeout = FBConfiguration.sharedInstance.waitForIdleTimeout;
  [FBLogger logFmt:@"Waiting up to %@s until %@ is in idle state (%@ animations)",
   @(desiredTimeout), bundleId, includingAnimations ? @"including" : @"excluding"];
  [FBXCAXClientProxy withApplicationStateTimeout:desiredTimeout do:^{
    original_waitForQuiescenceIncludingAnimationsIdlePreEvent(self, _cmd, includingAnimations, isPreEvent);
  }];
}

static void swizzledWaitForQuiescenceIncludingAnimationsIdleUsingActivity(id self, SEL _cmd, BOOL includingAnimations, BOOL usingActivity, BOOL isPreEvent)
{
  NSString *bundleId = [self bundleID];
  if (fb_quiescenceChecksDisabled(self)) {
    [FBLogger logFmt:@"Quiescence checks are disabled for %@ application. Making it to believe it is idling",
     bundleId];
    return;
  }

  NSTimeInterval desiredTimeout = FBConfiguration.sharedInstance.waitForIdleTimeout;
  [FBLogger logFmt:@"Waiting up to %@s until %@ is in idle state (%@ animations)",
   @(desiredTimeout), bundleId, includingAnimations ? @"including" : @"excluding"];
  [FBXCAXClientProxy withApplicationStateTimeout:desiredTimeout do:^{
    original_waitForQuiescenceIncludingAnimationsIdleUsingActivity(self, _cmd, includingAnimations, usingActivity, isPreEvent);
  }];
}

static BOOL swizzledShouldSkipPreEventQuiescence(id self, SEL _cmd)
{
  if (fb_quiescenceChecksDisabled(self)) {
    return YES;
  }
  return nil != original_shouldSkipPreEventQuiescence ? original_shouldSkipPreEventQuiescence(self, _cmd) : NO;
}

static BOOL swizzledShouldSkipPostEventQuiescence(id self, SEL _cmd)
{
  if (fb_quiescenceChecksDisabled(self)) {
    return YES;
  }
  return nil != original_shouldSkipPostEventQuiescence ? original_shouldSkipPostEventQuiescence(self, _cmd) : NO;
}

static void swizzledWaitForQuiescenceOnAllForegroundApplicationsAsPreEvent(id self, SEL _cmd, BOOL isPreEvent)
{
  if (FBConfiguration.sharedInstance.waitForIdleTimeout < DBL_EPSILON) {
    return;
  }
  original_waitForQuiescenceOnAllForegroundApplicationsAsPreEvent(self, _cmd, isPreEvent);
}

@implementation XCUIApplicationProcess (FBQuiescence)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-load-method"
#pragma clang diagnostic ignored "-Wcast-function-type-strict"

+ (void)load
{
  Method method = class_getInstanceMethod(self.class, @selector(waitForQuiescenceIncludingAnimationsIdle:));
  if (nil != method) {
    original_waitForQuiescenceIncludingAnimationsIdle = (void (*)(id, SEL, BOOL)) method_setImplementation(method, (IMP)swizzledWaitForQuiescenceIncludingAnimationsIdle);
  }
  method = class_getInstanceMethod(self.class, @selector(waitForQuiescenceIncludingAnimationsIdle:isPreEvent:));
  if (nil != method) {
    original_waitForQuiescenceIncludingAnimationsIdlePreEvent = (void (*)(id, SEL, BOOL, BOOL)) method_setImplementation(method, (IMP)swizzledWaitForQuiescenceIncludingAnimationsIdlePreEvent);
  }
  method = class_getInstanceMethod(self.class, @selector(waitForQuiescenceIncludingAnimationsIdle:usingActivity:isPreEvent:));
  if (nil != method) {
    original_waitForQuiescenceIncludingAnimationsIdleUsingActivity = (void (*)(id, SEL, BOOL, BOOL, BOOL)) method_setImplementation(method, (IMP)swizzledWaitForQuiescenceIncludingAnimationsIdleUsingActivity);
  }
  method = class_getInstanceMethod(self.class, @selector(shouldSkipPreEventQuiescence));
  if (nil != method) {
    original_shouldSkipPreEventQuiescence = (BOOL (*)(id, SEL)) method_setImplementation(method, (IMP)swizzledShouldSkipPreEventQuiescence);
  }
  method = class_getInstanceMethod(self.class, @selector(shouldSkipPostEventQuiescence));
  if (nil != method) {
    original_shouldSkipPostEventQuiescence = (BOOL (*)(id, SEL)) method_setImplementation(method, (IMP)swizzledShouldSkipPostEventQuiescence);
  }
  Class axClientClass = NSClassFromString(@"XCAXClient_iOS");
  method = nil != axClientClass
    ? class_getInstanceMethod(axClientClass, NSSelectorFromString(@"waitForQuiescenceOnAllForegroundApplicationsAsPreEvent:"))
    : nil;
  if (nil != method) {
    original_waitForQuiescenceOnAllForegroundApplicationsAsPreEvent = (void (*)(id, SEL, BOOL)) method_setImplementation(method, (IMP)swizzledWaitForQuiescenceOnAllForegroundApplicationsAsPreEvent);
  }
  if (nil == class_getInstanceMethod(self.class, @selector(waitForQuiescenceIncludingAnimationsIdle:))
      && nil == class_getInstanceMethod(self.class, @selector(waitForQuiescenceIncludingAnimationsIdle:isPreEvent:))) {
    [FBLogger log:@"Could not find method -[XCUIApplicationProcess waitForQuiescenceIncludingAnimationsIdle:]"];
  }
}

#pragma clang diagnostic pop

static char XCUIAPPLICATIONPROCESS_SHOULD_WAIT_FOR_QUIESCENCE;

@dynamic fb_shouldWaitForQuiescence;

- (NSNumber *)fb_shouldWaitForQuiescence
{
  id result = objc_getAssociatedObject(self, &XCUIAPPLICATIONPROCESS_SHOULD_WAIT_FOR_QUIESCENCE);
  if (nil == result) {
    return @(NO);
  }
  return (NSNumber *)result;
}

- (void)setFb_shouldWaitForQuiescence:(NSNumber *)value
{
  objc_setAssociatedObject(self, &XCUIAPPLICATIONPROCESS_SHOULD_WAIT_FOR_QUIESCENCE, value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)fb_waitForQuiescenceIncludingAnimationsIdle:(bool)waitForAnimations
{
  if ([self respondsToSelector:@selector(waitForQuiescenceIncludingAnimationsIdle:)]) {
    [self waitForQuiescenceIncludingAnimationsIdle:waitForAnimations];
  } else if ([self respondsToSelector:@selector(waitForQuiescenceIncludingAnimationsIdle:isPreEvent:)]) {
    [self waitForQuiescenceIncludingAnimationsIdle:waitForAnimations isPreEvent:NO];
  } else {
    @throw [NSException exceptionWithName:FBIncompatibleWdaException
                                   reason:@"The current WebDriverAgent build is not compatible to your device OS version"
                                 userInfo:@{}];
  }
}


@end
