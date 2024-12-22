#include "cuda-net-device.h"
#include "cuda-packet-kernel.cuh"

namespace ns3 {

NS_OBJECT_ENSURE_REGISTERED(CudaNetDevice);

TypeId CudaNetDevice::GetTypeId(void) {
    static TypeId tid = TypeId("ns3::CudaNetDevice")
        .SetParent<PointToPointNetDevice>()
        .SetGroupName("Network")
        .AddConstructor<CudaNetDevice>();
    return tid;
}

CudaNetDevice::CudaNetDevice() {
    // Allocate GPU memory for packet buffers
    cudaStreamCreate(&m_stream);
    cudaMalloc(&d_packetBuffer, 1024 * 1500); // Example size
}

CudaNetDevice::~CudaNetDevice() {
    cudaStreamDestroy(m_stream);
    cudaFree(d_packetBuffer);
}

bool CudaNetDevice::Send(Ptr<Packet> packet, const Address& dest, uint16_t protocolNumber) {
    uint8_t* buffer = new uint8_t[packet->GetSize()];
    packet->CopyData(buffer, packet->GetSize());

    // Copy packet to GPU
    cudaMemcpyAsync(d_packetBuffer, buffer, packet->GetSize(), cudaMemcpyHostToDevice, m_stream);

    // Launch a simple GPU kernel to process the packet
    ProcessPacketOnCuda(packet);

    delete[] buffer; // Clean up

    return true; // Indicate success
}

void CudaNetDevice::SetReceiveCallback(NetDevice::ReceiveCallback cb) {
    m_rxCallback = cb;
}

__global__ void PacketProcessingKernel(uint8_t* packet, int packetSize) {
  int idx = threadIdx.x + blockIdx.x * blockDim.x;
  printf("Processing packet on GPU, idx: %d\n", idx);
  if (idx < packetSize) {
    // Example: Increment each byte
    packet[idx] += 1;
  }
}

void CudaNetDevice::ProcessPacketOnCuda(Ptr<Packet> packet) {
  int packetSize = packet->GetSize();
  int blockSize = 256;
  int gridSize = (packetSize + blockSize - 1) / blockSize;

  PacketProcessingKernel<<<gridSize, blockSize, 0, m_stream>>>(d_packetBuffer, packetSize);

  // Wait for GPU to finish processing
  cudaStreamSynchronize(m_stream);

  // Optionally, copy data back to CPU
  uint8_t* processedPacket = new uint8_t[packetSize];
  cudaMemcpy(processedPacket, d_packetBuffer, packetSize, cudaMemcpyDeviceToHost);

  // Forward the processed packet using the receive callback
  Ptr<Packet> newPacket = Create<Packet>(processedPacket, packetSize);
//   m_rxCallback(newPacket, this, 0);

  delete[] processedPacket;
}



void CudaNetDevice::InitializeCudaBuffers() {
    // Additional GPU memory initialization if needed
}

void CudaNetDevice::OffloadPacketProcessing() {
    // Launch GPU kernel to process packets
    printf("Launching packet processing kernel at CudaNetDevice\n");
}

} // namespace ns3