#ifndef CUDA_HELPER_H
#define CUDA_HELPER_H

#include <cuda_runtime.h>
#include "../model/helper.h"
#include "ns3/nstime.h"

namespace ns3
{

// Each class should be documented using Doxygen,
// and have an \ingroup cuda directive

/* ... */
    bool InitCUDA(cudaDeviceProp &prop);
    void checkCudaErr();

    class CUDA_cb_data: public Managed{
        public:
            uint32_t context;
            void* client;
            uint8_t* packetBuffer;
            uint32_t packetSize;
            Time sendTime;
            float delay;
            // CudaSocket* socket;
            // Ptr<Packet> packet;
    };
}

#endif /* CUDA_HELPER_H */
