#ifndef CUDA_IPV4_HEADER_H
#define CUDA_IPV4_HEADER_H

#include "ns3/header.h"
#include "ns3/ipv4-address.h"
#include <cuda_runtime.h>

namespace ns3{
    /**
     * \ingroup ipv4
     *
     * \brief Packet header for IPv4
     */
    class CudaIpv4Header : public Header{

    };

} // namespace ns3

#endif // CUDA_IPV4_HEADER_H