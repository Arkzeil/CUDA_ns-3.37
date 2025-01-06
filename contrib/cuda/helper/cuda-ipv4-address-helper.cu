#include "cuda-ipv4-address-helper.h"

namespace ns3{
    NS_LOG_COMPONENT_DEFINE("CudaIpv4AddressHelper");

    CudaIpv4AddressHelper::CudaIpv4AddressHelper() {
        //
        // Set the default values to an illegal state.  Do this so the client is
        // forced to think at least briefly about what addresses get used and what
        // is going on here.
        //
        m_network = 0xffffffff;
        m_mask = 0;
        m_address = 0xffffffff;
        m_base = 0xffffffff;
        m_shift = 0xffffffff;
        m_max = 0xffffffff;
    }

    CudaIpv4AddressHelper::~CudaIpv4AddressHelper() {
        //
        // Nothing to do
        //
    }

    void CudaIpv4AddressHelper::SetBase(const Ipv4Address network, const Ipv4Mask mask, const Ipv4Address address) {
        //
        // Set the base address
        //
        m_network = network.Get();
        m_mask = mask.Get();
        m_address = address.Get();
        m_base = m_network & m_mask;
        m_shift = 32 - NumAddressBits(m_mask);
        m_max = (1 << NumAddressBits(m_mask)) - 1;
    }

    Ipv4InterfaceContainer CudaIpv4AddressHelper::Assign(const NetDeviceContainer& c) {
        //
        // Assign addresses to the devices in the container
        //
        for(uint32_t i = 0; i < c.GetN(); i++) {
            Ptr<NetDevice> device = c.Get(i);
            Ptr<Node> node = device->GetNode();
            Ptr<Ipv4> ipv4 = node->GetObject<Ipv4>();
            Ptr<Ipv4Interface> interface = ipv4->GetInterface(0);
            Ipv4InterfaceAddress address = interface->GetAddress(0);
            address.SetLocal(Ipv4Address(m_base | (m_address & m_max)));
            address.SetMask(Ipv4Mask(m_mask));
            interface->SetAddress(address);
            m_address = (m_address + 1) & m_max;
        }
    }
}