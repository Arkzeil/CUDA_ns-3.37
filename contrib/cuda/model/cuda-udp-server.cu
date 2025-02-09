#include "cuda-udp-server.h"
#include "cuda-udp-l4-protocol.h"
#include "cuda-packet.h"
#include "ns3/cuda-helper.h"
#include "cuda-socket.h"

namespace ns3 {
    NS_LOG_COMPONENT_DEFINE("CudaUdpServer");
    NS_OBJECT_ENSURE_REGISTERED(CudaUdpServer);

    TypeId CudaUdpServer::GetTypeId(void) {
        static TypeId tid = TypeId("ns3::CudaUdpServer")
                            .SetParent<Application>()
                            .SetGroupName("Applications")
                            .AddConstructor<CudaUdpServer>()
                            .AddAttribute("Port",
                                        "Port on which we listen for incoming packets.",
                                        UintegerValue(100),
                                        MakeUintegerAccessor(&CudaUdpServer::m_port),
                                        MakeUintegerChecker<uint16_t>());
                            // .AddAttribute("PacketWindowSize",
                            //             "The size of the window used to compute the packet loss. This value "
                            //             "should be a multiple of 8.",
                            //             UintegerValue(32),
                            //             MakeUintegerAccessor(&CudaUdpServer::GetPacketWindowSize,
                            //                                 &CudaUdpServer::SetPacketWindowSize),
                            //             MakeUintegerChecker<uint16_t>(8, 256));
        return tid;
    }

    CudaUdpServer::CudaUdpServer(): m_cudaSocket(nullptr), m_lossCounter(0), m_received(0) {
        // Constructor
        printf("CudaUdpServer initialized\n");
    }

    CudaUdpServer::CudaUdpServer(uint16_t port): m_cudaSocket(nullptr), m_lossCounter(0), m_received(0) {
        // Constructor
        m_port = port;
    }

    CudaUdpServer::~CudaUdpServer() {
        // Destructor
    }

    uint32_t CudaUdpServer::GetLost() const {
        // Get the number of lost packets
        return m_lossCounter;
    }

    uint64_t CudaUdpServer::GetReceived() const {
        // Get the number of received packets
        return m_received;
    }

    void CudaUdpServer::StartApplication() {
        // Start the application
        if(m_cudaSocket == nullptr){
            // cudaMallocManaged(&m_cudaSocket, sizeof(CudaSocket));
            // TypeId tid = TypeId::LookupByName("ns3::CudaSocket");
            // m_cudaSocket = new CudaSocket();
            Ptr<Node> node = GetNode();
            if(node == nullptr){
                printf("Node is null\n");
            }
            if(!m_cudaSocket){
                printf("Creating new socket at node %d\n", node->GetId());
                m_cudaSocket = CudaSocket::CreateSocket(node);
                // m_cudaSocket->SetNode(node);
                // cudaStreamAttachMemAsync(m_cudaStream, m_cudaSocket);
                // m_cudaSocket->Bind(InetSocketAddress(Ipv4Address::GetAny(), 9));
                InetSocketAddress local = InetSocketAddress(Ipv4Address::GetAny(), m_port);
                if(m_cudaSocket->Bind(local) == -1){
                    NS_LOG_ERROR("Failed to bind socket");
                    return;
                }
            }
            m_cudaSocket->SetRecv(this);
            printf("CudaUdpServer started: %p\n", m_cudaSocket);
            // m_cudaSocket->Connect(InetSocketAddress(Ipv4Address::ConvertFrom(m_peerAddress), m_peerPort));
        }
    }

    void CudaUdpServer::StopApplication() {
        // Stop the application
        // if(m_cudaSocket != nullptr){
        //     delete m_cudaSocket;
        //     m_cudaSocket = nullptr;
        // }
        cudaDeviceSynchronize();
        printf("Total packets received: %ld\n", m_received);
    }

    __device__ void CudaUdpServer::HandleRead(CudaSocket* socket) {
        // Handle a packet reception
        CudaPacket* packet;
        uint32_t from;
        while((packet = socket->CudaRecv(UINT32_MAX, 0, &from)) != nullptr){
            if(packet->GetSize() > 0){
                printf("CudaUdpServer Received packet: %d\n", packet->GetUid());
                uint32_t receivedSize = packet->GetSize();
                atomicAdd(&m_received, 1);
            }
        }
    }

    void CudaUdpServer::SetPort(uint16_t port) {
        // Set the port
        m_port = port;
    }
} // namespace ns3