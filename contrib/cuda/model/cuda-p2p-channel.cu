#include "cuda-p2p-channel.h"

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

    CudaP2PChannel::CudaP2PChannel() {
        m_delay = Seconds(0.0);
        // cudaStreamCreate(&m_stream);
    }
    
    CudaP2PChannel::~CudaP2PChannel() {
        // cudaStreamDestroy(m_stream);
    }

    void CudaP2PChannel::Attach(CudaNetDevice *device) {
        // Attach the device to the channel
        for (uint32_t i = 0; i < N_DEVICES; i++) {
            if (m_link[i].m_state == INITIALIZING) {
                m_link[i].m_src = device;
                m_link[i].m_state = IDLE;
                return;
            }
        }
    }

    void CudaP2PChannel::SetDelay(Time delay) {
        m_delay = delay;
    }

    __device__ void CudaP2PChannel::TransmitPacket(const uint8_t* packet, uint32_t size) {
        // Transmit packet from one device to another
        // For simplicity, we will just copy the packet to the destination device
        // and process it there
        uint8_t* d_packet;
        cudaMalloc(&d_packet, size);
        cudaMemcpy(d_packet, packet, size, cudaMemcpyDeviceToDevice);
        m_link[1].m_dst->Receive(d_packet, size, 0, m_stream);
    }


} // namespace ns3
