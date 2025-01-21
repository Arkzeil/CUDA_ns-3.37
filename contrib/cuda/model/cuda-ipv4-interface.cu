#include "cuda-ipv4-interface.h"
#include "ns3/log.h"
#include "cuda-net-device.h"
#include "ns3/cuda-packet.h"

namespace ns3{
    NS_LOG_COMPONENT_DEFINE("CudaIpv4Interface");
    NS_OBJECT_ENSURE_REGISTERED(CudaIpv4Interface);

    TypeId CudaIpv4Interface::GetTypeId(void) {
        // Get the type ID
        static TypeId tid = TypeId("ns3::CudaIpv4Interface")
                            .SetParent<Ipv4Interface>()
                            .SetGroupName("Internet")
                            .AddConstructor<CudaIpv4Interface>();
        return tid;
    }

    CudaIpv4Interface::CudaIpv4Interface() : m_isUp(false) {
        // Constructor
        printf("CudaIpv4Interface initialized\n");
    }

    CudaIpv4Interface::~CudaIpv4Interface() {
        // Destructor
    }

    void CudaIpv4Interface::SetNode(Ptr<Node> node) {
        // Set the node
        m_node = node;
    }

    void CudaIpv4Interface::SetDevice(CudaNetDevice *device) {
        // Set the device
        m_device = device;
    }

    void CudaIpv4Interface::SetTrafficControlLayer(Ptr<TrafficControlLayer> tc) {
        // Set the traffic control layer
        m_tc = tc;
    }

    void CudaIpv4Interface::SetAddress(Ipv4InterfaceAddress address) {
        // Set the address
        m_address = address;
    }

    __host__ __device__ CudaNetDevice* CudaIpv4Interface::GetDevice(void) const {
        // Get the device
        return m_device;
    }

    Ptr<Node> CudaIpv4Interface::GetNode(void) const {
        // Get the node
        return m_node;
    }

    Ptr<TrafficControlLayer> CudaIpv4Interface::GetTrafficControlLayer(void) const {
        // Get the traffic control layer
        return m_tc;
    }

    Ipv4InterfaceAddress CudaIpv4Interface::GetAddress(void) const {
        // Get the address
        return m_address;
    }

    void CudaIpv4Interface::SetMetric(uint16_t metric) {
        // Set the metric
        m_metric = metric;
    }

    __device__ void CudaIpv4Interface::test(CudaNetDevice* device, const uint8_t *data, CUDA_cb_data* cb_data) {
        // Test the interface
        printf("CudaIpv4Interface test, packet0: %d\n", data[0]);
        device->test(data, cb_data);
    }

    __device__ void CudaIpv4Interface::Send(CudaNetDevice* device, CudaPacket *d_packet, uint32_t destination, CUDA_cb_data* cb_data) {
        // Send a packet
        printf("CudaIpv4Interface Send, packet0: %d\n", d_packet->m_data[0]);
        device->Send(d_packet, destination, 0, cb_data);
    }

    __host__ __device__ bool CudaIpv4Interface::IsUp(void) const {
        // Check if the interface is up
        return m_isUp;
    }

    void CudaIpv4Interface::SetUp(void) {
        // Set the interface up
        m_isUp = true;
    }

    void CudaIpv4Interface::SetDown(void) {
        // Set the interface down
        m_isUp = false;
    }

    // void CudaIpv4Interface::DoDispose(void) {
    //     // Dispose of the object
    //     m_device = nullptr;
    //     m_node = nullptr;
    //     m_tc = nullptr;
    //     m_address = Ipv4InterfaceAddress();
    //     m_isUp = false;
    // }
    
    // void CudaIpv4Interface::DoInitialize(void) {
    //     // Initialize the object
    // }

    // void CudaIpv4Interface::Receive(Ptr<Packet> packet, const Address& from) {
    //     // Receive a packet
    // }

    // void CudaIpv4Interface::Send(Ptr<Packet> packet, const Address& to, uint8_t protocolNumber) {
    //     // Send a packet
    // }
}