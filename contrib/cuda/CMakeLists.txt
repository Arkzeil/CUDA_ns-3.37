# Specify the minimum CMake version
cmake_minimum_required (VERSION 3.25.2)

# Find CUDA Toolkit
#find_package(CUDAToolkit REQUIRED)
include(CheckLanguage)
check_language(CUDA)

# Enable CUDA support
enable_language(CUDA)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CUDA_STANDARD 17)
set(CMAKE_CUDA_STANDARD_REQUIRED ON)

# set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++17 -D_CMAKE_CUDA_HOST_COMPILER=/usr/bin/g++-10")
# set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -std=c++17 -D_CMAKE_CUDA_HOST_COMPILER=g++-10")

# Find the CUDA Toolkit
find_package(CUDAToolkit REQUIRED)

#project(cuda LAUGUAGE CUDA CXX)
# By adding this to suppress the warning "warning: style of line directive is a GCC extension"
add_compile_options(-Wno-pedantic)
# Declare the ns-3 module
build_lib(
    LIBNAME "cuda"                 # Module name
    SOURCE_FILES                          # Source files
        # model/cuda_wrapper.cc
        # model/cuda_module.cu
        # model/cuda_udp_wrapper.cu
        # model/udp_send_kernel.cu
        model/cuda-udp-client.cu
        model/cuda-packet-kernel.cu
        helper/cuda-helper.cc
    HEADER_FILES                          # Header files
        # model/cuda_wrapper.h
        # model/cuda_module.h
        # model/cuda_udp_wrapper.h
        # model/udp_send_kernel.h
        model/cuda-udp-client.h
        model/cuda-packet-kernel.cuh
        helper/cuda-helper.h
    LIBRARIES_TO_LINK             # Optional: link additional CUDA libraries
        CUDA::cudart
)

# Add example programs
#add_executable(cuda-example examples/cuda-example.cc)

# Link example to the module
#target_link_libraries(cuda-example
#    PRIVATE cuda_module
#    PRIVATE ${CUDAToolkit_LIBRARIES}
#)

# Add include directories for CUDA
#target_include_directories(cuda-example
#    PRIVATE ${CUDAToolkit_INCLUDE_DIRS}
#    PRIVATE ${CMAKE_SOURCE_DIR}/model
#)
