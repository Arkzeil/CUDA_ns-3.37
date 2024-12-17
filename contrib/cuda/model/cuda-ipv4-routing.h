#ifndef CUDA_IPV4_ROUTING_H
#define CUDA_IPV4_ROUTING_H

#include "ns3/ipv4-routing-protocol.h"
#include <iostream>
#include <stdint.h>
#include <cuda_runtime.h>

class GpuIpv4Routing : public Ipv4RoutingProtocol {
    public:
        void RoutePacketsOnGpu();
    private:
        void* d_routingTable; // GPU routing table.
};

#endif // GPU_IPV4_ROUTING_H   