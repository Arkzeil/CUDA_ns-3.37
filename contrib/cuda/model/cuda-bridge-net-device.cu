#include "cuda-bridge-net-device.h"
#include "ns3/cuda-helper.h"
#include "ns3/cuda-udp-client.h"
#include "ns3/cuda-packet.h"
#include "ns3/cuda-ipv4-l3-protocol.h"
#include "ns3/cuda-elp-simulator.h"
#include "ns3/cuda-bridge-net-device.h"

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
        cudaMallocManaged(&m_ports, sizeof(CudaNetDevice*) * maxPorts);
        cudaMallocManaged(&m_channel, sizeof(CudaP2PChannel*) * maxPorts);
        m_cudaSim = (CudaELPSimulator*)GetPointer(Simulator::GetImplementation());
    }
    CudaBridgeNetDevice::~CudaBridgeNetDevice() {
        // Destructor
        cudaFree(m_ports);
        cudaFree(m_channel);
        checkCudaErr();
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

    __device__ void CudaBridgeNetDevice::ReceiveFromDevice(CudaNetDevice* device,
                                                            CudaPacket* packet,
                                                            uint16_t protocol,
                                                            MACAddress& source,
                                                            MACAddress& destination,
                                                            PacketType packetType) {
        // Receive a packet from the device
        // This function is called from the GPU
        // Handle the received packet
        printf("Bridge received packet from device\n");
    }

    __host__ void CudaBridgeNetDevice::AddBridgePort(Ptr<NetDevice> bridgePort) {
        // Add a bridge port
        if (m_ports == nullptr){
            NS_FATAL_ERROR("CudaBridgeNetDevice::AddBridgePort(): No ports available");
        }

        if (!Mac48Address::IsMatchingType(bridgePort->GetAddress())){
            NS_FATAL_ERROR("CudaBridgeNetDevice::AddBridgePort(): Not a CudaNetDevice");
        }
        
        if (!bridgePort->SupportsSendFrom()){
            NS_FATAL_ERROR("Device does not support SendFrom: cannot be added to bridge.");
        }
        // why?
        if (m_address == Mac48Address()){
            m_address = Mac48Address::ConvertFrom(bridgePort->GetAddress());
        }

        CudaNetDevice *devicePtr = GetPointer(DynamicCast<CudaNetDevice>(bridgePort));
        // we have not implemented the callback mechanism in CUDA yet, use fixed callback for now
        devicePtr->register_callback(this);

        m_ports[portCnt] = devicePtr;
        m_channel[portCnt++] = devicePtr->GetChannel();
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
}