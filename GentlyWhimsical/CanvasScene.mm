//
//  CanvasScene.m
//  GentlyWhimsical
//
//  Created by Edward Oakenfold on 2015-06-13.
//  Copyright © 2015 conceptual inertia. All rights reserved.
//

#import <Physics2d/Physics2d.h>
#import <Metal/Metal.h>
#import "CanvasScene.h"

@interface CanvasScene() {
    
    Simulation* _simulation;
}
@end

@implementation CanvasScene


- (instancetype)initWithDevice:(id<MTLDevice>)device
                         layer:(CAMetalLayer*)layer
     numInflightCommandBuffers:(unsigned int)numInflightCommandBuffers
                       library:(id<MTLLibrary>)library {
    
    self = [super initWithFrame:layer.frame contentsScale:layer.contentsScale];
    
    if(self) {
        _simulation = [[Simulation alloc]init];
    }
    
    return self;
}

@end
