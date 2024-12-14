#include <cuda_runtime.h>
#include <iostream>

__global__ void my_kernel() {
    printf("Hello from CUDA kernel!\n");
}

extern "C" void launch_my_kernel() {
    my_kernel<<<1, 1>>>();
    cudaDeviceSynchronize();
}

