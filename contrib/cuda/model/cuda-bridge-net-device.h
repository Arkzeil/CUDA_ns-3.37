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

namespace ns3{
    class CudaPacket;
    class CudaELPSimulator;
    class CudaIpv4L3Protocol;

    class CudaBridgeNetDevice: public CudaNetDevice, public Managed{
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

            CudaNetDevice* m_ports; //!< Pointer to the CUDA net device, which is used to send packets as part of the bridge(port)

            // CUDA-related members
            CudaELPSimulator* m_cudaSim; //!< CUDA simulator
            CudaIpv4L3Protocol* m_ipv4; //!< Pointer to the IPv4 L3 protocol, used for packet receive as we currently do not adopting callback mechanism
            cudaStream_t m_stream;
            CudaP2PChannel *m_channel;
            uint32_t NodeID;
            uint32_t maxPorts = 10;
    };
}

#endif