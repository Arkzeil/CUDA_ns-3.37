#include "ns3/core-module.h"
#include "ns3/network-module.h"
#include "ns3/internet-module.h"
#include "ns3/point-to-point-module.h"
#include "ns3/applications-module.h"

using namespace ns3;

NS_LOG_COMPONENT_DEFINE("SimpleCudaUdpTestExample");

int main() {
  // Enable logging (optional)
//   LogComponentEnable("StaticRoutingExample", LOG_LEVEL_INFO);
    LogComponentEnable("UdpClient", LOG_LEVEL_INFO);
    LogComponentEnable("UdpServer", LOG_LEVEL_INFO);

  // Create nodes
  NodeContainer nodes;
  nodes.Create(3); // Create 3 nodes

  // Install Internet stack
  InternetStackHelper internet;
  internet.Install(nodes);

  // Create point-to-point links
  PointToPointHelper p2p;
  p2p.SetDeviceAttribute("DataRate", StringValue("5Mbps"));
  p2p.SetChannelAttribute("Delay", StringValue("2ms"));

  NetDeviceContainer devices01 = p2p.Install(nodes.Get(0), nodes.Get(1));
  NetDeviceContainer devices12 = p2p.Install(nodes.Get(1), nodes.Get(2));

  // Assign IP addresses
  Ipv4AddressHelper address;

  // Network 10.1.1.0/24
  address.SetBase("10.1.1.0", "255.255.255.0");
  Ipv4InterfaceContainer interfaces01 = address.Assign(devices01);

  // Network 10.1.2.0/24
  address.SetBase("10.1.2.0", "255.255.255.0");
  Ipv4InterfaceContainer interfaces12 = address.Assign(devices12);

  // Manually configure static routes

  // Node 0
  Ptr<Ipv4StaticRouting> staticRouting0 =
      CreateObject<Ipv4StaticRouting>();
  nodes.Get(0)->GetObject<Ipv4>()->SetRoutingProtocol(staticRouting0);

  // Node 1
  Ptr<Ipv4StaticRouting> staticRouting1 =
      CreateObject<Ipv4StaticRouting>();
  nodes.Get(1)->GetObject<Ipv4>()->SetRoutingProtocol(staticRouting1);

  // Node 2
  Ptr<Ipv4StaticRouting> staticRouting2 =
      CreateObject<Ipv4StaticRouting>();
  nodes.Get(2)->GetObject<Ipv4>()->SetRoutingProtocol(staticRouting2);

  // Node 0's routing table:
  // Route to 10.1.2.0/24 via 10.1.1.2 (Node 1)
  staticRouting0->AddNetworkRouteTo(Ipv4Address("10.1.2.0"),
                                     Ipv4Mask("255.255.255.0"),
                                     Ipv4Address("10.1.1.2"),
                                     interfaces01.Get(0).second);

  // Node 1's routing table:
  // Route to 10.1.1.0/24 via 10.1.1.1 (itself)
  staticRouting1->AddNetworkRouteTo(Ipv4Address("10.1.1.0"),
                                     Ipv4Mask("255.255.255.0"),
                                     Ipv4Address("10.1.1.1"),
                                     interfaces01.Get(1).second);

  // Route to 10.1.2.0/24 via 10.1.2.2 (Node 2)
  staticRouting1->AddNetworkRouteTo(Ipv4Address("10.1.2.0"),
                                     Ipv4Mask("255.255.255.0"),
                                     Ipv4Address("10.1.2.2"),
                                     interfaces12.Get(0).second);

  // Node 2's routing table:
  // Route to 10.1.1.0/24 via 10.1.2.1 (Node 1)
  staticRouting2->AddNetworkRouteTo(Ipv4Address("10.1.1.0"),
                                     Ipv4Mask("255.255.255.0"),
                                     Ipv4Address("10.1.2.1"),
                                     interfaces12.Get(1).second);

  // Create an application (e.g., UdpEchoClient/Server) to test the routing
  // ... (Add your application code here) ...
  uint16_t port = 4000;
  UdpServerHelper server(port);
  ApplicationContainer serverApp = server.Install(nodes.Get(1));
  serverApp.Start(Seconds(1.0));
  serverApp.Stop(Seconds(10.0));

  UdpClientHelper client(interfaces12.GetAddress(1), port);
  client.SetAttribute("MaxPackets", UintegerValue(100));
  client.SetAttribute("Interval", TimeValue(Seconds(0.1)));
  client.SetAttribute("PacketSize", UintegerValue(1024));

  ApplicationContainer apps = client.Install(nodes.Get(0));
  apps.Start(Seconds(2.0));
  apps.Stop(Seconds(10.0));

  Simulator::Run();
  Simulator::Destroy();

  return 0;
}