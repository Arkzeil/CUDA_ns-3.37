#include "cuda-p2p-helper.h"
#include "ns3/cuda-net-device.h"
#include "ns3/cuda-p2p-channel.h"
#include "ns3/cuda-elp-simulator.h"

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
        // Ptr<CudaNetDevice> deviceA = CreateObject<CudaNetDevice>();
        // Ptr<CudaNetDevice> deviceB = CreateObject<CudaNetDevice>();
        // Ptr<CudaP2PChannel> channel = CreateObject<CudaP2PChannel>();
        CudaNetDevice* deviceA = new CudaNetDevice();
        CudaNetDevice* deviceB = new CudaNetDevice();
        CudaP2PChannel* channel = new CudaP2PChannel();
        
        deviceA->SetDataRate(bandwidth);
        deviceA->SetAddress(Mac48Address::Allocate());
        deviceB->SetDataRate(bandwidth);
        deviceB->SetAddress(Mac48Address::Allocate());
        channel->SetDelay(delay);
        
        // deviceA->Attach(GetPointer(channel));
        // deviceB->Attach(GetPointer(channel));
        deviceA->Attach(channel);
        deviceB->Attach(channel);
        
        a->AddDevice(deviceA);
        b->AddDevice(deviceB);
        printf("Node 0 address: %p, device 0 address: %p\n", GetPointer(a), deviceA);
        printf("Node 1 address: %p, device 1 address: %p\n", GetPointer(b), deviceB);
        
        container.Add(deviceA);
        container.Add(deviceB);

        lookaheadTable.addValue(a->GetId(), b->GetId(), delay.GetNanoSeconds());
        lookaheadTable.addValue(b->GetId(), a->GetId(), delay.GetNanoSeconds());
        printf("Lookahead table: %d\n", lookaheadTable.getValue(a->GetId(), b->GetId()));
        
        return container;
    }
}