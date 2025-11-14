cmake_minimum_required(VERSION 3.10)
project(whisper_flutter)

set(CMAKE_CXX_STANDARD 17)
set(WHISPER_ROOT_DIR D:/projects/whisper.cpp)

# Whisper source files
set(WHISPER_SOURCES
    ${WHISPER_ROOT_DIR}/src/whisper.cpp
    ${CMAKE_SOURCE_DIR}/whisper_jni.cpp
)

# Create whisper library
add_library(whisper_flutter SHARED ${WHISPER_SOURCES})

# Fetch ggml dependency
include(FetchContent)
FetchContent_Declare(ggml SOURCE_DIR ${WHISPER_ROOT_DIR}/ggml)
FetchContent_MakeAvailable(ggml)

# Find required libraries
find_library(LOG_LIB log)
find_library(ANDROID_LIB android)

# Link libraries
target_link_libraries(whisper_flutter 
    ${LOG_LIB}
    ${ANDROID_LIB}
    ggml
)

# Include directories
target_include_directories(whisper_flutter PRIVATE
    ${WHISPER_ROOT_DIR}
    ${WHISPER_ROOT_DIR}/include
    ${WHISPER_ROOT_DIR}/src
    ${WHISPER_ROOT_DIR}/ggml/include
    ${WHISPER_ROOT_DIR}/ggml/src
    ${WHISPER_ROOT_DIR}/ggml/src/ggml-cpu
)

# Compile definitions
target_compile_definitions(whisper_flutter PUBLIC GGML_USE_CPU)
target_compile_definitions(whisper_flutter PRIVATE WHISPER_VERSION="1.7.5")

# Optimization flags - always use aggressive optimization for Whisper
# (Performance is critical for real-time transcription)
target_compile_options(whisper_flutter PRIVATE 
    -O3 
    -funroll-loops
    -ffast-math
    -fno-finite-math-only
)
target_compile_options(whisper_flutter PRIVATE 
    -fvisibility=hidden 
    -fvisibility-inlines-hidden
)

# ARM-specific optimizations
if (${ANDROID_ABI} STREQUAL "arm64-v8a")
    target_compile_options(whisper_flutter PRIVATE 
        -march=armv8.2-a+fp16+dotprod  # Enable dot product instructions
        -mtune=cortex-a76  # Optimize for modern ARM cores
    )
    target_compile_definitions(whisper_flutter PRIVATE GGML_USE_ARM_FP16)
elseif (${ANDROID_ABI} STREQUAL "armeabi-v7a")
    target_compile_options(whisper_flutter PRIVATE 
        -mfpu=neon-vfpv4
        -mfloat-abi=softfp
    )
endif()
