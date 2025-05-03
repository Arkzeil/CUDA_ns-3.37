#include "ns3/core-module.h"
#include "ns3/network-module.h"
#include "ns3/internet-module.h"
#include "ns3/point-to-point-module.h"
#include "ns3/applications-module.h"
// #include "ns3/cuda_wrapper.h"
#include "ns3/bridge-module.h"
#include "ns3/arp-cache.h"
#include "ns3/arp-l3-protocol.h"
#include "ns3/ipv4-address.h"
#include "ns3/bridge-net-device.h"
#include "ns3/bridged-p2p-helper.h"

using namespace ns3;

NS_LOG_COMPONENT_DEFINE("SimpleCudaUdpHelperExample");

int main(int argc, char *argv[]) {
    // LogComponentEnable("UdpClient", LOG_LEVEL_INFO);
    // LogComponentEnable("UdpServer", LOG_LEVEL_INFO);
    // LogComponentEnable("BridgeNetDevice", LOG_LOGIC);
    // LogComponentEnableAll(LOG_LEVEL_INFO);
    
    uint32_t numGroups = 250; // Default number of test groups (multiple client-server pairs with shared intermediate switches)
    uint32_t numPairs = 1; // Default number of client-server pair group
    uint32_t numSwitches = 2; // Number of switches between each pairs
    
    // NodeContainer nodes;
    NodeContainer clients;
    NodeContainer servers;
    // nodes.Create(2 * numPairs);
    clients.Create(numGroups * numPairs);
    servers.Create(numGroups * numPairs);
    // printf("client node id: %d\n", clients.Get(0)->GetId());
    // printf("server node id: %d\n", servers.Get(0)->GetId());
    
    NodeContainer switchNodes;
    switchNodes.Create(numGroups * numSwitches);
    // printf("switch node id: %d\n", switchNodes.Get(0)->GetId());
    
    InternetStackHelper internet;
    // internet.Install(nodes);
    internet.SetIpv6StackInstall(false);
    internet.Install(clients);
    internet.Install(servers);

    BridgedP2PHelper pointToPoint;
    BridgeHelper bridge;

    uint32_t j = 1;
    
    for (uint32_t i = 0; i < numGroups; i++) {        
        pointToPoint.SetDeviceAttribute("DataRate", StringValue("1000Mbps"));
        pointToPoint.SetChannelAttribute("Delay", StringValue("20ms"));

        for(uint32_t pair = 0; pair < numPairs; pair++){
            uint32_t pairIndex = i * numPairs + pair;
            std::vector<NetDeviceContainer> switchLinks(numSwitches + 1); // Link between each segment

            // Connect client to switch
            switchLinks[0] = pointToPoint.Install(clients.Get(pairIndex), switchNodes.Get(numSwitches * i));
            // Connect server to switch
            switchLinks[numSwitches] = pointToPoint.Install(switchNodes.Get(numSwitches * (i + 1) - 1), servers.Get(pairIndex));
            // Connect switch to switch
            for(uint32_t k = 1; k < numSwitches; k++)
                switchLinks[k] = pointToPoint.Install(switchNodes.Get(numSwitches * i + k - 1), switchNodes.Get(numSwitches * i + k)); 

            NetDeviceContainer endpoints;
            endpoints.Add(switchLinks[0].Get(0));
            endpoints.Add(switchLinks[numSwitches].Get(1));

            for(uint32_t k = 0; k < numSwitches; k++){
                NetDeviceContainer switchPorts; // Collect all port netdevices
                switchPorts.Add(switchLinks[k].Get(1));
                switchPorts.Add(switchLinks[k + 1].Get(0));
                // printf("switch port 0: %p\n", GetPointer(switchPorts.Get(0)));
                // printf("switch port 1: %p\n", GetPointer(switchPorts.Get(1)));
                NetDeviceContainer bridge_dev = bridge.Install(switchNodes.Get(numSwitches * i + k), switchPorts);
                // manually make bridge learn the destination MAC address
                DynamicCast<BridgeNetDevice>(bridge_dev.Get(0))->Learn(Mac48Address::ConvertFrom(switchLinks[numSwitches].Get(1)->GetAddress()), DynamicCast<PointToPointNetDevice>(switchLinks[k + 1].Get(0)));
            }
            
            Ipv4AddressHelper address;
            std::ostringstream subnet;
            // if(i / 256 >= j)
            //     j++;
            uint32_t subnetIndex = i * numPairs + pair;
            subnet << "10." << (subnetIndex / 256 + 1) << "." << (subnetIndex % 256) << ".0";
            // subnet << "10.1." << i + 1 << ".0";
            address.SetBase(subnet.str().c_str(), "255.255.255.0");
            Ipv4InterfaceContainer interfaces = address.Assign(endpoints);
            
            // manually set up the ARP table
            Ptr<Ipv4Interface> ipv4Interface = interfaces.Get(0).first->GetObject<Ipv4L3Protocol>()->GetInterface(interfaces.Get(0).second);
            Ptr<ArpCache> arp = CreateObject<ArpCache>();
            arp->SetDevice(switchLinks[0].Get(0), ipv4Interface);
            arp->SetAliveTimeout(Seconds(30000));
            arp->SetDeadTimeout(Seconds(30000));
            arp->SetWaitReplyTimeout(Seconds(30000));
            ArpCache::Entry* entry = arp->Add(Ipv4Address::ConvertFrom(interfaces.GetAddress(1)));
            entry->SetMacAddress(switchLinks[numSwitches].Get(1)->GetAddress());
            entry->MarkPermanent();
            ipv4Interface->SetArpCache(arp);
            
            // manually set up the routing table
            Ptr<Ipv4StaticRouting> staticRouting = CreateObject<Ipv4StaticRouting>();
            clients.Get(pairIndex)->GetObject<Ipv4>()->SetRoutingProtocol(staticRouting);
            staticRouting->AddNetworkRouteTo(interfaces.GetAddress(1), Ipv4Mask("255.255.255.0"), 1);
            
            uint16_t port = 4000;
            UdpServerHelper server(port);
            ApplicationContainer serverApp = server.Install(servers.Get(pairIndex));
            serverApp.Start(Seconds(0.0));
            serverApp.Stop(Seconds(5000.0));
            
            UdpClientHelper client(interfaces.GetAddress(1), port);
            client.SetAttribute("MaxPackets", UintegerValue(4096));
            client.SetAttribute("Interval", TimeValue(MilliSeconds(10)));
            client.SetAttribute("PacketSize", UintegerValue(256));
            
            ApplicationContainer clientApp = client.Install(clients.Get(pairIndex));
            clientApp.Start(Seconds(1.0));
            clientApp.Stop(Seconds(32.0));
        }
    }

    // uint32_t ipAddress = interfaces.GetAddress(1).Get();
    // printf("address: %d\n", ipAddress); 
    // if (ipAddress) {
    //     char ipAddr[16];
    //     snprintf(ipAddr,sizeof ipAddr,"%u.%u.%u.%u" ,(ipAddress & 0xff000000) >> 24 
    //                                             ,(ipAddress & 0x00ff0000) >> 16
    //                                             ,(ipAddress & 0x0000ff00) >> 8
    //                                             ,(ipAddress & 0x000000ff));
    //     printf("address: %s\n", ipAddr);
    // }
    struct timespec start, end;
    double time_used;
    clock_gettime(CLOCK_MONOTONIC, &start);
    // Run the simulation
    Simulator::Run();
    Simulator::Destroy();

    clock_gettime(CLOCK_MONOTONIC, &end);
    time_used = (end.tv_sec - start.tv_sec) + (end.tv_nsec - start.tv_nsec) / 1e9;
    printf("Time used: %f\n", time_used);

    return 0;
}