#include "bridged-p2p-channel.h"

#include "ns3/bridged-p2p-net-device.h"

#include "ns3/log.h"
#include "ns3/packet.h"
#include "ns3/simulator.h"
#include "ns3/trace-source-accessor.h"

namespace ns3
{

NS_LOG_COMPONENT_DEFINE("BridgedP2PChannel");

NS_OBJECT_ENSURE_REGISTERED(BridgedP2PChannel);

TypeId
BridgedP2PChannel::GetTypeId()
{
    static TypeId tid =
        TypeId("ns3::BridgedP2PChannel")
            .SetParent<Channel>()
            .SetGroupName("PointToPoint")
            .AddConstructor<BridgedP2PChannel>()
            .AddAttribute("Delay",
                          "Propagation delay through the channel",
                          TimeValue(Seconds(0)),
                          MakeTimeAccessor(&BridgedP2PChannel::m_delay),
                          MakeTimeChecker())
            .AddTraceSource("TxRxPointToPoint",
                            "Trace source indicating transmission of packet "
                            "from the BridgedP2PChannel, used by the Animation "
                            "interface.",
                            MakeTraceSourceAccessor(&BridgedP2PChannel::m_txrxPointToPoint),
                            "ns3::BridgedP2PChannel::TxRxAnimationCallback");
    return tid;
}

//
// By default, you get a channel that
// has an "infitely" fast transmission speed and zero delay.
BridgedP2PChannel::BridgedP2PChannel()
    : PointToPointChannel(),
      m_delay(Seconds(0.)),
      m_nDevices(0)
{
    NS_LOG_FUNCTION_NOARGS();
}

void
BridgedP2PChannel::Attach(Ptr<BridgedPointToPointNetDevice> device)
{
    NS_LOG_FUNCTION(this << device);
    NS_ASSERT_MSG(m_nDevices < N_DEVICES, "Only two devices permitted");
    NS_ASSERT(device);

    m_link[m_nDevices++].m_src = device;
    //
    // If we have both devices connected to the channel, then finish introducing
    // the two halves and set the links to IDLE.
    //
    if (m_nDevices == N_DEVICES)
    {
        m_link[0].m_dst = m_link[1].m_src;
        m_link[1].m_dst = m_link[0].m_src;
        m_link[0].m_state = IDLE;
        m_link[1].m_state = IDLE;
    }
}

bool
BridgedP2PChannel::TransmitStart(Ptr<const Packet> p, Ptr<BridgedPointToPointNetDevice> src, Time txTime)
{
    NS_LOG_FUNCTION(this << p << src);
    NS_LOG_LOGIC("UID is " << p->GetUid() << ")");

    NS_ASSERT(m_link[0].m_state != INITIALIZING);
    NS_ASSERT(m_link[1].m_state != INITIALIZING);

    uint32_t wire = src == m_link[0].m_src ? 0 : 1;
    // printf("Schelude receive\n");
    Simulator::ScheduleWithContext(m_link[wire].m_dst->GetNode()->GetId(),
                                   txTime + m_delay,
                                   &BridgedPointToPointNetDevice::Receive,
                                   m_link[wire].m_dst,
                                   p->Copy());

    // Call the tx anim callback on the net device
    m_txrxPointToPoint(p, src, m_link[wire].m_dst, txTime, txTime + m_delay);
    return true;
}

std::size_t
BridgedP2PChannel::GetNDevices() const
{
    NS_LOG_FUNCTION_NOARGS();
    return m_nDevices;
}

Ptr<BridgedPointToPointNetDevice>
BridgedP2PChannel::GetPointToPointDevice(std::size_t i) const
{
    NS_LOG_FUNCTION_NOARGS();
    NS_ASSERT(i < 2);
    return m_link[i].m_src;
}

Ptr<NetDevice>
BridgedP2PChannel::GetDevice(std::size_t i) const
{
    NS_LOG_FUNCTION_NOARGS();
    return GetPointToPointDevice(i);
}

Time
BridgedP2PChannel::GetDelay() const
{
    return m_delay;
}

Ptr<BridgedPointToPointNetDevice>
BridgedP2PChannel::GetSource(uint32_t i) const
{
    return m_link[i].m_src;
}

Ptr<BridgedPointToPointNetDevice>
BridgedP2PChannel::GetDestination(uint32_t i) const
{
    return m_link[i].m_dst;
}

bool
BridgedP2PChannel::IsInitialized() const
{
    NS_ASSERT(m_link[0].m_state != INITIALIZING);
    NS_ASSERT(m_link[1].m_state != INITIALIZING);
    return true;
}

} // namespace ns3
