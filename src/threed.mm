#include "Metal/MTLDevice.hpp"
#include "Metal/MTLPixelFormat.hpp"
#include "Metal/MTLResource.hpp"
#include "QuartzCore/CAMetalLayer.hpp"
#include <Metal/Metal.hpp>
#include <iostream>
#include <simd/matrix.h>
#include <simd/matrix_types.h>
#include <simd/simd.h>
#include <simd/vector_types.h>
#include <sstream>

struct Vertex {
  simd::float3 position;
  simd::float2 uv;
};

struct Uniforms {
  simd::float4x4 model;
  simd::float4x4 view;
  simd::float4x4 projetion;
};

static simd::float4x4 translation(float x, float y, float z) {
  simd::float4x4 matrix = matrix_identity_float4x4;
  matrix.columns[3] = {x, y, z, 1.0f};
  return matrix;
};

static simd::float4x4 rotationY(float angle) {
  float c = cosf(angle);
  float s = sinf(angle);

  return simd::float4x4{simd::float4{c, 0, -s, 0}, simd::float4{},
                        simd::float4{}, simd::float4{}};
};

int main() {
  static const Vertex vertices[] = {
      // Front
      {{-1, -1, 1}, {0, 1}},
      {{1, -1, 1}, {1, 1}},
      {{1, 1, 1}, {1, 0}},
      {{-1, 1, 1}, {0, 0}},

      // Back
      {{1, -1, -1}, {0, 1}},
      {{-1, -1, -1}, {1, 1}},
      {{-1, 1, -1}, {1, 0}},
      {{1, 1, -1}, {0, 0}},

      // Left
      {{-1, -1, -1}, {0, 1}},
      {{-1, -1, 1}, {1, 1}},
      {{-1, 1, 1}, {1, 0}},
      {{-1, 1, -1}, {0, 0}},

      // Right
      {{1, -1, 1}, {0, 1}},
      {{1, -1, -1}, {1, 1}},
      {{1, 1, -1}, {1, 0}},
      {{1, 1, 1}, {0, 0}},

      // Top
      {{-1, 1, 1}, {0, 1}},
      {{1, 1, 1}, {1, 1}},
      {{1, 1, -1}, {1, 0}},
      {{-1, 1, -1}, {0, 0}},

      // Bottom
      {{-1, -1, -1}, {0, 1}},
      {{1, -1, -1}, {1, 1}},
      {{1, -1, 1}, {1, 0}},
      {{-1, -1, 1}, {0, 0}},
  };

  static const uint16_t indices[] = {
      0,  1,  2,  2,  3,  0,  4,  5,  6,  6,  7,  4,  8,  9,  10, 10, 11, 8,
      12, 13, 14, 14, 15, 12, 16, 17, 18, 18, 19, 16, 20, 21, 22, 22, 23, 20,
  };

  constexpr size_t indexCount = sizeof(indices) / sizeof(indices[0]);

  @autoreleasepool {
    MTL::Device *device = MTL::CreateSystemDefaultDevice();
    if (!device) {
      std::cerr << "Failed to init metal device";
      return -1;
    }
    std::cout << "Successfully connected to metal device: "
              << device->name()->cString(NS::UTF8StringEncoding) << "\n";

    CA::MetalLayer *layer = CA::MetalLayer::layer();
    layer->setDevice(device);
    layer->setPixelFormat(MTL::PixelFormatBGRA8Unorm);

    MTL::Buffer *vertexBuffer = device->newBuffer(
        vertices, sizeof(vertices), MTL::ResourceStorageModeManaged);
    MTL::Buffer *indicesBuffer = device->newBuffer(
        indices, sizeof(indices), MTL::ResourceStorageModeManaged);
  }

  return 0;
}
