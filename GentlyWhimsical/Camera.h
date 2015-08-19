//
//  Camera.h
//  gently whimsical
//
//  Created by Edward Oakenfold on 2015-05-08.
//  Copyright (c) 2015 conceptual inertia. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>
#include <simd/simd.h>

typedef NS_ENUM(NSUInteger, ProjectionMode) {
    PERSPECTIVE,
    ORTHOGRAPHIC
};

// there are a number of coordinate bases that we migrate through to get to said perspective projection
// points start out relative to themselves in “model space”; for example, you might describe a point on a chair by the four points of the seat
// moving from the chair to the “world space” of the room, you want to move again to “eye space” to imagine the world as not being attached in the consistent observer
// then, projecting the points onto the near plane moves into “screen space”
// mathematically, this is done through matrix concatenation, where the move from “space” to “space” is associated with its own transformation matrix

@interface Camera : NSObject

@property simd::float4x4 prevView;
@property simd::float4x4 view;
@property simd::float4x4 projection;
@property (readonly) simd::float4x4 ortho;

@property (assign, nonatomic) ProjectionMode projectionMode;
@property (assign, nonatomic) float fov;
@property (assign, nonatomic) float near;
@property (assign, nonatomic) float far;

@property (assign, nonatomic) float moveCenterWithEye;

#pragma mark -
@property (assign, nonatomic) float x;
@property (assign, atomic) float y;
@property (assign, nonatomic) float z;

- (instancetype)initWithFrame:(CGRect)frame contentsScale:(CGFloat)contentScale;
- (simd::float4)screenToWorld:(simd::float2)screenPoint;
- (void)updateViewMatrix;

@end
