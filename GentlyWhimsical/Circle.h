//
//  Circle.h
//  gently whimsical
//
//  Created by Edward Oakenfold on 2015-05-06.
//  Copyright (c) 2015 conceptual inertia. All rights reserved.
//

#import <Metal/MTLRenderPass.h>
#import "Primitive.h"

// param keys
NSString* const kRadius = @"radius";
NSString* const kNumSlices = @"numSlices";

@interface Circle : Primitive

- (instancetype)initWithDevice:(id<MTLDevice>)device
                         layer:(CAMetalLayer*)layer
     numInflightCommandBuffers:(unsigned int)numInflightCommandBuffers
                       library:(id<MTLLibrary>)library
                        params:(NSDictionary*)params;

- (void)setGradientStops:(MTLClearColor)a b:(MTLClearColor)b;

@end
