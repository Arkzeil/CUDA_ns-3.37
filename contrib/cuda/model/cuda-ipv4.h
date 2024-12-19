#ifndef CUDA_IPV4_H
#define CUDA_IPV4_H

#include "ns3/ipv4.h"
#include "cuda_runtime.h"

namespace ns3 {

class GpuIpv4 : public Ipv4 {
public:
    static TypeId GetTypeId(void);

    GpuIpv4();
    virtual ~GpuIpv4();

    // GPU-based routing
    void OffloadRoutingToGpu();

private:
    uint8_t* d_routingTable; // GPU memory for routing table
};

} // namespace ns3

#endif // GPU_IPV4_H
