//
//  Primitive.m
//  gently whimsical
//
//  Created by Edward Oakenfold on 2015-05-06.
//  Copyright (c) 2015 conceptual inertia. All rights reserved.
//

#import <UIKit/UIImage.h>
#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>
#import "AAPLTransforms.h"
#import "Camera.h"
#import "Primitive.h"

@interface Primitive() {
    simd::float4x4 _model;
    simd::float3 _origin;
}
@end

@implementation Primitive

- (instancetype)initWithDevice:(id<MTLDevice>)device
                         layer:(CAMetalLayer*)layer
     numInflightCommandBuffers:(unsigned int)numInflightCommandBuffers
                       library:(id<MTLLibrary>)library
                    params:(NSDictionary*)params {
    
    self = [super init];
    
    if(self) {
        
        _viewFrame = layer.frame;
        _contentsScale = layer.contentsScale;
        
        _sx = _sy = _sz = 1.0f;
        
        NSNumber* isTextured = [params objectForKey:kIsTextured];
        if(isTextured == nil) {
            isTextured = @(0);
        }
        _isTextured = ([isTextured integerValue] == 1);
        
        if(_isTextured) {
            NSString* textureName = [params objectForKey:kTextureName];
            if(textureName != nil) { // TEMP
                UIImage* image = [UIImage imageNamed:textureName];
                _diffuseTexture = [self textureFromImage:image device:device];
               
                MTLSamplerDescriptor* samplerDesc = [MTLSamplerDescriptor new];
                samplerDesc.minFilter = MTLSamplerMinMagFilterNearest;
                samplerDesc.magFilter = MTLSamplerMinMagFilterNearest;
                
                _diffuseSampler = [device newSamplerStateWithDescriptor:samplerDesc];
            }
        }
    }
    
    return self;
}

- (void)dealloc {
    
    _vertexBuffer = nil;
    _colorBuffer = nil;
    _texelBuffer = nil;
    
    if(_isTextured) {
        _diffuseSampler = nil;
        _diffuseTexture = nil;
    }
}

- (id <MTLTexture>)textureFromImage:(UIImage*)image device:(id<MTLDevice>)device {
    
    CGImageRef imageRef = [image CGImage];
    
    _imageWidth = CGImageGetWidth(imageRef);
    _imageHeight = CGImageGetHeight(imageRef);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    NSUInteger bytesPerRow = _imageWidth * 4;
    NSUInteger bitsPerComponent = 8;
    CGContextRef ctx = CGBitmapContextCreate(NULL, _imageWidth, _imageHeight, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    
    // vertical flip
    CGContextTranslateCTM(ctx, 0, _imageHeight);
    CGContextScaleCTM(ctx, 1.0, -1.0);
    
    CGContextDrawImage(ctx, CGRectMake(0, 0, _imageWidth, _imageHeight), imageRef);
    const void* pixels = CGBitmapContextGetData(ctx);
    
    MTLTextureDescriptor* texDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                       width:_imageWidth
                                                                                      height:_imageHeight
                                                                                   mipmapped:NO];
    id <MTLTexture> tex = [device newTextureWithDescriptor:texDesc];
    
    MTLRegion region = MTLRegionMake2D(0, 0, _imageWidth, _imageHeight);
    [tex replaceRegion:region mipmapLevel:0 withBytes:pixels bytesPerRow:bytesPerRow];
    
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(ctx);
    
    return tex;
}

- (void)setOrigin:(float)x y:(float)y z:(float)z {
    _origin = { x, y, z };
}

- (simd::float4x4)model {
    
    simd::float4x4 offset1 = matrix_identity_float4x4;
    simd::float4x4 offset2 = matrix_identity_float4x4;
    
    if(_origin[0] != 0 || _origin[1] != 0 || _origin[2] != 0) {
        
        offset1 = AAPL::Math::translate(-_origin[0], -_origin[1], -_origin[2]);
        offset2 = AAPL::Math::translate(_origin[0], _origin[1], _origin[2]);
    }
    
    simd::float4x4 scale = AAPL::Math::scale(_sx, _sy, _sz);
    
    simd::float4x4 rotateX = AAPL::Math::rotate(_rx, 1.0f, 0.0f, 0.0f);
    simd::float4x4 rotateY = AAPL::Math::rotate(_ry, 0.0f, 1.0f, 0.0f);
    simd::float4x4 rotateZ = AAPL::Math::rotate(_rz, 0.0f, 0.0f, 1.0f);
    simd::float4x4 rotation = rotateZ * rotateY * rotateX;
    
    simd::float4x4 translate = AAPL::Math::translate(_x, _y, _z);
    
    _model = translate * offset2 * rotation * scale * offset1;
    
    return _model;
}

@end
