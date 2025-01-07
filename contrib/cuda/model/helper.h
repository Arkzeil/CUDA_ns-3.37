#ifndef HELPER_H
#define HELPER_H

#include <cuda_runtime.h>

class Managed {
public:
  void *operator new(size_t len) {
    void *ptr;
    cudaMallocManaged(&ptr, len);
    
    if (ptr == nullptr) {
      printf("cudaMallocManaged failed\n");
    }
    
    cudaDeviceSynchronize();
    
    // cudaError_t err = cudaGetLastError();
    // if (err != cudaSuccess) 
    //   printf("Error: %s\n", cudaGetErrorString(err));
    return ptr;
  }

  void operator delete(void *ptr) {
    cudaDeviceSynchronize();
    cudaFree(ptr);
  }
};

#endif // HELPER_H