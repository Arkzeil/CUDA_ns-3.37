#include "ns3/core-module.h"
#include "ns3/network-module.h"
#include "ns3/internet-module.h"
#include "ns3/point-to-point-module.h"
#include "ns3/applications-module.h"
#include "ns3/cuda_wrapper.h"

using namespace ns3;

NS_LOG_COMPONENT_DEFINE("SimpleCudaUdpHelperExample");

int main(int argc, char *argv[]) {
    LogComponentEnable("UdpClient", LOG_LEVEL_INFO);
    LogComponentEnable("UdpServer", LOG_LEVEL_INFO);
    // Create two nodes
    NodeContainer nodes;
    nodes.Create(2);

    // Configure a simple point-to-point channel with minimal settings
    PointToPointHelper pointToPoint;
    pointToPoint.SetDeviceAttribute("DataRate", StringValue("1Mbps"));
    pointToPoint.SetChannelAttribute("Delay", StringValue("10ms"));

    // Install the net device on the nodes
    NetDeviceContainer devices;
    devices = pointToPoint.Install(nodes);

    // Install minimal Internet stack on the nodes
    InternetStackHelper internet;
    internet.Install(nodes);

    // Assign IP addresses to each device
    Ipv4AddressHelper address;
    address.SetBase("10.1.1.0", "255.255.255.0");
    Ipv4InterfaceContainer interfaces = address.Assign(devices);

    uint32_t ipAddress = interfaces.GetAddress(1).Get();
    printf("address: %d\n", ipAddress); 
    if (ipAddress) {
        char ipAddr[16];
        snprintf(ipAddr,sizeof ipAddr,"%u.%u.%u.%u" ,(ipAddress & 0xff000000) >> 24 
                                                ,(ipAddress & 0x00ff0000) >> 16
                                                ,(ipAddress & 0x0000ff00) >> 8
                                                ,(ipAddress & 0x000000ff));
        printf("address: %s\n", ipAddr);
    }

    // Set up the UDP server application on node 1
    uint16_t port = 4000;
    UdpServerHelper server(port);
    ApplicationContainer serverApp = server.Install(nodes.Get(1));
    serverApp.Start(Seconds(1.0));
    serverApp.Stop(Seconds(10.0));

    UdpClientHelper client(interfaces.GetAddress(1), port);
    client.SetAttribute("MaxPackets", UintegerValue(100));
    client.SetAttribute("Interval", TimeValue(Seconds(0.1)));
    client.SetAttribute("PacketSize", UintegerValue(1024));

    ApplicationContainer apps = client.Install(nodes.Get(0));
    apps.Start(Seconds(2.0));
    apps.Stop(Seconds(10.0));

    // Run the simulation
    Simulator::Run();
    Simulator::Destroy();

    return 0;
}