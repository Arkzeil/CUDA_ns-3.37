#include "ns3/core-module.h"
#include "ns3/network-module.h"
#include "ns3/internet-module.h"
#include "ns3/point-to-point-module.h"
#include "ns3/applications-module.h"
// #include "ns3/cuda_wrapper.h"

using namespace ns3;

NS_LOG_COMPONENT_DEFINE("SimpleCudaUdpHelperExample");

int main(int argc, char *argv[]) {
    // LogComponentEnable("UdpClient", LOG_LEVEL_INFO);
    // LogComponentEnable("UdpServer", LOG_LEVEL_INFO);
    
    uint32_t numPairs = 500; // Default number of client-server pairs
    // Create two nodes
    NodeContainer nodes;
    nodes.Create(2 * numPairs);
    
    InternetStackHelper internet;
    internet.Install(nodes);

    uint32_t j = 1;
    
    for (uint32_t i = 0; i < numPairs; i++) {
        NodeContainer pair(nodes.Get(2 * i), nodes.Get(2 * i + 1));
        
        PointToPointHelper pointToPoint;
        pointToPoint.SetDeviceAttribute("DataRate", StringValue("10Mbps"));
        pointToPoint.SetChannelAttribute("Delay", StringValue("2ms"));
        
        NetDeviceContainer devices = pointToPoint.Install(pair);
        
        Ipv4AddressHelper address;
        std::ostringstream subnet;
        if(i / 256 >= j)
            j++;
        subnet << "10." << j << "." << (i + 1) % 256 << ".0";
        // subnet << "10.1." << i + 1 << ".0";
        address.SetBase(subnet.str().c_str(), "255.255.255.0");
        Ipv4InterfaceContainer interfaces = address.Assign(devices);
        
        Ptr<Ipv4StaticRouting> staticRouting = CreateObject<Ipv4StaticRouting>();
        pair.Get(0)->GetObject<Ipv4>()->SetRoutingProtocol(staticRouting);
        staticRouting->AddNetworkRouteTo(interfaces.GetAddress(1), Ipv4Mask("255.255.255.0"), 1);
        
        uint16_t port = 4000;
        UdpServerHelper server(port);
        ApplicationContainer serverApp = server.Install(pair.Get(1));
        serverApp.Start(Seconds(0.0));
        serverApp.Stop(Seconds(1002.0));
        
        UdpClientHelper client(interfaces.GetAddress(1), port);
        client.SetAttribute("MaxPackets", UintegerValue(1024));
        client.SetAttribute("Interval", TimeValue(Seconds(1)));
        client.SetAttribute("PacketSize", UintegerValue(256));
        
        ApplicationContainer clientApp = client.Install(pair.Get(0));
        clientApp.Start(Seconds(1.0));
        clientApp.Stop(Seconds(1001.0));
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