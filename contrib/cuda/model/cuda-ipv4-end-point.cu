#include "cuda-ipv4-end-point.h"
#include "ns3/cuda-socket.h"

namespace ns3{
    NS_LOG_COMPONENT_DEFINE("CudaIpv4EndPoint");

    CudaIpv4EndPoint::CudaIpv4EndPoint(): 
                                        m_localAddress(0), 
                                        m_localPort(0), 
                                        m_peerAddress(0), 
                                        m_peerPort(0), 
                                        m_boundNetDevice(nullptr), 
                                        m_rxEnabled(false) {
        // Constructor
        printf("CudaIpv4EndPoint initialized\n");
    }

    CudaIpv4EndPoint::CudaIpv4EndPoint(uint32_t address, uint16_t port): 
                                        m_localAddress(address), 
                                        m_localPort(port), 
                                        m_peerAddress(0), 
                                        m_peerPort(0), 
                                        m_boundNetDevice(nullptr), 
                                        m_rxEnabled(false) {
        // Constructor
        printf("CudaIpv4EndPoint initialized\n");
    }

    CudaIpv4EndPoint::~CudaIpv4EndPoint() {
        // Destructor
    }

    __host__ __device__ void CudaIpv4EndPoint::ForwardUp(CudaPacket* p, const Ipv4Header& header, uint16_t sport, CudaIpv4Interface* incomingInterface) {
        // Forward up
    }

    // void CudaIpv4EndPoint::ForwardIcmp(Ipv4Address icmpSource, uint8_t icmpTtl, uint8_t icmpType, uint8_t icmpCode, uint32_t icmpInfo) {
    //     // Forward ICMP
    // }

    __host__ __device__ void CudaIpv4EndPoint::SetRxEnabled(bool enabled) {
        // Set RX enabled
        m_rxEnabled = enabled;
    }

    __host__ __device__ bool CudaIpv4EndPoint::IsRxEnabled() {
        // Check if RX is enabled
        return m_rxEnabled;
    }

    __host__ __device__ uint16_t CudaIpv4EndPoint::GetLocalPort() {
        // Get local port
        return m_localPort;
    }

    __host__ __device__ uint32_t CudaIpv4EndPoint::GetLocalAddress() {
        // Get local address
        return m_localAddress;
    }

    __host__ __device__ uint16_t CudaIpv4EndPoint::GetPeerPort() {
        // Get peer port
        return m_peerPort;
    }

    __host__ __device__ uint32_t CudaIpv4EndPoint::GetPeerAddress() {
        // Get peer address
        return m_peerAddress;
    }

    __host__ __device__ void CudaIpv4EndPoint::SetLocalAddress(uint32_t address) {
        // Set local address
        m_localAddress = address;
    }

    __host__ __device__ void CudaIpv4EndPoint::SetPeerAddress(uint32_t address) {
        // Set peer address
        m_peerAddress = address;
    }

    __host__ __device__ void CudaIpv4EndPoint::SetLocalPort(uint16_t port) {
        // Set local port
        m_localPort = port;
    }

    __host__ __device__ void CudaIpv4EndPoint::SetPeerPort(uint16_t port) {
        // Set peer port
        m_peerPort = port;
    }

    __host__ __device__ CudaNetDevice* CudaIpv4EndPoint::GetBoundNetDevice() {
        // Get bound net device
        return m_boundNetDevice;
    }

    __host__ __device__ void CudaIpv4EndPoint::BindToNetDevice(CudaNetDevice* device) {
        // Bind to net device
        m_boundNetDevice = device;
    }

    __host__ __device__ void CudaIpv4EndPoint::SetSocket(CudaSocket* socket) {
        // Set socket
        m_socket = socket;
    }

    __host__ __device__ CudaSocket* CudaIpv4EndPoint::GetSocket() {
        // Get socket
        return m_socket;
    }
}