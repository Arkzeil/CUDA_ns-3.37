#ifndef CUDA_NET_DEVICE_H
#define CUDA_NET_DEVICE_H

#include "ns3/net-device.h"
#include <iostream>
#include <stdint.h>
#include <cuda_runtime.h>

class GpuNetDevice : public ns3::NetDevice
{
    public:
        bool TransmitFromGpuQueue();
    private:
        void TransmitPacketToNetwork(uint8_t* d_packet, int packetSize);
};

#endif // GPU_NET_DEVICE_H