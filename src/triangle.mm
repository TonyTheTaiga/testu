#include "Metal/MTLCommandBuffer.hpp"
#include "Metal/MTLCommandQueue.hpp"
#include "Metal/MTLDevice.hpp"
#include "Metal/MTLPixelFormat.hpp"
#include "Metal/MTLRenderCommandEncoder.hpp"
#include "Metal/MTLRenderPass.hpp"
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
}

- (void)configureWithDevice:(MTL::Device *)device
                      queue:(MTL::CommandQueue *)queue
                      timer:(NSTimer *)timer;
@end

@implementation AppDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
  return YES;
}

- (void)configureWithDevice:(MTL::Device *)device
                      queue:(MTL::CommandQueue *)queue
                      timer:(NSTimer *)timer {
  _device = device;
  _queue = queue;
  _drawTimer = timer;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
  std::cout << "cleaning up" << "\n";
  [_drawTimer invalidate];
  _queue->release();
  _device->release();
  _queue = nullptr;
  _device = nullptr;
}

@end

void draw(CA::MetalLayer *layer, MTL::CommandQueue *queue) {
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

    MTL::CommandQueue *queue = device->newCommandQueue();
    CA::MetalLayer *layer = CA::MetalLayer::layer();
    layer->setDevice(device);
    layer->setPixelFormat(MTL::PixelFormatBGRA8Unorm);
    layer->setDrawableSize(pixelBounds.size);

    [metalView setWantsLayer:YES];
    [metalView setLayer:(CALayer *)layer];
    [window setContentView:metalView];
    [window setTitle:@"draw_black"];
    [window makeKeyAndOrderFront:nil];
    [app activateIgnoringOtherApps:YES];

    NSTimer *drawTimer =
        [NSTimer scheduledTimerWithTimeInterval:(1.0 / 60.0)
                                        repeats:YES
                                          block:^(NSTimer *timer) {
                                            draw(layer, queue);
                                          }];

    [appDelegate configureWithDevice:device queue:queue timer:drawTimer];

    [app run];
  }

  return 0;
}
