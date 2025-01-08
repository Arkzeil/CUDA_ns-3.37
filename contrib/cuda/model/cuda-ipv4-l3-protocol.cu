#include "cuda-ipv4-l3-protocol.h"
#include "ns3/node.h"
#include "cuda-ipv4-interface.h"

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
        // m_protocols.push_back(protocol);
    }

    void CudaIpv4L3Protocol::Insert(Ptr<IpL4Protocol> protocol, uint32_t interfaceIndex) {
        // Insert an IP L4 protocol with an interface index
        // m_protocols.push_back(protocol);
    }

    void CudaIpv4L3Protocol::Remove(Ptr<IpL4Protocol> protocol) {
        // Remove an IP L4 protocol
        // m_protocols.erase(std::remove(m_protocols.begin(), m_protocols.end(), protocol), m_protocols.end());
    }

    void CudaIpv4L3Protocol::SetNode(Ptr<Node> node) {
        // Set the node
        m_node = node;
    }

    uint32_t CudaIpv4L3Protocol::AddInterface(CudaNetDevice* device) {
        // Add an interface
        // m_interfaces.push_back(device);
        // Should also set traffic control layer, skip for now
        CudaIpv4Interface *interface = new CudaIpv4Interface();
        interface->SetDevice(device);
        interface->SetNode(m_node);
        AddIpv4Interface(interface);
        return 0;
    }

    uint32_t CudaIpv4L3Protocol::AddIpv4Interface(CudaIpv4Interface* interface) {
        // Add an IPv4 interface
        m_ipv4Interfaces.push_back(interface);
        return 0;
    }

    CudaIpv4Interface* CudaIpv4L3Protocol::GetInterface(uint32_t interfaceIndex) const {
        // Get an interface
        if(interfaceIndex < m_ipv4Interfaces.size()){
            return m_ipv4Interfaces[interfaceIndex];
        }
        return nullptr;
    }

    int32_t CudaIpv4L3Protocol::GetInterfaceForDevice(CudaNetDevice* device) {
        // Get the interface for a device
        for(uint32_t i = 0; i < m_ipv4Interfaces.size(); i++){
            if(m_ipv4Interfaces[i]->GetDevice() == device){
                return i;
            }
        }
        return -1;
    }

    bool CudaIpv4L3Protocol::AddAddress(uint32_t interfaceIndex, Ipv4InterfaceAddress address) {
        // Add an address to an interface
        CudaIpv4Interface* interface = GetInterface(interfaceIndex);
        if(interface != nullptr){
            interface->SetAddress(address);
            return true;
        }
        return false;
    }

    Ipv4InterfaceAddress CudaIpv4L3Protocol::GetAddress(uint32_t interfaceIndex, uint32_t addressIndex) const {
        // Get an address
        CudaIpv4Interface* interface = GetInterface(interfaceIndex);
        // currently only one address per interface
        if(interface != nullptr){
            return interface->GetAddress();
        }
        return Ipv4InterfaceAddress();
    }

    void CudaIpv4L3Protocol::SetMetric(uint32_t i, uint16_t metric) {
        // Set the metric
        CudaIpv4Interface* interface = GetInterface(i);
        if(interface != nullptr){
            interface->SetMetric(metric);
        }
        // m_metrics[i] = metric;
    }

    void CudaIpv4L3Protocol::SetUp(uint32_t interfaceIndex) {
        // Set the interface up
        CudaIpv4Interface* interface = GetInterface(interfaceIndex);
        if(interface != nullptr){
            interface->SetUp();
        }
    }

    void CudaIpv4L3Protocol::SetDown(uint32_t interfaceIndex) {
        // Set the interface down
        CudaIpv4Interface* interface = GetInterface(interfaceIndex);
        if(interface != nullptr){
            interface->SetDown();
        }
    }

    void CudaIpv4L3Protocol::SetForwarding(uint32_t interfaceIndex, bool enable) {
        // Set forwarding
        // m_forwarding[interfaceIndex] = enable;
    }

    // void CudaIpv4L3Protocol::Send(const uint8_t *packet, Ipv4Address source, Ipv4Address destination, uint8_t protocol, Ptr<Ipv4Route> route) {
    //     // Send a packet
    //     // For simplicity, we will just print the packet contents
    //     // printf("Sending packet from %s to %s\n", source.GetLocal(), destination.GetLocal());
    //     printf("Packet contents: %s\n", packet);
    // }
    __device__ void CudaIpv4L3Protocol::test() {
        // Test function
        printf("Ipv4L3: Test function\n");
        // uint32_t a, b;
        // for(uint32_t i = 0; i < 10000000; i++){
        //     a = i;
        //     b = a + 1;
        // }
    }
    __device__ void CudaIpv4L3Protocol::Send(const uint8_t *packet, uint32_t source, uint32_t destination, uint8_t protocol, uint32_t route) {
        // Send a packet
        // For simplicity, we will just print the packet contents
        // printf("Sending packet from %s to %s\n", source.GetLocal(), destination.GetLocal());
        printf("CudaIpv4L3Protocol: Packet sending\n");
    }

    void CudaIpv4L3Protocol::SendRealOut(Ptr<Ipv4Route> route, Ptr<Packet> packet, const Ipv4Header& ipHeader) {
        // Send a packet out
        // For simplicity, we will just print the packet contents
        printf("Sending packet out\n");
    }

    void CudaIpv4L3Protocol::DoDispose() {
        // Dispose of the object
    }

    void CudaIpv4L3Protocol::NotifyNewAggregate() {
        printf("CudaIpv4L3Protocol: New aggregate\n");
        // Notify of a new aggregate
        if(m_node == nullptr){
            Ptr<Node> node = this->GetObject<Node>();
            // verify that it's a valid node and that
            // the node has not been set before
            if(node)
                this->SetNode(node);
        }
    }
}