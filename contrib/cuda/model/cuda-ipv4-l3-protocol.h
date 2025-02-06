#ifndef CUDA_IPV4_L3_PROTOCOL_H
#define CUDA_IPV4_L3_PROTOCOL_H

#include "vector"
#include "ns3/ipv4-l3-protocol.h"
#include "helper.h"

namespace ns3{
    class CudaNetDevice;
    class CudaIpv4Interface;
    class CUDA_cb_data;
    class CudaPacket;
    class CudaUdpL4Protocol;

    class CudaIpv4L3Protocol : public Ipv4L3Protocol, public Managed{
        public:
            static TypeId GetTypeId(void);
            CudaIpv4L3Protocol();
            ~CudaIpv4L3Protocol() override;
            void Insert(Ptr<IpL4Protocol> protocol) override;
            void Insert(Ptr<IpL4Protocol> protocol, uint32_t interfaceIndex) override;
            void Remove(Ptr<IpL4Protocol> protocol) override;
            // cuda Insert, this is only for testing as only one protocol is used
            void Insert(CudaUdpL4Protocol* protocol);

            void SetNode(Ptr<Node> node);
            uint32_t AddInterface(Ptr<NetDevice> device);
            uint32_t AddIpv4Interface(CudaIpv4Interface* interface);
            __host__ __device__ int32_t GetInterfaceForDevice(CudaNetDevice* device);
            __host__ __device__ CudaIpv4Interface* GetInterface(uint32_t interfaceIndex) const;
            bool AddAddress(uint32_t interfaceIndex, Ipv4InterfaceAddress address);
            Ipv4InterfaceAddress GetAddress(uint32_t interfaceIndex, uint32_t addressIndex) const;
            void SetMetric(uint32_t i, uint16_t metric);
            void SetUp(uint32_t interfaceIndex);
            void SetDown(uint32_t interfaceIndex);
            void SetForwarding(uint32_t interfaceIndex, bool enable);
            // void Send(const uint8_t *packet, Ipv4Address source, Ipv4Address destination, uint8_t protocol, Ptr<Ipv4Route> route);
            void Receive(Ptr<NetDevice> device, CudaPacket *packet, uint16_t protocol, const Address& from, const Address& to, NetDevice::PacketType packetType);
            __device__ void test(const uint8_t *data, CUDA_cb_data* cb_data);
            __device__ void Send(CudaPacket *d_packet, uint32_t source, uint32_t destination, uint8_t protocol, uint32_t route, CUDA_cb_data* cb_data);
            void SendRealOut(Ptr<Ipv4Route> route, Ptr<Packet> packet, const Ipv4Header& ipHeader);
        
        protected:
            void DoDispose() override;
            void NotifyNewAggregate() override;

        private:
            Ptr<Node> m_node;
            // std::vector<CudaIpv4Interface*> m_ipv4Interfaces;
            CudaIpv4Interface** m_ipv4Interface;
            CudaUdpL4Protocol* m_udp;
            int m_interfaceCount;
            static const uint32_t m_maxInterfaceCount = 10;
            static const uint8_t m_defaultTtl = 64; 
    };
} // namespace ns3

#endif // CUDA_IPV4_L3_PROTOCOL_H