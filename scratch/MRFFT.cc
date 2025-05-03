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
    
    typedef std::vector<Ptr<Node>> NodeList;

    uint32_t numGroups = 100;
    uint32_t numPairs = 4;
    uint32_t numCoreSwitches = 16; // Shared across all groups

    NodeContainer clients;
    NodeContainer servers;
    clients.Create(numGroups * numPairs);
    servers.Create(numGroups * numPairs);

    NodeContainer coreSwitches;
    coreSwitches.Create(numCoreSwitches);

    NodeList edgeClientSwitches;
    NodeList edgeServerSwitches;

    InternetStackHelper internet;
    internet.SetIpv6StackInstall(false);
    internet.Install(clients);
    internet.Install(servers);

    BridgedP2PHelper pointToPoint;
    BridgeHelper bridge;

    pointToPoint.SetDeviceAttribute("DataRate", StringValue("1000Mbps"));
    pointToPoint.SetChannelAttribute("Delay", StringValue("2ms"));

    for (uint32_t i = 0; i < numGroups; i++) {
        Ptr<Node> clientSwitch = CreateObject<Node>();
        Ptr<Node> serverSwitch = CreateObject<Node>();
        internet.Install(clientSwitch);
        internet.Install(serverSwitch);
        edgeClientSwitches.push_back(clientSwitch);
        edgeServerSwitches.push_back(serverSwitch);

        for (uint32_t pair = 0; pair < numPairs; pair++) {
            uint32_t pairIndex = i * numPairs + pair;
            NetDeviceContainer link1 = pointToPoint.Install(clients.Get(pairIndex), clientSwitch);
            NetDeviceContainer link2 = pointToPoint.Install(servers.Get(pairIndex), serverSwitch);

            // Connect edge switches to a random core switch
            Ptr<Node> core = coreSwitches.Get((i + pairIndex) % numCoreSwitches);
            NetDeviceContainer linkUp = pointToPoint.Install(clientSwitch, core);
            NetDeviceContainer linkDown = pointToPoint.Install(core, serverSwitch);

            // Bridge client edge switch
            NetDeviceContainer clientPorts;
            clientPorts.Add(link1.Get(1));
            clientPorts.Add(linkUp.Get(0));
            NetDeviceContainer bridgeDev1 = bridge.Install(clientSwitch, clientPorts);

            // Bridge server edge switch
            NetDeviceContainer serverPorts;
            serverPorts.Add(link2.Get(1));
            serverPorts.Add(linkDown.Get(1));
            NetDeviceContainer bridgeDev2 = bridge.Install(serverSwitch, serverPorts);

            // Bridge core switch
            NetDeviceContainer corePorts;
            corePorts.Add(linkUp.Get(1));
            corePorts.Add(linkDown.Get(0));
            NetDeviceContainer bridgeCore = bridge.Install(core, corePorts);

            // IP address assignment
            std::ostringstream subnet;
            uint32_t subnetIndex = i * numPairs + pair;
            subnet << "10." << (subnetIndex / 256 + 1) << "." << (subnetIndex % 256) << ".0";
            Ipv4AddressHelper address;
            address.SetBase(subnet.str().c_str(), "255.255.255.0");

            NetDeviceContainer endpoints;
            endpoints.Add(link1.Get(0));
            endpoints.Add(link2.Get(0));
            Ipv4InterfaceContainer interfaces = address.Assign(endpoints);

            // ARP and static routing
            Ptr<Ipv4Interface> iface = interfaces.Get(0).first->GetObject<Ipv4L3Protocol>()->GetInterface(interfaces.Get(0).second);
            Ptr<ArpCache> arp = CreateObject<ArpCache>();
            arp->SetDevice(link1.Get(0), iface);
            arp->SetAliveTimeout(Seconds(30000));
            arp->SetDeadTimeout(Seconds(30000));
            arp->SetWaitReplyTimeout(Seconds(30000));
            ArpCache::Entry* entry = arp->Add(Ipv4Address::ConvertFrom(interfaces.GetAddress(1)));
            entry->SetMacAddress(link2.Get(0)->GetAddress());
            entry->MarkPermanent();
            iface->SetArpCache(arp);

            Ptr<Ipv4StaticRouting> staticRouting = CreateObject<Ipv4StaticRouting>();
            clients.Get(pairIndex)->GetObject<Ipv4>()->SetRoutingProtocol(staticRouting);
            staticRouting->AddNetworkRouteTo(interfaces.GetAddress(1), Ipv4Mask("255.255.255.0"), 1);

            // Application setup
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
            clientApp.Stop(Seconds(31.0));
        }
    }


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