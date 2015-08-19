//
//  Quad.m
//  gently whimsical
//
//  Created by Edward Oakenfold on 2015-04-25.
//  Copyright (c) 2015 conceptual inertia. All rights reserved.
//

#import <UIKit/UIImage.h>
#import <Metal/Metal.h>
#import "SharedStruct.h"
#import "Camera.h"
#include "Misc.h"
#import "Quad.h"

static NSMapTable* _deviceVertexBuffers = [NSMapTable mapTableWithKeyOptions:NSMapTableStrongMemory valueOptions:NSMapTableStrongMemory];
static NSMutableDictionary* _deviceVertexBuffersRefCount = [[NSMutableDictionary alloc]init];

// TODO: throw in utils
inline float mapRange(float inMin, float inMax, float outMin, float outMax, float value) {
    return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
}

@interface Quad() {
    
    BOOL _isBeveled;
    
    int _numSlices;
    NSString* _vertexKey;
    
    float _radiusOffset;
    float _circOffset;
    float _aspectWidth;
    float _aspectHeight;
    
    CGRect _texelFrame;
}
@end

@implementation Quad

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
        
        NSNumber* cornerRadius = [params objectForKey:kCornerRadius];
        if(cornerRadius == nil) {
            cornerRadius = @0;
        }
        NSNumber* isFullscreen = [params objectForKey:kIsFullscreen];
        if(isFullscreen == nil) {
            isFullscreen = @0;
        }
        NSNumber* aspectWidth = [params objectForKey:kAspectWidth];
        if(aspectWidth == nil) {
            aspectWidth = @1;
        }
        _aspectWidth = [aspectWidth floatValue];
        NSNumber* aspectHeight = [params objectForKey:kAspectHeight];
        if(aspectHeight == nil) {
            aspectHeight = @1;
        }
        _aspectHeight = [aspectHeight floatValue];
        
        _isBeveled = [cornerRadius floatValue] > 0;
        
        if(_isBeveled) {
            // scaling the quad squashes the corner fans
            // so we use aspect ratio to adjust the vertices
            [self createBeveledQuad:device
                        aspectWidth:[aspectWidth floatValue]
                       aspectHeight:[aspectHeight floatValue]
                       cornerRadius:[cornerRadius floatValue]];
        } else {
            [self createSquareQuad:device];
        }
        
        simd::float3 normals[] = {
            { 0, 0, -1 }
        };
        super.normalBuffer = [device newBufferWithBytes:normals length:sizeof(simd::float3) options:MTLResourceOptionCPUCacheModeDefault];
    }
    
    return self;
}

// TODO: test by loading different scenes
- (void)dealloc {
    
    NSNumber* refCount = [_deviceVertexBuffersRefCount objectForKey:_vertexKey];
    refCount = @([refCount integerValue] - 1);
    
    if([refCount integerValue] == 0) {
        [_deviceVertexBuffersRefCount removeObjectForKey:_vertexKey];
        [_deviceVertexBuffers removeObjectForKey:_vertexKey];
    }
    else {
        [_deviceVertexBuffersRefCount setObject:refCount forKey:_vertexKey];
    }
}

- (void)createSquareQuad:(id<MTLDevice>)device {
    super.numVertices = 6;
    uint32_t sizeVertices  = super.numVertices * sizeof(simd::float4);
    simd::float4 vertices[] = {
        // counter-clockwise winding
        { -1.0f, -1.0f, 0.0f, 1.0f }, // left bottom
        {  1.0f, -1.0f, 0.0f, 1.0f }, // right bottom
        { -1.0f,  1.0f, 0.0f, 1.0f }, // left top
        
        {  1.0f, -1.0f, 0.0f, 1.0f }, // right bottom
        {  1.0f,  1.0f, 0.0f, 1.0f }, // right top
        { -1.0f,  1.0f, 0.0f, 1.0f }  // left top
    };
    
    uint32_t numColors = 6;
    uint32_t sizeColors  = numColors * sizeof(simd::float4);
    simd::float4 colors[] = {
        // horizontal gradient - blue left, red right
        { 0, 0, 1, 1 }, // blue bottom-left      -> for vertical, switch to red
        { 1, 0, 0, 1 }, // red  bottom-right
        { 0, 0, 1, 1 }, // blue top-left
        
        { 1, 0, 0, 1 }, // red  bottom-right
        { 1, 0, 0, 1 }, // red  top-right         -> for vertical, switch to blue
        { 0, 0, 1, 1 }  // blue top-left
    };
    
    super.vertexBuffer = [device newBufferWithBytes:vertices length:sizeVertices options:MTLResourceOptionCPUCacheModeDefault];
    super.colorBuffer = [device newBufferWithBytes:colors length:sizeColors options:MTLResourceOptionCPUCacheModeDefault];
    
    if(super.isTextured) {
        uint32_t numTexels = 6;
        uint32_t sizeTexels  = numTexels * sizeof(simd::float2);
        simd::float2 texels[] = {
            {0, 0}, // left bottom
            {1, 0}, // right bottom
            {0, 1}, // left top
            
            {1, 0}, // right bottom
            {1, 1}, // right top
            {0, 1}  // left top
        };
        
        super.texelBuffer = [device newBufferWithBytes:texels length:sizeTexels options:MTLResourceOptionCPUCacheModeDefault];
    }
}

- (void)createBeveledQuad:(id<MTLDevice>)device
              aspectWidth:(float)aspectWidth
             aspectHeight:(float)aspectHeight
             cornerRadius:(float)cornerRadius {
    
    _radiusOffset = cornerRadius / 100;
    _circOffset   = _radiusOffset * 2;
    
    aspectWidth /= 2;
    aspectHeight /= 2;
    
    super.numVertices = 6 * 5;
    uint32_t sizeVertices  = super.numVertices * sizeof(simd::float4);
    simd::float4 vertices[] = {
        // center quad
        { -aspectWidth + _circOffset, -aspectHeight + _circOffset, 0.0f, 1.0f },
        {  aspectWidth - _circOffset, -aspectHeight + _circOffset, 0.0f, 1.0f },
        { -aspectWidth + _circOffset,  aspectHeight - _circOffset, 0.0f, 1.0f },
        
        {  aspectWidth - _circOffset, -aspectHeight + _circOffset, 0.0f, 1.0f },
        {  aspectWidth - _circOffset,  aspectHeight - _circOffset, 0.0f, 1.0f },
        { -aspectWidth + _circOffset,  aspectHeight - _circOffset, 0.0f, 1.0f },
        
        // left edge quad
        { -aspectWidth,               -aspectHeight + _circOffset, 0.0f, 1.0f },
        { -aspectWidth + _circOffset, -aspectHeight + _circOffset, 0.0f, 1.0f },
        { -aspectWidth,                aspectHeight - _circOffset, 0.0f, 1.0f },
        
        { -aspectWidth + _circOffset, -aspectHeight + _circOffset, 0.0f, 1.0f },
        { -aspectWidth + _circOffset,  aspectHeight - _circOffset, 0.0f, 1.0f },
        { -aspectWidth,                aspectHeight - _circOffset, 0.0f, 1.0f },
        
        // right edge quad
        { aspectWidth - _circOffset, -aspectHeight + _circOffset, 0.0f, 1.0f },
        { aspectWidth,               -aspectHeight + _circOffset, 0.0f, 1.0f },
        { aspectWidth - _circOffset,  aspectHeight - _circOffset, 0.0f, 1.0f },
        
        { aspectWidth,               -aspectHeight + _circOffset, 0.0f, 1.0f },
        { aspectWidth,                aspectHeight - _circOffset, 0.0f, 1.0f },
        { aspectWidth - _circOffset,  aspectHeight - _circOffset, 0.0f, 1.0f },
        
        // top edge quad
        { -aspectWidth + _circOffset, aspectHeight - _circOffset, 0.0f, 1.0f },
        {  aspectWidth - _circOffset, aspectHeight - _circOffset, 0.0f, 1.0f },
        { -aspectWidth + _circOffset, aspectHeight,               0.0f, 1.0f },
        
        {  aspectWidth - _circOffset, aspectHeight - _circOffset, 0.0f, 1.0f },
        {  aspectWidth - _circOffset, aspectHeight,               0.0f, 1.0f },
        { -aspectWidth + _circOffset, aspectHeight,               0.0f, 1.0f },
        
        // bottom edge quad
        { -aspectWidth + _circOffset, -aspectHeight,               0.0f, 1.0f },
        {  aspectWidth - _circOffset, -aspectHeight,               0.0f, 1.0f },
        { -aspectWidth + _circOffset, -aspectHeight + _circOffset, 0.0f, 1.0f },
        
        {  aspectWidth - _circOffset, -aspectHeight,               0.0f, 1.0f },
        {  aspectWidth - _circOffset, -aspectHeight + _circOffset, 0.0f, 1.0f },
        { -aspectWidth + _circOffset, -aspectHeight + _circOffset, 0.0f, 1.0f }
    };
    
    _numSlices = 90;
    uint32_t numCornerVertices = _numSlices * 3 * 4;
    uint32_t sizeCornerVertices = numCornerVertices * sizeof(simd::float4);
    simd::float4* cornerVertices = (simd::float4*)malloc(sizeCornerVertices);
    
    uint32_t numCornerColors = _numSlices * 3 * 4;
    uint32_t sizeCornerColors = numCornerColors * sizeof(simd::float4);
    simd::float4* cornerColors = (simd::float4*)malloc(sizeCornerColors);
    
    float angleInc = DEGREES_TO_RADIANS(90.0f / _numSlices);
    
    __block float theta = 0.0f;
    __block int i = 0;
    __block CGPoint origin = CGPointMake(aspectWidth - _circOffset, aspectHeight - _circOffset);
    __block simd::float4 col = { 1, 0, 0, 1 };
    
    void(^fan)(void) = ^{
        int j = i;
        for(; i < j + _numSlices * 3; i += 3) {
            cornerVertices[i+0] = {
                _circOffset * cosf(theta) + (float)origin.x,
                _circOffset * sinf(theta) + (float)origin.y,
                0.0f,
                1.0f
            };
            cornerVertices[i+1] = {
                _circOffset * cosf(theta + angleInc) + (float)origin.x,
                _circOffset * sinf(theta + angleInc) + (float)origin.y,
                0.0f,
                1.0f
            };
            cornerVertices[i+2] = { (float)origin.x, (float)origin.y, 0, 1 };
            
            cornerColors[i+0] = col;
            cornerColors[i+1] = col;
            cornerColors[i+2] = col;
            
            theta += angleInc;
        }
    };
    fan();
    origin = CGPointMake(-aspectWidth + _circOffset,  aspectHeight - _circOffset);
    col = { 0, 0, 1, 1 };
    fan();
    origin = CGPointMake(-aspectWidth + _circOffset, -aspectHeight + _circOffset);
    fan();
    origin = CGPointMake( aspectWidth - _circOffset, -aspectHeight + _circOffset);
    col = { 1, 0, 0, 1 };
    fan();
    
    uint32_t numColors = 6 * 5;
    uint32_t sizeColors  = numColors * sizeof(simd::float4);
    simd::float4 colors[] = {
        
        // center quad
        { 0.0f, 0.0f, 1.0f, 1.0f },
        { 1.0f, 0.0f, 0.0f, 1.0f },
        { 0.0f, 0.0f, 1.0f, 1.0f },
        
        { 1.0f, 0.0f, 0.0f, 1.0f },
        { 1.0f, 0.0f, 0.0f, 1.0f },
        { 0.0f, 0.0f, 1.0f, 1.0f },
        
        // left edge quad
        { 0.0f, 0.0f, 1.0f, 1.0f },
        { 0.0f, 0.0f, 1.0f, 1.0f },
        { 0.0f, 0.0f, 1.0f, 1.0f },
        
        { 0.0f, 0.0f, 1.0f, 1.0f },
        { 0.0f, 0.0f, 1.0f, 1.0f },
        { 0.0f, 0.0f, 1.0f, 1.0f },
        
        // right edge quad
        { 1.0f, 0.0f, 0.0f, 1.0f },
        { 1.0f, 0.0f, 0.0f, 1.0f },
        { 1.0f, 0.0f, 0.0f, 1.0f },
        
        { 1.0f, 0.0f, 0.0f, 1.0f },
        { 1.0f, 0.0f, 0.0f, 1.0f },
        { 1.0f, 0.0f, 0.0f, 1.0f },
        
        // top edge quad
        { 0.0f, 0.0f, 1.0f, 1.0f },
        { 1.0f, 0.0f, 0.0f, 1.0f },
        { 0.0f, 0.0f, 1.0f, 1.0f },
        
        { 1.0f, 0.0f, 0.0f, 1.0f },
        { 1.0f, 0.0f, 0.0f, 1.0f },
        { 0.0f, 0.0f, 1.0f, 1.0f },
        
        // bottom edge quad
        { 0.0f, 0.0f, 1.0f, 1.0f },
        { 1.0f, 0.0f, 0.0f, 1.0f },
        { 0.0f, 0.0f, 1.0f, 1.0f },
        
        { 1.0f, 0.0f, 0.0f, 1.0f },
        { 1.0f, 0.0f, 0.0f, 1.0f },
        { 0.0f, 0.0f, 1.0f, 1.0f }
    };
    
    uint32_t sizeCombinedVertices = (super.numVertices + numCornerVertices) * sizeof(simd::float4);
    simd::float4* combinedVertices = (simd::float4*)malloc(sizeCombinedVertices);
    memcpy(combinedVertices, // dest
           vertices,         // src
           sizeVertices);    // size
    memcpy(&combinedVertices[super.numVertices], cornerVertices, sizeCornerVertices);
    super.numVertices += numCornerVertices;
    
    uint32_t sizeCombinedColors = (numColors + numCornerColors) * sizeof(simd::float4);
    simd::float4* combinedColors = (simd::float4*)malloc(sizeCombinedColors);
    memcpy(combinedColors, colors, sizeColors);
    memcpy(&combinedColors[numColors], cornerColors, sizeCornerColors);
    numColors += numCornerColors;
    
    _vertexKey = [NSString stringWithFormat:@"%.02f|%f|%f", cornerRadius, aspectWidth, aspectHeight];
    id<MTLBuffer> vertexBuf = [_deviceVertexBuffers objectForKey:_vertexKey];
    if(vertexBuf == nil) {
        NSLog(@"creating vertex buffer for key %@", _vertexKey);
        vertexBuf = [device newBufferWithBytes:combinedVertices length:sizeCombinedVertices options:MTLResourceOptionCPUCacheModeDefault];
        
        [_deviceVertexBuffers setObject:vertexBuf forKey:_vertexKey];
        [_deviceVertexBuffersRefCount setObject:@(0) forKey:_vertexKey];
    }
    super.vertexBuffer = vertexBuf;

    NSNumber* refCount = [_deviceVertexBuffersRefCount objectForKey:_vertexKey];
    refCount = @([refCount integerValue] + 1);
    [_deviceVertexBuffersRefCount setObject:refCount forKey:_vertexKey];
    
    super.colorBuffer = [device newBufferWithBytes:combinedColors length:sizeCombinedColors options:MTLResourceOptionCPUCacheModeDefault];
    
    if(super.isTextured) {
        uint32_t numTexels = 6 * 5;
        uint32_t sizeTexels  = numTexels * sizeof(simd::float2);
        
        float radiusOffsetByAspectWidth = _radiusOffset/aspectWidth;
        float radiusOffsetByAspectHeight = _radiusOffset/aspectHeight;
        
        simd::float2 texels[] = {
            // center quad
            { 0.0f + radiusOffsetByAspectWidth, 0.0f + radiusOffsetByAspectHeight }, // left bottom
            { 1.0f - radiusOffsetByAspectWidth, 0.0f + radiusOffsetByAspectHeight }, // right bottom
            { 0.0f + radiusOffsetByAspectWidth, 1.0f - radiusOffsetByAspectHeight }, // left top
            
            { 1.0f - radiusOffsetByAspectWidth, 0.0f + radiusOffsetByAspectHeight }, // right bottom
            { 1.0f - radiusOffsetByAspectWidth, 1.0f - radiusOffsetByAspectHeight }, // right top
            { 0.0f + radiusOffsetByAspectWidth, 1.0f - radiusOffsetByAspectHeight }, // left top
            
            // left edge quad
            { 0.0f,                             0.0f + radiusOffsetByAspectHeight },
            { 0.0f + radiusOffsetByAspectWidth, 0.0f + radiusOffsetByAspectHeight },
            { 0.0f,                             1.0f - radiusOffsetByAspectHeight },
            
            { 0.0f + radiusOffsetByAspectWidth, 0.0f + radiusOffsetByAspectHeight },
            { 0.0f + radiusOffsetByAspectWidth, 1.0f - radiusOffsetByAspectHeight },
            { 0.0f,                             1.0f - radiusOffsetByAspectHeight },
            
            // right edge quad
            { 1.0f - radiusOffsetByAspectWidth, 0.0f + radiusOffsetByAspectHeight },
            { 1.0f,                             0.0f + radiusOffsetByAspectHeight },
            { 1.0f - radiusOffsetByAspectWidth, 1.0f - radiusOffsetByAspectHeight },
            
            { 1.0f,                             0.0f + radiusOffsetByAspectHeight },
            { 1.0f,                             1.0f - radiusOffsetByAspectHeight },
            { 1.0f - radiusOffsetByAspectWidth, 1.0f - radiusOffsetByAspectHeight },
            
            // top edge quad
            { 0.0f + radiusOffsetByAspectWidth, 1.0f - radiusOffsetByAspectHeight },
            { 1.0f - radiusOffsetByAspectWidth, 1.0f - radiusOffsetByAspectHeight },
            { 0.0f + radiusOffsetByAspectWidth, 1.0f                              },
            
            { 1.0f - radiusOffsetByAspectWidth, 1.0f - radiusOffsetByAspectHeight },
            { 1.0f - radiusOffsetByAspectWidth, 1.0f                              },
            { 0.0f + radiusOffsetByAspectWidth, 1.0f                              },
            
            // botom edge quad
            { 0.0f + radiusOffsetByAspectWidth, 0.0f                              },
            { 1.0f - radiusOffsetByAspectWidth, 0.0f                              },
            { 0.0f + radiusOffsetByAspectWidth, 0.0f + radiusOffsetByAspectHeight },
            
            { 1.0f - radiusOffsetByAspectWidth, 0.0f                              },
            { 1.0f - radiusOffsetByAspectWidth, 0.0f + radiusOffsetByAspectHeight },
            { 0.0f + radiusOffsetByAspectWidth, 0.0f + radiusOffsetByAspectHeight }
        };
        
        uint32_t numCornerTexels = _numSlices * 3 * 4;
        uint32_t sizeCornerTexels = numCornerTexels * sizeof(simd::float2);
        simd::float2* cornerTexels = (simd::float2*)malloc(sizeCornerTexels);
        
        float angleInc = DEGREES_TO_RADIANS(90.0f / _numSlices);
        
        __block float theta = 0.0f;
        __block int i = 0;
        __block CGPoint origin = CGPointMake(1 - radiusOffsetByAspectWidth, 1 - radiusOffsetByAspectHeight);
        
        void(^texelFan)(void) = ^{
            int j = i;
            for(; i < j + _numSlices * 3; i += 3) {
                
                float a = radiusOffsetByAspectWidth  * cosf(theta) + (float)origin.x;
                float b = radiusOffsetByAspectHeight * sinf(theta) + (float)origin.y;
                if(a < 0) { a += 1; }
                if(b < 0) { b += 1; }
                cornerTexels[i+0] = { a, b };
                
                float c = radiusOffsetByAspectWidth  * cosf(theta + angleInc) + (float)origin.x;
                float d = radiusOffsetByAspectHeight * sinf(theta + angleInc) + (float)origin.y;
                if(c < 0) { c += 1; }
                if(d < 0) { d += 1; }
                cornerTexels[i+1] = { c, d };
                
                float e = (float)origin.x;
                float f = (float)origin.y;
                if(e < 0) { e += 1; }
                if(f < 0) { f += 1; }
                cornerTexels[i+2] = { e, f };
                
                theta += angleInc;
            }
        };
        texelFan();
        origin = CGPointMake(-1.0f + radiusOffsetByAspectWidth,  1.0f - radiusOffsetByAspectHeight);
        texelFan();
        origin = CGPointMake(-1.0f + radiusOffsetByAspectWidth, -1.0f + radiusOffsetByAspectHeight);
        texelFan();
        origin = CGPointMake( 1.0f - radiusOffsetByAspectWidth, -1.0f + radiusOffsetByAspectHeight);
        texelFan();
        
        uint32_t sizeCombinedTexels = (numTexels + numCornerTexels) * sizeof(simd::float2);
        simd::float2* combinedTexels = (simd::float2*)malloc(sizeCombinedTexels);
        memcpy(combinedTexels, // dest
               texels,         // src
               sizeTexels);    // size
        memcpy(&combinedTexels[numTexels], cornerTexels, sizeCornerTexels);
        
        super.texelBuffer = [device newBufferWithBytes:combinedTexels length:sizeCombinedTexels options:MTLResourceOptionCPUCacheModeDefault];
        
        free(cornerTexels);
        free(combinedTexels);
    }
    
    free(cornerColors);
    free(combinedColors);
    free(cornerVertices);
    free(combinedVertices);
}

- (float)ty {
    return _texelFrame.origin.y;
}

- (void)setTy:(float)value {
    _texelFrame.origin.y = value;
    [self setTexelRect:_texelFrame];
}

- (void)setTexelRect:(CGRect)frame {
    
    _texelFrame = frame;
    
    simd::float2* texels = (simd::float2*)[super.texelBuffer contents];
    
    float imageWidth = super.imageWidth; // px
    float imageHeight = super.imageHeight;
    
    float x = mapRange(0, imageWidth , 0, 1, frame.origin.x);
    float y = mapRange(0, imageHeight, 0, 1, frame.origin.y);
    float w = mapRange(0, imageWidth , 0, 1, frame.origin.x + frame.size.width);
    float h = mapRange(0, imageHeight, 0, 1, frame.origin.y + frame.size.height);
   
    if(_isBeveled) {
        
        float radiusOffsetByAspectWidth = _radiusOffset/_aspectWidth;
        float radiusOffsetByAspectHeight = _radiusOffset/_aspectHeight;
        
        // center quad
        texels[0]  = { x + radiusOffsetByAspectWidth, y + radiusOffsetByAspectHeight }; // left bottom
        texels[1]  = { w - radiusOffsetByAspectWidth, y + radiusOffsetByAspectHeight }; // right bottom
        texels[2]  = { x + radiusOffsetByAspectWidth, h - radiusOffsetByAspectHeight }; // left top
        
        texels[3]  = { w - radiusOffsetByAspectWidth, y + radiusOffsetByAspectHeight }; // right bottom
        texels[4]  = { w - radiusOffsetByAspectWidth, h - radiusOffsetByAspectHeight }; // right top
        texels[5]  = { x + radiusOffsetByAspectWidth, h - radiusOffsetByAspectHeight }; // left top
        
        // left edge quad
        texels[6]  = { x,                             y + radiusOffsetByAspectHeight };
        texels[7]  = { x + radiusOffsetByAspectWidth, y + radiusOffsetByAspectHeight };
        texels[8]  = { x,                             h - radiusOffsetByAspectHeight };
        
        texels[9]  = { x + radiusOffsetByAspectWidth, y + radiusOffsetByAspectHeight };
        texels[10] = { x + radiusOffsetByAspectWidth, h - radiusOffsetByAspectHeight };
        texels[11] = { x,                             h - radiusOffsetByAspectHeight };
        
        // right edge quad
        texels[12] = { w - radiusOffsetByAspectWidth, y + radiusOffsetByAspectHeight };
        texels[13] = { w,                             y + radiusOffsetByAspectHeight };
        texels[14] = { w - radiusOffsetByAspectWidth, h - radiusOffsetByAspectHeight };
    
        texels[15] = { w,                             y + radiusOffsetByAspectHeight };
        texels[16] = { w,                             h - radiusOffsetByAspectHeight };
        texels[17] = { w - radiusOffsetByAspectWidth, h - radiusOffsetByAspectHeight };
        
        // top edge quad
        texels[18] = { x + radiusOffsetByAspectWidth, h - radiusOffsetByAspectHeight };
        texels[19] = { w - radiusOffsetByAspectWidth, h - radiusOffsetByAspectHeight };
        texels[20] = { x + radiusOffsetByAspectWidth, h                              };
        
        texels[21] = { w - radiusOffsetByAspectWidth, h - radiusOffsetByAspectHeight };
        texels[22] = { w - radiusOffsetByAspectWidth, h                              };
        texels[23] = { x + radiusOffsetByAspectWidth, h                              };
        
        // botom edge quad
        texels[24] = { x + radiusOffsetByAspectWidth, y                              };
        texels[25] = { w - radiusOffsetByAspectWidth, y                              };
        texels[26] = { x + radiusOffsetByAspectWidth, y + radiusOffsetByAspectHeight };
        
        texels[27] = { w - radiusOffsetByAspectWidth, y                              };
        texels[28] = { w - radiusOffsetByAspectWidth, y + radiusOffsetByAspectHeight };
        texels[29] = { x + radiusOffsetByAspectWidth, y + radiusOffsetByAspectHeight };
        
        float angleInc = DEGREES_TO_RADIANS(90.0f / _numSlices);
        
        __block float theta = 0.0f;
        __block int i = 30;
        __block CGPoint origin = CGPointMake(w - radiusOffsetByAspectWidth, h - radiusOffsetByAspectHeight);
        
        void(^texelFan)(void) = ^{
            int j = i;
            for(; i < j + _numSlices * 3; i += 3) {
                
                float a = radiusOffsetByAspectWidth  * cosf(theta) + (float)origin.x;
                float b = radiusOffsetByAspectHeight * sinf(theta) + (float)origin.y;
                if(a < 0) { a += 1; }
                if(b < 0) { b += 1; }
                texels[i+0] = { a, b };
                
                float c = radiusOffsetByAspectWidth  * cosf(theta + angleInc) + (float)origin.x;
                float d = radiusOffsetByAspectHeight * sinf(theta + angleInc) + (float)origin.y;
                if(c < 0) { c += 1; }
                if(d < 0) { d += 1; }
                texels[i+1] = { c, d };
                
                float e = (float)origin.x;
                float f = (float)origin.y;
                if(e < 0) { e += 1; }
                if(f < 0) { f += 1; }
                texels[i+2] = { e, f };
                
                theta += angleInc;
            }
        };
        texelFan();
        origin = CGPointMake(x + radiusOffsetByAspectWidth, h - radiusOffsetByAspectHeight);
        texelFan();
        origin = CGPointMake(x + radiusOffsetByAspectWidth, y + radiusOffsetByAspectHeight);
        texelFan();
        origin = CGPointMake(w - radiusOffsetByAspectWidth, y + radiusOffsetByAspectHeight);
        texelFan();
    
    } else {
        
        simd::float2 left_bottom  = { x,     y     };
        simd::float2 right_bottom = { x + w, y     };
        simd::float2 right_top    = { x + w, y + h };
        simd::float2 left_top     = { x,     y + h };
        
        texels[0] = left_bottom;
        texels[1] = right_bottom;
        texels[2] = left_top;
        texels[3] = right_bottom;
        texels[4] = right_top;
        texels[5] = left_top;
    }
}

- (void)setGradientStops:(MTLClearColor)a b:(MTLClearColor)b isHorizontal:(BOOL)isHorizontal {
    simd::float4 a4 = { (float)a.red, (float)a.green, (float)a.blue, (float)a.alpha };
    simd::float4 b4 = { (float)b.red, (float)b.green, (float)b.blue, (float)b.alpha };
    
    simd::float4* colors = (simd::float4*)[super.colorBuffer contents];
    
    isHorizontal ? (*colors++ = a4) : (*colors++ = b4);
    *colors++ = b4;
    *colors++ = a4;
    *colors++ = b4;
    isHorizontal ? (*colors++ = b4) : (*colors++ = a4);
    *colors++ = a4;
    
    if(_isBeveled) {
        if(isHorizontal) {
            int i;
            // left edge
            for(i = 0; i < 6; ++i) {
                *colors++ = a4;
            }
            // right edge
            for(i = 0; i < 6; ++i) {
                *colors++ = b4;
            }
            // top/bottom edges
            for(i = 0; i < 2; ++i) {
                *colors++ = a4;
                *colors++ = b4;
                *colors++ = a4;
                *colors++ = b4;
                *colors++ = b4;
                *colors++ = a4;
            }
            // corners
            for(i = 0; i < _numSlices * 3; ++i) {
                *colors++ = b4;
            }
            for(i = 0; i < _numSlices * 3 * 2; ++i) {
                *colors++ = a4;
            }
            for(i = 0; i < _numSlices * 3; ++i) {
                *colors++ = b4;
            }
        } else {
            int i;
            // left/right edges
            for(i = 0; i < 2; ++i) {
                *colors++ = b4;
                *colors++ = b4;
                *colors++ = a4;
                *colors++ = b4;
                *colors++ = a4;
                *colors++ = a4;
            }
            for(i = 0; i < 6; ++i) {
                *colors++ = a4;
            }
            for(i = 0; i < 6; ++i) {
                *colors++ = b4;
            }
            // corners
            for(i = 0; i < _numSlices * 3 * 2; ++i) {
                *colors++ = a4;
            }
            for(i = 0; i < _numSlices * 3 * 2; ++i) {
                *colors++ = b4;
            }
        }
    }
}

- (BOOL)pointIsRightOfEdge:(CGPoint)pt p1:(CGPoint)p1 p2:(CGPoint)p2 {
    float a = -(p2.y - p1.y);
    float b = p2.x - p1.x;
    float c = -(a * p1.x + b * p1.y);
    
    float d = a * pt.x + b * pt.y + c;
    return d > 0;
}

- (BOOL)wasClicked:(CGPoint)screenTouchPos proj:(simd::float4x4)proj view:(simd::float4x4)view {
    
    simd::float4 left_top     = { -_aspectWidth/2,  _aspectHeight/2, 0.0f, 1.0f };
    simd::float4 right_top    = {  _aspectWidth/2,  _aspectHeight/2, 0.0f, 1.0f };
    simd::float4 right_bottom = {  _aspectWidth/2, -_aspectHeight/2, 0.0f, 1.0f };
    simd::float4 left_bottom  = { -_aspectWidth/2, -_aspectHeight/2, 0.0f, 1.0f };
    
    simd::float4 modelLeftTop     = matrix_multiply(super.model, left_top);
    simd::float4 modelRightTop    = matrix_multiply(super.model, right_top);
    simd::float4 modelRightBottom = matrix_multiply(super.model, right_bottom);
    simd::float4 modelLeftBottom  = matrix_multiply(super.model, left_bottom);
    
    simd::float4 clipSpaceLeftTop     = proj * (view * modelLeftTop);
    simd::float4 clipSpaceRightTop    = proj * (view * modelRightTop);
    simd::float4 clipSpaceRightBottom = proj * (view * modelRightBottom);
    simd::float4 clipSpaceLeftBottom  = proj * (view * modelLeftBottom);
    
    CGPoint perspDivideLeftTop     = CGPointMake(clipSpaceLeftTop[0] / clipSpaceLeftTop[3],
                                                 clipSpaceLeftTop[1] / clipSpaceLeftTop[3]);
    CGPoint perspDivideRightTop    = CGPointMake(clipSpaceRightTop[0] / clipSpaceRightTop[3],
                                                 clipSpaceRightTop[1] / clipSpaceRightTop[3]);
    CGPoint perspDivideRightBottom = CGPointMake(clipSpaceRightBottom[0] / clipSpaceRightBottom[3],
                                                 clipSpaceRightBottom[1] / clipSpaceRightBottom[3]);
    CGPoint perspDivideLeftBottom  = CGPointMake(clipSpaceLeftBottom[0] / clipSpaceLeftBottom[3],
                                                 clipSpaceLeftBottom[1] / clipSpaceLeftBottom[3]);
    
    CGPoint screenSpaceLeftTop     = CGPointMake((((float)perspDivideLeftTop.x + 1.0f) / 2.0f) * super.viewFrame.size.width,
                                                 ((1.0f - (float)perspDivideLeftTop.y) / 2.0f) * super.viewFrame.size.height);
    CGPoint screenSpaceRightTop    = CGPointMake((((float)perspDivideRightTop.x + 1.0f) / 2.0f) * super.viewFrame.size.width,
                                                 ((1.0f - (float)perspDivideRightTop.y) / 2.0f) * super.viewFrame.size.height);
    CGPoint screenSpaceRightBottom = CGPointMake((((float)perspDivideRightBottom.x + 1.0f) / 2.0f) * super.viewFrame.size.width,
                                                 ((1.0f - (float)perspDivideRightBottom.y) / 2.0f) * super.viewFrame.size.height);
    CGPoint screenSpaceLeftBottom  = CGPointMake((((float)perspDivideLeftBottom.x + 1.0f) / 2.0f) * super.viewFrame.size.width,
                                                 ((1.0f - (float)perspDivideLeftBottom.y) / 2.0f) * super.viewFrame.size.height);
    
    if([self pointIsRightOfEdge:screenTouchPos p1:screenSpaceLeftTop p2:screenSpaceRightTop]       &&
       [self pointIsRightOfEdge:screenTouchPos p1:screenSpaceRightTop p2:screenSpaceRightBottom]   &&
       [self pointIsRightOfEdge:screenTouchPos p1:screenSpaceRightBottom p2:screenSpaceLeftBottom] &&
       [self pointIsRightOfEdge:screenTouchPos p1:screenSpaceLeftBottom p2:screenSpaceLeftTop]) {
        
        return YES;
    }
    
    return NO;
}

@end
