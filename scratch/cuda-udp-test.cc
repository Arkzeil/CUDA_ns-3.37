#include "ns3/core-module.h"
#include "ns3/network-module.h"
#include "ns3/internet-module.h"
#include "ns3/point-to-point-module.h"
#include "ns3/cuda-udp-client.h"

using namespace ns3;

int main(int argc, char* argv[]) {
    LogComponentEnable("UdpClient", LOG_LEVEL_INFO);
    // Time::SetResolution(Time::NS);

    // Create nodes
    NodeContainer nodes;
    nodes.Create(2);

    // Create P2P link
    PointToPointHelper p2p;
    p2p.SetDeviceAttribute("DataRate", StringValue("1Mbps"));
    p2p.SetChannelAttribute("Delay", StringValue("10ms"));

    // Install the net device on the nodes
    NetDeviceContainer devices = p2p.Install(nodes);

    // Install Internet stack
    InternetStackHelper stack;
    stack.Install(nodes);

    Ipv4AddressHelper address;
    address.SetBase("10.1.1.0", "255.255.255.0");
    Ipv4InterfaceContainer interfaces = address.Assign(devices);

    // Install GpuUdpClient on Node 0
    uint16_t port = 8080;
    Address serverAddress(InetSocketAddress(interfaces.GetAddress(1), port));

    Ptr<GpuUdpClient> client = CreateObject<GpuUdpClient>();
    client->SetRemote(serverAddress);
    client->SetAttribute("MaxPackets", UintegerValue(100));
    client->SetAttribute("Interval", TimeValue(MilliSeconds(100)));
    client->SetAttribute("PacketSize", UintegerValue(1024));

    client->SetStartTime(Seconds(1.0));
    client->SetStopTime(Seconds(10.0));
    nodes.Get(0)->AddApplication(client);

    // Run simulation
    Simulator::Run();
    Simulator::Destroy();

    return 0;
}
