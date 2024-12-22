#ifndef CUDA_IPV4_H
#define CUDA_IPV4_H

#include "ns3/ipv4-l3-protocol.h"
#include "cuda_runtime.h"

namespace ns3 {

class GpuIpv4 : public Ipv4L3Protocol {
public:
    static TypeId GetTypeId(void);

    GpuIpv4();
    virtual ~GpuIpv4();

    // GPU-based routing
    void OffloadRoutingToGpu();
    // Override methods to offload to GPU
    // virtual bool Send(Ptr<Packet> packet, const Ipv4Header& header, Ptr<NetDevice> outDevice) override;
private:
    uint8_t* d_routingTable; // GPU memory for routing table
};

} // namespace ns3

#endif // GPU_IPV4_H
