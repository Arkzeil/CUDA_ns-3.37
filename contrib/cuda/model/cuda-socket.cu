#include "cuda-socket.h"
#include "cuda-udp-l4-protocol.h"
#include "cuda-net-device.h"
#include "ns3/cuda-helper.h"
#include "ns3/cuda-udp-socket-factory-impl.h"
#include "ns3/cuda-packet.h"
#include "ns3/cuda-ipv4-end-point.h"
#include "ns3/cuda-udp-server.h"

namespace ns3{
    CudaUdpL4Protocol* CudaSocket::m_udp = nullptr;
    // __device__ CudaUdpL4Protocol* d_m_udp;

    NS_LOG_COMPONENT_DEFINE("CudaSocket");

    NS_OBJECT_ENSURE_REGISTERED(CudaSocket);

    static const uint32_t MAX_IPV4_UDP_DATAGRAM_SIZE = 65507; //!< Maximum UDP datagram size

    TypeId CudaSocket::GetTypeId(void){
        // Get the type ID
        static TypeId tid = TypeId("ns3::CudaSocket")
                            .SetParent<Socket>()
                            .SetGroupName("Internet")
                            .AddConstructor<CudaSocket>()
                            .AddAttribute("IcmpCallback",
                                        "Callback invoked whenever an icmp error is received on this socket.",
                                        CallbackValue(),
                                        MakeCallbackAccessor(&CudaSocket::m_icmpCallback),
                                        MakeCallbackChecker());
        return tid;
    }

    CudaSocket::CudaSocket() : m_netDevice(nullptr), m_shutdownRecv(false), m_shutdownSend(false), m_connected(false), m_rxAvailable(0){
        // Constructor
        // cudaStreamCreate(&m_cudaStream);
        printf("CudaSocket initialized\n");
        // void *d_temp;
        cudaMallocManaged(&d_sendBuffer, 1500); // Allocate GPU memory for packets (MTU size).
        checkCudaErr();
        // cudaMallocManaged(&m_defaultAddress, sizeof(Address));
        // m_defaultAddress = new(m_defaultAddress) Address();
        m_defaultAddress = new Address();
        cudaMallocManaged(&m_defaultPort, sizeof(uint16_t));
        checkCudaErr();
        // m_netDevice = new CudaNetDevice();
        m_deliveryQueue = new Cuda_PairList<CudaPacket*, uint32_t>(10000);
    }

    CudaSocket::~CudaSocket(){
        // Destructor
        if(d_sendBuffer != nullptr){
            cudaFree(d_sendBuffer);
        }
        // cudaFree(d_sendBuffer);
        checkCudaErr();
        // cudaFree(m_defaultAddress);
        delete m_defaultAddress;
        // checkCudaErr();
        cudaFree(m_defaultPort);
        checkCudaErr();
        // cudaStreamDestroy(m_cudaStream);
    }

    CudaSocket* CudaSocket::CreateSocket(Ptr<Node> node){
        // Create a new socket
        // This is not a good way to create a socket, but it is just for demonstration
        // should use cuda node and call its socket factory
        // if(m_udp == nullptr){
        //     // cudaMallocManaged(&m_udp, sizeof(CudaUdpL4Protocol));
        //     // new (m_udp) CudaUdpL4Protocol();  // Explicitly call constructor
        //     checkCudaErr();
        //     m_udp = new CudaUdpL4Protocol();
        //     // cudaMallocManaged((void**)&m_udp, sizeof(CudaUdpL4Protocol));
        //     // m_udp = new(m_udp) CudaUdpL4Protocol();
            
        //     checkCudaErr();
        //     m_udp->SetNode(node);
        //     cudaMemcpyToSymbol(d_m_udp, &m_udp, sizeof(CudaUdpL4Protocol*));  // Copy pointer to GPU
        //     checkCudaErr();
        //     // m_udp = new CudaUdpL4Protocol();
        //     // m_udp->SetNode(node);
        // }

        Ptr<CudaUdpSocketFactoryImpl> cudaFactory = node->GetObject<CudaUdpSocketFactoryImpl>();
        NS_ASSERT(cudaFactory);
        return cudaFactory->CreateCudaSocket();

        // return m_udp->CreateSocket();
    }

    int CudaSocket::FinishBind(){
        // Finish binding the socket
        bool done = false;
        if (m_endPoint != nullptr)
        {
            // m_endPoint->SetRxCallback(
            //     MakeCallback(&UdpSocketImpl::ForwardUp, Ptr<UdpSocketImpl>(this)));
            // m_endPoint->SetIcmpCallback(
            //     MakeCallback(&UdpSocketImpl::ForwardIcmp, Ptr<UdpSocketImpl>(this)));
            // m_endPoint->SetDestroyCallback(
            //     MakeCallback(&UdpSocketImpl::Destroy, Ptr<UdpSocketImpl>(this)));
            m_endPoint->SetSocket(this);
            done = true;
        }

        if (done){
            return 0;
        }

        return -1;
    }

    int CudaSocket::Bind(){
        // Bind the socket to the default address
        // It should allocate a new socket and bind it to the default address
        printf("%d\n", m_defaultAddress->GetLength());
        m_endPoint = m_udp->Allocate();
        printf("%d\n", m_defaultAddress->GetLength());
        if(m_boundnetdevice){
            // if not set, the socket is not bound to a net device, and device will be found at Ipv4L3Protocol::SendRealOut using route
            m_endPoint->BindToNetDevice(m_boundnetdevice);            
        }
        printf("%d\n", m_defaultAddress->GetLength());
        return FinishBind();
    }

    int CudaSocket::Bind(const Address& address){
        // Bind the socket to the specified address
        // *m_defaultAddress = address;
        InetSocketAddress transport = InetSocketAddress::ConvertFrom(address);
        Ipv4Address ipv4 = transport.GetIpv4();
        uint16_t port = transport.GetPort();

        SetIpTos(transport.GetTos());
        if (ipv4 == Ipv4Address::GetAny() && port == 0)
        {
            m_endPoint = m_udp->Allocate();
        }
        else if (ipv4 == Ipv4Address::GetAny() && port != 0)
        {
            m_endPoint = m_udp->Allocate(GetBoundNetDevice(), port);
        }
        else if (ipv4 != Ipv4Address::GetAny() && port == 0)
        {
            m_endPoint = m_udp->Allocate(ipv4);
        }
        else if (ipv4 != Ipv4Address::GetAny() && port != 0)
        {
            m_endPoint = m_udp->Allocate(GetBoundNetDevice(), ipv4, port);
        }
        if (m_endPoint == nullptr)
        {
            m_errno = port ? ERROR_ADDRINUSE : ERROR_ADDRNOTAVAIL;
            return -1;
        }
        if (m_boundnetdevice)
        {
            m_endPoint->BindToNetDevice(m_boundnetdevice);
        }
        // NotifyBind();
        return FinishBind();
    }

    int CudaSocket::Bind6(){
        // Bind the socket to the default address
        return Bind(*m_defaultAddress);
    }

    int CudaSocket::Close(){
        // Close the socket
        cudaFree(d_sendBuffer);
        checkCudaErr();
        d_sendBuffer = nullptr;
        m_shutdownRecv = true;
        m_shutdownSend = true;
        // cudaStreamDestroy(m_cudaStream);
        return 0;
    }

    int CudaSocket::Connect(const Address& address){
        // Connect the socket to the specified address
        if (InetSocketAddress::IsMatchingType(address) == true){
            InetSocketAddress transport = InetSocketAddress::ConvertFrom(address);
            *m_defaultAddress = Address(transport.GetIpv4());
            // printf("%p\n", m_defaultPort);
            // if(m_defaultPort == nullptr){
            //     cudaMallocManaged(&m_defaultPort, sizeof(uint16_t));
            // }
            // printf("%p\n", m_defaultPort);
            // printf("Before: m_defaultPort=%p, value=%d\n", m_defaultPort, *m_defaultPort);
            *m_defaultPort = transport.GetPort();
            // uint16_t port = transport.GetPort();
            // memcpy(m_defaultPort, &port, sizeof(uint16_t));
            // SetIpTos(transport.GetTos());
            m_connected = true;
            // NotifyConnectionSucceeded();
            return 0;
        }
        else{
            // NotifyConnectionFailed();
            printf("Connection failed\n");
            return -1;
        }
    }

    int CudaSocket::Listen(){
        // Listen for incoming connections
        return 0;
    }

    int CudaSocket::ShutdownRecv(){
        // Shutdown the receive side of the socket
        m_shutdownRecv = true;
        return 0;
    }

    int CudaSocket::ShutdownSend(){
        // Shutdown the send side of the socket
        m_shutdownSend = true;
        return 0;
    }

    int CudaSocket::Send(Ptr<Packet> p, uint32_t flags){
        // Send data to the socket
        uint32_t size = p->GetSize();
        uint8_t* buffer = new uint8_t[size];
        p->CopyData(buffer, size);
        // Send(buffer, size);
        delete[] buffer;
        return 0;
    }

    __device__ int CudaSocket::Send(CudaPacket* d_packet, CUDA_cb_data* cb_data){
        // Send data to the socket
        // cudaMemcpy(d_sendBuffer, d_buffer, size, cudaMemcpyDeviceToDevice);
        // Send data to the network device
        // SendToNetDevice(d_sendBuffer, size);
        printf("Sending packet from CUDA Socket, packet id: %d\n", d_packet->GetUid());
        // if(m_netDevice == nullptr){
        //     // m_netDevice = new CudaNetDevice();
        //     printf("NetDevice is null\n");
        // }
        // printf("%p\n", d_m_udp);
        // if(d_packet->GetUid() == 7){
        //     for(int i = 0; i < d_packet->GetSize(); i++){
        //         printf("%d ", d_packet->m_data[i]);
        //     }
        //     printf("\n");
        // }
        return DoSendTo(d_packet, 0, *m_defaultPort, 0, cb_data);
        // d_m_udp->Send(d_buffer, nullptr, nullptr, 0, size);
        // DoSendTo(d_buffer, Ipv4Address::ConvertFrom(*m_defaultAddress), *m_defaultPort, 0, size);
        // m_netDevice->EnqueuePacket(d_buffer, size);
    }

    __device__ int CudaSocket::DoSendTo(CudaPacket* d_packet, uint32_t dest, uint16_t port, uint8_t tos, CUDA_cb_data* cb_data){
        // Send data to the specified address
        // Send data to the network device
        // SendToNetDevice(d_buffer, size);
        printf("DoSendTo: Sending packet from CUDA Socket, packet id: %d\n", d_packet->GetUid());
        // d_m_udp->test(d_packet->m_data, cb_data);  
        // printf("d_m_udp: %p\n", d_m_udp);
        if(m_endPoint == nullptr){
            printf("Endpoint is null\n");
            // just return without retrying bind
            // if(bind() == -1){
            //     printf("Failed to bind socket\n");
            //     return;
            // }
            return -1;
        }

        if(d_packet->GetSize() > MAX_IPV4_UDP_DATAGRAM_SIZE){
            printf("Packet size exceeds maximum UDP datagram size\n");
            return -1;
        }

        if(m_shutdownSend){
            printf("Send side of the socket is shutdown\n");
            return -1;
        }
        // Skip the check of tos, ttl, priority and broadcast
        // if(d_packet->GetUid() == 7){
        //     for(int i = 0; i < d_packet->GetSize(); i++){
        //         printf("%d ", d_packet->m_data[i]);
        //     }
        //     printf("\n");
        // }

        d_m_udp->Send(d_packet, 0, dest, 0, port, cb_data);
        // m_udp->Send(d_buffer, m_endPoint->GetLocalAddress(), dest, m_endPoint->GetLocalPort(), port);
    }

    void CudaSocket::SendToNetDevice(const uint8_t* d_buffer, uint32_t size){
        // This will call the GPU-based NetDevice's Transmit function
        NS_LOG_UNCOND("Sending packet from CUDA Socket to NetDevice");
    }

    Ptr<Packet> CudaSocket::Recv(uint32_t maxSize, uint32_t flags){
        // Receive data from the socket
        return nullptr;
    }

    Ptr<Packet> CudaSocket::RecvFrom(uint32_t maxSize, uint32_t flags, Address& fromAddress){
        // Receive data from the socket
        return nullptr;
    }

    __device__ void CudaSocket::ForwardPacket(CudaPacket* d_packet){
        // Forward the packet
        if(m_shutdownRecv){
            return;
        }
        printf("Forwarding packet from CUDA Socket, packet id: %d\n", d_packet->GetUid());

        if(m_rxAvailable + d_packet->GetSize() <= m_rcvBufSize){
            if(m_deliveryQueue->Add(d_packet, 0) == false){
                printf("Failed to add packet to delivery queue\n");
            }
            m_rxAvailable += d_packet->GetSize();

            m_server->HandleRead(this);
        }
        else{
            printf("No space in receive buffer\n");
        }
    }

    __device__ CudaPacket* CudaSocket::CudaRecv(uint32_t maxSize, uint32_t flags, uint32_t* from){
        printf("Trying to fetch packet from delivery queue\n");
        // Receive data from the socket
        if(m_deliveryQueue->empty()){
            printf("No packets in delivery queue\n");
            return nullptr;
        }
        CudaPair<CudaPacket*, uint32_t> pair = m_deliveryQueue->front();
        CudaPacket* d_packet = pair.first;
        *from = pair.second;

        if(d_packet->GetSize() < maxSize){
            m_rxAvailable -= d_packet->GetSize();
            m_deliveryQueue->pop_front();
            return d_packet;
        }
    }

    int CudaSocket::GetSockName(Address& address) const{
        // Get the socket name
        // address = *m_defaultAddress;
        return 0;
    }

    uint32_t CudaSocket::GetTxAvailable() const{
        // Get the number of bytes available for sending
        return 0;
    }

    int CudaSocket::SendTo(Ptr<Packet> p, uint32_t flags, const Address& address){
        // Send data to the specified address
        return 0;
    }

    uint32_t CudaSocket::GetRxAvailable() const{
        // Get the number of bytes available for receiving
        return 0;
    }

    enum Socket::SocketErrno CudaSocket::GetErrno() const{
        // Get the socket error code
        return m_errno;
    }

    enum Socket::SocketType CudaSocket::GetSocketType() const{
        // Get the socket type
        return SocketType::NS3_SOCK_STREAM;
    }

    Ptr<Node> CudaSocket::GetNode() const{
        // Get the associated node
        return m_node;
    }

    void CudaSocket::SetNode(Ptr<Node> node){
        // Set the associated node
        m_node = node;
    }

    void CudaSocket::SetUdp(CudaUdpL4Protocol* udp){
        // Set the associated UDP L4 protocol
        m_udp = udp;
        // cudaMemcpyToSymbol(d_m_udp, &m_udp, sizeof(CudaUdpL4Protocol*));
        // checkCudaErr();
        d_m_udp = m_udp;
        // printf("CudaSocket: SetUdp: %p\n", m_udp);
    }

    int CudaSocket::GetPeerName(Address& address) const{
        // Get the peer name
        return 0;
    }

    bool CudaSocket::SetAllowBroadcast(bool allowBroadcast){
        // Set the broadcast flag
        return false;
    }

    bool CudaSocket::GetAllowBroadcast() const{
        // Get the broadcast flag
        return false;
    }

    void CudaSocket::SetRcvBufSize(uint32_t size){
        // Set the receive buffer size
        m_rcvBufSize = size;
    }

    CudaNetDevice* CudaSocket::GetBoundNetDevice(){
        // Get the bound network device
        return m_boundnetdevice;
    }

    void CudaSocket::SetRecv(CudaUdpServer* server){
        // Set the receive server
        m_server = server;
    }
}