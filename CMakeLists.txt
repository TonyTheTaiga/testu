cmake_minimum_required(VERSION 3.15)
project(Tetsu CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/metal-cpp)

add_executable(Tetsu
    src/main.cpp
    src/metal_impl.cpp
)

find_library(METAL_FRAMEWORK Metal REQUIRED)
find_library(FOUNDATION_FRAMEWORK Foundation REQUIRED)
find_library(QUARTZ_FRAMEWORK QuartzCore REQUIRED)

target_link_libraries(Tetsu PRIVATE
    ${METAL_FRAMEWORK}
    ${FOUNDATION_FRAMEWORK}
    ${QUARTZ_FRAMEWORK}
    objc
)
