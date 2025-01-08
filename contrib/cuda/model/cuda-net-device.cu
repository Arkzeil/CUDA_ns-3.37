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

  CudaNetDevice::CudaNetDevice(): m_queueSize(1024), m_rxCallback(nullptr), m_txMachineState(READY), m_channel(nullptr), m_linkUp(false) {
      // Allocate GPU memory for packet buffers
      // m_queueSize = 1024;
      // cudaStreamCreate(&m_stream);
      cudaMalloc(&d_packetQueue, m_queueSize * 1500); // Example size
      cudaMallocManaged(&d_queueFront, sizeof(int));
      cudaMallocManaged(&d_queueRear, sizeof(int));
      // *d_queueFront = *d_queueRear = 0;
  }

  CudaNetDevice::~CudaNetDevice() {
      // cudaStreamDestroy(m_stream);
      cudaFree(d_packetQueue);
      cudaFree(d_queueFront);
      cudaFree(d_queueRear);
  }

  bool CudaNetDevice::Send(Ptr<Packet> packet, const Address& dest, uint16_t protocolNumber) {
      // Copy packet to GPU
      uint8_t* d_packet;
      cudaMalloc(&d_packet, packet->GetSize());
      packet->CopyData(reinterpret_cast<uint8_t*>(d_packet), packet->GetSize());

      // Enqueue packet on GPU
      // EnqueuePacket(d_packet, packet->GetSize());

      // Free temporary packet
      cudaFree(d_packet);

      return true; // Indicate success
  }

  void CudaNetDevice::SetReceiveCallback(NetDevice::ReceiveCallback cb) {
      m_rxCallback = cb;
  }

  bool CudaNetDevice::SupportsSendFrom() const {
      return false;
  }

  __global__ void PacketProcessingKernel(uint8_t* packet, int packetSize) {
      int idx = threadIdx.x + blockIdx.x * blockDim.x;
      printf("Processing packet on GPU, idx: %d\n", idx);
      if (idx < packetSize) {
        // Example: Increment each byte
        packet[idx] += 1;
      }
  }
  __global__ void TransmitKernel(uint8_t* queue, int* front, int* rear, int queueSize, float bandwidthMbps, float delayMs) {
      if (*front == *rear) return; // Queue is empty

      // Simulate delay (dummy computation)
      clock_t start = clock();
      while ((clock() - start) < delayMs * 1e6 / CLOCKS_PER_SEC);

      // Transmit logic
      int pos = (*front) % queueSize;
      uint8_t* packet = queue + pos * 1500; // Access packet
      printf("Transmitting packet: %s\n", packet);

      if (threadIdx.x == 0) {
        *front = (*front + 1) % queueSize;
      }
  }

  void CudaNetDevice::ProcessPacketOnCuda(Ptr<Packet> packet) {
      int packetSize = packet->GetSize();
      int blockSize = 256;
      int gridSize = (packetSize + blockSize - 1) / blockSize;

      PacketProcessingKernel<<<gridSize, blockSize, 0, m_stream>>>(d_packetQueue, packetSize);

      // Wait for GPU to finish processing
      cudaStreamSynchronize(m_stream);

      // Optionally, copy data back to CPU
      uint8_t* processedPacket = new uint8_t[packetSize];
      cudaMemcpy(processedPacket, d_packetQueue, packetSize, cudaMemcpyDeviceToHost);

      // Forward the processed packet using the receive callback
      Ptr<Packet> newPacket = Create<Packet>(processedPacket, packetSize);
    //   m_rxCallback(newPacket, this, 0);

      delete[] processedPacket;
  }

  void CudaNetDevice::TransmitPackets() {
      TransmitKernel<<<1, 256>>>(d_packetQueue, d_queueFront, d_queueRear, m_queueSize, 100.0, 1.0); // 100 Mbps, 1 ms delay
      cudaStreamSynchronize(m_stream); // Ensure transmission completes
  }

  __global__ void EnqueueKernel(uint8_t* queue, int* front, int* rear, int queueSize, const uint8_t* packet, uint32_t size) {
      int pos = (*rear) % queueSize;
      uint8_t* entry = queue + pos * 1500; // Move to the position for the packet
      for (int i = threadIdx.x; i < size; i += blockDim.x) {
        entry[i] = packet[i];
      }
      if (threadIdx.x == 0) {
        *rear = (*rear + 1) % queueSize;
      }
  }

  bool CudaNetDevice::Attach(CudaP2PChannel *channel) {
      m_channel = channel;
      m_channel->Attach(this);
      m_linkUp = true;
      printf("Attached CudaNetDevice to channel\n");
      return true;
  }

  void CudaNetDevice::SetDataRate(DataRate bps) {
      m_bps = bps;
  }

  Ptr<Node> CudaNetDevice::GetNode() const {
      return m_node;
  }

  void CudaNetDevice::SetNode(Ptr<Node> node) {
      m_node = node;
  }

  __device__ void CudaNetDevice::Send(const uint8_t* packet, uint32_t size) {
      if(m_linkUp == false) {
        printf("Link is down, dropping packet\n");
        cudaFree((void*)packet);
        return;
      }

      EnqueuePacket(packet, size);

  }
  // enqueue packet and start transmit(as kernel return queue status at different fucntion is troublesome)
  __device__ void CudaNetDevice::EnqueuePacket(const uint8_t* packet, uint32_t size) {
    // EnqueueKernel<<<1, 256>>>(d_packetQueue, d_queueFront, d_queueRear, m_queueSize, d_packet, size);
    // cudaDeviceSynchronize(); // Ensure enqueue completes
    if(m_txMachineState == BUSY) {
      printf("Transmitter busy, dropping packet\n");
      // cudaFree((void*)packet);
      return;
    }

    m_txMachineState = BUSY;

    int pos = atomicAdd(d_queueRear, 1) % m_queueSize; // Use atomic operation for thread safety
    uint8_t* entry = d_packetQueue + pos * 1500;         // Get position in the queue

    for (int i = threadIdx.x; i < size; i += blockDim.x) {
      entry[i] = packet[i];
    }

    printf("Enqueued packet on GPU, pos: %d\n", pos);
    __syncthreads();

    if(m_channel == nullptr) {
      printf("Channel not attached\n");
      cudaMalloc(&m_channel, sizeof(CudaP2PChannel));
    }

    m_channel->TransmitPacket(this, entry, size); // Start transmission
  }

  void CudaNetDevice::InitializeCudaBuffers() {
      // Additional GPU memory initialization if needed
  }

  void CudaNetDevice::OffloadPacketProcessing() {
      // Launch GPU kernel to process packets
      printf("Launching packet processing kernel at CudaNetDevice\n");
  }

} // namespace ns3