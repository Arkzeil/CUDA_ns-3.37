#include "cuda-bridge-net-device.h"
#include "cuda-ipv4-l3-protocol.h"
#include "cuda-net-device.h"

namespace ns3 {
    NS_LOG_COMPONENT_DEFINE("CudaBridgeNetDevice");
    NS_OBJECT_ENSURE_REGISTERED(CudaBridgeNetDevice);

    TypeId CudaBridgeNetDevice::GetTypeId(void) {
        // Get the type ID
        static TypeId tid = TypeId("ns3::CudaBridgeNetDevice")
                            .SetParent<CudaNetDevice>()
                            .SetGroupName("cuda")
                            .AddConstructor<CudaBridgeNetDevice>();
        return tid;
    }
    CudaBridgeNetDevice::CudaBridgeNetDevice() : m_linkUp(false) {
        // Constructor
        printf("CudaBridgeNetDevice initialized\n");
        cudaMallocManaged(&m_ports, sizeof(CudaNetDevice) * maxPorts);
        m_cudaSim = (CudaELPSimulator*)GetPointer(Simulator::GetImplementation());
    }
    CudaBridgeNetDevice::~CudaBridgeNetDevice() {
        // Destructor
        printf("CudaBridgeNetDevice destroyed\n");
    }
    void CudaBridgeNetDevice::SetNode(Ptr<Node> node) {
        // Set the node
        m_node = node;
    }
    void CudaBridgeNetDevice::SetIfIndex(const uint32_t index) {
        // Set the interface index
        m_ifIndex = index;
    }
    uint32_t CudaBridgeNetDevice::GetIfIndex(void) const {
        // Get the interface index
        return m_ifIndex;
    }
    void CudaBridgeNetDevice::SetAddress(Address address) {
        // Set the MAC address
        m_address = Mac48Address::ConvertFrom(address);
    }
    Address CudaBridgeNetDevice::GetAddress() const {
        // Get the MAC address
        return m_address;
    }
    bool CudaBridgeNetDevice::Send(Ptr<Packet> packet, const Address& dest, uint16_t protocolNumber){
        // Send a packet
        if (!m_linkUp) {
            NS_LOG_ERROR("Link is down");
            return false;
        }
        // Send the packet to the destination address
        NS_LOG_INFO("Sending packet to " << dest);
        return true;
    }

    bool CudaBridgeNetDevice::SupportsSendFrom(void) const {
        // Check if the device supports sending from
        return true;
    }

    void CudaBridgeNetDevice::SetReceiveCallback(ReceiveCallback callback) {
        // Set the receive callback
        m_rxCallback = callback;
    }

    bool CudaBridgeNetDevice::SetMtu(uint16_t mtu) {
        // Set the MTU
        m_mtu = mtu;
        return true;
    }
    uint16_t CudaBridgeNetDevice::GetMtu(void) const {
        // Get the MTU
        return m_mtu;
    }
    Ptr<Node> CudaBridgeNetDevice::GetNode(void) const {
        // Get the node
        return m_node;
    }
    void CudaBridgeNetDevice::SetNode(Ptr<Node> node) {
        // Set the node
        m_node = node;
        m_ipv4 = (CudaIpv4L3Protocol*)GetPointer(node->GetObject<Ipv4>());
        NodeID = node->GetId();
    }
}