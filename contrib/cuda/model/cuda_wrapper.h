#ifndef CUDA_WRAPPER_H
#define CUDA_WRAPPER_H

#include "cuda_module.h"

bool InitCUDA_test(cudaDeviceProp &prop);

namespace ns3{
	class CudaWrapper {
	public:
	    static void RunCudaCode();
	};
}

#endif // CUDA_WRAPPER_H

