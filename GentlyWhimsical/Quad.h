//
//  Quad.h
//  gently whimsical
//
//  Created by Edward Oakenfold on 2015-04-25.
//  Copyright (c) 2015 conceptual inertia. All rights reserved.
//

#import <Metal/MTLRenderPass.h>
#import <CoreGraphics/CGGeometry.h>
#import "Primitive.h"

// param keys
NSString* const kIsFullscreen = @"isFullscreen";
NSString* const kCornerRadius = @"cornerRadius";
NSString* const kAspectWidth = @"aspectWidth";
NSString* const kAspectHeight = @"aspectHeight";

@interface Quad : Primitive

@property (assign, nonatomic) float ty;

- (instancetype)initWithDevice:(id<MTLDevice>)device
                         layer:(CAMetalLayer*)layer
     numInflightCommandBuffers:(unsigned int)numInflightCommandBuffers
                       library:(id<MTLLibrary>)library
                        params:(NSDictionary*)params;

- (void)setGradientStops:(MTLClearColor)a b:(MTLClearColor)b isHorizontal:(BOOL)isHorizontal;
- (void)setTexelRect:(CGRect)frame;
- (BOOL)wasClicked:(CGPoint)screenTouchPos proj:(simd::float4x4)proj view:(simd::float4x4)view;

@end
