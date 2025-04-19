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
                            .AddConstructor<CudaBridgeNetDevice>()
                            .AddAttribute("EnableLearning",
                                        "Enable the learning mode of the Learning Bridge",
                                        BooleanValue(true),
                                        MakeBooleanAccessor(&CudaBridgeNetDevice::m_enableLearning),
                                        MakeBooleanChecker());
        return tid;
    }
    CudaBridgeNetDevice::CudaBridgeNetDevice() : m_linkUp(false), m_enableLearning(true) {
        // Constructor
        printf("CudaBridgeNetDevice initialized\n");
        cudaMallocManaged(&m_ports, sizeof(CudaNetDevice*) * MAX_MAC_ENTRIES);
        cudaMallocManaged(&m_channel, sizeof(CudaP2PChannel*) * MAX_MAC_ENTRIES);
        cudaMallocManaged(&m_learningTable, sizeof(LearnedState) * MAX_MAC_ENTRIES);
        m_cudaSim = (CudaELPSimulator*)GetPointer(Simulator::GetImplementation());
    }
    CudaBridgeNetDevice::~CudaBridgeNetDevice() {
        // Destructor
        cudaFree(m_ports);
        cudaFree(m_channel);
        cudaFree(m_learningTable);
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
        // printf("Bridge received packet from device\n");

        switch(packetType) {
            case PacketType::PACKET_HOST:
            case PacketType::PACKET_BROADCAST:
            case PacketType::PACKET_MULTICAST:
            case PacketType::PACKET_OTHERHOST:
                ForwardUnicast(device, packet, protocol, source, destination);
                break;
        }
    }

    __device__ void CudaBridgeNetDevice::ForwardUnicast(CudaNetDevice* incomingPort,
                                                        CudaPacket* packet,
                                                        uint16_t protocol,
                                                        MACAddress src,
                                                        MACAddress dst) {
        Learn(src, incomingPort);
        CudaNetDevice* outgoingPort = GetLearnedState(dst);
        if (outgoingPort != nullptr) {
            // Forward the packet to the outgoing port
            // printf("Forwarding packet to outgoing port\n");
            outgoingPort->SendFrom(packet, src, dst, protocol);
        } else {
            // printf("Flooding packet to all ports\n");
            // Flood the packet to all ports except the incoming port
            for (uint32_t i = 0; i < portCnt; i++) {
                if (m_ports[i] != incomingPort) {
                    m_ports[i]->SendFrom(packet, src, dst, protocol);
                }
            }
        }
    }

    __host__ void CudaBridgeNetDevice::AddBridgePort(Ptr<NetDevice> bridgePort) {
        if(portCnt >= MAX_MAC_ENTRIES){
            NS_FATAL_ERROR("CudaBridgeNetDevice::AddBridgePort(): Maximum number of ports reached");
        }
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

    __host__ __device__ void CudaBridgeNetDevice::Learn(MACAddress source, CudaNetDevice* port) {
        // Learn the source MAC address and the port
        if (m_enableLearning) {
            if(tableSize >= MAX_MAC_ENTRIES){
                printf("CudaBridgeNetDevice::Learn(): Maximum number of entries reached");
                return;
            }

            // Check if the MAC address is already in the table
            for (uint32_t i = 0; i < tableSize; i++) {
                if (m_learningTable[i].mac == source) {
                    // Update the port if the MAC address is already in the table
                    m_learningTable[i].associatedPort = port;
                    return;
                }
            }
            // If the MAC address is not in the table, add it
            m_learningTable[tableSize].mac = source;
        }
    }

    __host__ __device__ CudaNetDevice* CudaBridgeNetDevice::GetLearnedState(MACAddress source) {
        // Get the learned state for the source MAC address
        for (uint32_t i = 0; i < tableSize; i++) {
            if (m_learningTable[i].mac == source) {
                return m_learningTable[i].associatedPort;
            }
        }
        return nullptr; // Not found
    }

    bool CudaBridgeNetDevice::Send(Ptr<Packet> packet, const Address& dest, uint16_t protocolNumber){
        // Send a packet
        if (!m_linkUp) {
            NS_LOG_ERROR("Link is down");
            return false;
        }
        // Send the packet to the destination address
        // NS_LOG_INFO("Sending packet to " << dest);
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