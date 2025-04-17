#ifndef CUDA_BRIDGE_HELPER_H
#define CUDA_BRIDGE_HELPER_H

#include <cuda_runtime.h>
#include "ns3/node-container.h"
#include "ns3/net-device-container.h"
#include "ns3/nstime.h"
#include "ns3/data-rate.h"
#include "../model/helper.h"

namespace ns3
{
    class CudaNetDevice;
    class CudaBridgeChannel;

    class CudaBridgeHelper: public Managed
    {
    public:
        CudaBridgeHelper();
        virtual ~CudaBridgeHelper();

        void SetDelay(Time delay);
        void SetBandwidth(DataRate bandwidth);
        /**
         *
         * \param node The node to install the device in
         * \param c Container of NetDevices to add as bridge ports
         * \returns A container holding the added net device.
         */
        NetDeviceContainer Install(Ptr<Node> node, NetDeviceContainer c);
    private:
        Time delay;
        DataRate bandwidth;
    };
} // namespace ns3
#endif // CUDA_BRIDGE_HELPER_H