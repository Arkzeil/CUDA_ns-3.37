#include "ns3/core-module.h"
#include "ns3/network-module.h"
#include "ns3/internet-module.h"
#include "ns3/point-to-point-helper.h"
#include "ns3/udp-echo-helper.h"
#include "ns3/cuda-udp-client.h"
#include "ns3/cuda-node.h"
#include "ns3/cuda-p2p-helper.h"

using namespace ns3;

int main(int argc, char* argv[]) {
  LogComponentEnable("UdpEchoServerApplication", LOG_LEVEL_INFO);
//   LogComponentEnable("Socket", LOG_LEVEL_INFO);
  LogComponentEnable("CudaUdpClient", LOG_LEVEL_INFO);
  // NodeContainer nodes;
  // nodes.Create(2);
  Ptr<Node> node0 = CreateObject<Node>();
  Ptr<Node> node1 = CreateObject<Node>();
  // CudaNode *cudaNode0 = new CudaNode();
  // CudaNode *cudaNode1 = new CudaNode();

  // Install the Internet stack
  InternetStackHelper internet;
  internet.SetIpv6StackInstall(false);
  internet.Install(node0);
  internet.Install(node1);
  // internet.Install(cudaNode0);
  // internet.Install(cudaNode1);
  // internet.Install(nodes);

  // Create a point-to-point channel
  // PointToPointHelper p2p;
  // p2p.SetDeviceAttribute("DataRate", StringValue("10Mbps"));
  // p2p.SetChannelAttribute("Delay", StringValue("2ms"));
  // NetDeviceContainer devices = p2p.Install(nodes);
  // NetDeviceContainer devices = p2p.Install(node0, node1);

  CudaP2PHelper cudaP2P;
  cudaP2P.SetDelay(MilliSeconds(2.0));
  cudaP2P.SetBandwidth(DataRate("10Mbps"));
  NetDeviceContainer cudaDevices = cudaP2P.Install(node0, node1);
  // NetDeviceContainer cudaDevices = p2p.Install(cudaNode0, cudaNode1);

  // Assign IP addresses
  Ipv4AddressHelper ipv4;
  ipv4.SetBase("10.1.1.0", "255.255.255.0");
  // Ipv4InterfaceContainer interfaces = ipv4.Assign(devices);
  Ipv4InterfaceContainer cudaInterfaces = ipv4.Assign(cudaDevices);
  // Ipv4InterfaceContainer cudaInterfaces = ipv4.Assign(cudaDevices);

  // Install CUDA UDP application on node 0
  Ptr<CudaUdpClient> app = CreateObject<CudaUdpClient>();
  
  uint32_t ipAddress = cudaInterfaces.GetAddress(1).Get();
  char ipAddr[16];
  snprintf(ipAddr,sizeof ipAddr,"%u.%u.%u.%u" ,(ipAddress & 0xff000000) >> 24 
                                          ,(ipAddress & 0x00ff0000) >> 16
                                          ,(ipAddress & 0x0000ff00) >> 8
                                          ,(ipAddress & 0x000000ff));
  printf("address: %s\n", ipAddr);

  app->SetRemote(cudaInterfaces.GetAddress(1), 9); // Send to node 1
  app->SetPacketSize(512);
  app->SetSendInterval(Seconds(1.0));
  node0->AddApplication(app);
  app->SetStartTime(Seconds(1.0));
  app->SetStopTime(Seconds(10.0));
  // cudaNode0->AddApplication(app);

  // Install a UDP echo server on node 1
  UdpEchoServerHelper server(9);
  ApplicationContainer serverApp = server.Install(node1);
  serverApp.Start(Seconds(1.0));
  serverApp.Stop(Seconds(10.0));

  Simulator::Run();
  Simulator::Destroy();

  return 0;
}
