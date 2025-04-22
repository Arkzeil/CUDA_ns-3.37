#ifndef CUDA_ARP_L3_PROTOCOL_H
#define CUDA_ARP_L3_PROTOCOL_H

#include "ns3/ipv4-interface.h"
#include "ns3/ipv4-address.h"
#include "ns3/ipv4-interface-address.h"
#include "ns3/ptr.h"
#include "ns3/net-device.h"
#include "ns3/node.h"
#include "ns3/traffic-control-layer.h"
#include <cuda_runtime.h>
#include "helper.h"

namespace ns3{
    class CudaNetDevice;
    class CudaPacket;
    class CudaIpv4Interface;
    class MACAddress;

    class CudaArpL3Protocol{
        public:
            CudaArpL3Protocol();
            ~CudaArpL3Protocol();

            void SetNode(Ptr<Node> node);
            void SetDevice(Ptr<CudaNetDevice> device);
            void SetInterface(Ptr<CudaIpv4Interface> interface);

            __device__ void ProcessPacket(CudaPacket* packet, CudaNetDevice* device, uint16_t protocol, MACAddress& source, MACAddress& destination, PacketType packetType);
            __device__ void SendArpRequest(MACAddress to);
            __device__ void SendArpReply(MACAddress myIp, MACAddress toIp, Address toMac);

        private:
            Ptr<Node> m_node;
            Ptr<CudaNetDevice> m_device;
            Ptr<CudaIpv4Interface> m_interface;
    };
}

#endif /* CUDA_ARP_L3_PROTOCOL_H */