#ifndef CUDA_IPV4_INTERFACE_H
#define CUDA_IPV4_INTERFACE_H

#include <cuda_runtime.h>
#include "ns3/ipv4-interface.h"
#include "ns3/ipv4-address.h"
#include "ns3/ipv4-interface-address.h"
#include "ns3/ptr.h"
#include "ns3/net-device.h"
#include "ns3/node.h"
#include "ns3/traffic-control-layer.h"
#include "helper.h"

#include "ns3/cuda-arp-cache.h"

namespace ns3{
    class CudaNetDevice;
    class CUDA_cb_data;
    class CudaPacket;

    class CudaIpv4Interface : public Ipv4Interface, public Managed{
        public:
            static TypeId GetTypeId (void);
            CudaIpv4Interface ();
            virtual ~CudaIpv4Interface ();

            void SetDevice (CudaNetDevice* device);
            __host__ __device__ CudaNetDevice* GetDevice (void) const;

            void SetNode (Ptr<Node> node);
            Ptr<Node> GetNode (void) const;

            void SetTrafficControlLayer (Ptr<TrafficControlLayer> tc);
            Ptr<TrafficControlLayer> GetTrafficControlLayer (void) const;

            void SetAddress (Ipv4InterfaceAddress address);
            Ipv4InterfaceAddress GetAddress (void) const;
            __host__ __device__ uint32_t d_GetAddress (void) const;
            __host__ __device__ CudaArpCache *GetArpCache (void);
            void SetMetric (uint16_t metric);

            __device__ void test(CudaNetDevice* device, const uint8_t *data, CUDA_cb_data* cb_data);
            __device__ void Send(CudaNetDevice* device, CudaPacket *d_packet, uint32_t destination, uint8_t* RawIpv4Header, CUDA_cb_data* cb_data);
            __device__ void OptimizeSend(CudaNetDevice* device, CudaPacket *d_packet, uint32_t destination, CUDA_cb_data* cb_data, uint64_t *currentTs);

            __host__ __device__ bool IsUp (void) const;
            void SetUp (void);
            void SetDown (void);

        private:
            CudaNetDevice* m_device;
            Ptr<Node> m_node;
            Ptr<TrafficControlLayer> m_tc;
            Ipv4InterfaceAddress m_address;
            uint32_t rawAddress;
            bool m_isUp;
            uint16_t m_metric;
            // simplified version of the ARP cache
            CudaArpCache m_arp;
    };
}

#endif // CUDA_IPV4_INTERFACE_H