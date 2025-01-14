#ifndef HELPER_H
#define HELPER_H

#include <cuda_runtime.h>
#include <cstdio>

class Managed {
public:
  void *operator new(size_t len) {
    void *ptr;
    cudaMallocManaged(&ptr, len);
    
    if (ptr == nullptr) {
      printf("cudaMallocManaged failed\n");
    }
    
    cudaDeviceSynchronize();

    printf("Allocated Unified Memory at %p\n", ptr);  
    
    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess) 
      printf("Error: %s\n", cudaGetErrorString(err));
    return ptr;

  }

  void operator delete(void *ptr) {
    if (ptr) {
        cudaPointerAttributes attributes;
        cudaError_t err = cudaPointerGetAttributes(&attributes, ptr);
        if (err == cudaSuccess && attributes.type == cudaMemoryTypeManaged) {
            printf("Freeing Unified Memory at %p\n", ptr);
            cudaDeviceSynchronize();
            cudaFree(ptr);
        } else {
            printf("Warning: Trying to free invalid/unmanaged pointer %p\n", ptr);
        }
    }

    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess) 
      printf("Error: %s\n", cudaGetErrorString(err));
  }
};



#endif // HELPER_H