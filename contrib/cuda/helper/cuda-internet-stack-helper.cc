#include "cuda-internet-stack-helper.h"

#include "ns3/arp-l3-protocol.h"
#include "ns3/assert.h"
#include "ns3/callback.h"
#include "ns3/config.h"
#include "ns3/core-config.h"
#include "ns3/global-router-interface.h"
#include "ns3/icmpv6-l4-protocol.h"
#include "ns3/ipv4-global-routing-helper.h"
#include "ns3/ipv4-global-routing.h"
#include "ns3/ipv4-list-routing-helper.h"
#include "ns3/ipv4-static-routing-helper.h"
#include "ns3/ipv4.h"
#include "ns3/ipv6-extension-demux.h"
#include "ns3/ipv6-extension-header.h"
#include "ns3/ipv6-extension.h"
#include "ns3/ipv6-static-routing-helper.h"
#include "ns3/ipv6.h"
#include "ns3/log.h"
#include "ns3/names.h"
#include "ns3/net-device.h"
#include "ns3/node-list.h"
#include "ns3/node.h"
#include "ns3/object.h"
#include "ns3/packet-socket-factory.h"
#include "ns3/simulator.h"
#include "ns3/string.h"
#include "ns3/traffic-control-layer.h"

#include <limits>
#include <map>

#include "ns3/cuda-ipv4-l3-protocol.h"
#include "ns3/cuda-udp-l4-protocol.h"
#include "ns3/cuda-ipv4-interface.h"

namespace ns3{

    NS_LOG_COMPONENT_DEFINE("Cuda_InternetStackHelper");

    Cuda_InternetStackHelper::Cuda_InternetStackHelper(): m_routing(nullptr),
                                                        m_routingv6(nullptr),
                                                        m_ipv4Enabled(true),
                                                        m_ipv6Enabled(true),
                                                        m_ipv4ArpJitterEnabled(true),
                                                        m_ipv6NsRsJitterEnabled(true){
        Initialize();
    }

    Cuda_InternetStackHelper::~Cuda_InternetStackHelper(){
        delete m_routing;
        delete m_routingv6;
    }

    void Cuda_InternetStackHelper::Initialize(){
        SetTcp("ns3::TcpL4Protocol");
        Ipv4StaticRoutingHelper staticRouting;
        Ipv4GlobalRoutingHelper globalRouting;
        Ipv4ListRoutingHelper listRouting;
        Ipv6StaticRoutingHelper staticRoutingv6;
        listRouting.Add(staticRouting, 0);
        listRouting.Add(globalRouting, -10);
        SetRoutingHelper(listRouting);
        SetRoutingHelper(staticRoutingv6);
    }

    void Cuda_InternetStackHelper::Reset(){
        delete m_routing;
        m_routing = nullptr;
        delete m_routingv6;
        m_routingv6 = nullptr;
        m_ipv4Enabled = true;
        m_ipv6Enabled = true;
        m_ipv4ArpJitterEnabled = true;
        m_ipv6NsRsJitterEnabled = true;
        Initialize();
    }

    void Cuda_InternetStackHelper::SetTcp(const std::string tid){
        m_tcpFactory.SetTypeId(tid);
    }

    void Cuda_InternetStackHelper::SetRoutingHelper(const Ipv4RoutingHelper& routing){
        delete m_routing;
        m_routing = routing.Copy();
    }

    void Cuda_InternetStackHelper::SetRoutingHelper(const Ipv6RoutingHelper& routing){
        delete m_routingv6;
        m_routingv6 = routing.Copy();
    }

    void Cuda_InternetStackHelper::SetIpv4StackInstall(bool enable){
        m_ipv4Enabled = enable;
    }

    void Cuda_InternetStackHelper::SetIpv6StackInstall(bool enable){
        m_ipv6Enabled = enable;
    }

    void Cuda_InternetStackHelper::SetIpv4ArpJitter(bool enable){
        m_ipv4ArpJitterEnabled = enable;
    }

    void Cuda_InternetStackHelper::SetIpv6NsRsJitter(bool enable){
        m_ipv6NsRsJitterEnabled = enable;
    }

    void Cuda_InternetStackHelper::Install(NodeContainer c) const{
        for (NodeContainer::Iterator i = c.Begin(); i != c.End(); ++i){
            Install(*i);
        }
    }

    void Cuda_InternetStackHelper::InstallAll() const
    {
        Install(NodeContainer::GetGlobal());
    }

    void Cuda_InternetStackHelper::CreateAndAggregateObjectFromTypeId(Ptr<Node> node, const std::string typeId)
    {
        ObjectFactory factory;
        factory.SetTypeId(typeId);
        Ptr<Object> protocol = factory.Create<Object>();
        node->AggregateObject(protocol);
    }

    void Cuda_InternetStackHelper::Install(std::string nodeName) const
    {
        Ptr<Node> node = Names::Find<Node>(nodeName);
        Install(node);
    }

    void Cuda_InternetStackHelper::Install(Ptr<Node> node) const
    {
        if (m_ipv4Enabled)
        {
            if (node->GetObject<Ipv4>())
            {
                NS_FATAL_ERROR("Cuda_InternetStackHelper::Install (): Aggregating "
                            "an InternetStack to a node with an existing Ipv4 object");
                return;
            }

            CreateAndAggregateObjectFromTypeId(node, "ns3::ArpL3Protocol");
            CreateAndAggregateObjectFromTypeId(node, "ns3::CudaIpv4L3Protocol");
            CreateAndAggregateObjectFromTypeId(node, "ns3::Icmpv4L4Protocol");
            if (m_ipv4ArpJitterEnabled == false)
            {
                Ptr<ArpL3Protocol> arp = node->GetObject<ArpL3Protocol>();
                NS_ASSERT(arp);
                arp->SetAttribute("RequestJitter",
                                StringValue("ns3::ConstantRandomVariable[Constant=0.0]"));
            }
            // Set routing
            Ptr<Ipv4> ipv4 = node->GetObject<Ipv4>();
            Ptr<Ipv4RoutingProtocol> ipv4Routing = m_routing->Create(node);
            ipv4->SetRoutingProtocol(ipv4Routing);
        }

        if (m_ipv6Enabled)
        {
            /* IPv6 stack */
            if (node->GetObject<Ipv6>())
            {
                NS_FATAL_ERROR("Cuda_InternetStackHelper::Install (): Aggregating "
                            "an InternetStack to a node with an existing Ipv6 object");
                return;
            }

            CreateAndAggregateObjectFromTypeId(node, "ns3::Ipv6L3Protocol");
            CreateAndAggregateObjectFromTypeId(node, "ns3::Icmpv6L4Protocol");
            if (m_ipv6NsRsJitterEnabled == false)
            {
                Ptr<Icmpv6L4Protocol> icmpv6l4 = node->GetObject<Icmpv6L4Protocol>();
                NS_ASSERT(icmpv6l4);
                icmpv6l4->SetAttribute("SolicitationJitter",
                                    StringValue("ns3::ConstantRandomVariable[Constant=0.0]"));
            }
            // Set routing
            Ptr<Ipv6> ipv6 = node->GetObject<Ipv6>();
            Ptr<Ipv6RoutingProtocol> ipv6Routing = m_routingv6->Create(node);
            ipv6->SetRoutingProtocol(ipv6Routing);

            /* register IPv6 extensions and options */
            ipv6->RegisterExtensions();
            ipv6->RegisterOptions();
        }

        if (m_ipv4Enabled || m_ipv6Enabled)
        {
            CreateAndAggregateObjectFromTypeId(node, "ns3::TrafficControlLayer");
            CreateAndAggregateObjectFromTypeId(node, "ns3::CudaUdpL4Protocol");
            node->AggregateObject(m_tcpFactory.Create<Object>());
            Ptr<PacketSocketFactory> factory = CreateObject<PacketSocketFactory>();
            node->AggregateObject(factory);
        }

        if (m_ipv4Enabled)
        {
            Ptr<ArpL3Protocol> arp = node->GetObject<ArpL3Protocol>();
            Ptr<TrafficControlLayer> tc = node->GetObject<TrafficControlLayer>();
            NS_ASSERT(arp);
            NS_ASSERT(tc);
            arp->SetTrafficControl(tc);
        }
    }
}