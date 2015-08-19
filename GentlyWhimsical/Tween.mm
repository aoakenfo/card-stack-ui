//
//  Tween.m
//  gently whimsical
//
//  Created by Edward Oakenfold on 2015-05-01.
//  Copyright (c) 2015 conceptual inertia. All rights reserved.
//

#include <simd/simd.h>
#import "Primitive.h"
#import "AAPLTransforms.h"
#include "Easing.h"
#import "Tween.h"

NSString *const kCallerKey = @"caller";
NSString* const kCallbackKey = @"callback";

@interface TweenProp : NSObject

@end

@interface TweenProp() {
    float _time;
    float _startValue;
    float _endValue;
    float _duration;
    EasingFunction _easing;
    float _delay;
}

@end

@implementation TweenProp

- (instancetype)initWithTime:(float)time
                  startValue:(float)startValue
                    endValue:(float)endValue
                    duration:(float)duration
                      easing:(EasingFunction)easing
                       delay:(float)delay {
    
    self = [super init];
    
    if(self) {
        _time = time;
        _startValue = startValue;
        _endValue = endValue;
        _duration = duration;
        _easing = easing;
        _delay = delay;
    }
    
    return self;
}

- (BOOL)isFinished {
    return _time == _duration;
}

- (NSNumber*)nextValue:(float)deltaTime {
    
    if(_delay == 0) {
        _time = fmin(_time + deltaTime, _duration);
        return [[NSNumber alloc]initWithFloat:_easing(_time, _startValue, _endValue, _duration)];
    }
    else {
        _delay = fmax(0, _delay - deltaTime);
    }
    
    return nil;
}

@end

@interface Tween() {
    
    // Limitations of NSDictionary
    // NSDictionary provides a key-to-object mapping. In essence, NSDictionary stores the "objects" in locations indexed by the "keys".
    // Since the objects are stored at specific locations, NSDictionary requires that the key's value doesn't change (otherwise the object would suddenly be at the wrong location for its key). To ensure this requirement is maintained, NSDictionary always copies the keys to its own private location.
    // This key copying behavior is fundamental to how NSDictionary works but is also a limitation: you can only use an Objective-C object as a key in an NSDictionary if it supports the NSCopying protocol. Further, the key should be small and efficient enough that copying is does not burden CPU or memory.
    // This means that NSDictionary is really only suited to "value"-type objects as keys (eg. small strings and numbers). It is not ideal for modelling mappings from fully fledged objects to other objects.
    // Object to Object mappings
    // NSMapTable can handle the "key-to-object" style mapping of an NSDictionary but it can also handle "object-to-object" mappings
    NSMapTable* _tweens;
    NSMapTable* _callbacks;
}
@end

@implementation NSMutableDictionary(Extension)

// FIX: this hash
// hash doesn't account for duplicate props
// tween #1 = x, y, z
// tween #2 = rx, y
// #2 is unique hash, but will fuck over #1's y
// which may be fine. if ur tweening the same prop in parallel u deserve it
- (NSUInteger) hash {
    NSMutableString* keyCombo = [[NSMutableString alloc]init];
    
    NSArray* keys = [self.allKeys sortedArrayUsingComparator:^(id a, id b) {
        return [a compare:b];
    }];
    
    for(NSString* key in keys) {
        [keyCombo appendString:key];
    }
    
    NSUInteger value = [keyCombo hash];
    
    return value;
}
@end

@implementation Tween

- (instancetype)init {
    self = [super init];
    if(self) {
        // http://nshipster.com/nshashtable-and-nsmaptable/
        _tweens = [NSMapTable mapTableWithKeyOptions:NSMapTableStrongMemory valueOptions:NSMapTableStrongMemory];
        _callbacks = [NSMapTable mapTableWithKeyOptions:NSMapTableStrongMemory valueOptions:NSMapTableStrongMemory];
        
    }
    return self;
}

- (void)object:(NSObject*)objectToTween caller:(id)caller params:(NSDictionary*)params completion:(CompletionCallback)callback {
    
    // set TweenProp defaults if the following keys weren't passed
    NSNumber* duration = (NSNumber*)[params objectForKey:kDuration];
    if(duration == nil) {
        duration = @1;
    }
    NSNumber* easeIndex = (NSNumber*)[params objectForKey:kEasing];
    if(easeIndex == nil) {
        easeIndex = Linear;
    }
    NSNumber* delay = (NSNumber*)[params objectForKey:kDelay];
    if(delay == nil) {
        delay = @0;
    }
    
    // create a container for tween props and associate each with a prop key
    NSMutableDictionary* propertiesToTween = [[NSMutableDictionary alloc]init];
    
    NSMutableArray* parallelPropsToTween = [_tweens objectForKey:objectToTween];
    if(parallelPropsToTween == nil) {
        parallelPropsToTween = [[NSMutableArray alloc]init];
    }
    
    // TODO: maybe assert if kBezierCurve is set and x, y, or z
    
    for(NSString* key in params) {
        if([key isEqualToString:kDuration] || [key isEqualToString:kEasing] || [key isEqualToString:kDelay])
            continue;
        
        NSNumber* objectCurVal = [objectToTween valueForKey:key];
        NSAssert(!(objectCurVal == nil), @"you can't tween a prop that doens't exist");
        NSNumber* targetVal = [params objectForKey:key];
        NSAssert(!(targetVal == nil), @"only NSNumbers can be used in params");
        
        TweenProp* prop = [[TweenProp alloc]initWithTime:0.0f
                                   startValue:[objectCurVal floatValue]
                                     endValue:[targetVal floatValue] - [objectCurVal floatValue]
                                     duration:[duration floatValue]
                                       easing:easingFunctions[[easeIndex unsignedIntValue]]
                                        delay:[delay floatValue]
                ];
        
        [propertiesToTween setObject:prop forKey:key];
    }
    
    BOOL entryExists = NO;
    int i = 0;
    for(; i < parallelPropsToTween.count; ++i) {
        NSDictionary* propsToTween = [parallelPropsToTween objectAtIndex:i];
        if(propsToTween.hash == propertiesToTween.hash) {
            entryExists = YES;
            break;
        }
    }
    
    if(!entryExists) {
        [parallelPropsToTween addObject:propertiesToTween];
    } else {
        [parallelPropsToTween replaceObjectAtIndex:i withObject:propertiesToTween];
    }
    
    // associate callback data with object
    if(callback != nil) {
        [_callbacks setObject:@{kCallerKey:caller, kCallbackKey:callback} forKey:propertiesToTween];
    }
    
    [_tweens setObject:parallelPropsToTween forKey:objectToTween];
}

// plugs into display link loop
- (void)updateAnimations:(CFTimeInterval)deltaTime {
    
    NSMutableArray* pendingTweenPropsRemoval = [[NSMutableArray alloc]init];
    
    for(NSObject* objectToTween in _tweens) {
        NSMutableArray* parallelPropsToTween = [_tweens objectForKey:objectToTween];
        
        for(NSMutableDictionary* propertiesToTween in parallelPropsToTween) {
            
            // never mutate while enumerating
            BOOL removeTween = NO;
            
            for(NSString* propKey in propertiesToTween) {
                
                // ask tween prop to calculate the next interpolated value
                TweenProp* prop = [propertiesToTween objectForKey:propKey];
                
                NSNumber* value = [prop nextValue:deltaTime];
                if(value == nil) { // delayed
                    continue;
                }
                    
                // update the proprerty on the object being tweened
                [objectToTween setValue:value forKey:propKey];
                
                // done, schedule removal of this prop from future tweens
                // since all tweens finish at the same time, this flag will be set multiple times
                // a bit redundant, but easy to track
                if(prop.isFinished) {
                    removeTween = YES;
                }
            } // end for propertiestoTween
            
            if(removeTween) {
                [pendingTweenPropsRemoval addObject:propertiesToTween];
            }
        } // end for parallelPropsToTween
    }
    
    NSMutableArray* pendingCallbacks = [[NSMutableArray alloc]init];
    
    // remove finished tweens
    NSMapTable* pendingRemoval = [NSMapTable mapTableWithKeyOptions:NSMapTableStrongMemory valueOptions:NSMapTableStrongMemory];
    
    // for all the objects under going tweens
    for(NSObject* objectToTween in _tweens) {
        
        // get the array of of property bags (ie. x,y,z with duration)
        NSMutableArray* parallelPropsToTween = [_tweens objectForKey:objectToTween];
        
        for(int i = 0; i < parallelPropsToTween.count; ++i) {
        
            // given this dictionary of props
            NSMutableDictionary* propertiesToTween = [parallelPropsToTween objectAtIndex:i];
            
            // can it be found in the removal bucket?
            if([pendingTweenPropsRemoval containsObject:propertiesToTween]) {
                
                // grab the context when this call to tween was made
                NSDictionary* context = [_callbacks objectForKey:propertiesToTween];
                if(context != nil) {
                    [pendingCallbacks addObject:context];
                    // remove callback data
                    [_callbacks removeObjectForKey:propertiesToTween];
                }
                
                // schedule this property bag for removal
                NSMutableArray* arr =  [pendingRemoval objectForKey:objectToTween];
                if(arr == nil) {
                    arr = [[NSMutableArray alloc]init];
                }
                [arr addObject:propertiesToTween];
                [pendingRemoval setObject:arr forKey:objectToTween];
            }
        }
        
    }
    
    // TODO: unit test this mess
    if(pendingRemoval.count > 0) {
        for(NSObject* obj in pendingRemoval.keyEnumerator) {
            
            NSMutableArray* parallelPropsToTween = [_tweens objectForKey:obj];
            
            NSMutableArray* arr = [pendingRemoval objectForKey:obj];
            for(NSMutableDictionary* propertiesToTween in arr) {
                [parallelPropsToTween removeObject:propertiesToTween];
            }
            
            if(parallelPropsToTween.count == 0) {
                [_tweens removeObjectForKey:obj];
            }
        }
    }
    
    for(NSDictionary* context in pendingCallbacks) {
        CompletionCallback callback = (CompletionCallback)[context objectForKey:kCallbackKey];
        if(callback != nil) {
            // signal tween completion
            id caller = (NSObject*)[context objectForKey:kCallerKey];
            callback(caller);
        }
    }
}

// TODO: move remaining tween functions here

+ (float)backEaseOut:(float)t b:(float)b c:(float)c d:(float)d {
    static float s = 1.70158f;
    t=t/d-1;
    return c*(t*t*((s+1)*t + s) + 1) + b;
}

+ (float)cubicEaseOut:(float)t b:(float)b c:(float)c d:(float)d {
    t=t/d-1;
    return c*((t)*t*t + 1) + b;
}

+ (float)sineEaseInOut:(float)t b:(float)b c:(float)c d:(float)d {
    return -c/2 * (cos(M_PI*t/d) - 1) + b;
}

@end
