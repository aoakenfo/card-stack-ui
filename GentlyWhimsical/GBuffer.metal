
#include <metal_graphics>
#include <metal_texture>
#include <metal_matrix>
#include <metal_math>

#include <metal_stdlib>

#include "SharedStruct.h"

using namespace metal;

struct VertexOutput
{
    simd::float4 position [[position]];
    simd::float4 col;
    simd::float4 v_shadowcoord;
    simd::float3 v_normal;
    simd::float2 v_texcoord;
};


vertex VertexOutput gBufferVert(device float4* vertices      [[ buffer(VERTEX_BUFFER_INDEX)  ]],
                                device float2* texels        [[ buffer(TEXEL_BUFFER_INDEX)   ]],
                                device float4* colors       [[ buffer(COLOR_BUFFER_INDEX)   ]],
                                constant RenderUniform& uni  [[ buffer(UNIFORM_BUFFER_INDEX) ]],
                                uint vid [[vertex_id]])
{
    VertexOutput output;
    
    float3 normal = {0,0,-1};
    float4 tempPosition = vertices[vid];
    
    output.v_normal = normalize(uni.normalMatrix * normal);
    output.v_texcoord = texels[vid];
    output.position = uni.mvp * tempPosition;
    output.v_shadowcoord = uni.shadowMatrix * tempPosition;
    
    
    output.col = float4(colors[vid].rgb, clamp(colors[vid].a + uni.alphaModifier, 0.0f, 1.0f));
    
    return output;
}

fragment float4 gBufferFrag(VertexOutput in [[stage_in]],
                            texture2d<float> albedo_texture [[texture(1)]],
                            constant MaterialSunData& sunData [[buffer(2)]],
                            depth2d<float> shadow_texture [[texture(3)]])
{
    
    constexpr sampler linear_sampler(min_filter::linear, mag_filter::linear);
    constexpr sampler shadow_sampler(coord::normalized, filter::linear, address::clamp_to_edge, compare_func::less);
    
    float4 albedo = albedo_texture.sample(linear_sampler, in.v_texcoord.xy);
    float r = shadow_texture.sample_compare(shadow_sampler, in.v_shadowcoord.xy, in.v_shadowcoord.z);
    
    float3 diffuse = float3(0.5);
    float3 n_s = {0,0,-1};
    float sun_diffuse = dot(n_s, sunData.sunDirection.xyz) * r;
    
    diffuse += sunData.sunColor.rgb * sun_diffuse;
    diffuse *= albedo.rgb;
    
    return float4(diffuse.xyz * in.col.rgb, in.col.a);
}