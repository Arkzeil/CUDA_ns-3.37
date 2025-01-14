#ifndef CUDA_NET_DEVICE_H
#define CUDA_NET_DEVICE_H

#include "ns3/net-device.h"
#include "ns3/point-to-point-net-device.h"
#include "ns3/cuda-p2p-channel.h"
#include "ns3/net-device-container.h"
#include "ns3/node-container.h"
#include "ns3/log.h"
#include "ns3/data-rate.h"
#include <iostream>
#include <stdint.h>
#include <cuda_runtime.h>
#include "helper.h"


namespace ns3 {

class CUDA_cb_data;

class CudaNetDevice : public PointToPointNetDevice, public Managed{
public:
    static TypeId GetTypeId(void);

    CudaNetDevice();
    virtual ~CudaNetDevice();

    // Overridden methods for packet transmission
    virtual bool Send(Ptr<Packet> packet, const Address& dest, uint16_t protocolNumber);
    virtual bool SupportsSendFrom(void) const;
    virtual void SetReceiveCallback(NetDevice::ReceiveCallback cb);
    bool Attach(CudaP2PChannel *channel);
    void SetDataRate(DataRate bps);
    Ptr<Node> GetNode() const;
    void SetNode(Ptr<Node> node);
    void Receive();

    // GPU-specific methods
    void InitializeCudaBuffers();
    void OffloadPacketProcessing();
    __device__ void test(const uint8_t *data, CUDA_cb_data* cb_data);
    __device__ void Send(const uint8_t* packet, uint32_t size);
    __device__ bool TransmitStart(const uint8_t* packet, uint32_t size, CUDA_cb_data* cb_data);
    // Helper functions
    __device__ void EnqueuePacket(const uint8_t* packet, uint32_t size);
    void TransmitPackets();

private:
    void ProcessPacketOnCuda(Ptr<Packet> packet);

    enum TxMachineState
    {
        READY, /**< The transmitter is ready to begin transmission of a packet */
        BUSY   /**< The transmitter is busy transmitting a packet */
    };

    TxMachineState m_txMachineState;

    bool m_linkUp;
    DataRate m_bps;
    uint64_t d_bps;
    Time m_tInterframeGap;
    Ptr<Node> m_node;

    // CUDA-related members
    cudaStream_t m_stream;
    uint8_t* d_packetQueue; // GPU packet queue
    NetDevice::ReceiveCallback m_rxCallback;
    CudaP2PChannel *m_channel;
    int* d_queueFront;
    int* d_queueRear;
    int m_queueSize;
};

} // namespace ns3

#endif // GPU_NET_DEVICE_H