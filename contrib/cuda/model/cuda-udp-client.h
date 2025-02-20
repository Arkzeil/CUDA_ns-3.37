#ifndef CUDA_UDP_CLIENT_H
#define CUDA_UDP_CLIENT_H

#include "ns3/core-module.h"
#include "ns3/udp-client.h"
#include "ns3/socket.h"
#include "ns3/udp-socket-factory.h"
#include "ns3/log.h"
#include "ns3/cuda-simulator.h"
// #include "cuda-socket.h"
#include <cuda.h>
#include <cuda_runtime.h>
#include "helper.h"

namespace ns3{

    class CudaSocket;

    class CUDA_cb_data;

    class CudaUdpClient : public Application, public Managed{
        public:
            __host__ static TypeId GetTypeId(void);

            CudaUdpClient();
            virtual ~CudaUdpClient();
            void SetRemote(Address ip, uint16_t port);
            void SetRemote(Address addr);
            void SetPacketSize(uint32_t size);
            void SetSendInterval(Time interval);
            void RecvTest(Time sendTime);

            __device__ void test();
            __device__ void ELP_Send();

        protected:
            __host__ virtual void Send(); // Override the Send method.

        private:
            void StartApplication() override;
            void StopApplication() override;
            // __host__ void CudaUdpClient::OffloadToCuda(void);
            static void CUDART_CB Cuda_ReceiveCallback(cudaStream_t stream, cudaError_t status, void* data);
            void GeneratePacketOnGpu();
            __host__ void OffloadToCuda(int numPackets, int packetSize);
            __host__ void OffloadPacketToCuda(Ptr<Packet> packet);
            __host__ void InitCudaResources();
            __host__ void CleanupCudaResources();

            uint32_t m_count; //!< Maximum number of packets the application will send
            Time m_interval;  //!< Packet inter-send time
            uint32_t m_size;  //!< Size of the sent packet (including the SeqTsHeader)

            uint32_t *m_sent;       //!< Counter for sent packets
            uint64_cu *m_totalTx;    //!< Total bytes sent
            Ptr<Socket> m_socket;  //!< Socket
            CudaSocket* m_cudaSocket; //!< CUDA socket
            Address m_peerAddress; //!< Remote peer address
            uint16_t m_peerPort;   //!< Remote peer port
            EventId m_sendEvent;   //!< Event to send the next packet
            bool m_running;        //!< Flag to indicate if the application is running

            // GPU resources
            uint8_t* d_packetBuffer;      // Device memory for packet data
            cudaStream_t m_cudaStream;   // CUDA stream for async processing
    };

    __global__ void ProcessPacketKernel(uint8_t* packetBuffer, int packetSize);

} // namespace ns3

#endif // GPU_UDP_CLIENT_H
