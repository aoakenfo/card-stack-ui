//
//  Scene.h
//  gently whimsical
//
//  Created by Edward Oakenfold on 2015-05-04.
//  Copyright (c) 2015 conceptual inertia. All rights reserved.
//

#import <Foundation/Foundation.h>

@class UIView;
@class Camera;
@class Tween;

@interface Scene : NSObject

@property BOOL fullyUpdated;
@property UIView* view;
@property Camera* camera;
@property Tween* tween;

- (instancetype)initWithFrame:(CGRect)frame contentsScale:(CGFloat)contentsScale;

- (void)update:(CFTimeInterval)deltaTime inflightBufferIndex:(unsigned int)inflightBufferIndex;
- (void)encode:(id<MTLCommandBuffer>)commandBuffer inflightBufferIndex:(unsigned int)inflightBufferIndex drawableTexture:(id<MTLTexture>)drawableTexture;

- (void)didRender;

@end
