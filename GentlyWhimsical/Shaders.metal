//
//  Shaders.metal
//  gently whimsical
//
//  Created by Edward Oakenfold on 2015-05-06.
//  Copyright (c) 2015 conceptual inertia. All rights reserved.
//

#include <metal_stdlib>
#include "SharedStruct.h"

using namespace metal;

// normalized device coordinates (ndc):
// - metal defines ndc system as a 2x2x1 cube with its center at (0, 0, 0.5)
// - the left and bottom for x and y, respectively, of the ndc system are specified as -1
// - the right and top for x and y, respectively, of the ndc system are specified as +1
// - the viewport specifies the transformation from ndc to the window coordinates
// - the viewport is a 3D transformation specified by setViewport

// packing:
// - if most computations happen on GPU, use packed format
// - if most computations happen on CPU, let the compiler insert padding
// - better perf on CPU when types are aligned
// - CPU prefers aligned vector types
//      float4 = 16 byte alignment
//      float2 = 8
//      float  = 4

// address space qualifiers:
// - if multiple instances of a vertex/fragment shader are accessing the buffer using an index such as the vertex ID, fragment coordinate, or the thread position in grid, use the device address space
// - if multiple instances of a vertex/fragment shader are accessing the same location in the buffer (like a MVP matrix), use the constant address space
// - when using constant, pass by ref and metal will prefetch data as an optimization
// - metal always allocates texture objects from the device address space, you don’t need a device address qualifier to access texture types

// precision:
// - on A7, the gains from half precision for shader math are primarily in power consumption
// - using half for interpolators can make a huge difference in very high geometry scenes, as the precision of your interpolated values directly impacts amount of data read/written during the tiling process (which happens after vertex shading)
// - on A8, you are more likely to see a performance benifit for half precision math, but it still won't show up in all shaders, and the power benifits remain substantial

//----------------------------------------------------------------

vertex float4 zOnly(device float4* vertices      [[ buffer(VERTEX_BUFFER_INDEX)  ]],
                    constant float4x4& mvp  [[ buffer(UNIFORM_BUFFER_INDEX) ]],
                    uint vid                     [[vertex_id]]) {
    return mvp * vertices[vid];
}

//----------------------------------------------------------------

vertex Vertex_Col vertCol(device float4* vertices     [[ buffer(VERTEX_BUFFER_INDEX)  ]],
                          device float4* colors       [[ buffer(COLOR_BUFFER_INDEX)   ]],
                          constant RenderUniform& uni [[ buffer(UNIFORM_BUFFER_INDEX) ]],
                          uint vid                    [[ vertex_id                    ]]) {
    Vertex_Col vert;
    vert.pos = uni.mvp * vertices[vid];
    vert.col = float4(colors[vid].rgb, clamp(colors[vid].a + uni.alphaModifier, 0.0f, 1.0f));
    return vert;
}

fragment float4 fragCol(Vertex_Col interpolated [[ stage_in ]]) {
    
    return interpolated.col;
}

//----------------------------------------------------------------

vertex Vertex_ColTex vertColTex(device float4* vertices      [[ buffer(VERTEX_BUFFER_INDEX)  ]],
                                device float4* colors        [[ buffer(COLOR_BUFFER_INDEX)   ]],
                                device float2* texels        [[ buffer(TEXEL_BUFFER_INDEX)   ]],
                                constant RenderUniform& uni  [[ buffer(UNIFORM_BUFFER_INDEX) ]],
                                uint vid                     [[ vertex_id ]]) {
    Vertex_ColTex vert;
    vert.pos = uni.mvp * vertices[vid];
    vert.col = float4(colors[vid].rgb, clamp(colors[vid].a + uni.alphaModifier, 0.0f, 1.0f));
    vert.tex = texels[vid];
    
    return vert;
}

fragment float4 fragColTex(Vertex_ColTex interpolated       [[ stage_in                        ]],
                           texture2d<float> diffuseTexture  [[ texture(DIFFUSE_TEXTURE_INDEX)  ]],
                           sampler diffuseSampler           [[ sampler(DIFFUSE_SAMPLER_INDEX)  ]]) {
    
    float3 diffuseColor = diffuseTexture.sample(diffuseSampler, interpolated.tex).rgb;
    return float4(diffuseColor * interpolated.col.rgb, interpolated.col.a);
}

//----------------------------------------------------------------

vertex Vertex_ColTex vertFullscreen(device float4* vertices [[ buffer(VERTEX_BUFFER_INDEX) ]],
                                    device float2* texels   [[ buffer(TEXEL_BUFFER_INDEX)  ]],
                                    uint vid                [[ vertex_id                   ]]) {
    Vertex_ColTex o;
    o.pos = float4(vertices[vid].xy, 0.0f, 1.0f);
    o.tex = texels[vid];
    return o;
}

fragment float4 fragFullscreen(Vertex_ColTex interpolated      [[stage_in]],
                              texture2d<float> velocityTexture [[ texture(VELOCITY_TEXTURE_INDEX) ]],
                              texture2d<float> sceneTexture    [[ texture(SCENE_RENDER_TEXTURE_INDEX) ]],
                              sampler velocitySampler          [[ sampler(VELOCITY_SAMPLER_INDEX) ]]) {
    
    return float4(1,0,0,1);
}

