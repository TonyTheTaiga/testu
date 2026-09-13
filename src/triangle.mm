#include "Foundation/NSError.hpp"
#include "Foundation/NSObject.hpp"
#include "Foundation/NSString.hpp"
#include "Foundation/NSTypes.hpp"
#include "Metal/MTL4RenderPipeline.hpp"
#include "Metal/MTLArgument.hpp"
#include "Metal/MTLBuffer.hpp"
#include "Metal/MTLCommandBuffer.hpp"
#include "Metal/MTLCommandQueue.hpp"
#include "Metal/MTLDevice.hpp"
#include "Metal/MTLPixelFormat.hpp"
#include "Metal/MTLRenderCommandEncoder.hpp"
#include "Metal/MTLRenderPass.hpp"
#include "Metal/MTLRenderPipeline.hpp"
#include "Metal/MTLResource.hpp"
#include "Metal/MTLSampler.hpp"
#include "QuartzCore/CAMetalDrawable.hpp"
#include "QuartzCore/CAMetalLayer.hpp"
#include <AppKit/AppKit.h>
#include <Foundation/Foundation.h>
#include <Metal/Metal.hpp>
#include <MetalKit/MetalKit.h>
#include <MetalKit/Metalkit.h>
#include <QuartzCore/QuartzCore.h>
#include <Security/cssmconfig.h>
#include <algorithm>
#include <chrono>
#include <fstream>
#include <iostream>
#include <objc/NSObject.h>
#include <objc/objc.h>
#include <sstream>

@interface AppDelegate : NSObject <NSApplicationDelegate> {
  MTL::Device *_device;
  MTL::CommandQueue *_queue;
  NSTimer *_drawTimer;
  MTL::Buffer *_buffer;
}

- (void)configureWithDevice:(MTL::Device *)device
                      queue:(MTL::CommandQueue *)queue
                      timer:(NSTimer *)timer
                     buffer:(MTL::Buffer *)buffer;
@end

@implementation AppDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
  return YES;
}

- (void)configureWithDevice:(MTL::Device *)device
                      queue:(MTL::CommandQueue *)queue
                      timer:(NSTimer *)timer
                     buffer:(MTL::Buffer *)buffer {
  _device = device;
  _queue = queue;
  _drawTimer = timer;
  _buffer = buffer;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
  std::cout << "cleaning up" << "\n";
  [_drawTimer invalidate];
  _queue->release();
  _device->release();
  _buffer->release();
  _queue = nullptr;
  _device = nullptr;
  _buffer = nullptr;
}

@end

void draw(CA::MetalLayer *layer, MTL::CommandQueue *queue,
          MTL::Buffer *vertexBuffer, MTL::Buffer *indexBuffer,
          MTL::Buffer *uvBuffer, MTL::RenderPipelineState *pipeline,
          MTL::Texture *texture, MTL::SamplerState *sampler) {

  std::cout << "looping..." << "\n";
  @autoreleasepool {
    CA::MetalDrawable *drawable = layer->nextDrawable();
    if (!drawable) {
      return;
    }

    using Clock = std::chrono::steady_clock;
    static const auto start = Clock::now();

    float seconds = std::chrono::duration<float>(Clock::now() - start).count();

    MTL::RenderPassDescriptor *pass =
        MTL::RenderPassDescriptor::renderPassDescriptor();

    MTL::RenderPassColorAttachmentDescriptor *color =
        pass->colorAttachments()->object(0);

    color->setTexture(drawable->texture());
    color->setLoadAction(MTL::LoadActionClear);
    color->setClearColor(MTL::ClearColor::Make(0.0, 0.0, 0.0, 1.0));
    color->setStoreAction(MTL::StoreActionStore);

    MTL::CommandBuffer *commandBuffer = queue->commandBuffer();
    MTL::RenderCommandEncoder *encoder =
        commandBuffer->renderCommandEncoder(pass);

    encoder->setRenderPipelineState(pipeline);
    encoder->setVertexBuffer(vertexBuffer, 0, 0);
    encoder->setVertexBytes(&seconds, sizeof(seconds), 1);
    encoder->setVertexBuffer(uvBuffer, 0, 2);
    encoder->setFragmentTexture(texture, NS::UInteger{0});
    encoder->setFragmentSamplerState(sampler, NS::UInteger{0});
    encoder->drawIndexedPrimitives(MTL::PrimitiveTypeTriangle, NS::UInteger{6},
                                   MTL::IndexTypeUInt16, indexBuffer,
                                   NS::UInteger{0});

    encoder->endEncoding();
    commandBuffer->presentDrawable(drawable);
    commandBuffer->commit();
  }
}

int main() {
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

    NS::Error *error = nullptr;

    NSString *path = [[[NSFileManager defaultManager] currentDirectoryPath]
        stringByAppendingPathComponent:@"assets/textures/blue_marble.png"];

    NSURL *imageURL = [NSURL fileURLWithPath:path];

    id<MTLDevice> nativeDevice = (__bridge id<MTLDevice>)(void *)device;

    MTKTextureLoader *loader =
        [[MTKTextureLoader alloc] initWithDevice:nativeDevice];

    NSError *imageError = nil;

    id<MTLTexture> nativeTexture =
        [loader newTextureWithContentsOfURL:imageURL
                                    options:nil
                                      error:&imageError];

    if (!nativeTexture) {
      std::cerr << "Texture loading failed\n";

      if (imageError) {
        std::cerr << [[imageError localizedDescription] UTF8String] << "\n";
      }

      return -1;
    }

    MTL::Texture *texture =
        reinterpret_cast<MTL::Texture *>((__bridge void *)nativeTexture);

    MTL::SamplerDescriptor *samplerDescriptor =
        MTL::SamplerDescriptor::alloc()->init();

    samplerDescriptor->setMinFilter(MTL::SamplerMinMagFilterLinear);
    samplerDescriptor->setMagFilter(MTL::SamplerMinMagFilterLinear);
    samplerDescriptor->setSAddressMode(MTL::SamplerAddressModeRepeat);
    samplerDescriptor->setTAddressMode(MTL::SamplerAddressModeRepeat);

    MTL::SamplerState *sampler = device->newSamplerState(samplerDescriptor);

    samplerDescriptor->release();

    std::ifstream shaderFile("src/triangle.metal");
    if (!shaderFile) {
      std::cerr << "Could not open file src/triangle.metal\n";
    }

    std::ostringstream shaderText;
    shaderText << shaderFile.rdbuf();
    std::string shaderSource = shaderText.str();

    MTL::Library *library = device->newLibrary(
        NS::String::string(shaderSource.c_str(), NS::UTF8StringEncoding),
        nullptr, &error);

    if (!library) {
      std::cerr << "Shader compilation failed\n";
      if (error) {
        std::cerr << error->localizedDescription()->cString(
                         NS::UTF8StringEncoding)
                  << "\n";
      }
      return -1;
    }

    MTL::Function *vertexFunction = library->newFunction(
        NS::String::string("triangleVertex", NS::UTF8StringEncoding));

    MTL::Function *fragmentFunction = library->newFunction(
        NS::String::string("triangleFragment", NS::UTF8StringEncoding));

    MTL::RenderPipelineDescriptor *pipelineDescriptor =
        MTL::RenderPipelineDescriptor::alloc()->init();

    pipelineDescriptor->setVertexFunction(vertexFunction);
    pipelineDescriptor->setFragmentFunction(fragmentFunction);

    pipelineDescriptor->colorAttachments()->object(0)->setPixelFormat(
        layer->pixelFormat());

    MTL::RenderPipelineState *pipeline =
        device->newRenderPipelineState(pipelineDescriptor, &error);

    pipelineDescriptor->release();
    vertexFunction->release();
    fragmentFunction->release();
    library->release();

    if (!pipeline) {
      std::cerr << "Pipeline creation failed\n";
      if (error) {
        std::cerr << error->localizedDescription()->cString(
                         NS::UTF8StringEncoding)
                  << "\n";
      }
      return -1;
    }

    NSApplication *app = [NSApplication sharedApplication];
    [app setActivationPolicy:NSApplicationActivationPolicyRegular];

    AppDelegate *appDelegate = [[AppDelegate alloc] init];
    [app setDelegate:appDelegate];

    NSRect frame = NSMakeRect(100, 100, 800, 600);
    NSWindowStyleMask style = NSWindowStyleMaskTitled |
                              NSWindowStyleMaskClosable |
                              NSWindowStyleMaskResizable;

    NSWindow *window =
        [[NSWindow alloc] initWithContentRect:frame
                                    styleMask:style
                                      backing:NSBackingStoreBuffered
                                        defer:NO];
    NSView *metalView =
        [[NSView alloc] initWithFrame:[[window contentView] bounds]];

    NSRect pixelBounds = [metalView convertRectToBacking:[metalView bounds]];
    layer->setDrawableSize(pixelBounds.size);

    MTL::CommandQueue *queue = device->newCommandQueue();

    [metalView setWantsLayer:YES];
    [metalView setLayer:(CALayer *)layer];
    [window setContentView:metalView];
    [window setTitle:@"draw_black"];
    [window makeKeyAndOrderFront:nil];
    [app activateIgnoringOtherApps:YES];

    const float positions[4][2] = {
        {-0.5f, 0.5f},  // 0: top-left
        {-0.5f, -0.5f}, // 1: bottom-left
        {0.5f, 0.5f},   // 2: top-right
        {0.5f, -0.5f}   // 3: bottom-right
    };

    const uint16_t indices[6] = {0, 1, 2, 2, 1, 3};

    const float uv[4][2] = {
        {0.0f, 0.0f}, // vertex 0: top-left
        {0.0f, 2.0f}, // vertex 1: bottom-left
        {2.0f, 0.0f}, // vertex 2: top-right
        {2.0f, 2.0f}, // vertex 3: bottom-right
    };

    MTL::Buffer *vertexBuffer = device->newBuffer(
        positions, sizeof(positions), MTL::ResourceStorageModeShared);

    MTL::Buffer *indexBuffer = device->newBuffer(
        indices, sizeof(indices), MTL::ResourceStorageModeShared);

    MTL::Buffer *uvBuffer =
        device->newBuffer(uv, sizeof(uv), MTL::ResourceStorageModeShared);

    NSTimer *drawTimer = [NSTimer
        scheduledTimerWithTimeInterval:(1.0 / 60.0)
                               repeats:YES
                                 block:^(NSTimer *timer) {
                                   draw(layer, queue, vertexBuffer, indexBuffer,
                                        uvBuffer, pipeline, texture, sampler);
                                 }];

    [appDelegate configureWithDevice:device
                               queue:queue
                               timer:drawTimer
                              buffer:vertexBuffer];

    [app run];
  }

  return 0;
}
