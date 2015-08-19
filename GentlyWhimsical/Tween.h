//
//  Tween.h
//  gently whimsical
//
//  Created by Edward Oakenfold on 2015-05-01.
//  Copyright (c) 2015 conceptual inertia. All rights reserved.
//

#import <Foundation/Foundation.h>

// http://twobitlabs.com/2012/12/objective-c-ios-blocks-cheat-sheet/
typedef void (^CompletionCallback)(id);

NSString* const kDelay = @"delay";
NSString* const kDuration = @"duration";

NSString* const kTweenX = @"x";
NSString* const kTweenY = @"y";
NSString* const kTweenZ = @"z";
NSString* const kTweenRX = @"rx";
NSString* const kTweenRY = @"ry";
NSString* const kTweenRZ = @"rz";
NSString* const kTweenSX = @"sx";
NSString* const kTweenSY = @"sy";
NSString* const kTweenSZ = @"sz";

NSString* const kAlphaModifier = @"alphaModifier";

NSString* const kEasing = @"easing";

// corresponds to index in Easing.h easingFunctions[]
// why not an enum? added to NSDictionary params
NSNumber* const Linear              = @0;
NSNumber* const BackEaseIn          = @1;
NSNumber* const BackEaseOut         = @2;
NSNumber* const BackEaseInOut       = @3;
NSNumber* const BounceEaseIn        = @4;
NSNumber* const BounceEaseOut       = @5;
NSNumber* const BounceEaseInOut     = @6;
NSNumber* const CircEaseIn          = @7;
NSNumber* const CircEaseOut         = @8;
NSNumber* const CircEaseInOut       = @9;
NSNumber* const CubicEaseIn         = @10;
NSNumber* const CubicEaseOut        = @11;
NSNumber* const CubicEaseInOut      = @12;
NSNumber* const ElasticEaseIn       = @13;
NSNumber* const ElasticEaseOut      = @14;
NSNumber* const ElasticEaseInOut    = @15;
NSNumber* const ExpoEaseIn          = @16;
NSNumber* const ExpoEaseOut         = @17;
NSNumber* const ExpoEaseInOut       = @18;
NSNumber* const QuartEaseIn         = @19;
NSNumber* const QuartEaseOut        = @20;
NSNumber* const QuartEaseInOut      = @21;
NSNumber* const QuintEaseIn         = @22;
NSNumber* const QuintEaseOut        = @23;
NSNumber* const QuintEaseInOut      = @24;
NSNumber* const SineEaseIn          = @25;
NSNumber* const SineEaseOut         = @26;
NSNumber* const SineEaseInOut       = @27;

@interface Tween : NSObject

- (void)updateAnimations:(CFTimeInterval)deltaTime;
- (void)object:(NSObject*)objectToTween caller:(id)caller params:(NSDictionary*)params completion:(CompletionCallback)callback;

+ (float)backEaseOut:(float)t b:(float)b c:(float)c d:(float)d;
+ (float)cubicEaseOut:(float)t b:(float)b c:(float)c d:(float)d;
+ (float)sineEaseInOut:(float)t b:(float)b c:(float)c d:(float)d;

@end
