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
class CudaPacket;

class CudaNetDevice : public PointToPointNetDevice, public Managed{
public:
    static TypeId GetTypeId(void);

    CudaNetDevice();
    virtual ~CudaNetDevice();

    // Overridden methods for packet transmission
    void SetAddress(Address address) override;
    Address GetAddress() const override;
    virtual bool Send(Ptr<Packet> packet, const Address& dest, uint16_t protocolNumber);
    virtual bool SupportsSendFrom(void) const;
    virtual void SetReceiveCallback(NetDevice::ReceiveCallback cb);
    bool Attach(CudaP2PChannel *channel);
    void SetDataRate(DataRate bps);
    Ptr<Node> GetNode() const override;
    void SetNode(Ptr<Node> node);
    void Receive(CudaPacket *packet);

    // GPU-specific methods
    void InitializeCudaBuffers();
    void OffloadPacketProcessing();
    __device__ void test(const uint8_t *data, CUDA_cb_data* cb_data);
    __device__ void Send(CudaPacket* d_packet, uint32_t destination, uint16_t protocol, CUDA_cb_data* cb_data);
    __device__ bool TransmitStart(CudaPacket* packet, CUDA_cb_data* cb_data);
    void TransmitComplete(cudaStream_t stream);
    // Helper functions
    __device__ bool EnqueuePacket(CudaPacket* packet);
    __device__ CudaPacket* DequeuePacket();
    void TransmitPackets();

private:
    void ProcessPacketOnCuda(Ptr<Packet> packet);

    enum TxMachineState
    {
        READY, /**< The transmitter is ready to begin transmission of a packet */
        BUSY   /**< The transmitter is busy transmitting a packet */
    };

    TxMachineState m_txMachineState;
    Mac48Address m_address;                              //!< Mac48Address of this NetDevice

    bool m_linkUp;
    DataRate m_bps;
    uint64_t d_bps;
    Time m_tInterframeGap;
    Ptr<Node> m_node;

    // CUDA-related members
    cudaStream_t m_stream;
    cudaEvent_t m_event;        // !< CUDA event to synchronize packet enqueueing
    CudaPacket** d_packetQueue; // GPU packet queue
    NetDevice::ReceiveCallback m_rxCallback;
    CudaP2PChannel *m_channel;
    int* d_queueFront;
    int* d_queueRear;
    int m_queueSize;
};

} // namespace ns3

#endif // GPU_NET_DEVICE_H