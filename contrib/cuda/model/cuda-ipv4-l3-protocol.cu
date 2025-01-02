#include "cuda-ipv4-l3-protocol.h"

namespace ns3 {
    NS_LOG_COMPONENT_DEFINE("CudaIpv4L3Protocol");
    NS_OBJECT_ENSURE_REGISTERED(CudaIpv4L3Protocol);

    TypeId CudaIpv4L3Protocol::GetTypeId(void) {
        static TypeId tid = TypeId("ns3::CudaIpv4L3Protocol")
                            .SetParent<Ipv4L3Protocol>()
                            .SetGroupName("Internet")
                            .AddConstructor<CudaIpv4L3Protocol>();
        return tid;
    }

    CudaIpv4L3Protocol::CudaIpv4L3Protocol() {
        // Constructor
    }

    CudaIpv4L3Protocol::~CudaIpv4L3Protocol() {
        // Destructor
    }

    void CudaIpv4L3Protocol::Insert(Ptr<IpL4Protocol> protocol) {
        // Insert an IP L4 protocol
        m_protocols.push_back(protocol);
    }

    void CudaIpv4L3Protocol::Insert(Ptr<IpL4Protocol> protocol, uint32_t interfaceIndex) {
        // Insert an IP L4 protocol with an interface index
        m_protocols.push_back(protocol);
    }

    void CudaIpv4L3Protocol::Remove(Ptr<IpL4Protocol> protocol) {
        // Remove an IP L4 protocol
        m_protocols.erase(std::remove(m_protocols.begin(), m_protocols.end(), protocol), m_protocols.end());
    }

    void CudaIpv4L3Protocol::SetNode(Ptr<Node> node) {
        // Set the node
        m_node = node;
    }

    void CudaIpv4L3Protocol::Send(const uint8_t *packet, Ipv4Address source, Ipv4Address destination, uint8_t protocol, Ptr<Ipv4Route> route) {
        // Send a packet
        // For simplicity, we will just print the packet contents
        printf("Sending packet from %s to %s\n", source.GetLocal(), destination.GetLocal());
        printf("Packet contents: %s\n", packet);
    }

    void CudaIpv4L3Protocol::SendRealOut(Ptr<Ipv4Route> route, Ptr<Packet> packet, const Ipv4Header& ipHeader) {
        // Send a packet out
        // For simplicity, we will just print the packet contents
        printf("Sending packet out\n");
    }
}