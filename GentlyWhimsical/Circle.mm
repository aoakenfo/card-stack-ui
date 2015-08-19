//
//  Circle.m
//  gently whimsical
//
//  Created by Edward Oakenfold on 2015-05-06.
//  Copyright (c) 2015 conceptual inertia. All rights reserved.
//

#import <Metal/Metal.h>
#include "Misc.h"
#import "Circle.h"

@interface Circle() {
    uint32_t _numVertices;
    uint32_t _numColors;
}

@end

@implementation Circle

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
        
        NSNumber* radius = [params objectForKey:kRadius];
        if(radius == nil) {
            radius = @1;
        }
        NSNumber* numSlices = [params objectForKey:kNumSlices];
        if(numSlices == nil) {
            numSlices = @10;
        }
        
        _numVertices = [numSlices unsignedIntValue] * 3;
        uint32_t sizeVertices = _numVertices * sizeof(simd::float4);
        // calloc zero-initializes the buffer, while malloc leaves the memory uninitialized
        simd::float4* vertices = (simd::float4*)malloc(sizeVertices);
       
        _numColors = [numSlices unsignedIntValue] * 3;
        uint32_t sizeColors = _numColors * sizeof(simd::float4);
        simd::float4* colors = (simd::float4*)malloc(sizeColors);
        
        float theta = 0.0f;
        float angleInc = DEGREES_TO_RADIANS(360.0f / [numSlices integerValue]);
        
        for(int i = 0; i < _numVertices; i += 3) {
            
            vertices[i+0] = { [radius floatValue] * cosf(theta), [radius floatValue] * sinf(theta), 0.0f, 1.0f };
            vertices[i+1] = { [radius floatValue] * cosf(theta + angleInc), [radius floatValue] * sinf(theta + angleInc), 0.0f, 1.0f };
            vertices[i+2] = { 0, 0, 0, 1 };
            
            colors[i+0] = { 1, 0, 0, 1 }; // red
            colors[i+1] = { 1, 0, 0, 1 }; // red
            colors[i+2] = { 0, 0, 1, 1 }; // blue
            
            theta += angleInc;
        }
        
        super.vertexBuffer = [device newBufferWithBytes:vertices length:sizeVertices options:MTLResourceOptionCPUCacheModeDefault];
        super.colorBuffer = [device newBufferWithBytes:colors length:sizeColors options:MTLResourceOptionCPUCacheModeDefault];
        
        free(colors);
        free(vertices);
    }
    
    return self;
}

- (void)setGradientStops:(MTLClearColor)a b:(MTLClearColor)b {
    simd::float4 a4 = { (float)a.red, (float)a.green, (float)a.blue, (float)a.alpha };
    simd::float4 b4 = { (float)b.red, (float)b.green, (float)b.blue, (float)b.alpha };
    
    simd::float4* colors = (simd::float4*)[super.colorBuffer contents];
    
    for(int i = 0; i < _numColors; i += 3) {
        colors[i+0] = b4; // edge
        colors[i+1] = b4; // edge
        colors[i+2] = a4; // center
    }
}

@end
