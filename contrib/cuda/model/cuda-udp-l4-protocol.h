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
    class CudaIpv4L3Protocol;
    class CUDA_cb_data;
    class CudaPacket;
    class CudaIpv4Interface;
    class CudaIpv4EndPoint;
    class CudaNetDevice;
    // class CudaList<CudaIpv4EndPoint*>;

    typedef void (*DownDeviceFunctionPtr)(const uint8_t*, uint32_t, uint32_t, uint8_t, uint32_t);

    // Consider using __attribute__((packed)) or ensure no padding if exact layout matters
    struct CudaUdpHeader {
        uint16_t sport;
        uint16_t dport;
        uint16_t length;
        uint16_t checksum;
    }; // 8 bytes

    struct CudaIpv4Header {
        // Standard 20-byte header fields (ensure correct order)
        uint8_t  version_ihl;
        uint8_t  dscp_ecn;
        uint16_t total_length;
        uint16_t identification;
        uint16_t flags_fragment_offset;
        uint8_t  ttl;
        uint8_t  protocol;
        uint16_t header_checksum;
        uint32_t saddr;
        uint32_t daddr;
        // Options would go here if used
    }; // 20 bytes

    struct CombinedIpUdpHeaders {
        CudaIpv4Header ip; // Outer header comes first in memory
        CudaUdpHeader udp; // Inner header follows
    }; // Total 28 bytes (for standard headers)
    
    class CudaUdpL4Protocol : public UdpL4Protocol, public Managed{
        public:
            static TypeId GetTypeId(void);
            static const uint8_t PROT_NUMBER; //!< protocol number (0x11)

            CudaUdpL4Protocol();
            ~CudaUdpL4Protocol() override;

            void SetNode(Ptr<Node> node);
            CudaIpv4L3Protocol* GetIpv4();
            CudaIpv4EndPoint* Allocate();
            CudaIpv4EndPoint* Allocate(Ipv4Address address);
            CudaIpv4EndPoint* Allocate(CudaNetDevice* boundNetDevice, uint16_t port);
            CudaIpv4EndPoint* Allocate(CudaNetDevice* boundNetDevice, Ipv4Address address, uint16_t port);
            CudaIpv4EndPoint* Allocate(CudaNetDevice* boundNetDevice, Ipv4Address localAddress, uint16_t localPort, Ipv4Address peerAddress, uint16_t peerPort);

            void setDownTarget(DownDeviceFunctionPtr callback);

            // Delete copy constructor and assignment operator to avoid misuse
            CudaUdpL4Protocol(const CudaUdpL4Protocol &) = delete;
            CudaUdpL4Protocol &operator=(const CudaUdpL4Protocol &) = delete;

            CudaSocket* CreateSocket();
            __device__ void test(const uint8_t *data, CUDA_cb_data* cb_data);
            __device__ int Send(CudaPacket *d_packet, uint32_t saddr, uint32_t daddr, uint16_t sport, uint16_t dport, CUDA_cb_data* cb_data);
            __device__ void Receive(CudaPacket *packet, uint8_t* Ipv4Header, CudaIpv4Interface *interface);
            __device__ int PrepareHeader(CudaUdpHeader* udp_hdr_ptr, uint32_t saddr, uint32_t daddr, uint16_t sport, uint16_t dport, uint16_t len, CUDA_cb_data* cb_data);
            __device__ int OptimizeSend(CudaPacket *d_packet, uint32_t saddr, uint32_t daddr, uint16_t sport, uint16_t dport, CUDA_cb_data* cb_data);
        protected:
            // void DoDispose() override;
            void NotifyNewAggregate() override;
        
        private:
            Ptr<Node> m_node; //!< the node this stack is associated with
            // Ipv4EndPointDemux *m_endPoints; //!< A list of IPv4 end points.
            // CudaList<CudaIpv4EndPoint*> m_endPoints; //!< A list of IPv4 end points.
            CudaIpv4EndPoint* m_endPoints; //!< A list of IPv4 end points.
            uint32_t m_ephemeral; //!< Ephemeral port number
            uint32_t index; //!< index of the end point
            CudaIpv4L3Protocol *m_ipv4; //!< A pointer to the IPv4 L3 protocol
            // Ptr<CudaUdpSocketFactoryImpl> m_socketFactory;
            std::vector<CudaSocket*> m_sockets; //!< list of sockets
            // DownDeviceFunctionPtr m_downTarget;   //!< Callback to send packets over IPv4
    };
} // namespace ns3

#endif // CUDA_UDP_L4_PROTOCOL_H