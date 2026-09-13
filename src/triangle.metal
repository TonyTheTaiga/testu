#include <metal_stdlib>

using namespace metal;

struct VertexOutput {
  float4 position [[position]];
  float2 localPosition;
  float2 uv;
};

vertex VertexOutput triangleVertex(
  uint vertexID [[vertex_id]],
  const device float2* positions [[buffer(0)]],
  constant float& seconds [[buffer(1)]],
  const device float2* uvs [[buffer(2)]]
) {
    float2 original = positions[vertexID];
    float offset = sin(seconds) * 0.25;

    VertexOutput out;
    out.position = float4(original + float2(offset, 0.0), 0.0, 1.0);
    out.localPosition = original;
    out.uv = uvs[vertexID];
    return out;
}

fragment float4 triangleFragment(VertexOutput in [[stage_in]], texture2d<float> image [[texture(0)]], sampler imageSampler [[sampler(0)]]) {
  return image.sample(imageSampler, in.uv);
}
