
#include <metal_texture>
#include <metal_matrix>
#include <metal_math>
#include <metal_graphics>
#include <metal_geometric>
#include <metal_stdlib>

#include "SharedStruct.h"

using namespace metal;

struct VertexOutput
{
    float4 position [[position]];
};

vertex VertexOutput compositionVert(device float4* vertices [[ buffer(VERTEX_BUFFER_INDEX) ]],
                                      uint vid [[vertex_id]] )
{
    VertexOutput output;
    output.position = vertices[vid];
    
    return output;
}

// This fragment program will write its output to color[0], effectively overwriting the contents of gBuffers.albedo
fragment float4 compositionFrag(VertexOutput in [[stage_in]],
                                constant MaterialSunData& sunData [[buffer(0)]],
                                depth2d<float> shadow_texture [[texture(3)]],
                                FragOutput gBuffers)
{
    float4 light = {0, 0, 0, 1};
    
    float3 diffuse = light.rgb;
    
    float3 n_s = {0,0,-1};
    float sun_atten = gBuffers.albedo.a;
    float sun_diffuse = saturate(dot(n_s, sunData.sunDirection.xyz)) * sun_atten;
    
    diffuse += sunData.sunColor.rgb * sun_diffuse;
    diffuse *= gBuffers.albedo.rgb;
    diffuse += diffuse;
    
    return float4(diffuse.xyz, 1.0);
}

