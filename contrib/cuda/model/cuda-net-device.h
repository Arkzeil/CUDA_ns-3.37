#ifndef CUDA_NET_DEVICE_H
#define CUDA_NET_DEVICE_H

#include "ns3/net-device.h"
#include <iostream>
#include <stdint.h>
#include <cuda_runtime.h>


namespace ns3 {

class GpuNetDevice : public NetDevice {
public:
    static TypeId GetTypeId(void);

    GpuNetDevice();
    virtual ~GpuNetDevice();

    // Overridden methods for packet transmission
    virtual bool Send(Ptr<Packet> packet, const Address& dest, uint16_t protocolNumber);

    // GPU-specific methods
    void InitializeGpuBuffers();
    void OffloadPacketProcessing();

private:
    uint8_t* d_packetBuffer; // GPU memory for packets
};

} // namespace ns3

#endif // GPU_NET_DEVICE_H