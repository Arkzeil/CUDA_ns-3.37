#include "cuda-bridge-helper.h"
#include "ns3/cuda-net-device.h"
#include "ns3/cuda-p2p-channel.h"
#include "ns3/cuda-elp-simulator.h"
#include "ns3/cuda-bridge-net-device.h"

namespace ns3 {
    NS_LOG_COMPONENT_DEFINE("CudaBridgeHelper");

    CudaBridgeHelper::CudaBridgeHelper(): delay(0), bandwidth(0) {
        // Set default values
    }
    
    CudaBridgeHelper::~CudaBridgeHelper() {
        // Destructor
    }

    void CudaBridgeHelper::SetDelay(Time delay) {
        // Set the delay of the bridge net device
        this->delay = delay;
    }

    void CudaBridgeHelper::SetBandwidth(DataRate bandwidth) {
        // Set the bandwidth of the bridge net device
        this->bandwidth = bandwidth;
    }

    NetDeviceContainer CudaBridgeHelper::Install(Ptr<Node> node, NetDeviceContainer c) {
        // Install P2P net devices on the nodes
        NetDeviceContainer devs;
        // Ptr<CudaNetDevice> deviceA = CreateObject<CudaNetDevice>();
        // Ptr<CudaNetDevice> deviceB = CreateObject<CudaNetDevice>();
        // Ptr<CudaP2PChannel> channel = CreateObject<CudaP2PChannel>();
        CudaBridgeNetDevice* dev = new CudaBridgeNetDevice();
        devs.Add(dev);
        node->AddDevice(dev);
       
        for(NetDeviceContainer::Iterator i = c.Begin(); i != c.End(); ++i) {
            // Ptr<CudaNetDevice> device = DynamicCast<CudaNetDevice>(*i);
            // if (device == 0) {
            //     NS_FATAL_ERROR("CudaBridgeHelper::Install(): Not a CudaNetDevice");
            // }
            // dev->AddBridgePort(device);
            dev->AddBridgePort(*i);
        }

        return devs;
        
        // deviceA->SetDataRate(bandwidth);
        // deviceA->SetAddress(Mac48Address::Allocate());
        // deviceB->SetDataRate(bandwidth);
        // deviceB->SetAddress(Mac48Address::Allocate());
        // channel->SetDelay(delay);
        
    }
}