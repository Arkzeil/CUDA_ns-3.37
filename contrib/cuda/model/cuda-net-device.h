#ifndef CUDA_NET_DEVICE_H
#define CUDA_NET_DEVICE_H

#include "ns3/net-device.h"
#include "ns3/point-to-point-net-device.h"
#include "ns3/log.h"
#include <iostream>
#include <stdint.h>
#include <cuda_runtime.h>


namespace ns3 {

class CudaNetDevice : public PointToPointNetDevice {
public:
    static TypeId GetTypeId(void);

    CudaNetDevice();
    virtual ~CudaNetDevice();

    // Overridden methods for packet transmission
    virtual bool Send(Ptr<Packet> packet, const Address& dest, uint16_t protocolNumber);
    virtual void SetReceiveCallback(NetDevice::ReceiveCallback cb);

    // GPU-specific methods
    void InitializeCudaBuffers();
    void OffloadPacketProcessing();

private:
    void ProcessPacketOnCuda(Ptr<Packet> packet);

    // CUDA-related members
    cudaStream_t m_stream;
    uint8_t* d_packetBuffer; // GPU packet buffer
    NetDevice::ReceiveCallback m_rxCallback;
};

} // namespace ns3

#endif // GPU_NET_DEVICE_H