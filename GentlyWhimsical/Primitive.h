//
//  Primitive.h
//  gently whimsical
//
//  Created by Edward Oakenfold on 2015-05-06.
//  Copyright (c) 2015 conceptual inertia. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>
#import <Metal/MTLPixelFormat.h>
#include <simd/simd.h>

@protocol MTLDevice;
@protocol MTLLibrary;
@protocol MTLRenderCommandEncoder;
@protocol MTLBuffer;
@protocol MTLTexture;
@protocol MTLSamplerState;
@class CAMetalLayer;
@class UIImage;
@class Camera;

// param keys
NSString* const kIsTextured = @"isTextured";
NSString* const kTextureName = @"textureName";

@interface Primitive : NSObject

// MTLBuffer represents an allocation of unformatted memory that can contain any type of data
// buffers are often used for vertex and uniform data
@property id<MTLBuffer> vertexBuffer;
@property id<MTLBuffer> colorBuffer;
@property id<MTLBuffer> texelBuffer;
@property id<MTLBuffer> normalBuffer;

// sampler:
// if you want to get the value of a texel, or a pixel inside a texture, you can index directly into it to get the colour value
// sometimes, you want an abstraction over that, which we call sampling
// there’s not a one-to-one mapping between the texels and the pixels, so a sampler is an object that knows how to read a texture and interpolate between these texels
// sampler state defines the addressing, filtering, and other properties for sampling a texture
@property id<MTLSamplerState> diffuseSampler;
@property id<MTLTexture> diffuseTexture;
@property BOOL isTextured;

@property NSUInteger imageWidth;
@property NSUInteger imageHeight;
@property (assign, nonatomic) float contentsScale;

@property (readonly) simd::float4x4 model;
@property (readonly) CGRect viewFrame;

@property (assign, nonatomic) uint32_t numVertices;

#pragma mark -

@property (assign, nonatomic) float x;
@property (assign, nonatomic) float y;
@property (assign, nonatomic) float z;
@property (assign, nonatomic) float rx;
@property (assign, nonatomic) float ry;
@property (assign, nonatomic) float rz;
@property (assign, nonatomic) float sx;
@property (assign, nonatomic) float sy;
@property (assign, nonatomic) float sz;

// range -1.0f to 1.0f
// affects alpha component in the color buffer
// color buffer may have an existing alpha gradient
// making this property a dial to inc/dec the relative values
@property (assign, nonatomic) float alphaModifier;

- (void)setOrigin:(float)x y:(float)y z:(float)z;

#pragma mark -
- (instancetype)initWithDevice:(id<MTLDevice>)device
                         layer:(CAMetalLayer*)layer
     numInflightCommandBuffers:(unsigned int)numInflightCommandBuffers
                       library:(id<MTLLibrary>)library
                    params:(NSDictionary*)params;

- (id <MTLTexture>)textureFromImage:(UIImage*)image device:(id<MTLDevice>)device;

@end
