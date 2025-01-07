#ifndef CUDA_IPV4_ADDRESS_HELPER_H
#define CUDA_IPV4_ADDRESS_HELPER_H

#include "ns3/ipv4-address.h"
#include "ns3/ipv4-address-generator.h"
#include "ns3/ipv4-address-helper.h"
#include "ns3/ipv4-interface-container.h"
#include "ns3/ipv4-interface.h"
#include "ns3/ipv4-interface-address.h"
#include "ns3/ipv4-interface-container.h"

namespace ns3{
    class CudaIpv4AddressHelper: public Ipv4AddressHelper{
        public:
            CudaIpv4AddressHelper();
            CudaIpv4AddressHelper(const Ipv4Address network, const Ipv4Mask mask, const Ipv4Address address);
            void SetBase(const Ipv4Address network, const Ipv4Mask mask, const Ipv4Address address);
            Ipv4Address NewAddress();
            Ipv4InterfaceContainer Assign(const NetDeviceContainer& c);
            Ipv4Address NewAddress();
            uint32_t NumAddressBits(uint32_t maskbits) const;
        private:
            uint32_t m_network;
            uint32_t m_mask;
            uint32_t m_address;
            uint32_t m_base;
            uint32_t m_shift;
            uint32_t m_max;
    };
}

#endif // CUDA_IPV4_ADDRESS_HELPER_H