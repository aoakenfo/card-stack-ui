//
//  CanvasScene.h
//  GentlyWhimsical
//
//  Created by Edward Oakenfold on 2015-06-13.
//  Copyright © 2015 conceptual inertia. All rights reserved.
//

#import "Scene.h"

@interface CanvasScene : Scene

- (instancetype)initWithDevice:(id<MTLDevice>)device
                         layer:(CAMetalLayer*)layer
     numInflightCommandBuffers:(unsigned int)numInflightCommandBuffers
                       library:(id<MTLLibrary>)library;

@end
