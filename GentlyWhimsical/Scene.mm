//
//  Scene.m
//  gently whimsical
//
//  Created by Edward Oakenfold on 2015-05-04.
//  Copyright (c) 2015 conceptual inertia. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Tween.h"
#import "Camera.h"
#import "Scene.h"

@implementation Scene

- (instancetype)initWithFrame:(CGRect)frame contentsScale:(CGFloat)contentsScale {
    
    self = [super init];
    
    if(self) {
        _view = [[UIView alloc]initWithFrame:frame];
        _tween = [[Tween alloc]init];
        _camera = [[Camera alloc]initWithFrame:frame contentsScale:contentsScale];
    }
    
    return self;
}

- (void)update:(CFTimeInterval)deltaTime inflightBufferIndex:(unsigned int)inflightBufferIndex {
    _fullyUpdated = NO;
    
    // tween must be updated first as it is likely to animate properties on camera
    [_tween updateAnimations:deltaTime];
    
    [_camera updateViewMatrix];
}

- (void)encode:(id<MTLCommandBuffer>)commandBuffer inflightBufferIndex:(unsigned int)inflightBufferIndex drawableTexture:(id<MTLTexture>)drawableTexture {
    // nop
}

- (void)didRender {
    _fullyUpdated = YES;
}

@end
