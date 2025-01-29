#include "cuda-udp-l4-protocol.h"
#include "ns3/ipv4-end-point-demux.h"
#include "ns3/ipv4-end-point.h"
#include "cuda-socket.h"
#include "cuda-ipv4-l3-protocol.h"
#include "cuda-udp-socket-factory-impl.h"
#include "ns3/cuda-helper.h"
#include "ns3/cuda-packet.h"
#include "ns3/cuda-ipv4-interface.h"
#include "ns3/cuda-ipv4-end-point.h"

namespace ns3 {
    NS_LOG_COMPONENT_DEFINE("CudaUdpL4Protocol");
    NS_OBJECT_ENSURE_REGISTERED(CudaUdpL4Protocol);
    __device__ CudaIpv4L3Protocol* d_m_ipv4 = nullptr;

    TypeId CudaUdpL4Protocol::GetTypeId(void) {
        static TypeId tid = TypeId("ns3::CudaUdpL4Protocol")
                            .SetParent<UdpL4Protocol>()
                            .SetGroupName("Internet")
                            .AddConstructor<CudaUdpL4Protocol>();
        return tid;
    }

    CudaUdpL4Protocol::CudaUdpL4Protocol(): m_ipv4(nullptr), m_node(nullptr), m_endPoints(nullptr), m_ephemeral(49152), index(0) {
        // Constructor
        // cudaMallocManaged(&m_downTarget, sizeof(DownDeviceFunctionPtr));
        printf("CudaUdpL4Protocol initialized\n");
        // m_ipv4 = new CudaIpv4L3Protocol();
        // // cudaMallocManaged(&m_ipv4, sizeof(CudaIpv4L3Protocol));
        // checkCudaErr();
        // cudaMemcpyToSymbol(d_m_ipv4, &m_ipv4, sizeof(CudaIpv4L3Protocol*));
        // // cudaMalloc(&d_m_ipv4, sizeof(CudaIpv4L3Protocol));
        // // cudaMemcpy(d_m_ipv4, m_ipv4, sizeof(CudaIpv4L3Protocol), cudaMemcpyHostToDevice);
        // checkCudaErr();
        // m_downTarget = CudaIpv4L3Protocol::Send;
        // Ptr<CudaIpv4L3Protocol> ipv4 = this->GetObject<CudaIpv4L3Protocol>();
        // m_downTarget = ipv4->Send();
        m_endPoints = new CudaIpv4EndPoint[10];
    }

    CudaUdpL4Protocol::~CudaUdpL4Protocol() {
        // Destructor
    }

    void CudaUdpL4Protocol::SetNode(Ptr<Node> node) {
        // Set the node
        NS_ASSERT(node);
        m_node = node;
        // if(m_ipv4 == nullptr){
        //     m_ipv4->SetNode(node);
        //     cudaMemcpyToSymbol(d_m_ipv4, &m_ipv4, sizeof(CudaIpv4L3Protocol));
        // }
    }

    CudaIpv4EndPoint* CudaUdpL4Protocol::Allocate() {
        // Allocate an IPv4 end point
        return &m_endPoints[index++];
    }

    CudaIpv4EndPoint* CudaUdpL4Protocol::Allocate(Ipv4Address address) {
        // Allocate an IPv4 end point
        m_endPoints[index].SetLocalAddress(address.Get());
        return &m_endPoints[index++];
    }

    CudaIpv4EndPoint* CudaUdpL4Protocol::Allocate(CudaNetDevice* boundNetDevice, uint16_t port) {
        // Allocate an IPv4 end point
        m_endPoints[index].BindToNetDevice(boundNetDevice);
        m_endPoints[index].SetLocalPort(port);
        return &m_endPoints[index++];
    }

    CudaIpv4EndPoint* CudaUdpL4Protocol::Allocate(CudaNetDevice* boundNetDevice, Ipv4Address address, uint16_t port) {
        // Allocate an IPv4 end point
        m_endPoints[index].BindToNetDevice(boundNetDevice);
        m_endPoints[index].SetLocalAddress(address.Get());
        m_endPoints[index].SetLocalPort(port);
        return &m_endPoints[index++];
    }

    CudaIpv4EndPoint* CudaUdpL4Protocol::Allocate(CudaNetDevice* boundNetDevice, Ipv4Address localAddress, uint16_t localPort, Ipv4Address peerAddress, uint16_t peerPort) {
        // Allocate an IPv4 end point
        m_endPoints[index].BindToNetDevice(boundNetDevice);
        m_endPoints[index].SetLocalAddress(localAddress.Get());
        m_endPoints[index].SetLocalPort(localPort);
        m_endPoints[index].SetPeerAddress(peerAddress.Get());
        m_endPoints[index].SetPeerPort(peerPort);
        return &m_endPoints[index++];
    }

    void CudaUdpL4Protocol::setDownTarget(DownDeviceFunctionPtr callback) {
        // Set the down target
        // m_downTarget = callback;
    }

    CudaSocket* CudaUdpL4Protocol::CreateSocket() {
        // Create a new socket
        CudaSocket* socket = new CudaSocket();
        // checkCudaErr();
        socket->SetNode(m_node);
        socket->SetUdp(this);
        m_sockets.push_back(socket);
        return socket;
    }

    __device__ void CudaUdpL4Protocol::test(const uint8_t *data, CUDA_cb_data* cb_data) {
        // Test function
        printf("UdpL4: Test function, packet0: %d\n", data[0]);
        // uint32_t a, b;
        // for(uint32_t i = 0; i < 1000000; i++){
        //     a = i / 2;
        //     b = a * i / 5;
        // }
        d_m_ipv4->test(data, cb_data);
    }

    __device__ void CudaUdpL4Protocol::Send(CudaPacket *d_packet, uint32_t saddr, uint32_t daddr, uint16_t sport, uint16_t dport, CUDA_cb_data* cb_data){
        // Send a packet
        // For simplicity, we will just print the packet contents
        // printf("Sending packet from %s to %s\n", saddr.GetLocal(), daddr.GetLocal());
        // printf("Packet contents: %s\n", packet);
        // call the send function of callback
        printf("UdpL4: Send function, packet id: %d\n", d_packet->GetUid());
        // d_m_ipv4->test(d_packet->m_data, cb_data);
        d_m_ipv4->Send(d_packet, saddr, daddr, 0, 0, cb_data);
        // printf("Udp Prorocol: Sending packet from %d:%d to %d:%d\n", saddr.Get(), sport, daddr.Get(), dport);
    }

    __device__ void CudaUdpL4Protocol::Receive(CudaPacket *packet, CudaIpv4Interface *interface){
        // Receive a packet
        printf("UdpL4: Receiving packet: %d\n", packet->GetUid());
        m_endPoints[0].GetSocket()->ForwardPacket(packet);
    }

    void CudaUdpL4Protocol::NotifyNewAggregate() {
        // Notify a new aggregate
        Ptr<Node> node = this->GetObject<Node>();
        Ptr<Ipv4> ipv4 = this->GetObject<Ipv4>();
        if(ipv4 == nullptr){
            printf("UdpL4: No Ipv4 object found\n");
            return;
        }
        if(node == nullptr){
            printf("UdpL4: No Node object found\n");
            return;
        }
        printf("UdpL4: Notify new aggregate\n");
        if(m_node == nullptr){
            if(node && ipv4){
                this->SetNode(node);
                Ptr<CudaUdpSocketFactoryImpl> socketFactory = CreateObject<CudaUdpSocketFactoryImpl>();
                if(socketFactory == nullptr){
                    printf("Failed to create socket factory\n");
                    return;
                }
                socketFactory->SetUdp(this);
                node->AggregateObject(socketFactory);
            }
        }
        if(m_ipv4 == nullptr){
            m_ipv4 = GetPointer(DynamicCast<CudaIpv4L3Protocol>(ipv4));
            m_ipv4->SetNode(node);
            cudaMemcpyToSymbol(d_m_ipv4, &m_ipv4, sizeof(CudaIpv4L3Protocol*));
            checkCudaErr();
        }

        if(ipv4){
            GetPointer(DynamicCast<CudaIpv4L3Protocol>(ipv4))->Insert(this);
        }
        // Ptr<Ipv6> ipv6 = node->GetObject<Ipv6>();
    }

    // void CudaUdpL4Protocol::Receive(Ptr<Packet> packet, const Address& src, const Address& dst) {
    //     // Receive a packet
    //     // For simplicity, we will just print the packet contents
    //     printf("Receiving packet from %s to %s\n", src.GetIpv4().GetLocal(), dst.GetIpv4().GetLocal());
    //     uint8_t* buffer = new uint8_t[packet->GetSize()];
    //     packet->CopyData(buffer, packet->GetSize());
    //     printf("Packet contents: %s\n", buffer);
    // }
}