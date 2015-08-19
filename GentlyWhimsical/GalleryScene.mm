//
//  GalleryScene.mm
//  gently whimsical
//
//  Created by Edward Oakenfold on 2015-05-14.
//  Copyright (c) 2015 conceptual inertia. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import "SharedStruct.h"
#import "AAPLTransforms.h"
#include "Misc.h"
#import "Camera.h"
#import "Tween.h"
#import "Quad.h"
#import "CardStack.h"
#import "CardStackAnim.h"
#import "GalleryScene.h"

static NSString* const kPinchPercentage = @"pinchPercentage";

typedef NS_ENUM(NSUInteger, StackState) {
    StackState_Expanded,
    StackState_Collapsed
};

typedef NS_ENUM(NSUInteger, PanDir) {
    PanDir_Vertical,
    PanDir_Horizontal
};

@interface GalleryScene() {
    
    id <MTLTexture>  _depthTex;
    id <MTLTexture>  _stencilTex;
    
    id<MTLTexture> _msaaTex;
    id<MTLDepthStencilState> _depthStencilState;
    BOOL _disableDepthStencil;
    
    MTLRenderPassDescriptor* _shadowRenderPassDescriptor;
    id<MTLTexture> _shadow_texture;
    id<MTLDepthStencilState> _shadowDepthStencilState;
    id<MTLRenderPipelineState> _shadow_render_pipeline;

    MTLRenderPassDescriptor* _renderPassDesc;
    
    NSMapTable* _renderUniformsMap;
    NSMapTable* _shadowUniformsMap;
    
    id<MTLBuffer> _sunDataBuffer;
    
    id<MTLRenderPipelineState>  _gbuffer_render_pipeline;
    
    Quad* _backgroundQuad;
    Quad* _floorQuad1;
    Quad* _floorQuad2;
    Quad* _fullscreenQuad;
    
    float _screenWidthExtentInWorld;
    float _screenHeightExtentInWorld;
    
    NSMutableArray* _stacks; // array of CardStacks
    int _selectedStackIndex;
    StackState _stackState;
    CardStackAnim* _stackAnim;
    
    UITapGestureRecognizer* _tapGesture;
    UIPanGestureRecognizer* _panGesture;
    UIPinchGestureRecognizer* _pinchGesture;
    float _pinchPercentage;
    NSNumber* _panDuration;
    
    simd::float3 _sunColor;
    
    simd::float3 _lightPos;
    
}

@property (readonly) CardStack* leftStack;
@property (readonly) CardStack* rightStack;
@property (readonly) CardStack* centerStack;

@end


@implementation GalleryScene

- (instancetype)initWithDevice:(id<MTLDevice>)device
                         layer:(CAMetalLayer*)layer
     numInflightCommandBuffers:(unsigned int)numInflightCommandBuffers
                       library:(id<MTLLibrary>)library {
    
    self = [super initWithFrame:layer.frame contentsScale:layer.contentsScale];
    
    if(self) {
        
        // pos cam
        self.camera.moveCenterWithEye = YES;
        self.camera.z = -6.6;
        self.camera.y =  3.3;
        //self.camera.x = 2.0f;
        
        _lightPos = {0, 3, -3};
        
        self.camera.projectionMode = PERSPECTIVE;
        
        // create background gradient quad
        _backgroundQuad = [[Quad alloc]initWithDevice:device
                                                 layer:layer
                             numInflightCommandBuffers:numInflightCommandBuffers
                                               library:library
                                                params:nil];
        
        [_backgroundQuad setGradientStops:MTLClearColorMake(0x193441, 1) b:MTLClearColorMake(0xd1dbbd, 1) isHorizontal:NO];
        
        _floorQuad1 = [[Quad alloc]initWithDevice:device
                                           layer:layer
                       numInflightCommandBuffers:numInflightCommandBuffers
                                         library:library
                                          params:@{ kIsTextured:@1, kTextureName:@"white" }];
        [_floorQuad1 setGradientStops:MTLClearColorMake(0x193441, 1) b:MTLClearColorMake(0xd1dbbd, 1) isHorizontal:NO];
        _floorQuad1.sx = 4*4.5;
        _floorQuad1.sy = 1.1*4.5;
        _floorQuad1.y = 0;
        _floorQuad1.z = -8;
        
        _floorQuad2 = [[Quad alloc]initWithDevice:device
                                            layer:layer
                        numInflightCommandBuffers:numInflightCommandBuffers
                                          library:library
                                           params:@{ kIsTextured:@1, kTextureName:@"white" }];
        [_floorQuad2 setGradientStops:MTLClearColorMake(0xf0f0f0, 1) b:MTLClearColorMake(0x494949, 1) isHorizontal:NO];
        
        _floorQuad2.sx = 4*4;
        _floorQuad2.sy = 1*4;
        _floorQuad2.rx = 90;
        _floorQuad2.z = 0;
        _floorQuad2.y = -2;
        
        _fullscreenQuad = [[Quad alloc]initWithDevice:device
                                                layer:layer
                            numInflightCommandBuffers:numInflightCommandBuffers
                                              library:library
                                               params:@{ kIsTextured:@1 }]; // not really, but needed for texel interp
        [_fullscreenQuad setGradientStops:MTLClearColorMake(0xffffff, 1) b:MTLClearColorMake(0xffffff, 1) isHorizontal:NO];
        
        // find screen edges in world space
        simd::float4 rightEdge = [super.camera screenToWorld: {
                                    (float)super.view.frame.size.width,
                                    (float)(super.view.frame.size.height*0.5)
                                  }];
        
        float padding = 75.f; // compensate for camera fov and selected stack offset
        _screenWidthExtentInWorld = fabs(rightEdge.x * padding);
        NSLog(@"_screenWidthExtentInWorld = %f", _screenWidthExtentInWorld);
        
        simd::float4 bottomEdge = [super.camera screenToWorld: {
                                    (float)(super.view.frame.size.width*0.5),
                                    (float)super.view.frame.size.height
                                  }];
        _screenHeightExtentInWorld = fabs(bottomEdge.y * padding);
        NSLog(@"_screenHeightExtentInWorld = %f", _screenHeightExtentInWorld);
        
        // create stacks
        _stacks = [[NSMutableArray alloc]init];
        _stackAnim = [[CardStackAnim alloc]initWithScreenWidth:_screenWidthExtentInWorld
                                                  screenHeight:_screenHeightExtentInWorld
                                                         tween:super.tween];
        
        // TEMP: 6 stacks for testing
        for(int i = 0; i < 6; ++i) {
            CardStack* stack = [[CardStack alloc]initWithDevice:device
                                                          layer:layer
                                      numInflightCommandBuffers:numInflightCommandBuffers
                                                        library:library];
            
            stack.x = i * _screenWidthExtentInWorld;
            [_stacks addObject:stack];
        }
        _selectedStackIndex = 0;
        self.centerStack.y = _stackAnim.selectedStackOffsetY;
        self.centerStack.z = _stackAnim.selectedStackOffsetZ;
        _stackState = StackState_Collapsed;
        
        // add gestures
        _tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        [super.view addGestureRecognizer:_tapGesture];
        _tapGesture.delegate = self;
        
        _panGesture = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(handlePan:)];
        _panGesture.maximumNumberOfTouches = 1;
        _panGesture.delegate = self;
        [super.view addGestureRecognizer:_panGesture];
        _pinchGesture = [[UIPinchGestureRecognizer alloc]initWithTarget:self action:@selector(handlePinch:)];
        [super.view addGestureRecognizer:_pinchGesture];
        _pinchPercentage = 0.0f;
        
        _panDuration = @0.35;
        
        MTLDepthStencilDescriptor* depthStencilDesc = [MTLDepthStencilDescriptor new];
        depthStencilDesc.depthCompareFunction = MTLCompareFunctionLess;
        depthStencilDesc.depthWriteEnabled = YES;
        _depthStencilState = [device newDepthStencilStateWithDescriptor:depthStencilDesc];
        
        
        MTLTextureDescriptor* msaaDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: layer.pixelFormat
                                                                                            width: layer.drawableSize.width
                                                                                           height: layer.drawableSize.height
                                                                                        mipmapped: NO];
        msaaDesc.textureType = MTLTextureType2DMultisample;
        msaaDesc.sampleCount = 4;
        
        _msaaTex = [device newTextureWithDescriptor: msaaDesc];
        
        _renderUniformsMap = [NSMapTable mapTableWithKeyOptions:NSMapTableStrongMemory valueOptions:NSMapTableStrongMemory];
        [_renderUniformsMap setObject:[device newBufferWithLength:sizeof(RenderUniform) * numInflightCommandBuffers options:0] forKey:_backgroundQuad];
        [_renderUniformsMap setObject:[device newBufferWithLength:sizeof(RenderUniform) * numInflightCommandBuffers options:0] forKey:_floorQuad1];
        [_renderUniformsMap setObject:[device newBufferWithLength:sizeof(RenderUniform) * numInflightCommandBuffers options:0] forKey:_floorQuad2];
        [_renderUniformsMap setObject:[device newBufferWithLength:sizeof(RenderUniform) * numInflightCommandBuffers options:0] forKey:_fullscreenQuad];
        for(CardStack* cs in _stacks) {
            for(Quad* q in cs.cards)
            [_renderUniformsMap setObject:[device newBufferWithLength:sizeof(RenderUniform) * numInflightCommandBuffers options:0] forKey:q];
        }
        
        _sunDataBuffer = [device newBufferWithLength:sizeof(MaterialSunData) * numInflightCommandBuffers options:0];
        
        _shadowUniformsMap = [NSMapTable mapTableWithKeyOptions:NSMapTableStrongMemory valueOptions:NSMapTableStrongMemory];
        [_shadowUniformsMap setObject:[device newBufferWithLength:sizeof(simd::float4x4) * numInflightCommandBuffers options:0] forKey:_backgroundQuad];
        
        // not used:
        [_shadowUniformsMap setObject:[device newBufferWithLength:sizeof(simd::float4x4) * numInflightCommandBuffers options:0] forKey:_floorQuad1];
        [_shadowUniformsMap setObject:[device newBufferWithLength:sizeof(simd::float4x4) * numInflightCommandBuffers options:0] forKey:_floorQuad2];

        for(CardStack* cs in _stacks) {
            for(Quad* q in cs.cards)
                [_shadowUniformsMap setObject:[device newBufferWithLength:sizeof(simd::float4x4) * numInflightCommandBuffers options:0] forKey:q];
        }
        
        // a MTLRenderPassDescriptor object represents the destination for the encoded rendering commands, which is a collection of attachments
        // the loadAction and storeAction properties of an attachment descriptor specify an action that is performed at either the start or end of a rendering pass
        // MTLLoadActionLoad, which preserves the existing contents of the texture.
        // MTLStoreActionStore, which saves the final results of the rendering pass into the attachment
        // to display rendered content, you have to set the CAMetalLayer drawable as a color attachment
        _renderPassDesc = [MTLRenderPassDescriptor renderPassDescriptor];
        
        // When multisampling, perform rendering to _msaaTex, then resolve
        // to 'texture' at the end of the scene
        _renderPassDesc.colorAttachments[0].texture = _msaaTex;
        _renderPassDesc.colorAttachments[0].storeAction = MTLStoreActionMultisampleResolve;
        _renderPassDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
        _renderPassDesc.colorAttachments[0].clearColor = MTLClearColorMake(0.3, 0.3, 0.3, 1.0);
     
        MTLTextureDescriptor* shadowTextureDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float
                                                                                                     width:4096//layer.drawableSize.width
                                                                                                    height:4096//layer.drawableSize.height
                                                                                                 mipmapped:NO];
        _shadow_texture = [device newTextureWithDescriptor: shadowTextureDesc];
        
        _shadowRenderPassDescriptor = [MTLRenderPassDescriptor new];
        MTLRenderPassDepthAttachmentDescriptor* shadow_attachment = _shadowRenderPassDescriptor.depthAttachment;
        shadow_attachment.texture = _shadow_texture;
        shadow_attachment.loadAction = MTLLoadActionClear;
        shadow_attachment.storeAction = MTLStoreActionStore;
        shadow_attachment.clearDepth = 1.0;
        
        MTLRenderPipelineDescriptor* desc = [MTLRenderPipelineDescriptor new];
        NSError *err = nil;
        desc.label = @"Shadow Render";
        desc.vertexFunction = [library newFunctionWithName:@"zOnly"];
        desc.fragmentFunction = nil;
        desc.depthAttachmentPixelFormat = _shadow_texture.pixelFormat;
        _shadow_render_pipeline = [device newRenderPipelineStateWithDescriptor: desc error: &err];
        
        MTLDepthStencilDescriptor* stencilDesc = [[MTLDepthStencilDescriptor alloc] init];
        stencilDesc.depthWriteEnabled = YES;
        stencilDesc.depthCompareFunction = MTLCompareFunctionLessEqual;
        _shadowDepthStencilState = [device newDepthStencilStateWithDescriptor:stencilDesc];
        
        _sunColor = { 1.0, 0.875, 0.75 };
        
        MTLRenderPipelineDescriptor *desc2 = [MTLRenderPipelineDescriptor new];
        NSError *err2 = nil;
     
        desc2.label = @"GBuffer Render";
        desc2.vertexFunction = [library newFunctionWithName:@"gBufferVert"];
        desc2.fragmentFunction = [library newFunctionWithName:@"gBufferFrag"];
        desc2.colorAttachments[0].pixelFormat = layer.pixelFormat;
        
        // enable alpha blending
        desc2.colorAttachments[0].blendingEnabled = YES;
        // existing defaults
        desc2.colorAttachments[0].writeMask = MTLColorWriteMaskAll;
        desc2.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
        desc2.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
        // 1 minus source alpha
        desc2.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
        desc2.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        desc2.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        desc2.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        
        // specifies the number of samples in each pixel, must match msaaTex in Renderer
        desc2.sampleCount = 4;
        
        _gbuffer_render_pipeline = [device newRenderPipelineStateWithDescriptor: desc2 error: &err2];
        NSAssert(!(err2 != nil), err2.description);
    }
    
    return self;
}

#pragma mark -

- (float)pinchPercentage {
    return _pinchPercentage;
}

- (void)setPinchPercentage:(float)value {
    _pinchPercentage = value;
    
    ScrubDir dir = (_stackState == StackState_Collapsed) ? ScrubDirOut : ScrubDirIn;
    [_stackAnim scrubLeftStack:self.leftStack direction:dir percentage:_pinchPercentage];
    [_stackAnim scrubRightStack:self.rightStack direction:dir percentage:_pinchPercentage];
    [_stackAnim scrubCenterStack:self.centerStack direction:dir percentage:_pinchPercentage camera:super.camera];
}

#pragma mark -

- (void)handlePinch:(UIPinchGestureRecognizer*)sender {
    
    static double percentage;
    
    // the dist between 2 fingers (sender.scale) always starts at 1 and moves in or out
    switch(sender.state) {

        case UIGestureRecognizerStateBegan: {
            
            _disableDepthStencil = YES;
            
            if(_stackState == StackState_Collapsed) {
                [_stackAnim prepareAnimFor:self.centerStack
                                       leftStack:self.leftStack
                                      rightStack:self.rightStack];
                _pinchPercentage = 0;
            }
            else {
                _pinchPercentage = 1;
            }
            
            _tapGesture.enabled = NO;
            _panGesture.enabled = NO;
        } break;
            
        case UIGestureRecognizerStateChanged: {
            if(super.fullyUpdated) { // keep input in sync with render
                percentage = (_stackState == StackState_Collapsed) ? fmax(0, fmin(sender.scale, 2) - 1) : fmin(sender.scale, 1);
                [super.tween object:self caller:self
                             params:@{
                                 kDuration:@0.1
                                ,kEasing:CubicEaseOut
                                ,kPinchPercentage:@(percentage)
                             }
                         completion:nil];
            }
        } break;
            
        case UIGestureRecognizerStateEnded: {
            
            if(fabs(sender.velocity) > 3) { // arbitrary velocity threshold
                _stackState = (sender.velocity > 0) ? StackState_Expanded : StackState_Collapsed;
                [super.tween object:self caller:self
                             params:@{
                                 kDuration:@0.25
                                ,kEasing:CubicEaseOut
                                ,kPinchPercentage:(sender.velocity > 0) ? @1 : @0
                             }
                         completion:^(id self) {
                             _tapGesture.enabled = YES;
                             _panGesture.enabled = YES;
                             _disableDepthStencil = NO;
                             
                         }];
            } else { // snap to nearest value
                _stackState = (percentage >= 0.5f) ? StackState_Expanded : StackState_Collapsed;
                [super.tween object:self caller:self
                             params:@{
                                 kDuration:@0.25
                                ,kEasing:CubicEaseOut
                                ,kPinchPercentage:@(round(percentage))
                             }
                         completion:^(id self) {
                             _tapGesture.enabled = YES;
                             _panGesture.enabled = YES;
                             _disableDepthStencil = NO;
                             
                         }];
            }
        } break;
            
        default: break; // TODO: other states
            
    } // end switch sender.state
}

#pragma mark -

- (void)handleTap:(UITapGestureRecognizer*)sender {
    
    // TODO: selected quad touch code here
    // TODO: or tap edge stack to trigger scroll next
    
    if(_stackState == StackState_Collapsed) {
        _pinchGesture.enabled = NO;
        _tapGesture.enabled = NO;
        _panGesture.enabled = NO;
        _disableDepthStencil = YES;
        _stackState = StackState_Expanded;
        
        [_stackAnim prepareAnimFor:self.centerStack leftStack:self.leftStack rightStack:self.rightStack];
        _pinchPercentage = 0;
        
        // use the same mechanic as pinch to scrub through the card expand anim
        [super.tween object:self caller:self
                     params:@{
                         kDuration:@0.65
                        ,kEasing:CubicEaseOut
                        ,kPinchPercentage:@1
                     }
                 completion:^(id self) {
                     _pinchGesture.enabled = YES;
                     _tapGesture.enabled = YES;
                     _disableDepthStencil = NO;
                 }];
    }
}

#pragma mark -

- (void)handlePan:(UIPanGestureRecognizer*)sender {
    
    static PanDir panDir;
    
    switch(sender.state) {
            
        case UIGestureRecognizerStateBegan: {
            
            _tapGesture.enabled = NO;
            _pinchGesture.enabled = NO;
            
            CGPoint velocity = [sender velocityInView:super.view];
            panDir = (fabs(velocity.y) > fabs(velocity.x)) ? PanDir_Vertical : PanDir_Horizontal;
            if(panDir == PanDir_Horizontal) {
                [_stackAnim centerStackJump:self.centerStack jumpDir:StackJump_Backward completion:nil];
            }
        } break;
            
        case UIGestureRecognizerStateChanged: {
            if(panDir == PanDir_Horizontal) {
                CGPoint deltaLocation = [sender translationInView:super.view];
                
                // scale input down
                float x = (deltaLocation.x / super.camera.z);
                
                // pan camera left/right
                [super.tween object:super.camera caller:self
                             params:@{
                                 kDuration:_panDuration
                                ,kTweenX:@(super.camera.x + x)
                                ,kEasing:Linear
                             }
                         completion:nil];
            }
            // reset delta
            [_panGesture setTranslation:CGPointZero inView:super.view];
        } break;
            
        case UIGestureRecognizerStateEnded: {
            CGPoint velocity = [sender velocityInView:super.view];
            
            // TODO: check/fix retain cycles
            
            if(panDir == PanDir_Vertical) {
                
                _panGesture.enabled = NO; // prevent further swipes until anim is done
                
                if(velocity.y > 0) { // swipe down
                    [_stackAnim flipCenterStackCard:self.centerStack flipDir:FlipDir_Down completion:^{
                        _panGesture.enabled = YES;
                        _tapGesture.enabled = YES;
                        _pinchGesture.enabled = YES;
                    }];
                }
                else { // swipe up
                    [_stackAnim flipCenterStackCard:self.centerStack flipDir:FlipDir_Up completion:^{
                        _panGesture.enabled = YES;
                        _tapGesture.enabled = YES;
                        _pinchGesture.enabled = YES;
                    }];
                }
            }
            else {
                // round x to the nearest snap point
                // for example:
                //      (7.5 / 5) = round(1.5) = 2 * 5 = 10
                float x = roundf(super.camera.x / _screenWidthExtentInWorld) * _screenWidthExtentInWorld;
                
                // a fast flick beyond threshold jumps to stack item beyond currently snapped x
                // trying to scroll faster (by increasing the amount of x offset) makes it harder to single swipe to adjacent items
                // this setting has a really nice feel to it
                if(velocity.x > (super.view.frame.size.width)) {
                    x -= _screenWidthExtentInWorld;
                }
                else if(velocity.x < -(super.view.frame.size.width)) {
                    x += _screenWidthExtentInWorld;
                }
                
                BOOL wasClamped = NO;
                // clamp x if it goes beyond ends of stack list
                if(x < 0) {
                    x = 0;
                    wasClamped = YES;
                }
                else if(x > ((_stacks.count-1) * _screenWidthExtentInWorld)) {
                    x = (_stacks.count - 1) * _screenWidthExtentInWorld;
                    wasClamped = YES;
                }

                // pan camera
                [super.tween object:super.camera caller:self
                             params:@{
                                 kDuration:_panDuration
                                ,kTweenX:@(x)
                                 ,kEasing:(wasClamped == YES) ? BackEaseOut : CubicEaseOut
                             }
                         completion:nil];
                
                // update selected stack index
                _selectedStackIndex = (int)roundf(x / _screenWidthExtentInWorld);
                
                _panGesture.enabled = NO;
                [_stackAnim centerStackJump:self.centerStack jumpDir:StackJump_Forward completion:^{
                    _panGesture.enabled = YES;
                    _tapGesture.enabled = YES;
                    _pinchGesture.enabled = YES;
                }];
            }
        } break;
            
        // TODO: handle other enumeration values for uigesturerecognizer
        default: break;
            
    } // end switch
}

#pragma mark -

- (CardStack*)leftStack {
    if((_selectedStackIndex - 1) >= 0) {
        return [_stacks objectAtIndex:_selectedStackIndex-1];
    }
    return nil;
}

- (CardStack*)rightStack {
    if((_selectedStackIndex + 1) < _stacks.count) {
        return [_stacks objectAtIndex:_selectedStackIndex+1];
    }
    return nil;
}

- (CardStack*)centerStack {
    return [_stacks objectAtIndex:_selectedStackIndex];
}

#pragma mark -

static float so = 25.f;
- (simd::float4x4)shadowMatrixForTime:(CFTimeInterval) time
{
    simd::float3 sunLocation = _lightPos;
    
    simd::float4x4 cameraMatrix = AAPL::Math::lookAt(sunLocation, (simd::float3){super.camera.x, 0.0f, 0.0f}, (simd::float3){0.0f, 1.0f, 0.0f});
    
                                          // ortho2d_oc(left,right,bottom,top,near,far)
    simd::float4x4 orthoMatrix = AAPL::Math::ortho2d_oc(-so/2, so/2, -so/2, so/2,
                                      0.01f,
                                      so);
    
    return orthoMatrix * cameraMatrix;
}

// TODO: throw in utils
inline double mapRange(double inMin, double inMax, double outMin, double outMax, double value) {
    return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
}

- (void)update:(CFTimeInterval)deltaTime inflightBufferIndex:(unsigned int)inflightBufferIndex {
    
    // update tween and camera (will in turn update any properties on objects being animated)
    [super update:deltaTime inflightBufferIndex:inflightBufferIndex];
    
    _floorQuad1.x = super.camera.x;
    _floorQuad1.z = super.camera.y + 0.05;
    
    _floorQuad2.x = super.camera.x;
    _floorQuad2.y = super.camera.y-5.3;
    
    _lightPos.x = super.camera.x;
    
    // TODO: adjust position of sun in response to tilt would be cool
    
    simd::float4x4 shadowMatrix = [self shadowMatrixForTime:0];
    simd::float4x4 depthMvp;
    
    uint8_t* sunContents = (uint8_t*)[_sunDataBuffer contents] + sizeof(MaterialSunData) * inflightBufferIndex;
    simd::float3x3 normalMat = { super.camera.view.columns[0].xyz, super.camera.view.columns[1].xyz, super.camera.view.columns[2].xyz };
    
    MaterialSunData sunData;
    simd::float3 direction = {0, _lightPos.y, _lightPos.z};
    direction = simd::normalize(direction);
    sunData.sunDirection = {direction.x, direction.y, direction.z, 0.0f};
    sunData.sunColor = {1.0f, 0.875f, 0.75f, 1.0f};
    sunData.sunColor = simd::normalize(sunData.sunColor);
    simd::float3 fuckMe = normalMat * sunData.sunDirection.xyz;
    sunData.sunDirection = {fuckMe.x, fuckMe.y, fuckMe.z, 1};
    
    memcpy(sunContents, &sunData, sizeof(MaterialSunData));
    
    RenderUniform uni;
    
    simd::float4x4 m;
    
    id<MTLBuffer> buffer = [_renderUniformsMap objectForKey:_backgroundQuad];
    uni.mvp = matrix_identity_float4x4;
    uint8_t* contents = (uint8_t*)[buffer contents] + sizeof(RenderUniform) * inflightBufferIndex;
    memcpy(contents, &uni, sizeof(RenderUniform));
    
    simd::float4x4 translateMat = AAPL::Math::translate(0.5f, 0.5f, 0.0f);
    simd::float4x4 scaleMat = AAPL::Math::scale(0.5, -0.5, 1.0f);
    
    // TODO: clean up
    // TODO: could treat them all as Primitive*
    if(self.leftStack != nil) {
        for(Quad* q in self.leftStack.cards) {
            m = q.model;
            
            depthMvp = shadowMatrix * m;
            buffer = [_shadowUniformsMap objectForKey:q];
            contents = (uint8_t*)[buffer contents] + sizeof(simd::float4x4) * inflightBufferIndex;
            // TODO: &(orthoMatrix * cameraMatrix * m)
            memcpy(contents, &depthMvp, sizeof(simd::float4x4));
            
            simd::float4x4 mv = super.camera.view * m;
            simd::float3x3 normalMatrix = { mv.columns[0].xyz, mv.columns[1].xyz, mv.columns[2].xyz };
            normalMatrix = matrix_transpose(matrix_invert(normalMatrix));
            uni.normalMatrix = normalMatrix;
            
            uni.mvp = super.camera.projection * super.camera.view * m;
            
            uni.shadowMatrix = translateMat * scaleMat * depthMvp;
            
            uni.alphaModifier = q.alphaModifier;
            
            buffer = [_renderUniformsMap objectForKey:q];
            contents = (uint8_t*)[buffer contents] + sizeof(RenderUniform) * inflightBufferIndex;
            memcpy(contents, &uni, sizeof(RenderUniform));
        }
    }
    if(self.centerStack != nil) {
        for(Quad* q in self.centerStack.cards) {
            m = q.model;
            
            depthMvp = shadowMatrix * m;
            buffer = [_shadowUniformsMap objectForKey:q];
            contents = (uint8_t*)[buffer contents] + sizeof(simd::float4x4) * inflightBufferIndex;
            memcpy(contents, &depthMvp, sizeof(simd::float4x4));
            
            simd::float4x4 mv = super.camera.view * m;
            simd::float3x3 normalMatrix = { mv.columns[0].xyz, mv.columns[1].xyz, mv.columns[2].xyz };
            normalMatrix = matrix_transpose(matrix_invert(normalMatrix));
            uni.normalMatrix = normalMatrix;
            
            uni.mvp = super.camera.projection * super.camera.view * m;
            
            uni.shadowMatrix = translateMat * scaleMat * depthMvp;

            uni.alphaModifier = q.alphaModifier;
            
            buffer = [_renderUniformsMap objectForKey:q];
            contents = (uint8_t*)[buffer contents] + sizeof(RenderUniform) * inflightBufferIndex;
            memcpy(contents, &uni, sizeof(RenderUniform));
        }
    }
    if(self.rightStack != nil) {
        for(Quad* q in self.rightStack.cards) {
            m = q.model;
            
            depthMvp = shadowMatrix * m;
            buffer = [_shadowUniformsMap objectForKey:q];
            contents = (uint8_t*)[buffer contents] + sizeof(simd::float4x4) * inflightBufferIndex;
            memcpy(contents, &depthMvp, sizeof(simd::float4x4));
            
            simd::float4x4 mv = super.camera.view * m;
            simd::float3x3 normalMatrix = { mv.columns[0].xyz, mv.columns[1].xyz, mv.columns[2].xyz };
            normalMatrix = matrix_transpose(matrix_invert(normalMatrix));
            uni.normalMatrix = normalMatrix;
            
            uni.mvp = super.camera.projection * super.camera.view * m;
            
            uni.shadowMatrix = translateMat * scaleMat * depthMvp;
            
            uni.alphaModifier = q.alphaModifier;
            
            buffer = [_renderUniformsMap objectForKey:q];
            contents = (uint8_t*)[buffer contents] + sizeof(RenderUniform) * inflightBufferIndex;
            memcpy(contents, &uni, sizeof(RenderUniform));
        }
    }
    
    m = _floorQuad1.model;
    buffer = [_shadowUniformsMap objectForKey:_floorQuad1];
    contents = (uint8_t*)[buffer contents] + sizeof(simd::float4x4) * inflightBufferIndex;
    depthMvp = shadowMatrix * m;
    memcpy(contents, &depthMvp, sizeof(simd::float4x4));
    
    simd::float4x4 mv = super.camera.view * m;
    simd::float3x3 normalMatrix = { mv.columns[0].xyz, mv.columns[1].xyz, mv.columns[2].xyz };
    normalMatrix = matrix_transpose(matrix_invert(normalMatrix));
    uni.normalMatrix = normalMatrix;
    
    uni.mvp = super.camera.projection * super.camera.view * m;
    uni.shadowMatrix = translateMat * scaleMat * depthMvp;
    uni.alphaModifier = _floorQuad1.alphaModifier;
    
    buffer = [_renderUniformsMap objectForKey:_floorQuad1];
    contents = (uint8_t*)[buffer contents] + sizeof(RenderUniform) * inflightBufferIndex;
    memcpy(contents, &uni, sizeof(RenderUniform));
    
    m = _floorQuad2.model;
    buffer = [_shadowUniformsMap objectForKey:_floorQuad2];
    contents = (uint8_t*)[buffer contents] + sizeof(simd::float4x4) * inflightBufferIndex;
    depthMvp = shadowMatrix * m;
    memcpy(contents, &depthMvp, sizeof(simd::float4x4));
    
    mv = super.camera.view * m;
    normalMatrix = { mv.columns[0].xyz, mv.columns[1].xyz, mv.columns[2].xyz };
    normalMatrix = matrix_transpose(matrix_invert(normalMatrix));
    uni.normalMatrix = normalMatrix;
    
    uni.mvp = super.camera.projection * super.camera.view * m;
    uni.shadowMatrix = translateMat * scaleMat * depthMvp;
    uni.alphaModifier = _floorQuad2.alphaModifier;
    
    buffer = [_renderUniformsMap objectForKey:_floorQuad2];
    contents = (uint8_t*)[buffer contents] + sizeof(RenderUniform) * inflightBufferIndex;
    memcpy(contents, &uni, sizeof(RenderUniform));
}

- (void)depthEncode:(id<MTLRenderCommandEncoder>)depthEncoder inflightBufferIndex:(uint)inflightBufferIndex cardStack:(CardStack*)cardStack {
    if(cardStack == nil) {
        return;
    }
    
    // _floorQuad1
    [depthEncoder setVertexBuffer:_floorQuad1.vertexBuffer offset:0 atIndex:VERTEX_BUFFER_INDEX];
    [depthEncoder setVertexBuffer:[_shadowUniformsMap objectForKey:_floorQuad1]
                           offset:sizeof(simd::float4x4) * inflightBufferIndex atIndex:UNIFORM_BUFFER_INDEX];
    [depthEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:_floorQuad1.numVertices];
    
    // _floorQuad2
    [depthEncoder setVertexBuffer:_floorQuad2.vertexBuffer offset:0 atIndex:VERTEX_BUFFER_INDEX];
    [depthEncoder setVertexBuffer:[_shadowUniformsMap objectForKey:_floorQuad2]
                           offset:sizeof(simd::float4x4) * inflightBufferIndex atIndex:UNIFORM_BUFFER_INDEX];
    [depthEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:_floorQuad2.numVertices];
    
    for(Quad* q in cardStack.cards) {
        [depthEncoder setVertexBuffer:q.vertexBuffer offset:0 atIndex:VERTEX_BUFFER_INDEX];
        [depthEncoder setVertexBuffer:[_shadowUniformsMap objectForKey:q]
                               offset:sizeof(simd::float4x4) * inflightBufferIndex atIndex:UNIFORM_BUFFER_INDEX];
        [depthEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:q.numVertices];
    }
}

- (void)renderEncode:(id<MTLRenderCommandEncoder>)renderEncoder inflightBufferIndex:(uint)inflightBufferIndex cardStack:(CardStack*)cardStack {
    if(cardStack == nil) {
        return;
    }
    for(Quad* q in cardStack.cards) {
        [renderEncoder setFragmentBuffer: _sunDataBuffer offset:sizeof(MaterialSunData) * inflightBufferIndex atIndex: 2];
        
        [renderEncoder setVertexBuffer:q.vertexBuffer offset:0 atIndex:VERTEX_BUFFER_INDEX];
        [renderEncoder setVertexBuffer:q.colorBuffer offset:0 atIndex:COLOR_BUFFER_INDEX];
        [renderEncoder setVertexBuffer:[_renderUniformsMap objectForKey:q]
                                offset:sizeof(RenderUniform) * inflightBufferIndex atIndex:UNIFORM_BUFFER_INDEX];
        [renderEncoder setVertexBuffer:q.texelBuffer offset:0 atIndex:TEXEL_BUFFER_INDEX];
        [renderEncoder setFragmentTexture: _shadow_texture atIndex: 3];

        [renderEncoder setFragmentTexture:q.diffuseTexture atIndex:/*DIFFUSE_TEXTURE_INDEX*/1];
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:q.numVertices];
    }
}

- (void)renderGBuffer:(id<MTLRenderCommandEncoder>)renderEncoder inflightBufferIndex:(uint)inflightBufferIndex {
 
    [renderEncoder setRenderPipelineState: _gbuffer_render_pipeline];
    [renderEncoder setDepthStencilState:_depthStencilState];
  
    // _floorQuad1
    [renderEncoder setVertexBuffer:_floorQuad1.vertexBuffer offset:0 atIndex:VERTEX_BUFFER_INDEX];
    [renderEncoder setVertexBuffer:_floorQuad1.colorBuffer offset:0 atIndex:COLOR_BUFFER_INDEX];
    [renderEncoder setVertexBuffer:[_renderUniformsMap objectForKey:_floorQuad1]
                            offset:sizeof(RenderUniform) * inflightBufferIndex atIndex:UNIFORM_BUFFER_INDEX];
    [renderEncoder setVertexBuffer:_floorQuad1.texelBuffer offset:0 atIndex:TEXEL_BUFFER_INDEX];
    [renderEncoder setFragmentTexture: _shadow_texture atIndex: 3];
    [renderEncoder setFragmentTexture:_floorQuad1.diffuseTexture atIndex:1];
    [renderEncoder setFragmentBuffer: _sunDataBuffer offset:sizeof(MaterialSunData) * inflightBufferIndex atIndex: 2];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:_floorQuad1.numVertices];

    // _floorQuad2
    [renderEncoder setVertexBuffer:_floorQuad2.vertexBuffer offset:0 atIndex:VERTEX_BUFFER_INDEX];
    [renderEncoder setVertexBuffer:_floorQuad2.colorBuffer offset:0 atIndex:COLOR_BUFFER_INDEX];
    [renderEncoder setVertexBuffer:[_renderUniformsMap objectForKey:_floorQuad2]
                            offset:sizeof(RenderUniform) * inflightBufferIndex atIndex:UNIFORM_BUFFER_INDEX];
    [renderEncoder setVertexBuffer:_floorQuad2.texelBuffer offset:0 atIndex:TEXEL_BUFFER_INDEX];
    [renderEncoder setFragmentTexture: _shadow_texture atIndex: 3];
    [renderEncoder setFragmentTexture:_floorQuad2.diffuseTexture atIndex:1]; // TODO: should be managed by resource pool?
    [renderEncoder setFragmentBuffer: _sunDataBuffer offset:sizeof(MaterialSunData) * inflightBufferIndex atIndex: 2];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:_floorQuad2.numVertices];

    [self renderEncode:renderEncoder inflightBufferIndex:inflightBufferIndex cardStack:self.leftStack];
    [self renderEncode:renderEncoder inflightBufferIndex:inflightBufferIndex cardStack:self.centerStack];
    [self renderEncode:renderEncoder inflightBufferIndex:inflightBufferIndex cardStack:self.rightStack];
    
    [renderEncoder popDebugGroup];
}

- (void)encode:(id<MTLCommandBuffer>)commandBuffer inflightBufferIndex:(unsigned int)inflightBufferIndex drawableTexture:(id<MTLTexture>)drawableTexture {
    
    _renderPassDesc.colorAttachments[0].resolveTexture = drawableTexture;
    
    id<MTLRenderCommandEncoder> depthEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_shadowRenderPassDescriptor];
    [depthEncoder pushDebugGroup:@"shadow buffer pass"];
    depthEncoder.label = @"shadow buffer";
    [depthEncoder setRenderPipelineState: _shadow_render_pipeline];
    [depthEncoder setDepthStencilState: _shadowDepthStencilState];
    [depthEncoder setCullMode: MTLCullModeFront];
    [depthEncoder setDepthBias: 0.01 slopeScale: 1.0f clamp: 0.01];
    
    [self depthEncode:depthEncoder inflightBufferIndex:inflightBufferIndex cardStack:self.leftStack];
    [self depthEncode:depthEncoder inflightBufferIndex:inflightBufferIndex cardStack:self.centerStack];
    [self depthEncode:depthEncoder inflightBufferIndex:inflightBufferIndex cardStack:self.rightStack];
    
    [depthEncoder popDebugGroup];
    [depthEncoder endEncoding];
    
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_renderPassDesc];
    [renderEncoder pushDebugGroup:@"g-buffer pass"];
    renderEncoder.label = @"g-buffer";
    
    [self renderGBuffer:renderEncoder inflightBufferIndex:inflightBufferIndex];
    
    // end sun
    [renderEncoder popDebugGroup];

    // it's possible to pan-hold and see up to 2 more stacks left/right
    // TODO: frustum culling
    
    [renderEncoder popDebugGroup];
    [renderEncoder endEncoding];
}

@end
