#include "Foundation/NSError.hpp"
#include "Foundation/NSString.hpp"
#include "Foundation/NSTypes.hpp"
#include "Metal/MTL4RenderPipeline.hpp"
#include "Metal/MTLBuffer.hpp"
#include "Metal/MTLCommandBuffer.hpp"
#include "Metal/MTLCommandQueue.hpp"
#include "Metal/MTLDevice.hpp"
#include "Metal/MTLPixelFormat.hpp"
#include "Metal/MTLRenderCommandEncoder.hpp"
#include "Metal/MTLRenderPass.hpp"
#include "Metal/MTLRenderPipeline.hpp"
#include "Metal/MTLResource.hpp"
#include "QuartzCore/CAMetalDrawable.hpp"
#include "QuartzCore/CAMetalLayer.hpp"
#include <AppKit/AppKit.h>
#include <Foundation/Foundation.h>
#include <Metal/Metal.hpp>
#include <QuartzCore/QuartzCore.h>
#include <iostream>
#include <objc/NSObject.h>
#include <objc/objc.h>

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

const char *shaderSource = R"(
#include <metal_stdlib>

using namespace metal;

vertex float4 triangleVertex(
  uint vertexID [[vertex_id]],
  const device float2* positions [[buffer(0)]]
) {
    return float4(positions[vertexID], 0.0, 1.0);
}

fragment float4 triangleFragment() {
    return float4(1.0, 0.5, 0.0, 1.0);
}
)";

void draw(CA::MetalLayer *layer, MTL::CommandQueue *queue,
          MTL::Buffer *vertexBuffer, MTL::RenderPipelineState *pipeline) {

  std::cout << "looping..." << "\n";
  @autoreleasepool {
    CA::MetalDrawable *drawable = layer->nextDrawable();
    if (!drawable) {
      return;
    }

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
    encoder->drawPrimitives(MTL::PrimitiveTypeLine, NS::UInteger{0},
                            NS::UInteger{3});

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

    MTL::Library *library = device->newLibrary(
        NS::String::string(shaderSource, NS::UTF8StringEncoding), nullptr,
        &error);

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

    const float pos[3][2] = {{0.0f, 0.5f}, {-0.5f, -0.5f}, {0.5f, 0.5f}};
    MTL::Buffer *vertexBuffer =
        device->newBuffer(pos, sizeof(pos), MTL::ResourceStorageModeShared);

    NSTimer *drawTimer = [NSTimer
        scheduledTimerWithTimeInterval:(1.0 / 60.0)
                               repeats:YES
                                 block:^(NSTimer *timer) {
                                   draw(layer, queue, vertexBuffer, pipeline);
                                 }];

    [appDelegate configureWithDevice:device
                               queue:queue
                               timer:drawTimer
                              buffer:vertexBuffer];

    [app run];
  }

  return 0;
}
