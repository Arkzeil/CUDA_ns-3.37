#include "cuda-udp-client.h"
#include "cuda-packet-kernel.cuh"
#include <iostream>
#include <stdint.h>

namespace ns3 {

NS_OBJECT_ENSURE_REGISTERED(GpuUdpClient);

__host__ TypeId GpuUdpClient::GetTypeId(void) {
    static TypeId tid = TypeId("ns3::GpuUdpClient")
        .SetParent<Application>()
        .AddConstructor<GpuUdpClient>()
        .AddAttribute("MaxPackets",
                        "The maximum number of packets the application will send",
                        UintegerValue(100),
                        MakeUintegerAccessor(&GpuUdpClient::m_count),
                        MakeUintegerChecker<uint32_t>())
        .AddAttribute("Interval",
                        "The time to wait between packets",
                        TimeValue(Seconds(1.0)),
                        MakeTimeAccessor(&GpuUdpClient::m_interval),
                        MakeTimeChecker())
        .AddAttribute("RemoteAddress",
                        "The destination Address of the outbound packets",
                        AddressValue(),
                        MakeAddressAccessor(&GpuUdpClient::m_peerAddress),
                        MakeAddressChecker())
        .AddAttribute("RemotePort",
                        "The destination port of the outbound packets",
                        UintegerValue(100),
                        MakeUintegerAccessor(&GpuUdpClient::m_peerPort),
                        MakeUintegerChecker<uint16_t>())
        .AddAttribute("PacketSize",
                        "Size of packets generated. The minimum packet size is 12 bytes which is "
                        "the size of the header carrying the sequence number and the time stamp.",
                        UintegerValue(1024),
                        MakeUintegerAccessor(&GpuUdpClient::m_size),
                        MakeUintegerChecker<uint32_t>(12, 65507));
    return tid;
}

GpuUdpClient::GpuUdpClient() : d_packetBuffer(nullptr), m_size(1024), m_interval(Seconds(1.0)), m_count(100) {
    InitCudaResources();
    printf("GpuUdpClient initialized\n");
    printf("Packet size: %d bytes\n", m_size);
    printf("Interval: %f seconds\n", m_interval.GetSeconds());
    printf("Max packets: %d\n", m_count);
    // printf("Remote address: %s\n", Ipv4Address::ConvertFrom(m_peerAddress.Get()).Get());
    printf("Remote port: %d\n", m_peerPort);
}

GpuUdpClient::~GpuUdpClient() {
    CleanupCudaResources();
}

void
GpuUdpClient::SetRemote(Address ip, uint16_t port)
{
    // NS_LOG_FUNCTION(this << ip << port);
    m_peerAddress = ip;
    m_peerPort = port;
}

void
GpuUdpClient::SetRemote(Address addr)
{
    // NS_LOG_FUNCTION(this << addr);
    m_peerAddress = addr;
}

void 
GpuUdpClient::StartApplication(){
    m_sendEvent = Simulator::Schedule(Seconds(0.0), &GpuUdpClient::Send, this);
}

void
GpuUdpClient::StopApplication()
{
    // NS_LOG_FUNCTION(this);
    Simulator::Cancel(m_sendEvent);
}

__host__ void GpuUdpClient::InitCudaResources() {
    cudaStreamCreate(&m_cudaStream);
    cudaMalloc(&d_packetBuffer, 1500); // Allocate GPU memory for packets (MTU size).
}

__host__ void GpuUdpClient::CleanupCudaResources() {
    cudaFree(d_packetBuffer);
    cudaStreamDestroy(m_cudaStream);
}

__host__ void GpuUdpClient::Send() {
    // Ptr<Packet> packet = Create<Packet>(m_size); // Create the packet.
    // OffloadPacketToGpu(packet);                 // Offload packet to GPU for processing.

    // generate packets on GPU
    GeneratePacketsOnGpu(m_count / 8, m_size);

    // Schedule the next send event immediately
    m_sendEvent = Simulator::Schedule(m_interval, &GpuUdpClient::Send, this);
}

__host__ void GpuUdpClient::OffloadPacketToGpu(Ptr<Packet> packet) {
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

__host__ void GpuUdpClient::GeneratePacketsOnGpu(int numPackets, int packetSize) {
    // Allocate GPU memory for packets
    cudaMalloc(&d_packetBuffer, numPackets * packetSize);

    // Launch kernel
    int threadsPerBlock = 256;
    int blocks = (numPackets + threadsPerBlock - 1) / threadsPerBlock;

    GenerateUdpPackets<<<blocks, threadsPerBlock, 0, m_cudaStream>>>(d_packetBuffer, packetSize, numPackets);
    cudaDeviceSynchronize(); // Ensure packets are generated
}

__global__ void ProcessPacketKernel(uint8_t* packetBuffer, int packetSize) {
    // Example: Print packet size (real code would handle routing, etc.)
    if (threadIdx.x == 0) {
        printf("Processing packet of size: %d bytes on GPU\n", packetSize);
    }

    // TODO: Add routing, queuing, and forwarding logic here.
}

} // namespace ns3
