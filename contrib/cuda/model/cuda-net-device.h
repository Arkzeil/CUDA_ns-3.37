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
class CudaELPSimulator;
class CudaIpv4L3Protocol;
class CudaBridgeNetDevice;

class alignas(8) MACAddress: public Managed{
    public:
        __host__ __device__ MACAddress() = default;
        __host__ __device__ MACAddress(uint8_t mac[6]){
            for (int i = 0; i < 6; ++i) {
                addr[i] = mac[i];
            }
        }
        uint8_t addr[6];
        __host__ __device__ bool operator==(const MACAddress& other) const {
            for (int i = 0; i < 6; ++i) {
                if (addr[i] != other.addr[i]) {
                    return false;
                }
            }
            return true;
        }
};

class CudaNetDevice : public PointToPointNetDevice, public virtual Managed{
public:
    static TypeId GetTypeId(void);

    CudaNetDevice();
    virtual ~CudaNetDevice();

    // Overridden methods for packet transmission
    void SetIfIndex(const uint32_t index) override;
    uint32_t GetIfIndex() const override;
    void SetAddress(Address address) override;
    Address GetAddress() const override;
    // got 'function returning array is not allowed' when trying to return uint8_t [6]
    MACAddress GetMacAddress() const;
    virtual bool Send(Ptr<Packet> packet, const Address& dest, uint16_t protocolNumber);
    virtual bool SupportsSendFrom(void) const;
    virtual void SetReceiveCallback(NetDevice::ReceiveCallback cb);
    __host__ virtual void AddBridgePort(Ptr<NetDevice> bridgePort);
    bool Attach(CudaP2PChannel *channel);
    void SetDataRate(DataRate bps);
    bool SetMtu(const uint16_t mtu) override;
    uint16_t GetMtu() const override;
    Ptr<Node> GetNode() const override;
    void SetNode(Ptr<Node> node);
    __device__ bool d_IsBroadcast() const;
    __device__ MACAddress d_GetBroadcast() const;
    __device__ bool d_NeedsArp() const;
    void Receive(CudaPacket *packet);
    // __device__ virtual void ReceiveFromDevice();
    __device__ void d_Receive(CudaPacket *packet);

    // GPU-specific methods
    void InitializeCudaBuffers();
    void OffloadPacketProcessing();
    __host__ __device__ uint64_t GetBandwidth();
    // we have not implement callback mechanism for now, so the callback is actually pre-defined fixed function, 
    // this is just for setting the flag
    __host__ void register_callback(CudaNetDevice* device);
    __device__ void test(const uint8_t *data, CUDA_cb_data* cb_data);
    __device__ void Send(CudaPacket* d_packet, MACAddress destination, uint16_t protocol, CUDA_cb_data* cb_data);
    __device__ void SendFrom(CudaPacket* d_packet, MACAddress src, MACAddress dst, uint16_t protocol);
    __device__ bool TransmitStart(CudaPacket* packet, CUDA_cb_data* cb_data);
    __device__ void D_TransmitComplete();
    void TransmitComplete(cudaStream_t stream);
    // Helper functions
    __device__ bool EnqueuePacket(CudaPacket* packet);
    __device__ CudaPacket* DequeuePacket();
    void TransmitPackets();
    CudaP2PChannel* GetChannel();

    uint64_t lookahead;

    enum PacketType
    {
        PACKET_HOST = 1, //!< Packet addressed to us
        NS3_PACKET_HOST = PACKET_HOST,
        PACKET_BROADCAST, //!< Packet addressed to all
        NS3_PACKET_BROADCAST = PACKET_BROADCAST,
        PACKET_MULTICAST, //!< Packet addressed to multicast group
        NS3_PACKET_MULTICAST = PACKET_MULTICAST,
        PACKET_OTHERHOST, //!< Packet addressed to someone else
        NS3_PACKET_OTHERHOST = PACKET_OTHERHOST,
    };
    
private:
    void ProcessPacketOnCuda(Ptr<Packet> packet);

    static const uint16_t DEFAULT_MTU = 1500; //!< Default MTU

    enum TxMachineState
    {
        READY, /**< The transmitter is ready to begin transmission of a packet */
        BUSY   /**< The transmitter is busy transmitting a packet */
    };

    TxMachineState m_txMachineState;
    Mac48Address m_address;                              //!< Mac48Address of this NetDevice

    uint32_t m_ifIndex;                                  //!< Index of the interface
    bool m_linkUp;
    DataRate m_bps;
    uint64_t d_bps;
    Time m_tInterframeGap;
    Ptr<Node> m_node;
    uint32_t m_mtu;

    // CUDA-related members
    CudaELPSimulator* m_cudaSim; //!< CUDA simulator
    MACAddress m_macAddress;                            //!< MAC address of this NetDevice
    CudaIpv4L3Protocol* m_ipv4; //!< Pointer to the IPv4 L3 protocol, used for packet receive as we currently do not adopting callback mechanism
    cudaStream_t m_stream;
    cudaEvent_t m_event;        // !< CUDA event to synchronize packet enqueueing
    CudaPacket** d_packetQueue; // GPU packet queue
    NetDevice::ReceiveCallback m_rxCallback;
    CudaP2PChannel *m_channel;
    int* d_queueFront;
    int* d_queueRear;
    int m_queueSize;
    uint32_t NodeID;
    CudaNetDevice* bridge;
    // we have not implement callback mechanism for now, use a simple flag and pre-defined callback first
    bool m_rxCB_enable; //!< Enable or disable the recv callback of the device
};

} // namespace ns3

#endif // GPU_NET_DEVICE_H