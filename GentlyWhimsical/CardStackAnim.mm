//
//  CardStackAnim.m
//  gently whimsical
//
//  Created by Edward Oakenfold on 2015-06-02.
//  Copyright (c) 2015 conceptual inertia. All rights reserved.
//

#import "Quad.h"
#import "CardStack.h"
#import "Tween.h"
#import "Camera.h"
#import "CardStackAnim.h"

// TODO: throw in utils
inline double mapRange(double inMin, double inMax, double outMin, double outMax, double value) {
    return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
}

typedef struct {
    
    CGPoint leftStackOriginal;
    CGPoint leftStackOffset;
    
    CGPoint rightStackOriginal;
    CGPoint rightStackOffset;
    
} StackPos;

typedef struct {
    double x;
    double y;
    double z;
    double tx; // target x
    double ty;
    double rz;
    double rrx; // random rotation x
    double rry;
    
} CardAnimeInfo;

@interface CardStackAnim() {
    
    Tween* _tween;
    float _screenWidthExtentInWorld;
    float _screenHeightExtentInWorld;
    double _offsetX;
    double _offsetY;
    CardAnimeInfo _cardAnimeInfo[9];
    StackPos _stackPos;
}

@end

@implementation CardStackAnim

- (instancetype)initWithScreenWidth:(float)width screenHeight:(float)height tween:(Tween*)tween {
    self = [super init];
    
    if(self) {
        _tween = tween;
        
        _screenWidthExtentInWorld = width;
        _screenHeightExtentInWorld = height;
        
        float t = 0.25f;
        _offsetX = _screenWidthExtentInWorld  * (0.44) + t;
        _offsetY = _screenHeightExtentInWorld * (1.11) + t;
        
        _selectedStackOffsetY =  0.6f;
        _selectedStackOffsetZ = -1.8f;
    }
    
    return self;
}

- (void)prepareAnimFor:(CardStack*)centerStack leftStack:(CardStack*)leftStack rightStack:(CardStack*)rightStack {
    
    if(leftStack != nil) {
        _stackPos.leftStackOriginal.x = leftStack.x;
        _stackPos.leftStackOffset.x = leftStack.x - _screenWidthExtentInWorld*2.5;
    }
    if(rightStack != nil) {
        _stackPos.rightStackOriginal.x = rightStack.x;
        _stackPos.rightStackOffset.x = rightStack.x + _screenWidthExtentInWorld*2.5;
    }
    
    for(int i = 0; i < centerStack.cards.count; ++i) {
        Quad* quad = [centerStack.cards objectAtIndex:i];
        
        
        _cardAnimeInfo[i].x = quad.x;
        _cardAnimeInfo[i].y = quad.y;
        _cardAnimeInfo[i].z = quad.z;
        _cardAnimeInfo[i].rz = quad.rz;
       
        switch(i) {
            case 0: { // left top
                _cardAnimeInfo[i].tx = quad.x-_offsetX;
                _cardAnimeInfo[i].ty = quad.y+_offsetY-_selectedStackOffsetY;
                _cardAnimeInfo[i].rrx = arc4random_uniform(20);
                _cardAnimeInfo[i].rry = arc4random_uniform(20);
            } break;
            case 1: { // middle top
                _cardAnimeInfo[i].tx = quad.x;
                _cardAnimeInfo[i].ty = quad.y+_offsetY-_selectedStackOffsetY;
                _cardAnimeInfo[i].rrx = arc4random_uniform(20);
                _cardAnimeInfo[i].rry = arc4random_uniform(20);
            } break;
            case 2: { // right top
                _cardAnimeInfo[i].tx = quad.x+_offsetX;
                _cardAnimeInfo[i].ty = quad.y+_offsetY-_selectedStackOffsetY;
                _cardAnimeInfo[i].rrx = arc4random_uniform(20);
                _cardAnimeInfo[i].rry = arc4random_uniform(20);
            } break;
            case 3: { // left middle
                _cardAnimeInfo[i].tx = quad.x-_offsetX;
                _cardAnimeInfo[i].ty = quad.y-_selectedStackOffsetY;
                _cardAnimeInfo[i].rrx = arc4random_uniform(20);
                _cardAnimeInfo[i].rry = arc4random_uniform(20);
            } break;
            case 4: { // middle middle
                _cardAnimeInfo[i].tx = quad.x;
                _cardAnimeInfo[i].ty = quad.y-_selectedStackOffsetY;
                _cardAnimeInfo[i].rrx = arc4random_uniform(20);
                _cardAnimeInfo[i].rry = arc4random_uniform(20);
            } break;
            case 5: { // right middle
                _cardAnimeInfo[i].tx = quad.x+_offsetX;
                _cardAnimeInfo[i].ty = quad.y-_selectedStackOffsetY;
                _cardAnimeInfo[i].rrx = arc4random_uniform(20);
                _cardAnimeInfo[i].rry = arc4random_uniform(20);
            } break;
            case 6: { // left bottom
                _cardAnimeInfo[i].tx = quad.x-_offsetX;
                _cardAnimeInfo[i].ty = quad.y-_offsetY-_selectedStackOffsetY;
                _cardAnimeInfo[i].rrx = arc4random_uniform(20);
                _cardAnimeInfo[i].rry = arc4random_uniform(20);
            } break;
            case 7: { // middle bottom
                _cardAnimeInfo[i].tx = quad.x;
                _cardAnimeInfo[i].ty = quad.y-_offsetY-_selectedStackOffsetY;
                _cardAnimeInfo[i].rrx = arc4random_uniform(20);
                _cardAnimeInfo[i].rry = arc4random_uniform(20);
            } break;
            case 8: { // right bottom
                _cardAnimeInfo[i].tx = quad.x+_offsetX;
                _cardAnimeInfo[i].ty = quad.y-_offsetY-_selectedStackOffsetY;
                _cardAnimeInfo[i].rrx = arc4random_uniform(20);
                _cardAnimeInfo[i].rry = arc4random_uniform(20);
            } break;
                
        } // end switch
    } // end for
}

- (void)scrubLeftStack:(CardStack*)leftStack direction:(ScrubDir)dir percentage:(float)percentage {
    if(leftStack == nil) { return; }
    
    float dist = fabs(_stackPos.leftStackOriginal.x - _stackPos.leftStackOffset.x);
    float curPosX = dist * percentage;
    leftStack.x = (_stackPos.leftStackOriginal.x - curPosX);
}

- (void)scrubRightStack:(CardStack*)rightStack direction:(ScrubDir)dir percentage:(float)percentage {
    if(rightStack == nil) { return; }
    
    float dist = fabs(_stackPos.rightStackOriginal.x - _stackPos.rightStackOffset.x);
    float curPosX = dist * percentage;
    rightStack.x = (_stackPos.rightStackOriginal.x + curPosX);
}

- (void)scrubCenterStack:(CardStack*)centerStack direction:(ScrubDir)dir percentage:(float)percentage camera:(Camera*)camera {
    
    // TODO: pass isManualScrub? and alter the anim accordingly (ie. no back ease out, it would be linear)
    
    camera.y = mapRange(0, 1, 3.3, 0, percentage);
    
    // ! total keyframes must be less than or equal to 1
    static float keyframe1 = 0.15f;
    static float keyframe2 = keyframe1 + 0.85f;
    
    static float scale1 = 0.7f;
    
    if(percentage <= keyframe1) { // move cards down in response to touch
        double subRange = mapRange(0, keyframe1, 0, 1, percentage);
        for(int i = 0; i < centerStack.cards.count; ++i) {
            Quad* quad = [centerStack.cards objectAtIndex:i];
            
            double originalSelectedOffsetZ = [centerStack selectedCardOffsetZForIndex:i] + _selectedStackOffsetZ;
            double targetOffsetZ = originalSelectedOffsetZ + ((i+2) * 0.1f);
            double dist = fabs(targetOffsetZ - originalSelectedOffsetZ);
            double curOffsetZ = dist * subRange;
            
            // TODO: grab each original as part of loop
            // necessary for scrubbing backwards
            quad.x = _cardAnimeInfo[i].x;
            quad.y = _cardAnimeInfo[i].y;
            quad.z = curOffsetZ + originalSelectedOffsetZ;
        }
    }
    else if(percentage > keyframe1 && percentage <= keyframe2) { // move card into position, with scale down
        
        double subRange = mapRange(keyframe1, keyframe2, 0, 1, percentage);
        subRange = [Tween backEaseOut:subRange b:0 c:1 d:1];
        
        for(int i = 0; i < centerStack.cards.count; ++i) {
            Quad* quad = [centerStack.cards objectAtIndex:i];
            
            double distX = fabs(_cardAnimeInfo[i].x - _cardAnimeInfo[i].tx);
            double distY = fabs(_cardAnimeInfo[i].y - _cardAnimeInfo[i].ty);
            
            double curPosX = -(distX * subRange);
            double curPosY = distY * subRange;
            
            if(quad.x == _cardAnimeInfo[i].tx && quad.y == _cardAnimeInfo[i].ty) {
                continue;
            }
            
            double originalSelectedOffsetZ = [centerStack selectedCardOffsetZForIndex:i] + _selectedStackOffsetZ;
            double targetOffsetZ = originalSelectedOffsetZ + ((i+2) * 0.1f);
            
            double distZ = fabs(0 - targetOffsetZ);
            double curZ = distZ * subRange;
            if(targetOffsetZ > 0) {
                curZ *= -1;
            }
            
            double distSx = fabs(1 - scale1);
            double curScale1 = distSx * subRange;
            
            if(_cardAnimeInfo[i].tx > _cardAnimeInfo[i].x) {
                curPosX *= -1;
            }
            if(_cardAnimeInfo[i].ty < _cardAnimeInfo[i].y) {
                curPosY *= -1;
            }
            
            quad.x = _cardAnimeInfo[i].x + curPosX;
            quad.y = _cardAnimeInfo[i].y + curPosY;
            quad.z = targetOffsetZ + curZ;
            
            // we use scale instead of z, because moving quad down z-axis moves it along the projection lines, inward, instead of keeping it on the surface
            quad.sx = 1-curScale1;
            quad.sy = 1-curScale1;
        }
    }
    
    static float delay = /*(0 % 3) * */0.15f; // TODO: i
    static float keyframe4 = delay + 0.15f;     // 0.30
    static float keyframe5 = keyframe4 + 0.70f; // 1
    
    // animate card rotation in parallel during grid positioning with different durations
    if(percentage > delay && percentage <= keyframe4) {
        double subRange = mapRange(delay, keyframe4, 0, 1, percentage);
        for(int i = 0; i < centerStack.cards.count; ++i) {
            Quad* quad = [centerStack.cards objectAtIndex:i];
            
            double distRX = fabs(0-_cardAnimeInfo[i].rrx);
            double distRY = fabs(0-_cardAnimeInfo[i].rry);
            
            double curRX = distRX * subRange;
            double curRY = distRY * subRange;
   
            quad.rx = curRX;
            quad.ry = curRY;
        }
    }
    else if(percentage > keyframe4 && percentage <= keyframe5) {
        double subRange = mapRange(keyframe4, keyframe5, 0, 1, percentage);
        subRange = [Tween cubicEaseOut:subRange b:0 c:1 d:1];
       
        for(int i = 0; i < centerStack.cards.count; ++i) {
            Quad* quad = [centerStack.cards objectAtIndex:i];
            
            double distRX = fabs(_cardAnimeInfo[i].rrx - 0);
            double distRY = fabs(_cardAnimeInfo[i].rry - 0);
            double distRZ = fabs(0-_cardAnimeInfo[i].rz);
            
            double curRX = distRX * subRange;
            double curRY = distRY * subRange;
            double curRZ = distRZ * subRange;
            
            if(_cardAnimeInfo[i].rz < 0) {
                curRZ *= -1;
            }
            
            if(quad.rx < 0) {
                quad.rx = (-_cardAnimeInfo[i].rrx)+curRX;
            } else {
                quad.rx = _cardAnimeInfo[i].rrx-curRX;
            }
            if(quad.ry < 0) {
                quad.ry = (-_cardAnimeInfo[i].rry)+curRY;
            } else {
                quad.ry = _cardAnimeInfo[i].rry-curRY;
            }
            quad.rz = _cardAnimeInfo[i].rz-curRZ;
        }
    }
    
    // percentage doesn't align to keyframe boundaries
    // for example:
    //  - a keyframe boundary at 0.75
    //  - percentage can go from 0.73 to 0.75, or more if the pinch velocity is high
    //  - the next keyframe anim can pick up the slack, but
    //    if the above is the last keyframe *and* that keyframe falls short of 1, it can leave 0.02 in unfinished anim
    //  - so the quad never fully arrives at its target
    if(percentage >= keyframe2) {
        // snap to final position
        for(int i = 0; i < centerStack.cards.count; ++i) {
            Quad* quad = [centerStack.cards objectAtIndex:i];
            
            quad.x = _cardAnimeInfo[i].tx;
            quad.y = _cardAnimeInfo[i].ty;
            quad.z = 0;
        }
    }
    // the same holds true when moving from 1 to 0
    if(percentage < keyframe1) {
        for(int i = 0; i < centerStack.cards.count; ++i) {
            Quad* quad = [centerStack.cards objectAtIndex:i];
            
            quad.sx = 1;
            quad.sy = 1;
        }
    }
    if(percentage < delay) {
        for(int i = 0; i < centerStack.cards.count; ++i) {
            Quad* quad = [centerStack.cards objectAtIndex:i];
            
            quad.rx = 0;
            quad.ry = 0;
            quad.rz = _cardAnimeInfo[i].rz;
        }
    }
}

#pragma mark -

- (void)flipCenterStackCard:(CardStack*)centerStack flipDir:(FlipDir)flipDir completion:(void (^)())callback {
    
    Quad* q = nil;
    if(flipDir == FlipDir_Down) {
        q = [centerStack.cards objectAtIndex:0];
    }
    else {
        q = [centerStack.cards lastObject];
    }
    
    [q setOrigin:0 y:-1.5f z:0];
    
    static float s = 0.85f; // scale anim time modifier
    
    // alpha
    [_tween object:q caller:self
                 params:@{
                          kDuration:@(0.3*s)
                          ,kAlphaModifier:@-0.95
                          ,kEasing:SineEaseIn
                          } completion:^(id self) {
                              [_tween object:q caller:self
                                           params:@{
                                                    kDelay:@(0.3*s)
                                                    ,kDuration:@(0.35*s)
                                                    ,kAlphaModifier:@0
                                                    ,kEasing:SineEaseOut
                                                    } completion:^(id self) {
                                                        if(callback != nil) {
                                                            callback();
                                                        }
                                                    }];
                          }];
    
    // 360
    [_tween object:q caller:self
                 params:@{
                          kDuration:@(0.85*s)
                          ,kTweenRX:(flipDir == FlipDir_Down) ? @-360 : @360
                          ,kEasing:CubicEaseInOut
                          }
             completion:^(id self) {
                 q.rx = 0;
                 [q setOrigin:0 y:0 z:0];
             }];
    
    // z
    [_tween object:q caller:self
                 params:@{
                          kDuration:@(0.9*s)
                          ,kTweenZ:@(
                              (flipDir == FlipDir_Down) ?
                              ((Quad*)[centerStack.cards lastObject]).z :
                              ((Quad*)[centerStack.cards objectAtIndex:0]).z
                          )
                          ,kEasing:CubicEaseInOut
                          }
             completion:nil];
    
    // y
    float y = ((Quad*)[centerStack.cards lastObject]).y;
    [_tween object:q caller:self
                 params:@{
                          kDuration:@(0.32*s)
                          ,kTweenY:@(0+_selectedStackOffsetY - 0.75f)
                          ,kEasing:SineEaseInOut
                          }
             completion:^(id self) {
                 [_tween object:q caller:self
                              params:@{
                                       kDelay:@(0.20*s)
                                       ,kDuration:@(0.20*s)
                                       ,kTweenY:@(y-0.05f)
                                       ,kEasing:Linear
                                       }
                          completion:^(id self) {
                              [_tween object:q caller:self
                                           params:@{
                                                    kDuration:@(0.20*s)
                                                    ,kTweenY:@(y)
                                                    ,kEasing:BackEaseOut
                                                    }
                                       completion:nil];
                              
                          }];
             }];
    
    if(flipDir == FlipDir_Down) {
        // bump cards forward
        for(int i = 1; i < centerStack.cards.count; ++i) {
            Quad* quad = [centerStack.cards objectAtIndex:i];
            [_tween object:quad caller:self
                         params:@{
                                  kDuration:@(0.95*s)
                                  ,kTweenZ:@(((Quad*)[centerStack.cards objectAtIndex:i-1]).z)
                                  ,kEasing:BackEaseOut
                                  }
                     completion:^(id self) {
                         [centerStack shiftCards:ShiftDir_Forward];
                     }];
        }
    }
    else {
        for(int i = 0; i < centerStack.cards.count - 1; ++i) {
            Quad* quad = [centerStack.cards objectAtIndex:i];
            [_tween object:quad caller:self
                    params:@{
                             kDuration:@(0.95*s)
                             ,kTweenZ:@(((Quad*)[centerStack.cards objectAtIndex:i+1]).z)
                             ,kEasing:BackEaseOut
                             }
                completion:^(id self) {
                    [centerStack shiftCards:ShiftDir_Backward];
                }];
        }
    }
}

#pragma mark -

- (void)centerStackJump:(CardStack*)centerStack jumpDir:(StackJumpDir)jumpDir completion:(void (^)())callback {
    
    static float dur = 0.35f;
    
    if(jumpDir == StackJump_Backward) {
        int i = 0;
        for(Quad* q in centerStack.cards.reverseObjectEnumerator) {
            [_tween object:q caller:self
                         params:@{
                                  kDelay:@(i * 0.02)
                                  ,kDuration:@(dur)
                                  ,kTweenY:@0
                                  ,kEasing:CubicEaseOut
                                  }
                     completion:nil];
            
            ++i;
        }
        i = 0;
        for(Quad* q in centerStack.cards.reverseObjectEnumerator) {
            [_tween object:q caller:self
                         params:@{
                                  kDelay:@(i * 0.008)
                                  ,kDuration:@(dur)
                                  ,kTweenZ:@([centerStack selectedCardOffsetZForIndex:(int)centerStack.cards.count-1] - [centerStack selectedCardOffsetZForIndex:i]),
                                  kEasing:CubicEaseOut
                                  }
                     completion:nil];
            ++i;
        }
    }
    else { // StackJump_Forward
        int i = 0;
        Quad* q = nil;
        for(; i < centerStack.cards.count - 1; ++i) {
            q = [centerStack.cards objectAtIndex:i];
            [_tween object:q caller:self
                         params:@{
                                  kDelay:@(i * 0.02)
                                  ,kDuration:@(dur)
                                  ,kTweenY:@(_selectedStackOffsetY)
                                  ,kEasing:BackEaseOut
                                  }
                     completion:nil];
            
            [_tween object:q caller:self
                         params:@{
                                  kDelay:@(i * 0.06)
                                  ,kDuration:@(dur)
                                  ,kTweenZ:@([centerStack selectedCardOffsetZForIndex:i] + _selectedStackOffsetZ)
                                  ,kEasing:BackEaseOut
                                  }
                     completion:nil];
        }
        
        // use the last anim to make the callback
        // TODO: a bit clumsy. Tween should provide a non-tweenable anim
        q = [centerStack.cards objectAtIndex:i];
        [_tween object:q caller:self
                params:@{
                         kDelay:@(i * 0.02)
                         ,kDuration:@(dur)
                         ,kTweenY:@(_selectedStackOffsetY)
                         ,kEasing:BackEaseOut
                         }
            completion:^(id self) {
                if(callback != nil) {
                    callback();
                }
            }];
        
        [_tween object:q caller:self
                params:@{
                         kDelay:@(i * 0.06)
                         ,kDuration:@(dur)
                         ,kTweenZ:@([centerStack selectedCardOffsetZForIndex:i] + _selectedStackOffsetZ)
                         ,kEasing:BackEaseOut
                         }
            completion:nil];
    }
}

@end
