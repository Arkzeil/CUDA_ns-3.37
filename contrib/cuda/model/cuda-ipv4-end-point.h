#ifndef CUDA_IPV4_END_POINT_H
#define CUDA_IPV4_END_POINT_H

#include "ns3/ipv4-end-point.h"
#include "cuda-net-device.h"
#include "cuda-ipv4-interface.h"
#include <cuda_runtime.h>
#include "helper.h"

namespace ns3{
    class CudaPacket;
    class CudaNetDevice;
    class CudaSocket;

    class CudaIpv4EndPoint: public Managed{
        public:
            CudaIpv4EndPoint();
            CudaIpv4EndPoint(uint32_t address, uint16_t port);
            ~CudaIpv4EndPoint();
            __host__ __device__ void ForwardUp(CudaPacket* p, const Ipv4Header& header, uint16_t sport, CudaIpv4Interface* incomingInterface);
            // void ForwardIcmp(uint32_t icmpSource, uint8_t icmpTtl, uint8_t icmpType, uint8_t icmpCode, uint32_t icmpInfo);
            __host__ __device__ void SetRxEnabled(bool enabled);
            __host__ __device__ bool IsRxEnabled();
            __host__ __device__ uint16_t GetLocalPort();
            __host__ __device__ uint32_t GetLocalAddress();
            __host__ __device__ uint16_t GetPeerPort();
            __host__ __device__ uint32_t GetPeerAddress();
            __host__ __device__ void SetLocalAddress(uint32_t address);
            __host__ __device__ void SetPeerAddress(uint32_t address);
            __host__ __device__ void SetLocalPort(uint16_t port);
            __host__ __device__ void SetPeerPort(uint16_t port);
            __host__ __device__ CudaNetDevice* GetBoundNetDevice();
            __host__ __device__ void BindToNetDevice(CudaNetDevice* device);
            __host__ __device__ void SetSocket(CudaSocket* socket);
            __host__ __device__ CudaSocket* GetSocket();

        private:
            uint16_t m_localPort;
            uint32_t m_localAddress;
            uint16_t m_peerPort;
            uint32_t m_peerAddress;
            CudaNetDevice* m_boundNetDevice;
            bool m_rxEnabled;
            CudaSocket* m_socket;
    };
}

#endif // CUDA_IPV4_END_POINT_H