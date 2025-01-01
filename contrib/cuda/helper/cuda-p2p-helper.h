#ifndef CUDA_P2P_HELPER_H
#define CUDA_P2P_HELPER_H

#include "ns3/cuda-net-device.h"
#include "ns3/cuda-p2p-channel.h"
#include "ns3/node-container.h"
#include "ns3/net-device-container.h"

namespace ns3
{
    class CudaP2PHelper
    {
    public:
        CudaP2PHelper();
        virtual ~CudaP2PHelper();

        void SetDelay(Time delay);
        void SetBandwidth(DataRate bandwidth);

        NetDeviceContainer Install(NodeContainer a);
        NetDeviceContainer Install(Ptr<Node> a, Ptr<Node> b);
    private:
        Time delay;
        DataRate bandwidth;
    };
} // namespace ns3

#endif // CUDA_P2P_NET_DEVICE_HELPER_H