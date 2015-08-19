//
//  CardStack.h
//  gently whimsical
//
//  Created by Edward Oakenfold on 2015-05-25.
//  Copyright (c) 2015 conceptual inertia. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, ShiftDir) {
    ShiftDir_Forward,
    ShiftDir_Backward
};

@protocol MTLDevice;
@protocol MTLRenderCommandEncoder;
@protocol MTLLibrary;
@class CAMetalLayer;
@class Camera;

@interface CardStack : NSObject

@property NSMutableArray* cards;

@property (assign, nonatomic) float x;
@property (assign, nonatomic) float y;
@property (assign, nonatomic) float z;
@property (assign, nonatomic) float sx;
@property (assign, nonatomic) float sy;

- (float)selectedCardOffsetZForIndex:(int)index;

- (instancetype)initWithDevice:(id<MTLDevice>)device
                         layer:(CAMetalLayer*)layer
     numInflightCommandBuffers:(unsigned int)numInflightCommandBuffers
                       library:(id<MTLLibrary>)library;

- (void)shiftCards:(ShiftDir)shiftDir;

@end
