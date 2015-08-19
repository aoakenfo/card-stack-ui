//
//  SharedStruct.h
//  gently whimsical
//
//  Created by Edward Oakenfold on 2015-04-23.
//  Copyright (c) 2015 conceptual inertia. All rights reserved.
//

#ifndef gently_whimsical_SharedStruct_h
#define gently_whimsical_SharedStruct_h

#include <simd/simd.h>

#define VERTEX_BUFFER_INDEX 0
#define COLOR_BUFFER_INDEX 1
#define TEXEL_BUFFER_INDEX 2
#define UNIFORM_BUFFER_INDEX 3
#define NORMAL_BUFFER_INDEX 4

#define DIFFUSE_TEXTURE_INDEX 0
#define VELOCITY_TEXTURE_INDEX 1
#define SCENE_RENDER_TEXTURE_INDEX 2


#define DIFFUSE_SAMPLER_INDEX 0
#define VELOCITY_SAMPLER_INDEX 1

#ifdef __cplusplus

// ignore metal shading language extensions in objective-c++ files
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunknown-attributes"

typedef struct {
    simd::float4x4 mvp;
    float alphaModifier;
    
    simd::float3x3 normalMatrix;
    simd::float4x4 shadowMatrix;
} RenderUniform;

typedef struct
{
    simd::float4 albedo [[color(0)]];
    simd::float4 normal [[color(1)]];
    float  depth [[color(2)]];
    simd::float4 light [[color(3)]];
    
} FragOutput;

typedef struct
{
    simd::float4 sunDirection;
    simd::float4 sunColor;
} MaterialSunData;

typedef struct {
    simd::float4 pos [[ position ]];
    simd::float4 col;

} Vertex_Col;

typedef struct {
    simd::float4 pos [[ position ]];
    simd::float4 col;
    simd::float2 tex;
    
} Vertex_ColTex;

#pragma clang diagnostic pop

#endif // __cplusplus

#endif
