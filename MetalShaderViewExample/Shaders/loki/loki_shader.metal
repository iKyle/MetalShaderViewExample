//
//  loki_shader.metal
//  MetalShaderViewExample
//
//  Created by kylewu on 2024/3/21.
//

#include <metal_stdlib>
#import  "loki_header.metal"

using namespace metal;

/// Shade Image Based on a Random Number
kernel void loki_shader(texture2d<float, access::write> drawable [[ texture(0) ]],
                        constant uint& iteration [[  buffer(0) ]],
                        const uint2 position [[thread_position_in_grid]]) {
    
    // Loki takes in (up to) 3 seeds, but must have at least one.
    // All you have to do is just pass in some random seeds, on initialization
    Loki rng = Loki(position.x + 1, position.y + 1, iteration + 1);
    
    // When using Loki, it's as simple as just calling rand()!
    float random_float = rng.rand();
    drawable.write(float4(float3(random_float),1), position);
}
