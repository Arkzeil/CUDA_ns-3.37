#include "cuda-p2p-channel.h"
#include "cuda-net-device.h"
#include "ns3/cuda-helper.h"

namespace ns3 {

    NS_LOG_COMPONENT_DEFINE("CudaP2PChannel");
    NS_OBJECT_ENSURE_REGISTERED(CudaP2PChannel);

    TypeId CudaP2PChannel::GetTypeId(void) {
        static TypeId tid = TypeId("ns3::CudaP2PChannel")
                            .SetParent<Channel>()
                            .SetGroupName("PointToPoint")
                            .AddConstructor<CudaP2PChannel>()
                            .AddAttribute("Delay",
                                          "The propagation delay of the channel",
                                          TimeValue(Seconds(0.0)),
                                          MakeTimeAccessor(&CudaP2PChannel::m_delay),
                                          MakeTimeChecker());
        return tid;
    }

    CudaP2PChannel::CudaP2PChannel(): m_delay(Seconds(0.0)), m_stream(nullptr), m_nDevices(0) {
        // cudaStreamCreate(&m_stream);
    }

    CudaP2PChannel::CudaP2PChannel(Time delay): m_delay(delay), m_stream(nullptr), m_nDevices(0) {
        // cudaStreamCreate(&m_stream);
    }
    
    CudaP2PChannel::~CudaP2PChannel() {
        // cudaStreamDestroy(m_stream);
    }

    void CudaP2PChannel::Attach(CudaNetDevice *device) {
        // Attach the device to the channel
        m_link[m_nDevices++].m_src = device;

        if(m_nDevices == N_DEVICES) {
            // Both devices are attached, set the destination for each device
            m_link[0].m_dst = m_link[1].m_src;
            m_link[1].m_dst = m_link[0].m_src;
            m_link[0].m_state = IDLE;
            m_link[1].m_state = IDLE;
        }
    }

    void CudaP2PChannel::SetDelay(Time delay) {
        m_delay = delay;
        d_delay = delay.GetSeconds();
    }

    __device__ bool CudaP2PChannel::test(const uint8_t *data, CudaNetDevice* src, float txTime, CUDA_cb_data* cb_data) {
        // Test function for the channel
        printf("Test function in channel, packet 0: %d\n", data[0]);
        printf("Transmission time: %f\n", txTime);
        if(m_link[0].m_state == INITIALIZING || m_link[1].m_state == INITIALIZING) {
            printf("Channel not initialized\n");
            return false;
        }
        uint32_t wire = src == m_link[0].m_src ? 0 : 1;

        cb_data->empty = false;
        // cb_data->context = m_link[wire].m_dst->GetNode()->GetId();
        cb_data->packetSize = 256;
        cb_data->delay = txTime + d_delay;
        cb_data->dst = m_link[1].m_dst;
        // printf("Client: %p\n", m_link[1].m_dst);
        // cudaMalloc((void**)&cb_data->packetBuffer, cb_data->packetSize);
        cb_data->packetBuffer[0] = data[0];
        // cb_data->packetBuffer = const_cast<uint8_t*>(data);
        printf("Packet buffer: %d\n", cb_data->packetBuffer[0]);
        
        return true;
    }

    __device__ void CudaP2PChannel::TransmitPacket(CudaNetDevice* src, const uint8_t* packet, uint32_t size) {
        // Transmit packet from one device to another
        // For simplicity, we will just copy the packet to the destination device
        // and process it there
        if(m_link[0].m_state == INITIALIZING || m_link[1].m_state == INITIALIZING) {
            printf("Channel not initialized\n");
            return;
        }
        printf("transmitting packet in channel\n");

        // uint8_t* d_packet;
        // cudaMalloc(&d_packet, size);
        // cudaMemcpy(d_packet, packet, size, cudaMemcpyDeviceToDevice);
        // m_link[1].m_dst->Receive(d_packet, size, 0, m_stream);
    }

    __device__ void ReceivePacket(const uint8_t* packet, uint32_t size){
        // Receive packet from another device
        // For simplicity, we will just print the packet contents
        for (uint32_t i = 0; i < size; i++) {
            printf("%c", packet[i]);
        }
        printf("\n");
    }

} // namespace ns3
