//
//  GalleryScene.h
//  gently whimsical
//
//  Created by Edward Oakenfold on 2015-05-14.
//  Copyright (c) 2015 conceptual inertia. All rights reserved.
//

#import <UIKit/UIScrollView.h>
#import <UIKit/UIGestureRecognizer.h>
#import "Scene.h"

@interface GalleryScene : Scene <UIGestureRecognizerDelegate>

@property float pinchPercentage;
@property float tapPercentage;

- (instancetype)initWithDevice:(id<MTLDevice>)device
                         layer:(CAMetalLayer*)layer
     numInflightCommandBuffers:(unsigned int)numInflightCommandBuffers
                       library:(id<MTLLibrary>)library;

@end
