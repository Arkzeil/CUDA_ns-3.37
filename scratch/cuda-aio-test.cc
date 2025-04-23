#include "ns3/core-module.h"
#include "ns3/network-module.h"
#include "ns3/internet-module.h"
#include "ns3/point-to-point-helper.h"
#include "ns3/udp-echo-helper.h"
#include "ns3/cuda-udp-client.h"
#include "ns3/cuda-p2p-helper.h"
#include "ns3/cuda-helper.h"
#include "ns3/cuda-ipv4-l3-protocol.h"
#include "ns3/cuda-udp-l4-protocol.h"
#include "ns3/cuda-internet-stack-helper.h"
#include "ns3/cuda-ipv4-address-helper.h"
#include "ns3/cuda-udp-server.h"
#include "ns3/cuda-ipv4-static-routing.h"
#include "ns3/cuda-elp-simulator.h"

#include <ctime>

using namespace ns3;

// Network topology
//
//        n0    
//        |      
//        |
//        |  x numPairs
//        |
//        |      
//        n1     
//

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
  // GlobalValue::Bind("SchedulerImplementationType",
  //                   StringValue("ns3::MapScheduler"));
  uint32_t numPairs = 500; // Default number of client-server pairs

  NodeContainer nodes;
  nodes.Create(2 * numPairs);

  // Install the Internet stack
  Cuda_InternetStackHelper internet;
  // InternetStackHelper internet;
  internet.SetIpv6StackInstall(false);
  internet.Install(nodes);

  // Create a point-to-point channel
  // PointToPointHelper p2p;
  // p2p.SetDeviceAttribute("DataRate", StringValue("10Mbps"));
  // p2p.SetChannelAttribute("Delay", StringValue("2ms"));
  // NetDeviceContainer devices = p2p.Install(nodes);
  // NetDeviceContainer devices = p2p.Install(node0, node1);
  CudaP2PHelper cudaP2P;
  Ptr<CudaUdpClient> app1;

  uint32_t j = 1;

  for (uint32_t i = 0; i < numPairs; i++){
    cudaP2P.SetDelay(MilliSeconds(2.0));
    cudaP2P.SetBandwidth(DataRate("10Mbps"));
    NetDeviceContainer cudaDevices = cudaP2P.Install(nodes.Get(2 * i), nodes.Get(2 * i + 1));

    // Assign IP addresses
    CudaIpv4AddressHelper ipv4;
    std::ostringstream subnet;
    if(i / 256 >= j)
      j++;
    subnet << "10." << j << "." << (i + 1) % 256 << ".0";
    // subnet << "10.1." << i + 1 << ".0";
    ipv4.SetBase(subnet.str().c_str(), "255.255.255.0");

    Ipv4InterfaceContainer cudaInterfaces = ipv4.Assign(cudaDevices);

    Ptr<CudaUdpClient> app = CreateObject<CudaUdpClient>();
    Ptr<CudaUdpServer> server = CreateObject<CudaUdpServer>();

    nodes.Get(2 * i)->GetObject<CudaIpv4L3Protocol>()->m_routing->AddRoute(cudaInterfaces.GetAddress(1).Get(), 0xffffff00, cudaInterfaces.Get(1).second);

    app->SetRemote(cudaInterfaces.GetAddress(1), 9); // Send to node 1
    app->SetPacketSize(256);
    app->SetSendInterval(Seconds(1.0));
    nodes.Get(2 * i)->AddApplication(app);
    app->SetStartTime(Seconds(1.0));
    app->SetStopTime(Seconds(3001.0));

    app1 = app;
    // Ptr<CudaUdpClient> app2 = CreateObject<CudaUdpClient>();
    // app2->SetRemote(cudaInterfaces.GetAddress(1), 9); // Send to node 1
    // app2->SetPacketSize(256);
    // app2->SetSendInterval(Seconds(1.0));
    // nodes.Get(2 * i)->AddApplication(app2);
    // app2->SetStartTime(Seconds(1.0));
    // app2->SetStopTime(Seconds(10.0));

    server->SetPort(9);
    nodes.Get(2 * i + 1)->AddApplication(server);
    server->SetStartTime(Seconds(0.0));
    server->SetStopTime(Seconds(3002.0));
  }

  // CudaP2PHelper cudaP2P;
  // cudaP2P.SetDelay(MilliSeconds(2.0));
  // cudaP2P.SetBandwidth(DataRate("10Mbps"));
  // NetDeviceContainer cudaDevices = cudaP2P.Install(nodes.Get(0), nodes.Get(1));
  // cudaP2P.SetDelay(MilliSeconds(3.0));
  // NetDeviceContainer cudaDevices1 = cudaP2P.Install(nodes.Get(2), nodes.Get(3));
  // // NetDeviceContainer cudaDevices = p2p.Install(cudaNode0, cudaNode1);

  // // Assign IP addresses
  // CudaIpv4AddressHelper ipv4;
  // // Ipv4AddressHelper ipv4;
  // ipv4.SetBase("10.1.1.0", "255.255.255.0");
  // // Ipv4InterfaceContainer interfaces = ipv4.Assign(devices);
  // Ipv4InterfaceContainer cudaInterfaces = ipv4.Assign(cudaDevices);
  // // Network 10.1.2.0/24
  // // ipv4.SetBase("10.1.2.0", "255.255.255.0");
  // Ipv4InterfaceContainer cudaInterfaces1 = ipv4.Assign(cudaDevices1);
  // // Ipv4InterfaceContainer cudaInterfaces = ipv4.Assign(cudaDevices);

  // // Install CUDA UDP application on node 0
  // Ptr<CudaUdpClient> app = CreateObject<CudaUdpClient>();
  // Ptr<CudaUdpClient> app1 = CreateObject<CudaUdpClient>();
  // Ptr<CudaUdpClient> app2 = CreateObject<CudaUdpClient>();
  
  // uint32_t ipAddress = cudaInterfaces.GetAddress(1).Get();
  // uint32_t ipAddress1 = cudaInterfaces1.GetAddress(1).Get();
  // char ipAddr[16];
  // snprintf(ipAddr,sizeof ipAddr,"%u.%u.%u.%u" ,(ipAddress & 0xff000000) >> 24 
  //                                         ,(ipAddress & 0x00ff0000) >> 16
  //                                         ,(ipAddress & 0x0000ff00) >> 8
  //                                         ,(ipAddress & 0x000000ff));
  // printf("address: %s\n", ipAddr);

  // nodes.Get(0)->GetObject<CudaIpv4L3Protocol>()->m_routing->AddRoute(ipAddress, 0xffffff00, cudaInterfaces.Get(1).second);
  // nodes.Get(2)->GetObject<CudaIpv4L3Protocol>()->m_routing->AddRoute(ipAddress1, 0xffffff00, cudaInterfaces1.Get(0).second);

  // app->SetRemote(cudaInterfaces.GetAddress(1), 9); // Send to node 1
  // app->SetPacketSize(256);
  // app->SetSendInterval(Seconds(1.0));
  // nodes.Get(0)->AddApplication(app);
  // app->SetStartTime(Seconds(1.0));
  // app->SetStopTime(Seconds(10.0));

  // app1->SetRemote(cudaInterfaces1.GetAddress(1), 9); // Send to node 3
  // app1->SetPacketSize(256);
  // app1->SetSendInterval(Seconds(1.0));
  // nodes.Get(2)->AddApplication(app1);
  // app1->SetStartTime(Seconds(1.0));
  // app1->SetStopTime(Seconds(10.0));

  // // app2->SetRemote(cudaInterfaces.GetAddress(1), 9); // Send to node 1
  // // app2->SetPacketSize(256);
  // // app2->SetSendInterval(Seconds(1.0));
  // // node0->AddApplication(app2);
  // // app2->SetStartTime(Seconds(1.0));
  // // app2->SetStopTime(Seconds(10.0));
  // // cudaNode0->AddApplication(app);
  // Ptr<CudaUdpServer> server = CreateObject<CudaUdpServer>();
  // Ptr<CudaUdpServer> server1 = CreateObject<CudaUdpServer>();
  // server->SetPort(9);
  // server1->SetPort(9);

  // nodes.Get(1)->AddApplication(server);
  // nodes.Get(3)->AddApplication(server1);
  // server->SetStartTime(Seconds(0.0));
  // server->SetStopTime(Seconds(11.0));
  // server1->SetStartTime(Seconds(0.0));
  // server1->SetStopTime(Seconds(11.0));

  // Install a UDP echo server on node 1
  // UdpEchoServerHelper server(9);
  // ApplicationContainer serverApp = server.Install(node1);
  // serverApp.Start(Seconds(1.0));
  // serverApp.Stop(Seconds(10.0));
  InitCudaSim();

  // ((CudaELPSimulator*)GetPointer(Simulator::GetImplementation()))->print_test();
  // printf("cudaSim: %p\n", cudaSim);
  cudaSim = (CudaELPSimulator*)GetPointer(Simulator::GetImplementation());
  // printf("cudaSim main: %p\n", cudaSim);
  // cudaSim->print_test();
  // Simulator::GetSystemId();
  // Simulator::Run();
  printf("------------------------Start ELP Simulator-----------------------------\n");
  struct timespec start, end;
  double time_used;
  clock_gettime(CLOCK_MONOTONIC, &start);

  // app1->StartApplication();
  // cudaSim->ELP_Test(GetPointer(app1));
  // testSend(GetPointer(app1));
  // int stop = 1;
  // cudaMemcpyAsync((void*)d_stop, &stop, sizeof(int), cudaMemcpyHostToDevice, streamC);
  // cudaCheckErrors("stop cudaMemcpyAsync failed");
  cudaSim->ELP_RunSK();

  // cudaSim->test(GetPointer(app));
  // printf("Current time: %f\n", Simulator::Now().GetSeconds());
  // ((CudaELPSimulator*)GetPointer(Simulator::GetImplementation()))->test(GetPointer(app));

  Simulator::Destroy();
  
  clock_gettime(CLOCK_MONOTONIC, &end);
  time_used = (end.tv_sec - start.tv_sec) + (end.tv_nsec - start.tv_nsec) / 1e9;
  printf("Time used: %f\n", time_used);

  return 0;
}
