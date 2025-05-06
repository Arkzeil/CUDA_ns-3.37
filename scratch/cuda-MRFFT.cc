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
  // Refactored MR-FFT topology with 2-hop structure

    uint32_t numGroups = 100;
    uint32_t numPairsPerGroup = 2;
    uint32_t edgeSwitches = numGroups * 2; // Two edge switches per group (one for clients, one for servers)
    uint32_t coreSwitches = 16; // Shared across groups
    
    NodeContainer clients;
    NodeContainer servers;
    clients.Create(numGroups * numPairsPerGroup);
    servers.Create(numGroups * numPairsPerGroup);
    
    NodeContainer edgeSwitchNodes;
    edgeSwitchNodes.Create(edgeSwitches);
    NodeContainer coreSwitchNodes;
    coreSwitchNodes.Create(coreSwitches);
    
    Cuda_InternetStackHelper internet;
    internet.SetIpv6StackInstall(false);
    internet.Install(clients);
    internet.Install(servers);

    CudaP2PHelper cudaP2P;
    CudaBridgeHelper bridge;
    cudaP2P.SetDelay(MilliSeconds(2.0));
    cudaP2P.SetBandwidth(DataRate("1000Mbps"));

    for (uint32_t i = 0; i < numGroups; ++i) {
        uint32_t clientEdgeIndex = 2 * i;
        uint32_t serverEdgeIndex = 2 * i + 1;
        Ptr<Node> clientEdge = edgeSwitchNodes.Get(clientEdgeIndex);
        Ptr<Node> serverEdge = edgeSwitchNodes.Get(serverEdgeIndex);

        NetDeviceContainer clientBridgePorts;
        NetDeviceContainer serverBridgePorts;
        NetDeviceContainer ClientBridgeDsts;
        NetDeviceContainer ServerBridgeDsts;
        NetDeviceContainer Dsts;
        
        
        for (uint32_t pair = 0; pair < numPairsPerGroup; ++pair) {
            uint32_t pairIndex = i * numPairsPerGroup + pair;
        
            // Connect client to client edge switch
            NetDeviceContainer clientLink = cudaP2P.Install(clients.Get(pairIndex), clientEdge);
        
            // Connect server to server edge switch
            NetDeviceContainer serverLink = cudaP2P.Install(servers.Get(pairIndex), serverEdge);
        
            // Connect both edge switches to a shared core switch
            Ptr<Node> coreSwitch = coreSwitchNodes.Get((pairIndex + i) % coreSwitches);
            NetDeviceContainer upLink = cudaP2P.Install(clientEdge, coreSwitch);
            NetDeviceContainer downLink = cudaP2P.Install(coreSwitch, serverEdge);
        
            // Bridge client edge switch
            
            clientBridgePorts.Add(clientLink.Get(1));
            clientBridgePorts.Add(upLink.Get(0));
            ClientBridgeDsts.Add(upLink.Get(0));
        
            // Bridge server edge switch
            
            serverBridgePorts.Add(serverLink.Get(1));
            serverBridgePorts.Add(downLink.Get(1));
            ServerBridgeDsts.Add(serverLink.Get(1));
            
            Dsts.Add(serverLink.Get(0));
            // Bridge core switch
            NetDeviceContainer coreBridgePorts;
            coreBridgePorts.Add(upLink.Get(1));
            coreBridgePorts.Add(downLink.Get(0));
            NetDeviceContainer coreBridge = bridge.Install(coreSwitch, coreBridgePorts);
            ((CudaBridgeNetDevice*)GetPointer(coreBridge.Get(0)))->Learn(((CudaNetDevice*)GetPointer(serverLink.Get(0)))->GetMacAddress(), GetPointer(DynamicCast<CudaNetDevice>(downLink.Get(0))));
        
            // Save endpoints for IP config
            NetDeviceContainer endpoints;
            endpoints.Add(clientLink.Get(0));
            endpoints.Add(serverLink.Get(0));
        
            CudaIpv4AddressHelper ipv4;
            std::ostringstream subnet;
            subnet << "10." << (pairIndex / 256 + 1) << "." << (pairIndex % 256) << ".0";
            ipv4.SetBase(subnet.str().c_str(), "255.255.255.0");
            Ipv4InterfaceContainer interfaces = ipv4.Assign(endpoints);
        
            // ARP
            DynamicCast<CudaIpv4L3Protocol>(interfaces.Get(0).first)->GetInterface(interfaces.Get(0).second)->GetArpCache()->AddEntry(
                interfaces.GetAddress(1).Get(),
                DynamicCast<CudaNetDevice>(serverLink.Get(0))->GetMacAddress());
        
            // Routing
            clients.Get(pairIndex)->GetObject<CudaIpv4L3Protocol>()->m_routing->AddRoute(
                interfaces.GetAddress(1).Get(), 0xffffff00, interfaces.Get(0).second);
        
            // Applications
            Ptr<CudaUdpClient> app = CreateObject<CudaUdpClient>();
            Ptr<CudaUdpServer> server = CreateObject<CudaUdpServer>();
        
            app->SetRemote(interfaces.GetAddress(1), 9);
            app->SetPacketSize(256);
            app->SetSendInterval(MilliSeconds(10));
            clients.Get(pairIndex)->AddApplication(app);
            app->SetStartTime(Seconds(1.0));
            app->SetStopTime(Seconds(31.0));
        
            server->SetPort(9);
            servers.Get(pairIndex)->AddApplication(server);
            server->SetStartTime(Seconds(0.0));
            server->SetStopTime(Seconds(5000.0));
        }
        NetDeviceContainer clientBridge = bridge.Install(clientEdge, clientBridgePorts);
        NetDeviceContainer serverBridge = bridge.Install(serverEdge, serverBridgePorts);
        for(uint32_t pair = 0; pair < numPairsPerGroup; pair++){
          // manually set the MAC address of the bridge ports
          ((CudaBridgeNetDevice*)GetPointer(clientBridge.Get(0)))->Learn(((CudaNetDevice*)GetPointer(Dsts.Get(pair)))->GetMacAddress(), GetPointer(DynamicCast<CudaNetDevice>(ClientBridgeDsts.Get(pair))));
          ((CudaBridgeNetDevice*)GetPointer(serverBridge.Get(0)))->Learn(((CudaNetDevice*)GetPointer(Dsts.Get(pair)))->GetMacAddress(), GetPointer(DynamicCast<CudaNetDevice>(ServerBridgeDsts.Get(pair))));
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
