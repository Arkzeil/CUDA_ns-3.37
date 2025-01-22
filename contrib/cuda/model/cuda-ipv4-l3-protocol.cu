#include "cuda-ipv4-l3-protocol.h"
#include "ns3/node.h"
#include "cuda-ipv4-interface.h"
#include "ns3/cuda-helper.h"
#include "ns3/cuda-net-device.h"
#include "ns3/cuda-packet.h"

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

    CudaIpv4L3Protocol::CudaIpv4L3Protocol(): m_node(nullptr), m_interfaceCount(0) {
        // Constructor
        printf("CudaIpv4L3Protocol initialized\n");
        cudaMallocManaged(&m_ipv4Interface, m_maxInterfaceCount * sizeof(CudaIpv4Interface*));
        checkCudaErr();
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
        m_node->RegisterProtocolHandler(MakeCallback(&CudaIpv4L3Protocol::Receive, this), 0, device);

        CudaIpv4Interface *interface = new CudaIpv4Interface();
        interface->SetDevice(device);
        interface->SetNode(m_node);
        return AddIpv4Interface(interface);
    }

    uint32_t CudaIpv4L3Protocol::AddIpv4Interface(CudaIpv4Interface* interface) {
        // Add an IPv4 interface
        // m_ipv4Interfaces.push_back(interface);
        m_ipv4Interface[m_interfaceCount++] = interface;
        return m_interfaceCount - 1;
    }

    __host__ __device__ CudaIpv4Interface* CudaIpv4L3Protocol::GetInterface(uint32_t interfaceIndex) const {
        // Get an interface
        // if(interfaceIndex < m_ipv4Interfaces.size()){
        //     return m_ipv4Interfaces[interfaceIndex];
        // }
        if(interfaceIndex < m_interfaceCount){
            return m_ipv4Interface[interfaceIndex];
        }
        return nullptr;
    }

    __host__ __device__ int32_t CudaIpv4L3Protocol::GetInterfaceForDevice(CudaNetDevice* device) {
        // Get the interface for a device
        // for(uint32_t i = 0; i < m_ipv4Interfaces.size(); i++){
        //     if(m_ipv4Interfaces[i]->GetDevice() == device){
        //         return i;
        //     }
        // }
        for(uint32_t i = 0; i < m_interfaceCount; i++){
            printf("index: %d\n", i);
            if(m_ipv4Interface[i]->GetDevice() == device){
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
    void CudaIpv4L3Protocol::Receive(Ptr<NetDevice> device, CudaPacket *packet, uint16_t protocol, const Address& from, const Address& to, NetDevice::PacketType packetType) {
        // Receive a packet
        // For simplicity, we will just print the packet contents
        printf("Ipv4L3: Received packet\n");
        // printf("Packet contents: %s\n", packet);
    }

    __device__ void CudaIpv4L3Protocol::test(const uint8_t *data, CUDA_cb_data* cb_data) {
        // Test function
        printf("Ipv4L3: Test function, packet0: %d\n", data[0]);

        // assume output device is 0
        // CudaNetDevice *device = GetPointer(DynamicCast<CudaNetDevice>(m_node->GetDevice(0)));
        // int32_t interface = GetInterfaceForDevice(m_ipv4Interface[0]);
        // if(interface == -1){
        //     printf("No interface found for device\n");
        //     return;
        // }

        // assuming only one interface
        CudaIpv4Interface *outInterface = GetInterface(0);

        if(outInterface == nullptr){
            printf("No interface found\n");
            return;
        }

        if(outInterface->IsUp() == false){
            printf("Interface is down\n");
            return;
        }
        else{
            CudaNetDevice *device = outInterface->GetDevice();
            int32_t interface = GetInterfaceForDevice(device);
            if(interface == -1){
                printf("No device found for interface\n");
                return;
            }
            else{
                printf("device found\n");
            }

            outInterface->test(device, data, cb_data);
        }
        // uint32_t a, b;
        // for(uint32_t i = 0; i < 10000000; i++){
        //     a = i;
        //     b = a + 1;
        // }
    }
    __device__ void CudaIpv4L3Protocol::Send(CudaPacket *d_packet, uint32_t source, uint32_t destination, uint8_t protocol, uint32_t route, CUDA_cb_data* cb_data){
        // Send a packet
        // For simplicity, we will just print the packet contents
        // printf("Sending packet from %s to %s\n", source.GetLocal(), destination.GetLocal());
        printf("Ipv4L3: Send function, packet id: %d\n", d_packet->GetUid());

        // assuming only one interface
        CudaIpv4Interface *outInterface = GetInterface(0);

        if(outInterface == nullptr){
            printf("No interface found\n");
            return;
        }

        if(outInterface->IsUp() == false){
            printf("Interface is down\n");
            return;
        }
        else{
            CudaNetDevice *device = outInterface->GetDevice();
            int32_t interface = GetInterfaceForDevice(device);
            if(interface == -1){
                printf("No device found for interface\n");
                return;
            }
            else{
                printf("device found\n");
            }

            outInterface->Send(device, d_packet, 0, cb_data);
        }
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