//
//  CardStackAnim.h
//  gently whimsical
//
//  Created by Edward Oakenfold on 2015-06-02.
//  Copyright (c) 2015 conceptual inertia. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, ScrubDir) {
    ScrubDirIn,
    ScrubDirOut,
    ScrubDirUp,
    ScrubDirDown
};

typedef NS_ENUM(NSUInteger, FlipDir) {
    FlipDir_Up,
    FlipDir_Down
};

typedef NS_ENUM(NSUInteger, StackJumpDir) {
    StackJump_Forward,
    StackJump_Backward
};

@class Tween;
@class CardStack;

@interface CardStackAnim : NSObject

@property (readonly) float selectedStackOffsetY;
@property (readonly) float selectedStackOffsetZ;

- (instancetype)initWithScreenWidth:(float)width screenHeight:(float)height tween:(Tween*)tween;

- (void)prepareAnimFor:(CardStack*)centerStack leftStack:(CardStack*)leftStack rightStack:(CardStack*)rightStack;
- (void)scrubLeftStack:(CardStack*)leftStack direction:(ScrubDir)dir percentage:(float)percentage;
- (void)scrubRightStack:(CardStack*)rightStack direction:(ScrubDir)dir percentage:(float)percentage;
- (void)scrubCenterStack:(CardStack*)centerStack direction:(ScrubDir)dir percentage:(float)percentage camera:(Camera*)camera;

- (void)flipCenterStackCard:(CardStack*)centerStack flipDir:(FlipDir)flipDir completion:(void (^)())callback;
- (void)centerStackJump:(CardStack*)centerStack jumpDir:(StackJumpDir)jumpDir completion:(void (^)())callback;

@end
