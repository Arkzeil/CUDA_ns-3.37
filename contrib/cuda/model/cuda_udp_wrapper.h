#ifndef CUDA_UDP_WRAPPER_H
#define CUDA_UDP_WRAPPER_H

#include <stdio.h>
#include <time.h>
#include "udp_send_kernel.h"

namespace ns3{
    namespace cuda{
        struct Index{
            int block, thread;
        };

        bool InitCUDA(cudaDeviceProp &prop);

        __host__ void gpuUdpSend(char *packets, int *metadata, int numPackets);
        __host__ void gpuAssemblePkt(uint8_t *ipHeader, uint8_t *udpHeader, uint8_t *payload, uint8_t *packet, uint32_t payloadSize);
        __host__ void GenerateIpUdpPacketsinCUDA(GpuSocketInfo *socketInfo, uint8_t *packets, size_t payloadSize, size_t numPackets);
    }
}

#endif