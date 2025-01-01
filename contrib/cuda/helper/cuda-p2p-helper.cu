#include "cuda-p2p-helper.h"

namespace ns3 {
    NS_LOG_COMPONENT_DEFINE("CudaPointToPointHelper");

    CudaP2PHelper::CudaP2PHelper(): delay(0), bandwidth(0) {
        // Set default values
    }
    
    CudaP2PHelper::~CudaP2PHelper() {
        // Destructor
    }

    void CudaP2PHelper::SetDelay(Time delay) {
        // Set the delay of the P2P net device
        this->delay = delay;
    }

    void CudaP2PHelper::SetBandwidth(DataRate bandwidth) {
        // Set the bandwidth of the P2P net device
        this->bandwidth = bandwidth;
    }

    NetDeviceContainer CudaP2PHelper::Install(NodeContainer a) {
        // Install P2P net devices on the nodes in the container
        if(a.GetN() != 2) {
            NS_LOG_ERROR("Node container must contain exactly 2 nodes");
        }
        return Install(a.Get(0), a.Get(1));
    }

    NetDeviceContainer CudaP2PHelper::Install(Ptr<Node> a, Ptr<Node> b) {
        // Install P2P net devices on the nodes
        NetDeviceContainer container;
        CudaNetDevice* deviceA = new CudaNetDevice();
        CudaNetDevice* deviceB = new CudaNetDevice();
        CudaP2PChannel* channel = new CudaP2PChannel(delay);
        
        deviceA->SetDataRate(bandwidth);
        deviceA->SetAddress(Mac48Address::Allocate());
        deviceB->SetDataRate(bandwidth);
        deviceB->SetAddress(Mac48Address::Allocate());
        channel->SetDelay(delay);
        
        deviceA->Attach(channel);
        deviceB->Attach(channel);
        
        a->AddDevice(deviceA);
        b->AddDevice(deviceB);
        
        container.Add(deviceA);
        container.Add(deviceB);
        
        return container;
    }
}