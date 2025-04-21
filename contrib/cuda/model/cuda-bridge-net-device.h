#ifndef CUDA_BRIDGE_NET_DEVICE_H
#define CUDA_BRIDGE_NET_DEVICE_H

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
#include "ns3/cuda-net-device.h"

#define MAX_MAC_ENTRIES 16 

namespace ns3{
    class CudaPacket;
    class CudaELPSimulator;
    class CudaIpv4L3Protocol;
    class CudaNetDevice;

    // struct EthernetHeader {
    //     uint8_t dst[6];    // Destination MAC
    //     uint8_t src[6];    // Source MAC
    //     uint16_t ethType;  // EtherType (e.g., 0x0800 for IPv4)
    // };

    class CudaBridgeNetDevice: public CudaNetDevice, public virtual Managed{
        public:
            static TypeId GetTypeId(void);

            CudaBridgeNetDevice();
            virtual ~CudaBridgeNetDevice();

            // Overridden methods for packet transmission
            void SetIfIndex(const uint32_t index) override;
            uint32_t GetIfIndex() const override;
            void SetAddress(Address address) override;
            Address GetAddress() const override;
            virtual bool Send(Ptr<Packet> packet, const Address& dest, uint16_t protocolNumber);
            virtual bool SupportsSendFrom(void) const;
            virtual void SetReceiveCallback(NetDevice::ReceiveCallback cb);
            bool SetMtu(const uint16_t mtu) override;
            uint16_t GetMtu() const override;
            Ptr<Node> GetNode() const override;
            void SetNode(Ptr<Node> node);
            __device__ void ReceiveFromDevice(CudaNetDevice* device,
                                                CudaPacket* packet,
                                                uint16_t protocol,
                                                MACAddress& source,
                                                MACAddress& destination,
                                                PacketType packetType);
            __host__ void AddBridgePort(Ptr<NetDevice> bridgePort) override;

            __host__ __device__ void Learn(MACAddress source, CudaNetDevice* port);
            __host__ __device__ CudaNetDevice* GetLearnedState(MACAddress source);
            __device__ void ForwardUnicast(CudaNetDevice* incomingPort,
                                            CudaPacket* packet,
                                            uint16_t protocol,
                                            MACAddress src,
                                            MACAddress dst);

            // GPU-specific methods
            CudaP2PChannel* GetChannel();
            __device__ void Send(CudaPacket* d_packet, uint32_t destination, uint16_t protocol, CUDA_cb_data* cb_data);
            __device__ bool TransmitStart(CudaPacket* packet, CUDA_cb_data* cb_data);

        private:
            static const uint16_t DEFAULT_MTU = 1500; //!< Default MTU
            Mac48Address m_address;                              //!< Mac48Address of this NetDevice

            uint32_t m_ifIndex;                                  //!< Index of the interface
            bool m_linkUp;
            DataRate m_bps;
            uint64_t d_bps;
            Time m_tInterframeGap;
            Ptr<Node> m_node;
            uint32_t m_mtu;
            NetDevice::ReceiveCallback m_rxCallback;
            bool m_enableLearning;

            /**
             * \ingroup bridge
             * Structure holding the status of an address
             */
            struct  LearnedState
            {
                MACAddress mac;                     //!< MAC address
                CudaNetDevice* associatedPort;      //!< port associated with the address
                uint64_t expirationTime;           //!< time it takes for learned MAC state to expire(ns)
            };

            CudaNetDevice** m_ports; //!< Pointer to the CUDA net device, which is used to send packets as part of the bridge(port)

            LearnedState* m_learningTable; //!< Container for known address statuses
            // CUDA-related members
            CudaELPSimulator* m_cudaSim; //!< CUDA simulator
            CudaIpv4L3Protocol* m_ipv4; //!< Pointer to the IPv4 L3 protocol, used for packet receive as we currently do not adopting callback mechanism
            cudaStream_t m_stream;
            CudaP2PChannel **m_channel;
            uint32_t NodeID;
            uint32_t portCnt = 0;
            uint32_t tableSize = 0;
    };
}

#endif