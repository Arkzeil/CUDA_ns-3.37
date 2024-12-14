#ifndef CUDA_MODULE_H
#define CUDA_MODULE_H
#include <cuda_runtime.h>

__global__ void my_kernel();
void launch_my_kernel();

#endif
