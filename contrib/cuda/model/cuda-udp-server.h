#ifndef CUDA_UDP_SERVER_H
#define CUDA_UDP_SERVER_H

#include "ns3/core-module.h"
#include "ns3/udp-server.h"
#include "ns3/socket.h"
#include "ns3/udp-socket-factory.h"
#include "ns3/log.h"

#include <cuda_runtime.h>
#include "helper.h"

namespace ns3{
    class CudaSocket;
    class CUDA_cb_data;
    
    class CudaUdpServer: public Application, public Managed{
        public:
            __host__ static TypeId GetTypeId(void);

            CudaUdpServer();
            CudaUdpServer(uint16_t port);
            virtual ~CudaUdpServer();

            /**
             * \brief Returns the number of lost packets
             * \return the number of lost packets
             */
            uint32_t GetLost() const;

            /**
             * \brief Returns the number of received packets
             * \return the number of received packets
             */
            uint64_t GetReceived() const;
            /**
             * \brief Handle a packet reception.
             *
             * This function is called by lower layers.
             *
             * \param socket the socket the packet was received to.
             */
            __device__ void test();
            __device__ void HandleRead(CudaSocket* socket);

            void SetPort(uint16_t port);

        private:
            void StartApplication() override;
            void StopApplication() override;
            
            uint16_t m_port;                 //!< Port on which we listen for incoming packets.
            CudaSocket* m_cudaSocket;            //!< IPv4 Socket
            // Ptr<Socket> m_socket6;           //!< IPv6 Socket
            volatile uint64_cu m_received;             //!< Number of received packets
            uint32_t m_lossCounter; //!< Lost packet counter
    };
}

#endif // CUDA_UDP_SERVER_H