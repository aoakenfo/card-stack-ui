//
//  Triangle.m
//  gently whimsical
//
//  Created by Edward Oakenfold on 2015-04-30.
//  Copyright (c) 2015 conceptual inertia. All rights reserved.
//

#import <Metal/Metal.h>
#import "Triangle.h"

@interface Triangle() {
    uint32_t _numVertices;
}
@end

@implementation Triangle

- (instancetype)initWithDevice:(id<MTLDevice>)device
                         layer:(CAMetalLayer*)layer
     numInflightCommandBuffers:(unsigned int)numInflightCommandBuffers
                       library:(id<MTLLibrary>)library
                        params:(NSDictionary*)params {
    
    self = [super initWithDevice:device
                           layer:layer
       numInflightCommandBuffers:numInflightCommandBuffers
                         library:library
                          params:params];
    
    if(self) {
        _numVertices = 3;
        uint32_t sizeVertices  = _numVertices * sizeof(simd::float4);
        simd::float4 vertices[] = {
            { -1.0f, -1.0f, 0.0f, 1.0f },
            {  1.0f, -1.0f, 0.0f, 1.0f },
            { -1.0f,  1.0f, 0.0f, 1.0f }
        };
        
        uint32_t numColors = 3;
        uint32_t sizeColors  = numColors * sizeof(simd::float4);
        simd::float4 colors[] = {
            {0, 0, 1, 1},
            {1, 0, 0, 1},
            {0, 1, 0, 1}
        };
        
        super.vertexBuffer = [device newBufferWithBytes:vertices length:sizeVertices options:MTLResourceOptionCPUCacheModeDefault];
        super.colorBuffer = [device newBufferWithBytes:colors length:sizeColors options:MTLResourceOptionCPUCacheModeDefault];
    }
    
    return self;
}

@end
