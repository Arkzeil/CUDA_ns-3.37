#include "cuda-udp-l4-protocol.h"
#include "ns3/ipv4-end-point-demux.h"
#include "ns3/ipv4-end-point.h"

namespace ns3 {
    NS_LOG_COMPONENT_DEFINE("CudaUdpL4Protocol");
    NS_OBJECT_ENSURE_REGISTERED(CudaUdpL4Protocol);

    TypeId CudaUdpL4Protocol::GetTypeId(void) {
        static TypeId tid = TypeId("ns3::CudaUdpL4Protocol")
                            .SetParent<UdpL4Protocol>()
                            .SetGroupName("Internet")
                            .AddConstructor<CudaUdpL4Protocol>();
        return tid;
    }

    CudaUdpL4Protocol::CudaUdpL4Protocol(): m_endPoints(new Ipv4EndPointDemux()) {
        // Constructor
    }

    CudaUdpL4Protocol::~CudaUdpL4Protocol() {
        // Destructor
    }

    void CudaUdpL4Protocol::SetNode(Ptr<Node> node) {
        // Set the node
        m_node = node;
    }

    Ipv4EndPoint* CudaUdpL4Protocol::Allocate() {
        // Allocate an IPv4 end point
        return m_endPoints->Allocate();
    }

    CudaSocket* CudaUdpL4Protocol::CreateSocket() {
        // Create a new socket
        CudaSocket* socket = new CudaSocket();
        socket->SetNode(m_node);
        socket->SetUdp(this);
        m_sockets.push_back(socket);
        return socket;
    }

    __device__ void Send(const uint8_t* packet, Ipv4Address saddr, Ipv4Address daddr, uint16_t sport, uint16_t dport){
        // Send a packet
        // For simplicity, we will just print the packet contents
        printf("Sending packet from %s to %s\n", src.GetIpv4().GetLocal(), dst.GetIpv4().GetLocal());
        uint8_t* buffer = new uint8_t[packet->GetSize()];
        packet->CopyData(buffer, packet->GetSize());
        printf("Packet contents: %s\n", buffer);
    }

    void CudaUdpL4Protocol::Receive(Ptr<Packet> packet, const Address& src, const Address& dst) {
        // Receive a packet
        // For simplicity, we will just print the packet contents
        printf("Receiving packet from %s to %s\n", src.GetIpv4().GetLocal(), dst.GetIpv4().GetLocal());
        uint8_t* buffer = new uint8_t[packet->GetSize()];
        packet->CopyData(buffer, packet->GetSize());
        printf("Packet contents: %s\n", buffer);
    }
}