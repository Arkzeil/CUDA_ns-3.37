#ifndef CUDA_NET_DEVICE_H
#define CUDA_NET_DEVICE_H

#include "ns3/net-device.h"
#include "ns3/point-to-point-net-device.h"
#include "ns3/log.h"
#include <iostream>
#include <stdint.h>
#include <cuda_runtime.h>
#include "helper.h"


namespace ns3 {

class CudaNetDevice : public PointToPointNetDevice, public Managed{
public:
    static TypeId GetTypeId(void);

    CudaNetDevice();
    virtual ~CudaNetDevice();

    // Overridden methods for packet transmission
    virtual bool Send(Ptr<Packet> packet, const Address& dest, uint16_t protocolNumber);
    virtual bool SupportsSendFrom(void) const;
    virtual void SetReceiveCallback(NetDevice::ReceiveCallback cb);

    // GPU-specific methods
    void InitializeCudaBuffers();
    void OffloadPacketProcessing();
    // Helper functions
    __device__ void EnqueuePacket(const uint8_t* packet, uint32_t size);
    void TransmitPackets();

private:
    void ProcessPacketOnCuda(Ptr<Packet> packet);

    // CUDA-related members
    cudaStream_t m_stream;
    uint8_t* d_packetQueue; // GPU packet queue
    NetDevice::ReceiveCallback m_rxCallback;
    int* d_queueFront;
    int* d_queueRear;
    int m_queueSize;
};

} // namespace ns3

#endif // GPU_NET_DEVICE_H