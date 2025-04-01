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
    // __device__ CudaIpv4L3Protocol* d_m_ipv4;
    /* see http://www.iana.org/assignments/protocol-numbers */
    const uint8_t CudaUdpL4Protocol::PROT_NUMBER = 17;

    TypeId CudaUdpL4Protocol::GetTypeId(void) {
        static TypeId tid = TypeId("ns3::CudaUdpL4Protocol")
                            .SetParent<UdpL4Protocol>()
                            .SetGroupName("cuda")
                            .AddConstructor<CudaUdpL4Protocol>();
        return tid;
    }

    CudaUdpL4Protocol::CudaUdpL4Protocol(): m_ipv4(nullptr), m_node(nullptr), m_endPoints(nullptr), m_ephemeral(49152), index(0) {
        // Constructor
        // cudaMallocManaged(&m_downTarget, sizeof(DownDeviceFunctionPtr));
        // printf("CudaUdpL4Protocol initialized\n");
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
        // cudaMallocManaged(&m_endPoints, 10 * sizeof(CudaIpv4EndPoint));
        checkCudaErr();
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

    CudaIpv4L3Protocol* CudaUdpL4Protocol::GetIpv4() {
        // Get the IPv4 protocol
        return m_ipv4;
    }

    CudaIpv4EndPoint* CudaUdpL4Protocol::Allocate() {
        // Allocate an IPv4 end point
        return (m_endPoints + index++);
    }

    CudaIpv4EndPoint* CudaUdpL4Protocol::Allocate(Ipv4Address address) {
        // Allocate an IPv4 end point
        m_endPoints[index].SetLocalAddress(address.Get());
        return (m_endPoints + index++);
    }

    CudaIpv4EndPoint* CudaUdpL4Protocol::Allocate(CudaNetDevice* boundNetDevice, uint16_t port) {
        // Allocate an IPv4 end point
        m_endPoints[index].BindToNetDevice(boundNetDevice);
        m_endPoints[index].SetLocalPort(port);
        return (m_endPoints + index++);
    }

    CudaIpv4EndPoint* CudaUdpL4Protocol::Allocate(CudaNetDevice* boundNetDevice, Ipv4Address address, uint16_t port) {
        // Allocate an IPv4 end point
        m_endPoints[index].BindToNetDevice(boundNetDevice);
        m_endPoints[index].SetLocalAddress(address.Get());
        m_endPoints[index].SetLocalPort(port);
        return (m_endPoints + index++);
    }

    CudaIpv4EndPoint* CudaUdpL4Protocol::Allocate(CudaNetDevice* boundNetDevice, Ipv4Address localAddress, uint16_t localPort, Ipv4Address peerAddress, uint16_t peerPort) {
        // Allocate an IPv4 end point
        m_endPoints[index].BindToNetDevice(boundNetDevice);
        m_endPoints[index].SetLocalAddress(localAddress.Get());
        m_endPoints[index].SetLocalPort(localPort);
        m_endPoints[index].SetPeerAddress(peerAddress.Get());
        m_endPoints[index].SetPeerPort(peerPort);
        return (m_endPoints + index++);
    }

    void CudaUdpL4Protocol::setDownTarget(DownDeviceFunctionPtr callback) {
        // Set the down target
        // m_downTarget = callback;
    }

    CudaSocket* CudaUdpL4Protocol::CreateSocket() {
        // Create a new socket
        CudaSocket* socket = new CudaSocket();
        // checkCudaErr();
        // printf("UdpL4: %p\n", this);
        socket->SetNode(m_node);
        socket->SetUdp(this);
        socket->SetRcvBufSize(131072);
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
        m_ipv4->test(data, cb_data);
    }

    __device__ uint16_t compute_udp_checksum(const uint8_t *udp_header, const uint8_t *payload, int length, uint32_t pseudo_header_sum) {
        uint32_t sum = pseudo_header_sum; // Start with pseudo-header sum
        uint32_t UDP_sum = 0;
        uint32_t payload_sum = 0;
        
        for (int i = 0; i < 4; i++) { // 8-byte UDP header
            sum += (udp_header[i * 2] << 8) | udp_header[i * 2 + 1];
            UDP_sum += (udp_header[i * 2] << 8) | udp_header[i * 2 + 1];
        }
        
        for (int i = 0; i < length / 2; i++) { // Payload
            sum += (payload[i * 2] << 8) | payload[i * 2 + 1];
            payload_sum += (payload[i * 2] << 8) | payload[i * 2 + 1];
        }
        
        if (length % 2) { // If payload length is odd, pad last byte with 0
            sum += payload[length - 1] << 8;
        }
        
        // printf("sum: %d, Udp sum: %d, payload sum: %d\n", sum, UDP_sum, payload_sum);
        return ones_complement_sum(sum);
    }

    __device__ int CudaUdpL4Protocol::Send(CudaPacket *d_packet, uint32_t saddr, uint32_t daddr, uint16_t sport, uint16_t dport, CUDA_cb_data* cb_data){
        // Send a packet
        // For simplicity, we will just print the packet contents
        // printf("Sending packet from %s to %s\n", saddr.GetLocal(), daddr.GetLocal());
        // printf("Packet contents: %s\n", packet);
        // call the send function of callback
        // printf("UdpL4: Send function, packet id: %d\n", d_packet->GetUid());
        // d_m_ipv4->test(d_packet->m_data, cb_data);
        // uint8_t protocol = PROT_NUMBER;
        // printf("m_ipv4: %p\n", m_ipv4);
        
        // length = payload length + 8-byte UDP header
        uint16_t udp_length = d_packet->GetSize() + 8;

        // Compute UDP checksum
        uint8_t udp_header[8];
        // cudaError_t ret = cudaMalloc(&udp_header, 8);
        // if(ret != cudaSuccess){
        //     printf("%s\n", cudaGetErrorString(ret));
        //     // return;
        // }
        udp_header[0] = sport >> 8;
        udp_header[1] = sport & 0xFF;
        udp_header[2] = dport >> 8;
        udp_header[3] = dport & 0xFF;
        udp_header[4] = udp_length >> 8;
        udp_header[5] = udp_length & 0xFF;
        udp_header[6] = 0;
        udp_header[7] = 0;
        
        #ifdef CHECKSUM_CHECK
            uint32_t pseudo_header_sum = 0;
            pseudo_header_sum += (saddr >> 16) & 0xFFFF;
            pseudo_header_sum += saddr & 0xFFFF;
            pseudo_header_sum += (daddr >> 16) & 0xFFFF;
            pseudo_header_sum += daddr & 0xFFFF;
            pseudo_header_sum += PROT_NUMBER; // Protocol number
            pseudo_header_sum += udp_length;

            // printf("UdpL4: send pseudo checksum: %d\n", pseudo_header_sum);
            
            uint16_t checksum = compute_udp_checksum(udp_header, d_packet->m_data, d_packet->GetSize(), pseudo_header_sum);
            // printf("UdpL4: checksum: %d\n", checksum);
            
            udp_header[6] = checksum >> 8;
            udp_header[7] = checksum & 0xFF;
        #endif
        // if(d_packet->GetUid() == 7){
        //     printf("UdpL4: udp header: ");
        //     for(int i = 0; i < 8; i++){
        //         printf("%d ", udp_header[i]);
        //     }
        //     printf("\n");
        // }

        // if(d_packet->GetUid() == 7){
        //     for(int i = 0; i < d_packet->GetSize(); i++){
        //         printf("%d ", d_packet->m_data[i]);
        //     }
        //     printf("\n");
        // }

        d_packet->AddHeader(udp_header, 8);
        // cudaFree(udp_header);

        // if(d_packet->GetUid() == 7){
        //     for(int i = 0; i < d_packet->GetSize(); i++){
        //         printf("%d ", d_packet->m_data[i]);
        //     }
        //     printf("\n");
        // }
        // for(int i = 0; i < 8; i++){
        //     printf("%d ", d_packet->m_data[i]);
        // }
        // printf("\n");

        m_ipv4->Send(d_packet, saddr, daddr, 0, 0, cb_data);

        return d_packet->GetSize();
        // printf("Udp Prorocol: Sending packet from %d:%d to %d:%d\n", saddr.Get(), sport, daddr.Get(), dport);
    }

    __device__ bool verify_udp_checksum(const uint8_t *udp_header, const uint8_t *payload, int length, uint32_t pseudo_header_sum, uint16_t received_checksum) {
        uint32_t sum = pseudo_header_sum; // Start with pseudo-header sum
        uint32_t UDP_sum = 0;
        uint32_t payload_sum = 0;
        
        for (int i = 0; i < 4; i++) { // 8-byte UDP header
            sum += (udp_header[i * 2] << 8) | udp_header[i * 2 + 1];
            UDP_sum += (udp_header[i * 2] << 8) | udp_header[i * 2 + 1];
        }
        
        for (int i = 0; i < length / 2; i++) { // Payload
            sum += (payload[i * 2] << 8) | payload[i * 2 + 1];
            payload_sum += (payload[i * 2] << 8) | payload[i * 2 + 1];
        }
        
        if (length % 2) { // If payload length is odd, pad last byte with 0
            sum += payload[length - 1] << 8;
        }
        
        // sum += received_checksum;
        
        // return ones_complement_sum(sum) == 0xFFFF;
        // printf("sum: %d, Udp sum: %d, payload sum: %d, received checksum: %d\n", sum, UDP_sum, payload_sum, received_checksum);
        return sum == 0xFFFF;
    }

    __device__ void CudaUdpL4Protocol::Receive(CudaPacket *packet, uint8_t* Ipv4Header, CudaIpv4Interface *interface){
        // Receive a packet
        // printf("UdpL4: Receiving packet: %d\n", packet->GetUid());
        // printf("UdpL4: socket: %p\n", m_endPoints[0].GetSocket());
        uint8_t udp_header[8];
        uint32_t pseudo_header_sum = 0;
        // cudaError_t ret = cudaMalloc(&udp_header, 8);
        // if(ret != cudaSuccess){
        //     printf("%s\n", cudaGetErrorString(ret));
        //     // return;
        // }
        packet->ExtractPayload(udp_header, 0, 8);

        // for(int i = 0; i < 20; i++){
        //     printf("%d ", Ipv4Header[i]);
        // }
        // printf("\n");
        #ifdef CHECKSUM_CHECK
            // little endian
            pseudo_header_sum += ((uint16_t)Ipv4Header[13]) << 8 | Ipv4Header[12];
            pseudo_header_sum += ((uint16_t)Ipv4Header[15]) << 8 | Ipv4Header[14];
            pseudo_header_sum += ((uint16_t)Ipv4Header[17]) << 8 | Ipv4Header[16];
            pseudo_header_sum += ((uint16_t)Ipv4Header[19]) << 8 | Ipv4Header[18];
            pseudo_header_sum += PROT_NUMBER;
            pseudo_header_sum += (udp_header[4] << 8) | udp_header[5];
            cudaFree(Ipv4Header);
        #endif
        // printf("UdpL4: receive pseudo checksum: %d\n", pseudo_header_sum);

        // if(packet->GetUid() == 7){
        //     for(int i = 0; i < packet->GetSize(); i++){
        //         printf("%d ", packet->m_data[i]);
        //     }
        //     printf("\n");
        // }

        packet->RemoveHeader(8);
        // cudaFree(udp_header);
        // if(packet->GetUid() == 7){
        //     for(int i = 0; i < packet->GetSize(); i++){
        //         printf("%d ", packet->m_data[i]);
        //     }
        //     printf("\n");
        // }
        #ifdef CHECKSUM_CHECK
            if(!verify_udp_checksum(udp_header, packet->m_data, packet->GetSize(), pseudo_header_sum, (udp_header[6] << 8) | udp_header[7])){
                printf("UdpL4: Checksum failed\n");
                printf("checksum: %d\n", (udp_header[6] << 8) | udp_header[7]);
                // return;
            }
        #endif

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
        // printf("UdpL4: Notify new aggregate\n");
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
                // printf("UdpL4: Socket factory added, node: %p, UdpL4: %p\n", GetPointer(node), this);
            }
        }
        if(m_ipv4 == nullptr){
            m_ipv4 = GetPointer(DynamicCast<CudaIpv4L3Protocol>(ipv4));
            m_ipv4->SetNode(node);
            // cudaMemcpyToSymbol(d_m_ipv4, &m_ipv4, sizeof(CudaIpv4L3Protocol*));
            // checkCudaErr();
            // printf("UdpL4: node: %p, UdpL4: %p, ipv4: %p\n", GetPointer(node), this, m_ipv4);
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