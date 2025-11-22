cmake_minimum_required(VERSION 3.10)
project(whisper_flutter)

set(CMAKE_CXX_STANDARD 17)
# Options for whisper.cpp
set(WHISPER_BUILD_TESTS OFF CACHE BOOL "Build tests" FORCE)
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "Build examples" FORCE)
set(WHISPER_BUILD_SERVER OFF CACHE BOOL "Build server" FORCE)

# Fetch whisper.cpp
include(FetchContent)
FetchContent_Declare(
    whisper
    GIT_REPOSITORY https://github.com/ggerganov/whisper.cpp.git
    GIT_TAG        v1.8.2
)
FetchContent_MakeAvailable(whisper)

# Create JNI library
add_library(whisper_flutter SHARED whisper_jni.cpp)

# Find required libraries
find_library(LOG_LIB log)
find_library(ANDROID_LIB android)

# Link libraries
target_link_libraries(whisper_flutter 
    PRIVATE 
    whisper
    ${LOG_LIB}
    ${ANDROID_LIB}
)

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
        -march=armv8.2-a+fp16+dotprod+i8mm  # Enable dot product and int8 matrix multiplication
        -mtune=cortex-x3  # Optimize for modern ARM cores (Pixel 10 Pro)
    )
    target_compile_definitions(whisper_flutter PRIVATE GGML_USE_ARM_FP16)
elseif (${ANDROID_ABI} STREQUAL "armeabi-v7a")
    target_compile_options(whisper_flutter PRIVATE 
        -mfpu=neon-vfpv4
        -mfloat-abi=softfp
    )
endif()
