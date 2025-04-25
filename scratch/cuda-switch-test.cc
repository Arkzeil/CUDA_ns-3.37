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
#include "ns3/cuda-ipv4-interface.h"
#include "ns3/cuda-internet-stack-helper.h"
#include "ns3/cuda-ipv4-address-helper.h"
#include "ns3/cuda-udp-server.h"
#include "ns3/cuda-ipv4-static-routing.h"
#include "ns3/cuda-elp-simulator.h"
#include "ns3/cuda-bridge-helper.h"
#include "ns3/cuda-bridge-net-device.h"

#include <ctime>

using namespace ns3;

// Network topology
//
//        n0     
//        |      
//       -----------
//       | Switch0 |
//       -----------
//        |
//       -----------
//       | Switch1 |
//       -----------
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
  uint32_t numGroups = 20; // Default number of test groups (multiple client-server pairs with shared intermediate switches)
  uint32_t numPairs = 5; // Default number of client-server pair group
  uint32_t numSwitches = 2; // Number of switches between each pairs

  NodeContainer clients;
  NodeContainer servers;
  clients.Create(numGroups * numPairs);
  servers.Create(numGroups * numPairs);
  // nodes.Create(2 * numPairs);
  NodeContainer switchNodes;
  switchNodes.Create(numSwitches * numGroups);

  // Install the Internet stack
  Cuda_InternetStackHelper internet;
  // InternetStackHelper internet;
  internet.SetIpv6StackInstall(false);
  internet.Install(clients);
  internet.Install(servers);

  // Create a point-to-point channel
  // PointToPointHelper p2p;
  // p2p.SetDeviceAttribute("DataRate", StringValue("10Mbps"));
  // p2p.SetChannelAttribute("Delay", StringValue("2ms"));
  // NetDeviceContainer devices = p2p.Install(nodes);
  // NetDeviceContainer devices = p2p.Install(node0, node1);
  CudaP2PHelper cudaP2P;
  CudaBridgeHelper bridge;
  Ptr<CudaUdpClient> app1;

  uint32_t j = 1;

  for (uint32_t i = 0; i < numGroups; i++){
    cudaP2P.SetDelay(MilliSeconds(2.0));
    cudaP2P.SetBandwidth(DataRate("10Mbps"));
    // NetDeviceContainer cudaDevices = cudaP2P.Install(nodes.Get(2 * i), nodes.Get(2 * i + 1));
    for(uint32_t pair = 0; pair < numPairs; pair++){
      uint32_t pairIndex = i * numPairs + pair;
      std::vector<NetDeviceContainer> switchLinks(numSwitches + 1); // Link between each segment
      // Connect client to switch
      switchLinks[0] = cudaP2P.Install(clients.Get(pairIndex), switchNodes.Get(numSwitches * i));
      // Connect server to switch
      switchLinks[numSwitches] = cudaP2P.Install(switchNodes.Get(numSwitches * (i + 1) - 1), servers.Get(pairIndex));
      // Connect switch to switch
      for(uint32_t k = 1; k < numSwitches; k++)
        switchLinks[k] = cudaP2P.Install(switchNodes.Get(numSwitches * i + k - 1), switchNodes.Get(numSwitches * i + k));
      // NetDeviceContainer link3 = cudaP2P.Install(switchNodes.Get(2 * i), switchNodes.Get(2 * i + 1));

      // Save the endpoint devices for IP assignment
      NetDeviceContainer endpoints;
      // Save the corrsponding switch device
      // NetDeviceContainer switch0Devices;
      // NetDeviceContainer switch1Devices;
      endpoints.Add(switchLinks[0].Get(0));
      endpoints.Add(switchLinks[numSwitches].Get(1));
      // switch0Devices.Add(link1.Get(1));
      // switch0Devices.Add(switchLinks[0].Get(0));
      // switch1Devices.Add(link2.Get(1));
      // switch1Devices.Add(switchLinks[0].Get(1));

      // NetDeviceContainer bridge_dev0 = bridge.Install(switchNodes.Get(2 * i), switch0Devices);
      // NetDeviceContainer bridge_dev1 = bridge.Install(switchNodes.Get(2 * i + 1), switch1Devices);


      for(uint32_t k = 0; k < numSwitches; k++){
        NetDeviceContainer switchPorts; // Collect all port netdevices
        switchPorts.Add(switchLinks[k].Get(1));
        switchPorts.Add(switchLinks[k + 1].Get(0));
        NetDeviceContainer bridge_dev = bridge.Install(switchNodes.Get(numSwitches * i + k), switchPorts);
        // manually make bridge learn the destination MAC address
        ((CudaBridgeNetDevice*)GetPointer(bridge_dev.Get(0)))->Learn(((CudaNetDevice*)GetPointer(switchLinks[numSwitches].Get(1)))->GetMacAddress(), GetPointer(DynamicCast<CudaNetDevice>(switchLinks[k + 1].Get(0))));
      }
      // manually make bridge learn
      // ((CudaBridgeNetDevice*)GetPointer(bridge_dev0.Get(0)))->Learn(((CudaNetDevice*)GetPointer(link2.Get(0)))->GetMacAddress(), GetPointer(DynamicCast<CudaNetDevice>(switchLinks[0].Get(0))));
      // ((CudaBridgeNetDevice*)GetPointer(bridge_dev1.Get(0)))->Learn(((CudaNetDevice*)GetPointer(link2.Get(0)))->GetMacAddress(), GetPointer(DynamicCast<CudaNetDevice>(link2.Get(1))));
      
      // Assign IP addresses
      CudaIpv4AddressHelper ipv4;
      std::ostringstream subnet;
      // if(i / 256 >= j)
      //   j++;
      uint32_t subnetIndex = i * numPairs + pair;
      subnet << "10." << (subnetIndex / 256 + 1) << "." << (subnetIndex % 256) << ".0";
      // subnet << "10.1." << i + 1 << ".0";
      ipv4.SetBase(subnet.str().c_str(), "255.255.255.0");

      Ipv4InterfaceContainer cudaInterfaces = ipv4.Assign(endpoints);
      // manually set up the ARP table
      DynamicCast<CudaIpv4L3Protocol>(cudaInterfaces.Get(0).first)->GetInterface(cudaInterfaces.Get(0).second)->GetArpCache()->AddEntry(
          cudaInterfaces.GetAddress(1).Get(), 
          ((CudaNetDevice*)GetPointer(switchLinks[numSwitches].Get(1)))->GetMacAddress());

      Ptr<CudaUdpClient> app = CreateObject<CudaUdpClient>();
      Ptr<CudaUdpServer> server = CreateObject<CudaUdpServer>();
      // manually set up the routing table
      clients.Get(pairIndex)->GetObject<CudaIpv4L3Protocol>()->m_routing->AddRoute(cudaInterfaces.GetAddress(1).Get(), 0xffffff00, cudaInterfaces.Get(0).second);

      app->SetRemote(cudaInterfaces.GetAddress(1), 9); // Send to node 1
      app->SetPacketSize(256);
      app->SetSendInterval(Seconds(1.0));
      clients.Get(pairIndex)->AddApplication(app);
      app->SetStartTime(Seconds(1.0));
      app->SetStopTime(Seconds(3001.0));

      // app1 = app;

      server->SetPort(9);
      servers.Get(pairIndex)->AddApplication(server);
      server->SetStartTime(Seconds(0.0));
      server->SetStopTime(Seconds(3002.0));
    }
  }

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
