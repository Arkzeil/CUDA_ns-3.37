#include "cuda-udp-client.h"
#include "cuda-socket.h"
#include "cuda-udp-socket-factory-impl.h"
#include "ns3/cuda-helper.h"
#include "ns3/cuda-net-device.h"
#include "ns3/cuda-packet.h"
// #include "cuda-packet-kernel.cuh"
// #include "cuda-ipv4-routing.h"
#include <iostream>
#include <stdint.h>

namespace ns3 {

    NS_LOG_COMPONENT_DEFINE("CudaUdpClient");
    NS_OBJECT_ENSURE_REGISTERED(CudaUdpClient);

    __managed__ bool receiveEventFlag = false;
    std::vector<CUDA_cb_data*> cb_data_list;
    cudaEvent_t startEvent, stopEvent;

    __host__ TypeId CudaUdpClient::GetTypeId(void) {
        static TypeId tid = TypeId("ns3::CudaUdpClient")
            .SetParent<Application>()
            .SetGroupName("Applications")
            .AddConstructor<CudaUdpClient>()
            .AddAttribute("MaxPackets",
                            "The maximum number of packets the application will send",
                            UintegerValue(100),
                            MakeUintegerAccessor(&CudaUdpClient::m_count),
                            MakeUintegerChecker<uint32_t>())
            .AddAttribute("Interval",
                            "The time to wait between packets",
                            TimeValue(Seconds(1.0)),
                            MakeTimeAccessor(&CudaUdpClient::m_interval),
                            MakeTimeChecker())
            .AddAttribute("RemoteAddress",
                            "The destination Address of the outbound packets",
                            AddressValue(),
                            MakeAddressAccessor(&CudaUdpClient::m_peerAddress),
                            MakeAddressChecker())
            .AddAttribute("RemotePort",
                            "The destination port of the outbound packets",
                            UintegerValue(100),
                            MakeUintegerAccessor(&CudaUdpClient::m_peerPort),
                            MakeUintegerChecker<uint16_t>())
            .AddAttribute("PacketSize",
                            "Size of packets generated. The minimum packet size is 12 bytes which is "
                            "the size of the header carrying the sequence number and the time stamp.",
                            UintegerValue(1024),
                            MakeUintegerAccessor(&CudaUdpClient::m_size),
                            MakeUintegerChecker<uint32_t>(12, 65507));
        return tid;
    }

    CudaUdpClient::CudaUdpClient() 
        : d_packetBuffer(nullptr), m_size(1500), 
        m_interval(Seconds(1.0)), m_count(100), 
        m_peerPort(0), m_socket(nullptr), m_sent(0), 
        m_totalTx(0), m_running(false), m_cudaSocket(nullptr) {
        
        InitCudaResources();
        printf("CudaUdpClient initialized\n");
        printf("Packet size: %d bytes\n", m_size);
        printf("Interval: %f seconds\n", m_interval.GetSeconds());
        printf("Max packets: %d\n", m_count);
        // printf("Remote address: %s\n", Ipv4Address::ConvertFrom(m_peerAddress.Get()).Get());
        printf("Remote port: %d\n", m_peerPort);
    }

    CudaUdpClient::~CudaUdpClient() {
        CleanupCudaResources();
    }

    void
    CudaUdpClient::SetRemote(Address ip, uint16_t port)
    {
        NS_LOG_FUNCTION(this << ip << port);
        m_peerAddress = ip;
        m_peerPort = port;
    }

    void
    CudaUdpClient::SetRemote(Address addr)
    {
        // NS_LOG_FUNCTION(this << addr);
        m_peerAddress = addr;
    }

    void
    CudaUdpClient::SetPacketSize(uint32_t size)
    {
        // NS_LOG_FUNCTION(this << size);
        m_size = size;
        cudaFree(d_packetBuffer);
        checkCudaErr();
        cudaMallocManaged(&d_packetBuffer, m_size);
        checkCudaErr();
    }

    void
    CudaUdpClient::SetSendInterval(Time interval)
    {
        // NS_LOG_FUNCTION(this << interval);
        m_interval = interval;
    }

    void CudaUdpClient::RecvTest(Time sendTime) {
        double simTime = Simulator::Now().GetSeconds();
        std::cout << "RecvTest executed at simulation time: " << simTime << "s" << " sendTime: " << sendTime.GetSeconds() << "s\n";
        // printf("Recv test\n");
        receiveEventFlag = false;
    }

    void 
    CudaUdpClient::StartApplication(){
        printf("Initial thread: %ld\n", std::this_thread::get_id());
        EventDispatcher::GetInstance().StartWorker();
        // NS_LOG_FUNCTION(this);
        // if (!m_socket) {
        //     m_socket = Socket::CreateSocket(GetNode(), UdpSocketFactory::GetTypeId());
        //     if(m_socket->Bind() == -1){
        //         NS_LOG_ERROR("Failed to bind socket");
        //         return;
        //     }
        //     // should check if m_peerAddress already contain port number or not
        //     m_socket->Connect(InetSocketAddress(Ipv4Address::ConvertFrom(m_peerAddress), m_peerPort));
        // }
        if(m_cudaSocket == nullptr){
            // cudaMallocManaged(&m_cudaSocket, sizeof(CudaSocket));
            // TypeId tid = TypeId::LookupByName("ns3::CudaSocket");
            // m_cudaSocket = new CudaSocket();
            Ptr<Node> node = GetNode();
            if(node == nullptr){
                printf("Node is null\n");
            }
            m_cudaSocket = CudaSocket::CreateSocket(node);
            // m_cudaSocket->SetNode(node);
            // cudaStreamAttachMemAsync(m_cudaStream, m_cudaSocket);
            // m_cudaSocket->Bind(InetSocketAddress(Ipv4Address::GetAny(), 9));
            if(m_cudaSocket->Bind() == -1){
                NS_LOG_ERROR("Failed to bind socket");
                return;
            }
            m_cudaSocket->Connect(InetSocketAddress(Ipv4Address::ConvertFrom(m_peerAddress), m_peerPort));
        }
        // cudaMallocManaged((void**)&(d_data->packetBuffer), m_size);
        // m_socket->SetRecvCallback(MakeCallback(&CudaUdpClient::Receive, this));
        m_sendEvent = Simulator::Schedule(Seconds(0.0), &CudaUdpClient::Send, this);
    }

    void
    CudaUdpClient::StopApplication()
    {
        // NS_LOG_FUNCTION(this);
        // if(m_sendEvent.IsRunning()){
        //     Simulator::Cancel(m_sendEvent);
        // }
        // cudaStreamSynchronize(m_cudaStream);
        if (m_socket) {
            m_socket->Close();
            m_socket = nullptr;
        }
        else if(m_cudaSocket){
            EventDispatcher::GetInstance().StopWorker();
            cudaDeviceSynchronize();
            m_cudaSocket->Close();
            // checkCudaErr();
            // printf("Deleting m_cudaSocket: %p\n", m_cudaSocket);
            delete m_cudaSocket;
            // checkCudaErr();
            m_cudaSocket = nullptr;
        }
        
        Simulator::Cancel(m_sendEvent);
    }

    __host__ void CudaUdpClient::InitCudaResources() {
        cudaStreamCreate(&m_cudaStream);
        cudaMalloc(&d_packetBuffer, m_size); // Allocate GPU memory for packets (MTU size).
        if(d_packetBuffer == nullptr){
            printf("Failed to allocate GPU memory for packet buffer\n");
        }
        checkCudaErr();
    }

    __host__ void CudaUdpClient::CleanupCudaResources() {
        cudaFree(d_packetBuffer);
        checkCudaErr();
        cudaStreamDestroy(m_cudaStream);
        checkCudaErr(); 
    }

    void CUDART_CB CudaUdpClient::Cuda_ReceiveCallback(cudaStream_t stream, cudaError_t status, void* data) {
        // cudaEventSynchronize(stopEvent); // Wait for kernel completion
        // checkCudaErr();

        CUDA_cb_data* cbData = static_cast<CUDA_cb_data*>(data);
        if(cbData == nullptr){
            printf("Callback data is null\n");
            return;
        }
        if(cbData->empty){
            printf("Callback data is empty\n");
            return;
        }
        printf("Cuda receive callback, pkt size: %d\n", cbData->packetSize);

        while(cbData != nullptr){
            CudaNetDevice* device = (CudaNetDevice*)cbData->dst;

            Time delay = Seconds(cbData->delay);
            Time dataTime = cbData->sendTime;
            // We can't use any CUDA API inside callback function
            // cudaMemcpy(next_cb, next, sizeof(CUDA_cb_data), cudaMemcpyDeviceToHost);
            // checkCudaErr();
            // printf("Next packetsize: %d\n", next->packetSize);

            switch(cbData->func_id){
                case -1:
                    printf("Function: None\n");
                    break;
                case 0:
                    printf("Function: Receive, delay: %f\n", cbData->delay);
                    // printf("h_packet: %p, d_packet: %p\n", cbData->h_packet, cbData->d_packet);
                    printf("packet id: %d\n", cbData->packet->GetUid());
                    EventDispatcher::GetInstance().Dispatch(device->GetNode()->GetId(), delay, [device, cbData]() {
                        device->Receive(cbData->packet);
                    });
                    break;
                case 1:
                    printf("Function: TransmitComplete, delay: %f\n", cbData->delay);
                    EventDispatcher::GetInstance().Dispatch(device->GetNode()->GetId(), delay, [device, stream]() {
                        device->TransmitComplete(stream);
                    });
                    break;
                default:
                    printf("Unknown function\n");
                    break;
            }
            cbData = cbData->next;
        }
        
    }

    __global__ void notifyHost(bool &flag) {
        flag = true;
    }

    __host__ void CudaUdpClient::Send() {
        // Ptr<Packet> packet = Create<Packet>(m_size); // Create the packet.
        // OffloadPacketToCuda(packet);                 // Offload packet to GPU for processing.

        // OffloadToCuda(1, m_size); // Offload packet generation to GPU.
        double simTime = Simulator::Now().GetSeconds();
        std::cout << "Send executed at simulation time: " << simTime << "s\n";

        GeneratePacketOnGpu(); // Generate packet on GPU.
        // uint8_t* h_packetData = new uint8_t[m_size];
        // cudaMemcpy(h_packetData, d_packetBuffer, m_size, cudaMemcpyDeviceToHost);
        // // Wrap the GPU buffer in a ns3::Packet and send
        // Ptr<Packet> packet = Create<Packet>(h_packetData, m_size);
        // m_cudaSocket->Send(h_packetData, m_size); // Send the packet.
        // Schedule the next send event immediately
        m_sendEvent = Simulator::Schedule(m_interval, &CudaUdpClient::Send, this);
    }   

    __global__ void GeneratePacketKernel(CudaSocket* socket, int packetSize, CUDA_cb_data* d_data) {
        // Allocate packet data in shared memory or local GPU memory
        // printf("Generating packet on GPU\n");
        __shared__ uint8_t packet[1500]; // Example size of a packet
        // uint8_t* d_packet;
        // cudaMalloc(&d_packet, packetSize);
        int idx = threadIdx.x + blockIdx.x * blockDim.x;
        // if (idx < packetSize) {
        //     d_packet[idx] = (char)((idx) % 256); // Example payload logic
        // }
        // printf("Generated packet on GPU, idx: %d\n", idx);
        __syncthreads();
        packet[0] = idx % 256; // Example payload logic
        // Call the socket's Send logic directly
        if (threadIdx.x == 0) { // Single thread handles the send
            // CudaPacket* cuda_packet;
            // cudaMalloc(&cuda_packet, sizeof(CudaPacket));
            // new(cuda_packet) CudaPacket();
            // cuda_packet->Allocate(packetSize);
            // cuda_packet->m_data[0] = packet[0];
            d_data->packet->Allocate(packetSize);
            d_data->packet->m_data[0] = packet[0];
            printf("packet uid: %d, packet size: %d\n", d_data->packet->GetUid(), d_data->packet->GetSize());

            printf("Sending packet from CUDA UDP client, packet id: %d\n", d_data->packet->GetUid());
            socket->Send(d_data->packet, d_data);
        }
        // cudaFree(d_packet);
    }

    void CudaUdpClient::GeneratePacketOnGpu() {
    //   static uint32_t seqNumber = 0; // the sequence number of the packet, but it will not auto increment at kernel
        int blockSize = 256;
        int gridSize = (m_size + blockSize - 1) / blockSize;

        if(d_packetBuffer == nullptr){
            printf("Packet buffer is null\n");
        }
        if(m_cudaSocket == nullptr){
            printf("Cuda socket is null\n");
        }
        
        CUDA_cb_data* d_data = new CUDA_cb_data(256);
        d_data->init_pkt();
        // cb_data_list.push_back(new CUDA_cb_data(256));
        // CUDA_cb_data* d_data = cb_data_list.back();
        d_data->addNext(1);
        // d_data->client = (void*)this;
        // d_data->packetSize = 123;
        d_data->sendTime = Simulator::Now();
        cudaDeviceSynchronize();
        // printf("cb_data: %p\n", d_data);
        
        // cudaEventCreate(&startEvent);

        GeneratePacketKernel<<<gridSize, blockSize, 0, m_cudaStream>>>(m_cudaSocket, m_size, d_data);
        // cudaEventCreate(&stopEvent);
        
        cudaStreamSynchronize(m_cudaStream);
        // CUDA_cb_data* next = d_data->next;
        // CUDA_cb_data* next_cb = (CUDA_cb_data*)malloc(sizeof(CUDA_cb_data));
        // if(next != nullptr){
        //     cudaMemcpy(next_cb, next, sizeof(CUDA_cb_data), cudaMemcpyDeviceToHost);
        //     printf("Next packetsize: %d\n", next_cb->packetSize);
        // }

        notifyHost<<<1,1>>>(receiveEventFlag);
        cudaMemcpyAsync(nullptr, nullptr, 0, cudaMemcpyDeviceToHost, m_cudaStream);
        // cudaMemcpyAsync(d_data->h_packet, d_data->d_packet, sizeof(CudaPacket), cudaMemcpyDeviceToHost, m_cudaStream);
        cudaStreamAddCallback(m_cudaStream, CudaUdpClient::Cuda_ReceiveCallback, d_data, 0);
    }

    // __host__ void CudaUdpClient::OffloadToCuda(int numPackets, int packetSize) {
    //     // Allocate and initialize routing table on GPU
    //     RoutingTable* d_routingTable;
    //     int tableSize = 10;
    //     RoutingTable h_routingTable[10] = {
    //         {8080, 1}, {8081, 2}, {8082, 3} // Example entries
    //     };
    //     cudaMalloc(&d_routingTable, tableSize * sizeof(RoutingTable));
    //     cudaMemcpy(d_routingTable, h_routingTable, tableSize * sizeof(RoutingTable), cudaMemcpyHostToDevice);

    //     // Launch packet generation and processing kernel
    //     int threadsPerBlock = 256;
    //     int blocks = (numPackets + threadsPerBlock - 1) / threadsPerBlock;
    //     OffloadToGpuKernel<<<blocks, threadsPerBlock>>>(numPackets, packetSize, d_routingTable, tableSize);

    //     cudaDeviceSynchronize(); // Ensure all GPU operations complete

    //     // Free resources
    //     cudaFree(d_routingTable);
    // }

    __host__ void CudaUdpClient::OffloadPacketToCuda(Ptr<Packet> packet) {
        // Copy packet data to GPU memory
        uint8_t* h_packetData = new uint8_t[packet->GetSize()];
        packet->CopyData(h_packetData, packet->GetSize());

        cudaMemcpyAsync(d_packetBuffer, h_packetData, packet->GetSize(),
                        cudaMemcpyHostToDevice, m_cudaStream);

        // Launch a placeholder kernel (replace with your logic)
        // Replace <<<1, 1>>> with appropriate grid/block size.
        ProcessPacketKernel<<<1, 1, 0, m_cudaStream>>>(d_packetBuffer, packet->GetSize());

        // Clean up host memory
        delete[] h_packetData;

        // Synchronization is optional since CPU doesn’t wait.
    }

    __global__ void ProcessPacketKernel(uint8_t* packetBuffer, int packetSize) {
        // Example: Print packet size (real code would handle routing, etc.)
        if (threadIdx.x == 0) {
            printf("Processing packet of size: %d bytes on GPU\n", packetSize);
        }

        // TODO: Add routing, queuing, and forwarding logic here.
    }

} // namespace ns3
