#include "Metal/MTLDevice.hpp"
#include <Metal/Metal.hpp>
#include <iostream>
#include <sstream>

int main() {
  @autoreleasepool {
    MTL::Device *device = MTL::CreateSystemDefaultDevice();
    if (!device) {
      std::cerr << "Failed to init metal device";
      return -1;
    }
    std::cout << "Successfully connected to metal device: "
              << device->name()->cString(NS::UTF8StringEncoding) << "\n";
  }

  return 0;
}
