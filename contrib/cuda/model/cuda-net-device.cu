#include "cuda-net-device.h"
#include "cuda-packet-kernel.cuh"
#include "ns3/cuda-helper.h"
#include "ns3/cuda-udp-client.h"
#include "ns3/cuda-packet.h"

namespace ns3 {

  NS_OBJECT_ENSURE_REGISTERED(CudaNetDevice);

  TypeId CudaNetDevice::GetTypeId(void) {
      static TypeId tid = TypeId("ns3::CudaNetDevice")
                          .SetParent<PointToPointNetDevice>()
                          .SetGroupName("Network")
                          .AddConstructor<CudaNetDevice>();
      return tid;
  }

  CudaNetDevice::CudaNetDevice(): m_queueSize(1024), m_rxCallback(nullptr), m_txMachineState(READY), m_channel(nullptr), m_linkUp(false), m_tInterframeGap(0), m_node(nullptr) {
      // Allocate GPU memory for packet buffers
      // m_queueSize = 1024;
      // cudaStreamCreate(&m_stream);
      cudaMallocManaged(&d_packetQueue, m_queueSize * sizeof(CudaPacket)); // Example size
      cudaMallocManaged(&d_queueFront, sizeof(int));
      cudaMallocManaged(&d_queueRear, sizeof(int));
      // initliaze queue front and rear
      uint32_t zero = 0;
      cudaMemcpy(d_queueFront, &zero, sizeof(uint32_t), cudaMemcpyHostToDevice);
      cudaMemcpy(d_queueRear, &zero, sizeof(uint32_t), cudaMemcpyHostToDevice);
      // *d_queueFront = *d_queueRear = 0;
  }

  CudaNetDevice::~CudaNetDevice() {
      // cudaStreamDestroy(m_stream);
      cudaFree(d_packetQueue);
      checkCudaErr();
      cudaFree(d_queueFront);
      checkCudaErr();
      cudaFree(d_queueRear);
      checkCudaErr();
  }

  void CudaNetDevice::SetAddress(Address address) {
      m_address = Mac48Address::ConvertFrom(address);
      printf("Set address at CudaNetDevice\n");
  }

  Address CudaNetDevice::GetAddress() const {
      return m_address;
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
      checkCudaErr();

      return true; // Indicate success
  }

  void CudaNetDevice::SetReceiveCallback(NetDevice::ReceiveCallback cb) {
      m_rxCallback = cb;
      printf("Set receive callback at CudaNetDevice\n");
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

      // PacketProcessingKernel<<<gridSize, blockSize, 0, m_stream>>>(d_packetQueue, packetSize);

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
      // TransmitKernel<<<1, 256>>>(d_packetQueue, d_queueFront, d_queueRear, m_queueSize, 100.0, 1.0); // 100 Mbps, 1 ms delay
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
      d_bps = bps.GetBitRate();
  }

  Ptr<Node> CudaNetDevice::GetNode() const {
      return m_node;
  }

  void CudaNetDevice::SetNode(Ptr<Node> node) {
      m_node = node;
  }

  void CudaNetDevice::Receive(CudaPacket* packet) {
      // Process received packet
      printf("Received packet on GPU, Node id: %d, packet id: %d\n", m_node->GetId(), packet->GetUid());
      m_rxCallback(this, (ns3::Packet*)packet, 69, Address());
      // ProcessPacketOnCuda(packet);
  } 

  __device__ void CudaNetDevice::test(const uint8_t *data, CUDA_cb_data* cb_data) {
      printf("CudaNetDevice: Test function, packet0: %d\n", data[0]);
      if(m_linkUp == false)
        printf("Link is down\n");

      if(m_txMachineState != READY)
        printf("Transmitter is not ready\n");
      else
        printf("Transmitter is ready\n");

      // if(EnqueuePacket(data, 256) == false)
      //   printf("Enqueue failed\n");
      // else{
      //   if(m_txMachineState == READY){
      //     // cudaFree((void*)data);
      //     uint8_t* packet = DequeuePacket();
      //     TransmitStart(packet, 256, cb_data);
      //   }
      // }
  }

  __device__ void CudaNetDevice::Send(CudaPacket* d_packet, uint32_t destination, uint16_t protocol, CUDA_cb_data* cb_data) {
      printf("CudaNetDevice: Send function, packet id: %d\n", d_packet->GetUid());
      if(m_linkUp == false)
        printf("Link is down\n");

      if(m_txMachineState != READY)
        printf("Transmitter is not ready\n");
      else
        printf("Transmitter is ready\n");

      if(EnqueuePacket(d_packet) == false)
        printf("Enqueue failed\n");
      else{
        if(m_txMachineState == READY){
          // cudaFree((void*)data);
          CudaPacket* packet = DequeuePacket();
          TransmitStart(packet, cb_data);
        }
      }
  }

  __device__ bool CudaNetDevice::TransmitStart(CudaPacket* packet, CUDA_cb_data* cb_data) {
    // Start transmission
    // assuming size is in bytes
    if(m_txMachineState == BUSY) {
      printf("Transmitter busy, dropping packet\n");
      return false;
    }
    m_txMachineState = BUSY;
    // assuming m_InterframeGap is 0
    float TxTime = (float)(packet->GetSize() * 8) / d_bps; // in seconds

    cb_data->empty = false;
    // cudaMalloc((void**)&(cb_data->next), sizeof(CUDA_cb_data));
    // cb_data->next->init();
    cb_data->packetSize = 666;
    cb_data->dst = this;
    cb_data->delay = TxTime;
    cb_data->func_id = 1;

    bool result = m_channel->TransmitStart(packet, this, TxTime, cb_data);
    if(result == false) {
      printf("Channel TransmitStart failed\n");
    }

    return result;
  }

  

  __global__ void d_TransmitComplete(CudaNetDevice* device, cudaStream_t stream, CUDA_cb_data* cb_data) {
    CudaPacket* packet = device->DequeuePacket();
    if(packet == nullptr){
      printf("packet queue is empty\n");
      return;
    }
    
    device->TransmitStart(packet, cb_data);
  }

  void CudaNetDevice::TransmitComplete(cudaStream_t stream) {
    if(m_txMachineState != BUSY){
      printf("Device state must be busy\n");
      return;
    }
    m_txMachineState = READY;
    printf("Reset device status on GPU\n");

    CUDA_cb_data* d_data = new CUDA_cb_data();
    d_data->addNext(1);
    // 
    d_TransmitComplete<<<1, 1, 0, stream>>>(this, stream, d_data);
    cudaMemcpyAsync(nullptr, nullptr, 0, cudaMemcpyDeviceToHost, stream);
    cudaStreamAddCallback(stream, Cuda_ScheduleCallBack, d_data, 0);
  }
  // enqueue packet and start transmit(as kernel return queue status at different fucntion is troublesome)
  __device__ bool CudaNetDevice::EnqueuePacket(CudaPacket* packet) {
    // EnqueueKernel<<<1, 256>>>(d_packetQueue, d_queueFront, d_queueRear, m_queueSize, d_packet, size);
    // cudaDeviceSynchronize(); // Ensure enqueue completes
    
    // queue is full
    if ((*d_queueRear + 1) % m_queueSize == *d_queueFront) {
      printf("Queue is full, dropping packet\n");
      return false;
    }

    int pos = atomicAdd(d_queueRear, 1) % m_queueSize; // Use atomic operation for thread safety
    CudaPacket* entry = d_packetQueue + pos;         // Get position in the queue
    *entry = *packet; // Assign packet (uses device-side assignment operator)

    printf("Enqueued packet on GPU, pos: %d\n", pos);
    // __syncthreads();

    return true;
  }

  __device__ CudaPacket* CudaNetDevice::DequeuePacket() {
    // Dequeue packet from GPU
    if (*d_queueFront == *d_queueRear) {
      return nullptr; // Queue is empty
    }

    int pos = atomicAdd(d_queueFront, 1) % m_queueSize; // Use atomic operation for thread safety
    CudaPacket* entry = d_packetQueue + pos;         // Get position in the queue

    printf("Dequeued packet on GPU, pos: %d\n", pos);
    return entry;
  }

  void CudaNetDevice::InitializeCudaBuffers() {
      // Additional GPU memory initialization if needed
  }

  void CudaNetDevice::OffloadPacketProcessing() {
      // Launch GPU kernel to process packets
      printf("Launching packet processing kernel at CudaNetDevice\n");
  }

} // namespace ns3