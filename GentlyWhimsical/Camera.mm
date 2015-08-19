//
//  Camera.m
//  gently whimsical
//
//  Created by Edward Oakenfold on 2015-05-08.
//  Copyright (c) 2015 conceptual inertia. All rights reserved.
//

#import "AAPLTransforms.h"
#import "Camera.h"

// there are a number of coordinate bases that we migrate through to get to said perspective projection
// points start out relative to themselves in “model space”; for example, you might describe a point on a chair by the four points of the seat
// moving from the chair to the “world space” of the room, you want to move again to “eye space” to imagine the world as not being attached in the consistent observer
// then, projecting the points onto the near plane moves into “screen space”
// mathematically, this is done through matrix concatenation, where the move from “space” to “space” is associated with its own transformation matrix
@interface Camera() {
    
    CGRect _viewFrame;
    float _aspect;
    
    // ortho
    float _left;
    float _right;
    float _bottom;
    float _top;
    
    float _eye[3];
    float _center[3];
    float _up[3];
}
@end

// TODO: frustum culling
@implementation Camera

- (float)x { return _eye[0]; }
- (float)y { return _eye[1]; }
- (float)z { return _eye[2]; }

- (void)setX:(float)value { _eye[0] = value; }
- (void)setY:(float)value { _eye[1] = value; }
- (void)setZ:(float)value { _eye[2] = value; }

- (simd::float4x4)ortho {
    return AAPL::Math::ortho2d(_left, _right, _bottom, _top, _near, _far);
}

- (void)setProjectionMode:(ProjectionMode)projectionMode {
    _projectionMode = projectionMode;
    
    if(_projectionMode == PERSPECTIVE) {
        _projection = AAPL::Math::perspective_fov(_fov, _aspect, _near, _far);
    } else {
        _projection = AAPL::Math::ortho2d(_left, _right, _bottom, _top, _near, _far);
    }
    
    _view = AAPL::Math::lookAt(_eye, _center, _up);
}

- (instancetype)initWithFrame:(CGRect)frame contentsScale:(CGFloat)contentScale {
    self = [super init];
    
    if(self) {
        _viewFrame = frame;
        
        _fov = 65;
        _aspect = fabs((frame.size.width * contentScale) / (frame.size.height * contentScale));
        _near = 0.1f; // never have 0 or inverse proj will return NaN and Inf
        _far = 100.0f;
        
        _left = 0;
        _right = frame.size.width * contentScale;
        _bottom = frame.size.height * contentScale;
        _top = 0;

        _view = matrix_identity_float4x4;
        _projection = matrix_identity_float4x4;
        
        _eye[0] = 0;
        _eye[1] = 0;
        _eye[2] = -1;
        
        _center[0] = 0;
        _center[1] = 0;
        _center[2] = 0;
        
        _up[0] = 0;
        _up[1] = 1;
        _up[2] = 0;
    }
    
    return self;
}

- (simd::float4)screenToWorld:(simd::float2)screenPoint {
    
    _view = AAPL::Math::lookAt(_eye, _center, _up);
    _projection = AAPL::Math::perspective_fov(_fov, _aspect, _near, _far);
    
    float ndcX =  (2.0f * screenPoint.x) / _viewFrame.size.width  - 1.0f;
    float ndcY = -(2.0f * screenPoint.y) / _viewFrame.size.height + 1.0f;
    
    simd::float4x4 inverseViewProj = simd::inverse(_projection * _view);
    simd::float4 ndc = { ndcX, ndcY, 0.0f, 1.0f };
    simd::float4 world = ndc * inverseViewProj;
    world.w = 1.0 / world.w;
    world.x *= world.w;
    world.y *= world.w;
    
    return world;
}

- (void)updateViewMatrix {
    
    if(_projectionMode == ORTHOGRAPHIC || _moveCenterWithEye) {
        // move center along with it
        _center[0] = _eye[0];
        //_center[1] = _eye[1];
    }
    
    _prevView = _view;
    
    // TODO: dirty flag
    _view = AAPL::Math::lookAt(_eye, _center, _up);
}

@end
