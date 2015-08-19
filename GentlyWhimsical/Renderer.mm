//
//  Renderer.mm
//  gently whimsical
//
//  Created by Edward Oakenfold on 2015-04-23.
//  Copyright (c) 2015 conceptual inertia. All rights reserved.
//

// @import not required because project build settings default to:
//  - enable modules
//  - link frameworks automatically
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import "GalleryScene.h"
#import "CanvasScene.h"
#import "Renderer.h"

// if your game is currently CPU bound pushing the draw call limit due to the overhead required by OpenGL ES state validation, metal is the solution to move beyond that

// when a metal app is running from Xcode, the default scheme settings reduce performance
// Xcode detects whether the metal API is used in the source code and automatically enables the GPU Frame Capture and metal API validation settings
// when GPU Frame Capture is enabled, the debug layer is activated
// when Metal API Validation is enabled, each call is validated, which affects performance further
// for both settings, CPU performance is more affected than GPU performance
// unless you disable these settings, app performance may noticeably improve when the app is run outside of Xcode
// to disable, edit scheme -> run -> options
//  - gpu frame capture
//  - metal api validation
//  - enable user interface debugging

// 4 color attachments on A7, 8 color attachments for the A8
// it's possible to test for the GPU family using MTLFeatureSet:
//      A7 = MTLFeatureSet_iOS_GPUFamily1_v1
//      A8 = MTLFeatureSet_iOS_GPUFamily2_v1
// maximum MTLTextureDescriptor height and width is 4096

// the following objects are *not* transient
// reuse these objects in performance sensitive code, and avoid creating them repeatedly
//  - Command queues
//  - Data buffers
//  - Textures
//  - Sampler states
//  - Libraries
//  - Compute states
//  - Render pipeline states
//  - Depth/stencil states

// there are 2 ways to pass input to your vertex shader
// - pass a pointer to a struct, you declare, and then you use your vertex ID to index into it
//   which means you know the data layout of your vertex data in the shader
// - if you want to decouple it, use a vertex descriptor
//   the vertex descriptor tells metal how the vertices are laid out in memory
//   use a vertex descriptor for interleaved data

// --------------------------------
// lines of code:
//  find . -type f \( -name "*.h" -or -name "*.m" -or -name "*.mm" -or -name "*.metal" \) -print0 | xargs -0 wc -l

// show build time:
//  defaults write com.apple.dt.Xcode ShowBuildOperationDuration YES

// search codebase:
//  git rev-list --all | xargs git grep <expression>

// ipad air 2 tech specs:
//  https://www.apple.com/ca/ipad-air-2/specs/
//  2048x1536 pixel resolution at 264 ppi
// without mipmaps:
//  1024x1024 * 32-bits or 4-bytes = 4MB (1MB = 1048576 bytes)
//  2048x2048 = 16MB
//  4096x4096 = 64MB

// for a pool of 3 buffers
const uint32_t kNumInFlightCommandBuffers = 3;

@interface Renderer() {
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;
    id<MTLLibrary> _library;
    
    // both the CPU and GPU can access the underlying storage for a MTLResource object
    // however, the GPU operates asynchronously from the host CPU so we need a synchronization primitive
    dispatch_semaphore_t _inflightSemaphore;
    unsigned int _inflightBufferIndex;
    
    Scene* _scene;
}
@end

@implementation Renderer

#pragma mark -

- (instancetype)init {
    self = [super init];
    
    if(self) {
        _device = MTLCreateSystemDefaultDevice();
        
        _metalLayer = [CAMetalLayer layer];
        // the lowest address contains blue
        _metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm; //MTLPixelFormatBGRA8Unorm_sRGB;
        _metalLayer.device = _device;
        _metalLayer.opaque = YES;
        _metalLayer.backgroundColor = nil;
        
        // the framebufferOnly property declares whether the texture can be used only as an attachment (YES) or whether it can also be used for texture sampling and pixel read/write operations (NO)
        // if YES, the layer object can optimize the texture for display
        //_metalLayer.framebufferOnly = YES; // try YES first. i'm not sure i fully understand why NO
        
        // a command queue accepts an ordered list of command buffers that the GPU will execute
        // all command buffers sent to a single queue are guaranteed to execute in the order in which the command buffers were enqueued
        _commandQueue = [_device newCommandQueue];
        
        // newDefaultLibrary retrieves a library built for the main bundle that contains all shader and compute functions in an app’s Xcode project
        _library = [_device newDefaultLibrary];
        
        // _projectionMatrix created on updateLayerSize because it needs to calculate the aspect ratio using view bounds
        
        _inflightSemaphore = dispatch_semaphore_create(kNumInFlightCommandBuffers);
        _inflightBufferIndex = 0;
    }
    
    return self;
}

#pragma mark -

// bounds defines drawable area relative to frame, allowing you to draw outside the frame but is usually 1:1
- (void)updateLayerSize:(CGRect)frame bounds:(CGRect)bounds contentScaleFactor:(CGFloat)contentScaleFactor {
    _metalLayer.frame = frame;
    
    CGFloat drawableWidth = bounds.size.width * contentScaleFactor;
    CGFloat drawableHeight = bounds.size.height * contentScaleFactor;
    _metalLayer.contentsScale = contentScaleFactor;
    _metalLayer.drawableSize = CGSizeMake(drawableWidth, drawableHeight);
    
    _scene = [[GalleryScene alloc]initWithDevice:_device
                                    layer:_metalLayer
                numInflightCommandBuffers:kNumInFlightCommandBuffers
                                  library:_library];
    
    // TODO: removeFromSuperview on scene transition
    _rootView = _scene.view;
}

#pragma mark -

- (void)frameUpdate:(CFTimeInterval)deltaTime {
    
    // avoid race conditions writing to shared (buffer) memory during CPU-write and GPU-read
    // shared memory has no synchronization by default
    // wait for GPU to finish executing one of the command buffers
    // each time you wait on the semaphore it decrements the counter by 1
    dispatch_semaphore_wait(_inflightSemaphore, DISPATCH_TIME_FOREVER);
    
    [_scene update:deltaTime inflightBufferIndex:_inflightBufferIndex];
    
    // wait for next renderable target, potentially blocking if no more available textures in swap chain if you're GPU bound
    // calling the nextDrawable method of CAMetalLayer blocks its CPU thread until the method is completed
    // do as much CPU work as possible before referencing next drawable
    __block id<CAMetalDrawable> frameBuffer = [_metalLayer nextDrawable];
    
    // command queue -> command buffer -> encoder (render, compute, or blit)
    // at any point in time, only a single command encoder can be active and append commands into a command buffer
    // command buffer and command encoder objects are transient and designed for a single use
    // they are inexpensive to allocate and deallocate, so their creation methods return autoreleased objects
    // a command buffer stores encoded commands until the buffer is committed for execution by the GPU
    // in a typical app, an entire frame of rendering is encoded into a single command buffer, even if rendering that frame involves multiple rendering passes, compute processing functions, or blit operations
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    
    // encode GPU commands and state for a single render pass
    // while a command encoder is active, it has the exclusive right to append commands to the command buffer
    // render process:
    //  - set buffer and texture objects, that contain vertex, fragment, or texture image data
    //  - set MTLRenderPipelineState object that contains compiled render state for vertex and fragment shaders
    //  - set fixed-function state, including viewport, triangle fill mode, scissor rectangle, depth and stencil tests
    //  - draw primitives
    
    [_scene encode:commandBuffer inflightBufferIndex:_inflightBufferIndex drawableTexture:frameBuffer.texture];
    
    // presentDrawable is a special case of completed handler
    [commandBuffer presentDrawable:frameBuffer];
    
    __block dispatch_semaphore_t block_sema = _inflightSemaphore;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        
        [_scene didRender];
        // GPU has completed rendering the frame and is done using the contents of any buffers previously encoded on the CPU for that frame
        // signal the semaphore and allow the CPU to proceed and construct the next frame
        dispatch_semaphore_signal(block_sema);
    }];
    
    // match semaphore frame index to ensure writing occurs at correct offset in buffers
    _inflightBufferIndex = (_inflightBufferIndex + 1) % kNumInFlightCommandBuffers;
    
    [commandBuffer commit];
}

@end
