//
//  Renderer.h
//  gently whimsical
//
//  Created by Edward Oakenfold on 2015-04-23.
//  Copyright (c) 2015 conceptual inertia. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>

@class CAMetalLayer;
@class UIView;

@interface Renderer : NSObject

@property (readonly) CAMetalLayer* metalLayer;
@property (readonly) UIView* rootView;

- (void)updateLayerSize:(CGRect)frame bounds:(CGRect)bounds contentScaleFactor:(CGFloat)contentScaleFactor;
- (void)frameUpdate:(CFTimeInterval)deltaTime;

@end
