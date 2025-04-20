#include "cuda-p2p-channel.h"
#include "cuda-net-device.h"
#include "ns3/cuda-helper.h"
#include "ns3/cuda-packet.h"
#include "ns3/cuda-elp-simulator.h"

namespace ns3 {

    NS_LOG_COMPONENT_DEFINE("CudaP2PChannel");
    NS_OBJECT_ENSURE_REGISTERED(CudaP2PChannel);

    TypeId CudaP2PChannel::GetTypeId(void) {
        static TypeId tid = TypeId("ns3::CudaP2PChannel")
                            .SetParent<Channel>()
                            .SetGroupName("cuda")
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
        m_cudaSim = (CudaELPSimulator*)GetPointer(Simulator::GetImplementation());
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

            NodeID = m_link[0].m_src->GetNode()->GetId();
            dst_NodeID = m_link[0].m_dst->GetNode()->GetId();

            printf("Device 0: %p, Device 1: %p\n", m_link[0].m_src, m_link[1].m_src);
        }
    }

    void CudaP2PChannel::SetDelay(Time delay) {
        m_delay = delay;
        d_delay = delay.GetNanoSeconds();;
    }

    __device__ void CudaP2PChannel::test(){
        printf("CudaP2PChannel: called Test from CUDA ELP Scheduler\n");
        // cudaSim_d->insert(this, 0, 0, 0);
    }

    __device__ bool CudaP2PChannel::test(const uint8_t *data, CudaNetDevice* src, float txTime, CUDA_cb_data* cb_data) {
        // Test function for the channel
        printf("Test function in channel, packet 0: %d\n", data[0]);
        // printf("Transmission time: %f\n", txTime);
        if(m_link[0].m_state == INITIALIZING || m_link[1].m_state == INITIALIZING) {
            printf("Channel not initialized\n");
            return false;
        }
        uint32_t wire = src == m_link[0].m_src ? 0 : 1;

        if(cb_data->next == nullptr) {
            printf("Next is null\n");
        }
        else{
            cb_data->next->empty = false;
            cb_data->packetSize = 256;
            cb_data->next->dst = m_link[wire].m_dst;
            cb_data->next->delay = txTime + d_delay;
            cb_data->next->func_id = 0;
            cb_data->next->packetBuffer[0] = data[0];
        }

        // cb_data->empty = false;
        // // cb_data->context = m_link[wire].m_dst->GetNode()->GetId();
        // cb_data->packetSize = 256;
        // cb_data->delay = txTime + d_delay;
        // cb_data->dst = m_link[wire].m_dst;
        // cb_data->func_id = 0;
        // // printf("Client: %p\n", m_link[1].m_dst);
        // // cudaMalloc((void**)&cb_data->packetBuffer, cb_data->packetSize);
        // cb_data->packetBuffer[0] = data[0];
        // cb_data->packetBuffer = const_cast<uint8_t*>(data);
        // printf("Packet buffer: %d\n", cb_data->packetBuffer[0]);
        // printf("Packet size: %d\n", cb_data->packetSize);

        // if(cb_data->next != nullptr) {
        //     printf("P2pChannel: Next packet size: %d\n", cb_data->next->packetSize);
        //     // printf("Next packet size: %d\n", cb_data->next->packetSize);
        //     printf("Next address: %p\n", cb_data->next);
        // }
        
        return true;
    }

    CudaNetDevice* CudaP2PChannel::GetDstDev(CudaNetDevice* src) {
        uint32_t wire = src == m_link[0].m_src ? 0 : 1;
        return m_link[wire].m_dst;
    }

    __device__ bool CudaP2PChannel::TransmitStart(CudaPacket* d_packet, CudaNetDevice* src, uint64_t txTime, CUDA_cb_data* cb_data) {
        // Transmit packet from one device to another
        // printf("TransmitStart function in channel, packet id: %d, data0: %d\n", d_packet->GetUid(), d_packet->m_data[0]);
        // printf("Device address: %p\n", src);
        // printf("Transmission time: %f\n", txTime);
        if(m_link[0].m_state == INITIALIZING || m_link[1].m_state == INITIALIZING) {
            printf("Channel not initialized\n");
            return false;
        }
        uint32_t wire = src == m_link[0].m_src ? 0 : 1;

        if(cb_data != nullptr){
            if(cb_data->next == nullptr) {
                printf("Next is null\n");
            }
            else{
                cb_data->next->empty = false;
                cb_data->packetSize = d_packet->GetSize();
                cb_data->next->dst = m_link[wire].m_dst;
                cb_data->next->delay = txTime + d_delay;
                cb_data->next->func_id = 0;
                cb_data->next->packetBuffer[0] = d_packet->m_data[0];
                cb_data->next->packet = d_packet;
            }
        }

        // for(int i = 0; i < 28; i++){
        //     printf("%d ", d_packet->m_data[i]);
        // }
        // printf("\n");

        uint32_t context;

        if(!wire)
            context = dst_NodeID;
        else
            context = NodeID;
        // printf("delay: %f\n", txTime + d_delay);
        // cudaSim_d->deviceMethod(this, 0);
        // d_packet->ready = 1;
        m_cudaSim->d_insert(m_link[wire].m_dst, txTime + d_delay, context, 2, UINT64_MAX, (void*)d_packet);
        // __threadfence();

        return true;
        // uint8_t* d_packet;
        // cudaMalloc(&d_packet, size);
        // cudaMemcpy(d_packet, packet, size, cudaMemcpyDeviceToDevice);
        // m_link[1].m_dst->Receive(d_packet, size, 0, m_stream);
    }
    __device__ bool CudaP2PChannel::TransmitStart_test(CudaPacket* d_packet, CudaNetDevice* src, uint64_t txTime, CUDA_cb_data* cb_data) {
        if(m_link[0].m_state == INITIALIZING || m_link[1].m_state == INITIALIZING) {
            printf("Channel not initialized\n");
            return false;
        }
        uint32_t wire = src == m_link[0].m_src ? 0 : 1;

        if(cb_data != nullptr){
            if(cb_data->next == nullptr) {
                printf("Next is null\n");
            }
            else{
                cb_data->next->empty = false;
                cb_data->packetSize = d_packet->GetSize();
                cb_data->next->dst = m_link[wire].m_dst;
                cb_data->next->delay = txTime + d_delay;
                cb_data->next->func_id = 0;
                cb_data->next->packetBuffer[0] = d_packet->m_data[0];
                cb_data->next->packet = d_packet;
            }
        }

        uint32_t context;

        if(!wire)
            context = dst_NodeID;
        else
            context = NodeID;

        m_cudaSim->d_insert(m_link[wire].m_dst, txTime + d_delay, context, 2, UINT64_MAX, (void*)d_packet);


        return true;
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
