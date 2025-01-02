#ifndef CUDA_IPV4_L3_PROTOCOL_H
#define CUDA_IPV4_L3_PROTOCOL_H

#include "ns3/ipv4-l3-protocol.h"
#include "helper.h"

namespace ns3{
    class CudaIpv4L3Protocol : public Ipv4L3Protocol, public Managed{
        public:
            static TypeId GetTypeId(void);
            CudaIpv4L3Protocol();
            ~CudaIpv4L3Protocol() override;
            void Insert(Ptr<IpL4Protocol> protocol) override;
            void Insert(Ptr<IpL4Protocol> protocol, uint32_t interfaceIndex) override;
            void Remove(Ptr<IpL4Protocol> protocol) override;
            void SetNode(Ptr<Node> node);
            void Send(const uint8_t *packet, Ipv4Address source, Ipv4Address destination, uint8_t protocol, Ptr<Ipv4Route> route);
            void SendRealOut(Ptr<Ipv4Route> route, Ptr<Packet> packet, const Ipv4Header& ipHeader);
        
        private:
            Ptr<Node> m_node;
    };
} // namespace ns3

#endif // CUDA_IPV4_L3_PROTOCOL_H