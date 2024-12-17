#ifndef GPU_NET_DEVICE_H
#define GPU_NET_DEVICE_H

#include <iostream>
#include <stdint.h>
#include <cuda_runtime.h>

class GpuNetDevice
{
    public:
        bool TransmitFromGpu(uint8_t* d_packetBuffer, int numPackets, int packetSize);
    private:
        void TransmitPacketToNetwork(uint8_t* d_packet, int packetSize);
};

#endif // GPU_NET_DEVICE_H