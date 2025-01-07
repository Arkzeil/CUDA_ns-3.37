#ifndef CUDA_UDP_SOCKET_FACTORY_IMPL_H
#define CUDA_UDP_SOCKET_FACTORY_IMPL_H

#include "ns3/ptr.h"
#include "ns3/udp-socket-factory.h"

namespace ns3
{
    class CudaSocket;
    class CudaUdpL4Protocol;

    class CudaUdpSocketFactoryImpl : public UdpSocketFactory
    {
    public:
        CudaUdpSocketFactoryImpl();
        ~CudaUdpSocketFactoryImpl() override;

        void SetUdp(CudaUdpL4Protocol* udp);

        Ptr<Socket> CreateSocket();
        CudaSocket *CreateCudaSocket();

    protected:
        void DoDispose() override;

    private:
        CudaUdpL4Protocol* m_udp;
    };
} // namespace ns3

#endif /* CUDA_UDP_SOCKET_FACTORY_IMPL_H */