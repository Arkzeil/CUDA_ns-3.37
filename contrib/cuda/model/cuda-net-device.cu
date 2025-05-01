#include "cuda-net-device.h"
#include "cuda-packet-kernel.cuh"
#include "ns3/cuda-helper.h"
#include "ns3/cuda-udp-client.h"
#include "ns3/cuda-packet.h"
#include "ns3/cuda-ipv4-l3-protocol.h"
#include "ns3/cuda-elp-simulator.h"
#include "ns3/cuda-bridge-net-device.h"

namespace ns3 {

  NS_OBJECT_ENSURE_REGISTERED(CudaNetDevice);

  TypeId CudaNetDevice::GetTypeId(void) {
      static TypeId tid = TypeId("ns3::CudaNetDevice")
                          .SetParent<NetDevice>()
                          .SetGroupName("cuda")
                          .AddConstructor<CudaNetDevice>()
                          .AddAttribute("Mtu",
                                        "The MAC-level Maximum Transmission Unit",
                                        UintegerValue(DEFAULT_MTU),
                                        MakeUintegerAccessor(&CudaNetDevice::SetMtu,
                                                            &CudaNetDevice::GetMtu),
                                        MakeUintegerChecker<uint16_t>())
                          .AddAttribute("DataRate",
                                        "The default data rate for point to point links",
                                        DataRateValue(DataRate("32768b/s")),
                                        MakeDataRateAccessor(&CudaNetDevice::SetDataRate),
                                        MakeDataRateChecker())
                          .AddAttribute("InterframeGap",
                                        "The time to wait between packet (frame) transmissions",
                                        TimeValue(Seconds(0.0)),
                                        MakeTimeAccessor(&CudaNetDevice::m_tInterframeGap),
                                        MakeTimeChecker());
      return tid;
  }

  CudaNetDevice::CudaNetDevice(): m_queueSize(2048), m_rxCallback(nullptr), m_txMachineState(READY), 
  m_channel(nullptr), m_linkUp(false), m_tInterframeGap(0), m_node(nullptr), m_rxCB_enable(false), m_mtu(DEFAULT_MTU) {
      // Allocate GPU memory for packet buffers
      // m_queueSize = 1024;
      // cudaStreamCreate(&m_stream);
      cudaMallocManaged(&d_packetQueue, m_queueSize * sizeof(CudaPacket*)); // Example size
      cudaMallocManaged(&d_queueFront, sizeof(int));
      cudaMallocManaged(&d_queueRear, sizeof(int));
      // initliaze queue front and rear
      uint32_t zero = 0;
      cudaMemcpy(d_queueFront, &zero, sizeof(uint32_t), cudaMemcpyHostToDevice);
      cudaMemcpy(d_queueRear, &zero, sizeof(uint32_t), cudaMemcpyHostToDevice);
      // *d_queueFront = *d_queueRear = 0;
      m_cudaSim = (CudaELPSimulator*)GetPointer(Simulator::GetImplementation());
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

  void CudaNetDevice::SetIfIndex(const uint32_t index){
      m_ifIndex = index;
  }

  uint32_t CudaNetDevice::GetIfIndex() const{
      return m_ifIndex;
  }

  void CudaNetDevice::SetAddress(Address address) {
      m_address = Mac48Address::ConvertFrom(address);
      m_address.CopyTo(m_macAddress.addr);
      printf("Set address at CudaNetDevice\n");
  }

  Address CudaNetDevice::GetAddress() const {
      return m_address;
  }

  MACAddress CudaNetDevice::GetMacAddress() const {
      // return const_cast<uint8_t*>(m_macAddress); // Ensure m_macAddress is of type uint8_t[]
      return m_macAddress;
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

  __host__ void CudaNetDevice::AddBridgePort(Ptr<NetDevice> bridgePort){
      printf("Should not be called here\n");
  }

  bool CudaNetDevice::SupportsSendFrom() const {
      return true;
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

  bool CudaNetDevice::SetMtu(const uint16_t mtu) {
      m_mtu = mtu;
      return true;
  }

  uint16_t CudaNetDevice::GetMtu() const{
      return m_mtu;
  }

  __device__ uint16_t CudaNetDevice::d_GetMtu() const{
      return m_mtu;
  }

  Ptr<Node> CudaNetDevice::GetNode() const {
      return m_node;
  }

  void CudaNetDevice::SetNode(Ptr<Node> node) {
      m_node = node;
      m_ipv4 = (CudaIpv4L3Protocol*)GetPointer(node->GetObject<Ipv4>());
      NodeID = node->GetId();
  }

  __device__ bool CudaNetDevice::d_IsBroadcast() const {
      return true;
  }

  __device__ MACAddress CudaNetDevice::d_GetBroadcast() const {
      uint8_t broadcastAddr[6] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
      return MACAddress(broadcastAddr);
  }

  __device__ bool CudaNetDevice::d_NeedsArp() const {
      return true;
  }

  __host__ __device__ uint64_t CudaNetDevice::GetBandwidth(){
      return d_bps;
  }

  void CudaNetDevice::Receive(CudaPacket* packet) {
      // Process received packet
      printf("Received packet on GPU, Node id: %d, packet id: %d\n", m_node->GetId(), packet->GetUid());
      printf("Current simulation time: %f\n", Simulator::Now().GetSeconds());
      m_rxCallback(this, (ns3::Packet*)packet, 69, Address());
      // ProcessPacketOnCuda(packet);
  } 

  __device__ void CudaNetDevice::d_Receive(CudaPacket* packet, uint64_t *currentTs) {
      // for(int i = 0; i < 28; i++){
      //   printf("%d ", packet->m_data[i]);
      // }
      // printf("\n");
      // Process received packet
      // printf("Received packet on GPU, packet id: %d\n", packet->GetUid());
      if(packet->ready == 0){
        printf("Packet is not ready\n");
        return;
      }

      #ifdef CHECKSUM_CHECK
        uint32_t fcs = 0;
        packet->GetTrailer(&fcs, sizeof(fcs));
        // printf("FCS: %x\n", fcs);
        packet->RemoveTrailer(sizeof(fcs));
      #endif

      uint32_t ethertype_padded;
      uint16_t etherType;
      MACAddress dst;
      MACAddress src;

      packet->ExtractPayload(dst.addr, 0, 6);
      packet->RemoveHeader(6);
      packet->ExtractPayload(src.addr, 0, 6);
      packet->RemoveHeader(6);
      packet->ExtractPayload((uint8_t*)&ethertype_padded, 0, sizeof(ethertype_padded));
      packet->RemoveHeader(4);

      if(m_rxCB_enable){
        // the inheritance does not work in CUDA(I have to make descructor __device__, but its parent is in host space)
        // so I can only explictly do static cast
        etherType = ethertype_padded & 0xFFFF;
        ((CudaBridgeNetDevice*)bridge)->ReceiveFromDevice(this, packet, etherType, src, dst, PacketType::PACKET_OTHERHOST, currentTs);
      }
      else
        m_ipv4->d_Receive(this, packet);
      // ProcessPacketOnCuda(packet);
  }

  // __device__ void CudaNetDevice::ReceiveFromDevice() {
  //     // Process received packet
  //     printf("Should not be called here\n");
  //     // ProcessPacketOnCuda(packet);
  // }

  __host__ void CudaNetDevice::register_callback(CudaNetDevice* device) {
      // Register the callback function
      // m_rxCallback = device->m_rxCallback;
      // m_rxCB_enable = true;
      printf("Registering callback at CudaNetDevice\n");
      // m_rxCallback = device->m_rxCallback;
      m_rxCB_enable = true;
      bridge = device;
  }

  __device__ bool CudaNetDevice::isPortInBridge() {
      // Check if the device is in a bridge
      return m_rxCB_enable;
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

  __device__ void CudaNetDevice::Send(CudaPacket* d_packet, MACAddress destination, uint16_t protocol, CUDA_cb_data* cb_data, uint64_t *currentTs) {
      // // printf("CudaNetDevice: Send function, packet id: %d\n", d_packet->GetUid());
      // if(m_linkUp == false)
      //   printf("Link is down\n");

      // // if(m_txMachineState != READY)
      // //   printf("Transmitter is not ready\n");
      // // else
      // //   printf("Transmitter is ready\n");

      // if(EnqueuePacket(d_packet) == false)
      //   printf("Enqueue failed\n");
      // else{
      //   if(m_txMachineState == READY){
      //     // cudaFree((void*)data);
      //     CudaPacket* packet = DequeuePacket();
      //     if(packet == nullptr){
      //       printf("dequeued packet is null\n");
      //       return;
      //     }

      //     // cudaFree(d_packet->m_data);
          
      //     TransmitStart(packet, cb_data);
      //   }
      // }
      SendFrom(d_packet, m_macAddress, destination, protocol, currentTs);
  }

  __device__ void CudaNetDevice::SendFrom(CudaPacket* d_packet, MACAddress src, MACAddress dst, uint16_t protocol, uint64_t *currentTs) {
      // printf("CudaNetDevice: Send function, packet id: %d\n", d_packet->GetUid());
      if(m_linkUp == false)
        printf("Link is down\n");

      // if(m_txMachineState != READY)
      //   printf("Transmitter is not ready\n");
      // else
      //   printf("Transmitter is ready\n");
      uint32_t fcs;
      // if not padding, the header would not be aligned, error would occur when adding header
      uint32_t ethertype_padded = 0x0800; // IPv4
      d_packet->AddHeader(&ethertype_padded, sizeof(ethertype_padded));
      d_packet->AddHeader(src.addr, 6);
      d_packet->AddHeader(dst.addr, 6);

      #ifdef CHECKSUM_CHECK
        // fcs CRC32 implementation
        // AddTrailer is now deprecated
        d_packet->AddTrailer(&fcs, sizeof(fcs));
      #endif

      if(EnqueuePacket(d_packet) == false)
        printf("Enqueue failed\n");
      else{
        if(m_txMachineState == READY){
          // cudaFree((void*)data);
          CudaPacket* packet = DequeuePacket();
          if(packet == nullptr){
            printf("dequeued packet is null\n");
            return;
          }

          // cudaFree(d_packet->m_data);
          
          TransmitStart(packet, nullptr, currentTs);
        }
      }
  }

  __device__ bool CudaNetDevice::TransmitStart(CudaPacket* packet, CUDA_cb_data* cb_data, uint64_t *currentTs) {
    // Start transmission
    // assuming size is in bytes
    if(m_txMachineState == BUSY) {
      printf("Transmitter busy, dropping packet\n");
      return false;
    }
    m_txMachineState = BUSY;
    // assuming m_InterframeGap is 0
    double TxTime = (double)(packet->GetSize() * 8) / d_bps; // in seconds
    uint64_t d_interval = (uint64_t)(TxTime * 1e9); // in nanoseconds

    if(cb_data != nullptr){
      cb_data->empty = false;
      // cudaMalloc((void**)&(cb_data->next), sizeof(CUDA_cb_data));
      // cb_data->next->init();
      cb_data->packetSize = 0;
      cb_data->dst = this;
      cb_data->delay = TxTime;
      cb_data->func_id = 1;
    }
    // cudaEventSynchronize(m_event);
    // cudaFree(cb_data->packet->m_data);
    m_cudaSim->d_insert(this, *currentTs + d_interval, NodeID, 1, lookahead, nullptr);
    // m_cudaSim->d_insert(this, 1, 0, 2, 0, (void*)packet);

    bool result = m_channel->TransmitStart(packet, this, d_interval, cb_data, currentTs);
    if(result == false) {
      printf("Channel TransmitStart failed\n");
    }

    return result;
  }

  __device__ void CudaNetDevice::D_TransmitComplete(uint64_t *currentTs){
    if(m_txMachineState != BUSY){
      printf("Device state must be busy\n");
      return;
    }
    // m_txMachineState = READY;
    atomicExch(&m_txMachineState, READY);
    // printf("Reset device status using GPU\n");

    CudaPacket* packet = DequeuePacket();
    if(packet == nullptr){
      // printf("packet queue is empty\n");
      return;
    }
    
    TransmitStart(packet, nullptr, currentTs);
  }

  __global__ void d_TransmitComplete(CudaNetDevice* device, cudaStream_t stream, CUDA_cb_data* cb_data) {
    CudaPacket* packet = device->DequeuePacket();
    if(packet == nullptr){
      printf("packet queue is empty\n");
      return;
    }
    
    // device->TransmitStart(packet, cb_data);
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
    // Check if the queue is full

    if ((*d_queueRear + 1) == *d_queueFront) {
      printf("Queue is full, dropping packet\n");
      return false;
    }

    // use AND to replace MOD operation, which require queue size to be power of 2
    int pos = atomicAdd(d_queueRear, 1) & (m_queueSize - 1); // Use atomic operation for thread safety

    // CudaPacket* entry = d_packetQueue[pos];           // Get position in the queue

    // *entry = *packet; // Assign packet (uses device-side assignment operator)
    // entry = packet;
    d_packetQueue[pos] = packet;

    // printf("Enqueued packet on GPU, pos: %d\n", pos);

    return true;
  }

  __device__ CudaPacket* CudaNetDevice::DequeuePacket() {
    // Dequeue packet from GPU
    if (*d_queueFront == *d_queueRear) {
      return nullptr; // Queue is empty
    }

    int pos = atomicAdd(d_queueFront, 1) & (m_queueSize - 1); // Use atomic operation for thread safety
    // int pos = *d_queueFront & (m_queueSize - 1); // Get position in the queue
    // CudaPacket* entry = d_packetQueue[pos];  // Access packet

    // if (threadIdx.x == 0) {
    // *d_queueFront = (*d_queueFront + 1) & (m_queueSize - 1); // Update front position
    // }

    // printf("Dequeued packet on GPU, pos: %d\n", pos);

    return d_packetQueue[pos];
  }

  CudaP2PChannel *CudaNetDevice::GetChannel(){
      return m_channel;
  }

  void CudaNetDevice::InitializeCudaBuffers() {
      // Additional GPU memory initialization if needed
  }

  void CudaNetDevice::OffloadPacketProcessing() {
      // Launch GPU kernel to process packets
      printf("Launching packet processing kernel at CudaNetDevice\n");
  }

} // namespace ns3