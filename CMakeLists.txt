cmake_minimum_required(VERSION 3.15)
project(Tetsu LANGUAGES CXX OBJCXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Emit compile_commands.json so clangd resolves metal-cpp headers.
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_library(METAL_FRAMEWORK Metal REQUIRED)
find_library(FOUNDATION_FRAMEWORK Foundation REQUIRED)
find_library(QUARTZ_FRAMEWORK QuartzCore REQUIRED)
find_library(APPKIT_FRAMEWORK AppKit REQUIRED)

# Every src/<name>.mm file is one independently runnable Metal experiment.
file(GLOB APP_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.mm")

if(APP_SOURCES STREQUAL "")
    message(FATAL_ERROR "Add an Objective-C++ example at src/<name>.mm")
endif()

foreach(APP_SOURCE IN LISTS APP_SOURCES)
    get_filename_component(APP_NAME "${APP_SOURCE}" NAME_WE)

    add_executable(${APP_NAME}
        ${APP_SOURCE}
        ${CMAKE_CURRENT_SOURCE_DIR}/src/metal_impl.cpp
    )

    target_include_directories(${APP_NAME} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/metal-cpp)

    target_link_libraries(${APP_NAME} PRIVATE
        ${METAL_FRAMEWORK}
        ${FOUNDATION_FRAMEWORK}
        ${QUARTZ_FRAMEWORK}
        ${APPKIT_FRAMEWORK}
        objc
    )
endforeach()
