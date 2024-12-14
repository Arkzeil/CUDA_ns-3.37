#include "ns3/cuda_wrapper.h"
#include <iostream>

int main() {
    std::cout << "Running CUDA code in ns-3!" << std::endl;
    CudaWrapper::RunCudaCode();
    return 0;
}

