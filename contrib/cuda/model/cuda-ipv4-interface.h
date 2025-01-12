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

namespace ns3{
    class CudaNetDevice;

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
            void SetMetric (uint16_t metric);

            __device__ void test(CudaNetDevice* device, const uint8_t *data);

            __host__ __device__ bool IsUp (void) const;
            void SetUp (void);
            void SetDown (void);

        private:
            CudaNetDevice* m_device;
            Ptr<Node> m_node;
            Ptr<TrafficControlLayer> m_tc;
            Ipv4InterfaceAddress m_address;
            bool m_isUp;
            uint16_t m_metric;
    };
}

#endif // CUDA_IPV4_INTERFACE_H