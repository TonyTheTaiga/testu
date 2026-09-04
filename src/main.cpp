#include <Metal/Metal.hpp>
#include <iostream>


int main() {
  MTL::Device* device = MTL::CreateSystemDefaultDevice();
  
  if (!device) {
    std::cerr << "Failed to init metal device";
    return -1;
  }

  std::cout << "Successfully connected to metal device: "
    << device->name()->cString(NS::UTF8StringEncoding) << "\n"; 

  device->release();

  return 0;
}
