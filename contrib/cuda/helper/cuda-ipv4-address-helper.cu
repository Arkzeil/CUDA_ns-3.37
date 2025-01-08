#include "cuda-ipv4-address-helper.h"
#include "ns3/cuda-ipv4-l3-protocol.h"
#include "ns3/cuda-net-device.h"

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

    CudaIpv4AddressHelper::CudaIpv4AddressHelper(const Ipv4Address network, const Ipv4Mask mask, const Ipv4Address address) {
        //
        // Set the base address
        //
        SetBase(network, mask, address);
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
        m_base = m_address = address.Get();
        m_shift = NumAddressBits(m_mask);
        m_max = (1 << m_shift) - 2;
        m_network >>= m_shift;
    }

    Ipv4Address CudaIpv4AddressHelper::NewAddress() {
        //
        // Generate a new address
        //
        Ipv4Address addr((m_network << m_shift) | m_address);
        ++m_address;
        //
        // The Ipv4AddressGenerator allows us to keep track of the addresses we have
        // allocated and will assert if we accidentally generate a duplicate.  This
        // avoids some really hard to debug problems.
        //
        Ipv4AddressGenerator::AddAllocated(addr);
        return addr;
    }

    Ipv4InterfaceContainer CudaIpv4AddressHelper::Assign(const NetDeviceContainer& c) {
        //
        // Assign addresses to the devices in the container
        //
        Ipv4InterfaceContainer retval;

        for(uint32_t i = 0; i < c.GetN(); i++) {
            Ptr<NetDevice> device = c.Get(i);
            Ptr<Node> node = device->GetNode();
            // Ptr<Ipv4> ipv4 = node->GetObject<Ipv4>();
            Ptr<CudaIpv4L3Protocol> ipv4 = node->GetObject<CudaIpv4L3Protocol>();
            if(ipv4 == nullptr){
                NS_LOG_ERROR("No Ipv4L3Protocol found for node");
                return retval;
            }
            int32_t interface = ipv4->GetInterfaceForDevice(GetPointer(DynamicCast<CudaNetDevice>(device)));
            if(interface == -1) {
                NS_LOG_ERROR("No interface found for device");
                interface = ipv4->AddInterface(GetPointer(DynamicCast<CudaNetDevice>(device)));
            }
            Ipv4InterfaceAddress ipv4Addr = Ipv4InterfaceAddress(NewAddress(), m_mask);
            if(ipv4->AddAddress(interface, ipv4Addr) == false) {
                NS_LOG_ERROR("Error adding address to interface");
            }
            ipv4->SetMetric(interface, 1);
            ipv4->SetUp(interface);
            retval.Add(ipv4, interface);
            // Ptr<Ipv4Interface> interface = ipv4->GetInterface(0);
            // Ipv4InterfaceAddress address = interface->GetAddress(0);
            // address.SetLocal(Ipv4Address(m_base | (m_address & m_max)));
            // address.SetMask(Ipv4Mask(m_mask));
            // interface->SetAddress(address);
            // m_address = (m_address + 1) & m_max;
        }
        printf("retval.GetN() = %d\n", retval.GetN());
        return retval;
    }

    uint32_t CudaIpv4AddressHelper::NumAddressBits(uint32_t maskbits) const {
        //
        // Calculate the number of address bits
        //
        uint32_t bits = 0;
        for(uint32_t i = 0; i < 32; i++) {
            if(maskbits & (1 << i)) {
                bits++;
            }
        }
        return bits;
    }
}