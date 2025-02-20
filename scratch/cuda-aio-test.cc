#include "ns3/core-module.h"
#include "ns3/network-module.h"
#include "ns3/internet-module.h"
#include "ns3/point-to-point-helper.h"
#include "ns3/udp-echo-helper.h"
#include "ns3/cuda-udp-client.h"
#include "ns3/cuda-node.h"
#include "ns3/cuda-p2p-helper.h"
#include "ns3/cuda-helper.h"
#include "ns3/cuda-ipv4-l3-protocol.h"
#include "ns3/cuda-udp-l4-protocol.h"
#include "ns3/cuda-internet-stack-helper.h"
#include "ns3/cuda-ipv4-address-helper.h"
#include "ns3/cuda-udp-server.h"
#include "ns3/cuda-elp-simulator.h"

using namespace ns3;

int main(int argc, char* argv[]) {
  LogComponentEnable("UdpEchoServerApplication", LOG_LEVEL_INFO);
//   LogComponentEnable("Socket", LOG_LEVEL_INFO);
  LogComponentEnable("CudaUdpClient", LOG_LEVEL_INFO);

  cudaDeviceProp prop;
  if (!InitCUDA(prop)) {
    return 1;
  }

  GlobalValue::Bind("SimulatorImplementationType",
                    StringValue("ns3::CudaELPSimulator"));
  // NodeContainer nodes;
  // nodes.Create(2);
  Ptr<Node> node0 = CreateObject<Node>();
  Ptr<Node> node1 = CreateObject<Node>();
  Ptr<Node> node2 = CreateObject<Node>();
  Ptr<Node> node3 = CreateObject<Node>(); 
  // CudaNode *cudaNode0 = new CudaNode();
  // CudaNode *cudaNode1 = new CudaNode();

  // Install the Internet stack
  Cuda_InternetStackHelper internet;
  // InternetStackHelper internet;
  internet.SetIpv6StackInstall(false);
  internet.Install(node0);
  internet.Install(node1);
  internet.Install(node2);
  internet.Install(node3);
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
  NetDeviceContainer cudaDevices1 = cudaP2P.Install(node2, node3);
  // NetDeviceContainer cudaDevices = p2p.Install(cudaNode0, cudaNode1);

  // Assign IP addresses
  CudaIpv4AddressHelper ipv4;
  // Ipv4AddressHelper ipv4;
  ipv4.SetBase("10.1.1.0", "255.255.255.0");
  // Ipv4InterfaceContainer interfaces = ipv4.Assign(devices);
  Ipv4InterfaceContainer cudaInterfaces = ipv4.Assign(cudaDevices);
  Ipv4InterfaceContainer cudaInterfaces1 = ipv4.Assign(cudaDevices1);
  // Ipv4InterfaceContainer cudaInterfaces = ipv4.Assign(cudaDevices);

  // Install CUDA UDP application on node 0
  Ptr<CudaUdpClient> app = CreateObject<CudaUdpClient>();
  Ptr<CudaUdpClient> app1 = CreateObject<CudaUdpClient>();
  Ptr<CudaUdpClient> app2 = CreateObject<CudaUdpClient>();
  
  uint32_t ipAddress = cudaInterfaces.GetAddress(1).Get();
  char ipAddr[16];
  snprintf(ipAddr,sizeof ipAddr,"%u.%u.%u.%u" ,(ipAddress & 0xff000000) >> 24 
                                          ,(ipAddress & 0x00ff0000) >> 16
                                          ,(ipAddress & 0x0000ff00) >> 8
                                          ,(ipAddress & 0x000000ff));
  printf("address: %s\n", ipAddr);

  app->SetRemote(cudaInterfaces.GetAddress(1), 9); // Send to node 1
  app->SetPacketSize(256);
  app->SetSendInterval(Seconds(1.0));
  node0->AddApplication(app);
  app->SetStartTime(Seconds(1.0));
  app->SetStopTime(Seconds(10.0));

  // app1->SetRemote(cudaInterfaces1.GetAddress(1), 9); // Send to node 3
  // app1->SetPacketSize(256);
  // app1->SetSendInterval(Seconds(1.0));
  // node2->AddApplication(app1);
  // app1->SetStartTime(Seconds(1.0));
  // app1->SetStopTime(Seconds(10.0));

  // app2->SetRemote(cudaInterfaces.GetAddress(1), 9); // Send to node 1
  // app2->SetPacketSize(256);
  // app2->SetSendInterval(Seconds(1.0));
  // node0->AddApplication(app2);
  // app2->SetStartTime(Seconds(1.0));
  // app2->SetStopTime(Seconds(10.0));
  // cudaNode0->AddApplication(app);
  Ptr<CudaUdpServer> server = CreateObject<CudaUdpServer>();
  Ptr<CudaUdpServer> server1 = CreateObject<CudaUdpServer>();
  server->SetPort(9);
  server1->SetPort(9);

  node1->AddApplication(server);
  node3->AddApplication(server1);
  server->SetStartTime(Seconds(0.0));
  server->SetStopTime(Seconds(11.0));
  server1->SetStartTime(Seconds(0.0));
  server1->SetStopTime(Seconds(11.0));

  // Install a UDP echo server on node 1
  // UdpEchoServerHelper server(9);
  // ApplicationContainer serverApp = server.Install(node1);
  // serverApp.Start(Seconds(1.0));
  // serverApp.Stop(Seconds(10.0));
  InitCudaSim();

  ((CudaELPSimulator*)GetPointer(Simulator::GetImplementation()))->print_test();
  // printf("cudaSim: %p\n", cudaSim);
  cudaSim = (CudaELPSimulator*)GetPointer(Simulator::GetImplementation());
  // printf("cudaSim main: %p\n", cudaSim);
  // cudaSim->print_test();
  // Simulator::GetSystemId();
  Simulator::Run();

  cudaSim->test(GetPointer(app));
  // printf("Current time: %f\n", Simulator::Now().GetSeconds());
  // ((CudaELPSimulator*)GetPointer(Simulator::GetImplementation()))->test(GetPointer(app));

  Simulator::Destroy();

  return 0;
}
