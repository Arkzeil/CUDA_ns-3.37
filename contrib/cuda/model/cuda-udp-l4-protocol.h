#ifndef CUDA_UDP_L4_PROTOCOL_H
#define CUDA_UDP_L4_PROTOCOL_H

#include "ns3/udp-l4-protocol.h"
#include <cuda_runtime.h>
#include "helper.h"
// #include "ns3/udp-socket-factory-impl.h"

namespace ns3
{
    class Ipv4EndPointDemux;
    class Ipv4EndPoint;
    class CudaSocket;
    typedef Callback<void, const uint8_t, uint32_t, uint32_t, uint8_t, uint32_t> DownTargetCallback;
    
    class CudaUdpL4Protocol : public UdpL4Protocol, public Managed{
        public:
            static TypeId GetTypeId(void);
            static const uint8_t PROT_NUMBER; //!< protocol number (0x11)

            CudaUdpL4Protocol();
            ~CudaUdpL4Protocol() override;

            void SetNode(Ptr<Node> node);
            Ipv4EndPoint* Allocate();

            void setDownTarget(DownTargetCallback callback);

            // Delete copy constructor and assignment operator to avoid misuse
            CudaUdpL4Protocol(const CudaUdpL4Protocol &) = delete;
            CudaUdpL4Protocol &operator=(const CudaUdpL4Protocol &) = delete;

            CudaSocket* CreateSocket();
            __device__ void test();
            __device__ void Send(const uint8_t* packet, Ipv4Address saddr, Ipv4Address daddr, uint16_t sport, uint16_t dport);

        
        private:
            Ptr<Node> m_node; //!< the node this stack is associated with
            Ipv4EndPointDemux *m_endPoints; //!< A list of IPv4 end points.
            // Ptr<CudaUdpSocketFactoryImpl> m_socketFactory;
            std::vector<CudaSocket*> m_sockets; //!< list of sockets
            DownTargetCallback m_downTarget;   //!< Callback to send packets over IPv4
    };
} // namespace ns3

#endif // CUDA_UDP_L4_PROTOCOL_H