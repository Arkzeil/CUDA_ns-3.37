#include "cuda-udp-socket-factory-impl.h"
#include "cuda-udp-l4-protocol.h"
#include "cuda-socket.h"

namespace ns3 {
    NS_LOG_COMPONENT_DEFINE("CudaUdpSocketFactoryImpl");

    CudaUdpSocketFactoryImpl::CudaUdpSocketFactoryImpl(): m_udp(nullptr) {
        // Constructor
    }

    CudaUdpSocketFactoryImpl::~CudaUdpSocketFactoryImpl() {
        // Destructor
    }

    void CudaUdpSocketFactoryImpl::SetUdp(CudaUdpL4Protocol* udp) {
        // Set the UDP protocol
        m_udp = udp;
    }

    Ptr<Socket> CudaUdpSocketFactoryImpl::CreateSocket() {
        // Create a new socket
        // return CreateObject<UdpSocket>();
        return m_udp->CreateSocket();
    }

    CudaSocket* CudaUdpSocketFactoryImpl::CreateCudaSocket() {
        // Create a new CUDA socket
        return m_udp->CreateSocket();
    }

    void CudaUdpSocketFactoryImpl::DoDispose() {
        // Dispose of the socket
        m_udp = nullptr;
    }
} // namespace ns3