#ifndef CUDA_P2P_CHANNEL_H
#define CUDA_P2P_CHANNEL_H

#include "ns3/point-to-point-channel.h"
#include "ns3/point-to-point-net-device.h"
#include "ns3/log.h"
#include <cuda_runtime.h>
#include "helper.h"

namespace ns3
{
    class CudaNetDevice;
    class CUDA_cb_data;
    class CudaPacket;
    
    class CudaP2PChannel: public PointToPointChannel, public Managed{
        public:
            static TypeId GetTypeId(void);

            CudaP2PChannel();
            CudaP2PChannel(Time delay);
            virtual ~CudaP2PChannel();

            void Attach(CudaNetDevice *device);
            void SetDelay(Time delay);

            // GPU-specific methods
            __device__ void test();
            __device__ bool test(const uint8_t *data, CudaNetDevice* src, float txTime, CUDA_cb_data* cb_data);
            __device__ bool TransmitStart(CudaPacket* d_packet, CudaNetDevice* src, float txTime, CUDA_cb_data* cb_data);
            __device__ void ReceivePacket(const uint8_t* packet, uint32_t size);
        private:
            static const uint32_t N_DEVICES = 2;    // Number of devices in the channel
            uint32_t m_nDevices;    // Number of devices attached to the channel
            Time m_delay;       // Delay in nanoseconds
            uint32_t d_delay;   // Delay in device memory
            cudaStream_t m_stream;  // CUDA stream for async processing

        enum WireState
        {
            /** Initializing state */
            INITIALIZING,
            /** Idle state (no transmission from NetDevice) */
            IDLE,
            /** Transmitting state (data being transmitted from NetDevice. */
            TRANSMITTING,
            /** Propagating state (data is being propagated in the channel. */
            PROPAGATING
        };

        /**
         * \brief Wire model for the PointToPointChannel
         */
        class Link
        {
            public:
                /** \brief Create the link, it will be in INITIALIZING state
                 *
                 */
                Link()
                    : m_state(INITIALIZING),
                    m_src(nullptr),
                    m_dst(nullptr)
                {
                }

                WireState m_state;                //!< State of the link
                CudaNetDevice *m_src; //!< First NetDevice
                CudaNetDevice *m_dst; //!< Second NetDevice
        };

        Link m_link[N_DEVICES]; //!< Link model
    };
} // namespace ns3

#endif // CUDA_P2P_CHANNEL_H