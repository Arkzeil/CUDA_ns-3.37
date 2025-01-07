#include "cuda-internet-stack-helper.h"

namespace ns3{
    Cuda_Cuda_InternetStackHelper::Cuda_Cuda_InternetStackHelper(){
        Cuda_InternetStackHelper();
    }

    Cuda_Cuda_InternetStackHelper::~Cuda_Cuda_InternetStackHelper(){
        ~Cuda_InternetStackHelper();
    }

    void Cuda_Cuda_InternetStackHelper::Install(Ptr<Node> node) const{
        Install(node);
    }

    void Cuda_Cuda_InternetStackHelper::InstallAll() const{
        InstallAll();
    }

    void Cuda_Cuda_InternetStackHelper::CreateAndAggregateObjectFromTypeId(Ptr<Node> node, const std::string typeId){
        CreateAndAggregateObjectFromTypeId(node, typeId);
    }

    void Cuda_InternetStackHelper::Install(NodeContainer c) const
    {
        for (NodeContainer::Iterator i = c.Begin(); i != c.End(); ++i)
        {
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
            CreateAndAggregateObjectFromTypeId(node, "ns3::Ipv4L3Protocol");
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
            CreateAndAggregateObjectFromTypeId(node, "ns3::UdpL4Protocol");
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

    void Cuda_InternetStackHelper::Install(std::string nodeName) const
    {
        Ptr<Node> node = Names::Find<Node>(nodeName);
        Install(node);
    }
}