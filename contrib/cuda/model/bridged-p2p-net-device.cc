/*
 * Copyright (c) 2007, 2008 University of Washington
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation;
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

 #include "bridged-p2p-net-device.h"

 #include "ns3/bridged-p2p-channel.h"
 #include "ns3/ppp-header.h"
 
 #include "ns3/error-model.h"
 #include "ns3/llc-snap-header.h"
 #include "ns3/log.h"
 #include "ns3/mac48-address.h"
 #include "ns3/pointer.h"
 #include "ns3/queue.h"
 #include "ns3/simulator.h"
 #include "ns3/trace-source-accessor.h"
 #include "ns3/uinteger.h"
 #include "ns3/ethernet-header.h"
#include "ns3/ethernet-trailer.h"
#include "ns3/llc-snap-header.h"
 
 namespace ns3
 {
 
 NS_LOG_COMPONENT_DEFINE("BridgedPointToPointNetDevice");
 
 NS_OBJECT_ENSURE_REGISTERED(BridgedPointToPointNetDevice);
 
 TypeId
 BridgedPointToPointNetDevice::GetTypeId()
 {
     static TypeId tid =
         TypeId("ns3::BridgedPointToPointNetDevice")
             .SetParent<NetDevice>()
             .SetGroupName("PointToPoint")
             .AddConstructor<BridgedPointToPointNetDevice>()
             .AddAttribute("Mtu",
                           "The MAC-level Maximum Transmission Unit",
                           UintegerValue(DEFAULT_MTU),
                           MakeUintegerAccessor(&BridgedPointToPointNetDevice::SetMtu,
                                                &BridgedPointToPointNetDevice::GetMtu),
                           MakeUintegerChecker<uint16_t>())
             .AddAttribute("Address",
                           "The MAC address of this device.",
                           Mac48AddressValue(Mac48Address("ff:ff:ff:ff:ff:ff")),
                           MakeMac48AddressAccessor(&BridgedPointToPointNetDevice::m_address),
                           MakeMac48AddressChecker())
             .AddAttribute("DataRate",
                           "The default data rate for point to point links",
                           DataRateValue(DataRate("32768b/s")),
                           MakeDataRateAccessor(&BridgedPointToPointNetDevice::m_bps),
                           MakeDataRateChecker())
             .AddAttribute("ReceiveErrorModel",
                           "The receiver error model used to simulate packet loss",
                           PointerValue(),
                           MakePointerAccessor(&BridgedPointToPointNetDevice::m_receiveErrorModel),
                           MakePointerChecker<ErrorModel>())
             .AddAttribute("InterframeGap",
                           "The time to wait between packet (frame) transmissions",
                           TimeValue(Seconds(0.0)),
                           MakeTimeAccessor(&BridgedPointToPointNetDevice::m_tInterframeGap),
                           MakeTimeChecker())
 
             //
             // Transmit queueing discipline for the device which includes its own set
             // of trace hooks.
             //
             .AddAttribute("TxQueue",
                           "A queue to use as the transmit queue in the device.",
                           PointerValue(),
                           MakePointerAccessor(&BridgedPointToPointNetDevice::m_queue),
                           MakePointerChecker<Queue<Packet>>())
 
             //
             // Trace sources at the "top" of the net device, where packets transition
             // to/from higher layers.
             //
             .AddTraceSource("MacTx",
                             "Trace source indicating a packet has arrived "
                             "for transmission by this device",
                             MakeTraceSourceAccessor(&BridgedPointToPointNetDevice::m_macTxTrace),
                             "ns3::Packet::TracedCallback")
             .AddTraceSource("MacTxDrop",
                             "Trace source indicating a packet has been dropped "
                             "by the device before transmission",
                             MakeTraceSourceAccessor(&BridgedPointToPointNetDevice::m_macTxDropTrace),
                             "ns3::Packet::TracedCallback")
             .AddTraceSource("MacPromiscRx",
                             "A packet has been received by this device, "
                             "has been passed up from the physical layer "
                             "and is being forwarded up the local protocol stack.  "
                             "This is a promiscuous trace,",
                             MakeTraceSourceAccessor(&BridgedPointToPointNetDevice::m_macPromiscRxTrace),
                             "ns3::Packet::TracedCallback")
             .AddTraceSource("MacRx",
                             "A packet has been received by this device, "
                             "has been passed up from the physical layer "
                             "and is being forwarded up the local protocol stack.  "
                             "This is a non-promiscuous trace,",
                             MakeTraceSourceAccessor(&BridgedPointToPointNetDevice::m_macRxTrace),
                             "ns3::Packet::TracedCallback")
 #if 0
     // Not currently implemented for this device
     .AddTraceSource ("MacRxDrop",
                      "Trace source indicating a packet was dropped "
                      "before being forwarded up the stack",
                      MakeTraceSourceAccessor (&BridgedPointToPointNetDevice::m_macRxDropTrace),
                      "ns3::Packet::TracedCallback")
 #endif
             //
             // Trace sources at the "bottom" of the net device, where packets transition
             // to/from the channel.
             //
             .AddTraceSource("PhyTxBegin",
                             "Trace source indicating a packet has begun "
                             "transmitting over the channel",
                             MakeTraceSourceAccessor(&BridgedPointToPointNetDevice::m_phyTxBeginTrace),
                             "ns3::Packet::TracedCallback")
             .AddTraceSource("PhyTxEnd",
                             "Trace source indicating a packet has been "
                             "completely transmitted over the channel",
                             MakeTraceSourceAccessor(&BridgedPointToPointNetDevice::m_phyTxEndTrace),
                             "ns3::Packet::TracedCallback")
             .AddTraceSource("PhyTxDrop",
                             "Trace source indicating a packet has been "
                             "dropped by the device during transmission",
                             MakeTraceSourceAccessor(&BridgedPointToPointNetDevice::m_phyTxDropTrace),
                             "ns3::Packet::TracedCallback")
 #if 0
     // Not currently implemented for this device
     .AddTraceSource ("PhyRxBegin",
                      "Trace source indicating a packet has begun "
                      "being received by the device",
                      MakeTraceSourceAccessor (&BridgedPointToPointNetDevice::m_phyRxBeginTrace),
                      "ns3::Packet::TracedCallback")
 #endif
             .AddTraceSource("PhyRxEnd",
                             "Trace source indicating a packet has been "
                             "completely received by the device",
                             MakeTraceSourceAccessor(&BridgedPointToPointNetDevice::m_phyRxEndTrace),
                             "ns3::Packet::TracedCallback")
             .AddTraceSource("PhyRxDrop",
                             "Trace source indicating a packet has been "
                             "dropped by the device during reception",
                             MakeTraceSourceAccessor(&BridgedPointToPointNetDevice::m_phyRxDropTrace),
                             "ns3::Packet::TracedCallback")
 
             //
             // Trace sources designed to simulate a packet sniffer facility (tcpdump).
             // Note that there is really no difference between promiscuous and
             // non-promiscuous traces in a point-to-point link.
             //
             .AddTraceSource("Sniffer",
                             "Trace source simulating a non-promiscuous packet sniffer "
                             "attached to the device",
                             MakeTraceSourceAccessor(&BridgedPointToPointNetDevice::m_snifferTrace),
                             "ns3::Packet::TracedCallback")
             .AddTraceSource("PromiscSniffer",
                             "Trace source simulating a promiscuous packet sniffer "
                             "attached to the device",
                             MakeTraceSourceAccessor(&BridgedPointToPointNetDevice::m_promiscSnifferTrace),
                             "ns3::Packet::TracedCallback");
     return tid;
 }
 
 BridgedPointToPointNetDevice::BridgedPointToPointNetDevice()
     : m_txMachineState(READY),
       m_channel(nullptr),
       m_linkUp(false),
       m_currentPkt(nullptr)
 {
     NS_LOG_FUNCTION(this);
 }
 
 BridgedPointToPointNetDevice::~BridgedPointToPointNetDevice()
 {
     NS_LOG_FUNCTION(this);
 }
 
 void
 BridgedPointToPointNetDevice::AddHeader(Ptr<Packet> p, uint16_t protocolNumber)
 {
     NS_LOG_FUNCTION(this << p << protocolNumber);
     PppHeader ppp;
     ppp.SetProtocol(EtherToPpp(protocolNumber));
     p->AddHeader(ppp);
 }

 void
 BridgedPointToPointNetDevice::AddHeader(Ptr<Packet> p,
                                        Mac48Address source,
                                        Mac48Address dest,
                                        uint16_t protocolNumber)
    {
    NS_LOG_FUNCTION(p << source << dest << protocolNumber);

    EthernetHeader header(false);
    header.SetSource(source);
    header.SetDestination(dest);

    EthernetTrailer trailer;

    NS_LOG_LOGIC("p->GetSize () = " << p->GetSize());
    NS_LOG_LOGIC("m_mtu = " << m_mtu);

    uint16_t lengthType = protocolNumber;
    // switch (m_encapMode)
    // {
    //     case DIX:
    //         NS_LOG_LOGIC("Encapsulating packet as DIX (type interpretation)");
    //         //
    //         // This corresponds to the type interpretation of the lengthType field as
    //         // in the old Ethernet Blue Book.
    //         //
    //         lengthType = protocolNumber;

    //         //
    //         // All Ethernet frames must carry a minimum payload of 46 bytes.  We need
    //         // to pad out if we don't have enough bytes.  These must be real bytes
    //         // since they will be written to pcap files and compared in regression
    //         // trace files.
    //         //
    //         if (p->GetSize() < 46)
    //         {
    //             uint8_t buffer[46];
    //             memset(buffer, 0, 46);
    //             Ptr<Packet> padd = Create<Packet>(buffer, 46 - p->GetSize());
    //             p->AddAtEnd(padd);
    //         }
    //         break;
    // case LLC: {
    //     NS_LOG_LOGIC("Encapsulating packet as LLC (length interpretation)");

    //     LlcSnapHeader llc;
    //     llc.SetType(protocolNumber);
    //     p->AddHeader(llc);

    //     //
    //     // This corresponds to the length interpretation of the lengthType
    //     // field but with an LLC/SNAP header added to the payload as in
    //     // IEEE 802.2
    //     //
    //     lengthType = p->GetSize();

    //     //
    //     // All Ethernet frames must carry a minimum payload of 46 bytes.  The
    //     // LLC SNAP header counts as part of this payload.  We need to padd out
    //     // if we don't have enough bytes.  These must be real bytes since they
    //     // will be written to pcap files and compared in regression trace files.
    //     //
    //     if (p->GetSize() < 46)
    //     {
    //     uint8_t buffer[46];
    //     memset(buffer, 0, 46);
    //     Ptr<Packet> padd = Create<Packet>(buffer, 46 - p->GetSize());
    //     p->AddAtEnd(padd);
    //     }

    //     NS_ASSERT_MSG(p->GetSize() <= GetMtu(),
    //     "CsmaNetDevice::AddHeader(): 802.3 Length/Type field with LLC/SNAP: "
    //     "length interpretation must not exceed device frame size minus overhead");
    //     }
    //     break;
    // case ILLEGAL:
    // default:
    //     NS_FATAL_ERROR("CsmaNetDevice::AddHeader(): Unknown packet encapsulation mode");
    //     break;
    // }

    NS_LOG_LOGIC("header.SetLengthType (" << lengthType << ")");
    header.SetLengthType(lengthType);
    p->AddHeader(header);

    if (Node::ChecksumEnabled())
    {
        trailer.EnableFcs(true);
    }
    trailer.CalcFcs(p);
    p->AddTrailer(trailer);
}
 
 bool
 BridgedPointToPointNetDevice::ProcessHeader(Ptr<Packet> p, uint16_t& param)
 {
     NS_LOG_FUNCTION(this << p << param);
     PppHeader ppp;
     p->RemoveHeader(ppp);
     param = PppToEther(ppp.GetProtocol());
     return true;
 }
 
 void
 BridgedPointToPointNetDevice::DoDispose()
 {
     NS_LOG_FUNCTION(this);
     m_node = nullptr;
     m_channel = nullptr;
     m_receiveErrorModel = nullptr;
     m_currentPkt = nullptr;
     m_queue = nullptr;
     NetDevice::DoDispose();
 }
 
 void
 BridgedPointToPointNetDevice::SetDataRate(DataRate bps)
 {
     NS_LOG_FUNCTION(this);
     m_bps = bps;
 }
 
 void
 BridgedPointToPointNetDevice::SetInterframeGap(Time t)
 {
     NS_LOG_FUNCTION(this << t.As(Time::S));
     m_tInterframeGap = t;
 }
 
 bool
 BridgedPointToPointNetDevice::TransmitStart(Ptr<Packet> p)
 {
     NS_LOG_FUNCTION(this << p);
     NS_LOG_LOGIC("UID is " << p->GetUid() << ")");
 
     //
     // This function is called to start the process of transmitting a packet.
     // We need to tell the channel that we've started wiggling the wire and
     // schedule an event that will be executed when the transmission is complete.
     //
     NS_ASSERT_MSG(m_txMachineState == READY, "Must be READY to transmit");
     m_txMachineState = BUSY;
     m_currentPkt = p;
     m_phyTxBeginTrace(m_currentPkt);
 
     Time txTime = m_bps.CalculateBytesTxTime(p->GetSize());
     Time txCompleteTime = txTime + m_tInterframeGap;
 
     NS_LOG_LOGIC("Schedule TransmitCompleteEvent in " << txCompleteTime.As(Time::S));
     Simulator::Schedule(txCompleteTime, &BridgedPointToPointNetDevice::TransmitComplete, this);
 
     bool result = m_channel->TransmitStart(p, this, txTime);
     if (result == false)
     {
         m_phyTxDropTrace(p);
     }
     return result;
 }
 
 void
 BridgedPointToPointNetDevice::TransmitComplete()
 {
     NS_LOG_FUNCTION(this);
 
     //
     // This function is called to when we're all done transmitting a packet.
     // We try and pull another packet off of the transmit queue.  If the queue
     // is empty, we are done, otherwise we need to start transmitting the
     // next packet.
     //
     NS_ASSERT_MSG(m_txMachineState == BUSY, "Must be BUSY if transmitting");
     m_txMachineState = READY;
 
     NS_ASSERT_MSG(m_currentPkt, "BridgedPointToPointNetDevice::TransmitComplete(): m_currentPkt zero");
 
     m_phyTxEndTrace(m_currentPkt);
     m_currentPkt = nullptr;
 
     Ptr<Packet> p = m_queue->Dequeue();
     if (!p)
     {
         NS_LOG_LOGIC("No pending packets in device queue after tx complete");
         return;
     }
 
     //
     // Got another packet off of the queue, so start the transmit process again.
     //
     m_snifferTrace(p);
     m_promiscSnifferTrace(p);
     TransmitStart(p);
 }
 
 bool
 BridgedPointToPointNetDevice::Attach(Ptr<BridgedP2PChannel> ch)
 {
     NS_LOG_FUNCTION(this << &ch);
 
     m_channel = ch;
 
     m_channel->Attach(this);
 
     //
     // This device is up whenever it is attached to a channel.  A better plan
     // would be to have the link come up when both devices are attached, but this
     // is not done for now.
     //
     NotifyLinkUp();
     return true;
 }
 
 void
 BridgedPointToPointNetDevice::SetQueue(Ptr<Queue<Packet>> q)
 {
     NS_LOG_FUNCTION(this << q);
     m_queue = q;
 }
 
 void
 BridgedPointToPointNetDevice::SetReceiveErrorModel(Ptr<ErrorModel> em)
 {
     NS_LOG_FUNCTION(this << em);
     m_receiveErrorModel = em;
 }
 
 void
 BridgedPointToPointNetDevice::Receive(Ptr<Packet> packet)
 {
     NS_LOG_FUNCTION(this << packet);
     uint16_t protocol = 0;
 
     if (m_receiveErrorModel && m_receiveErrorModel->IsCorrupt(packet))
     {
         //
         // If we have an error model and it indicates that it is time to lose a
         // corrupted packet, don't forward this packet up, let it go.
         //
         m_phyRxDropTrace(packet);
     }
     else
     {
         //
         // Hit the trace hooks.  All of these hooks are in the same place in this
         // device because it is so simple, but this is not usually the case in
         // more complicated devices.
         //
         m_snifferTrace(packet);
         m_promiscSnifferTrace(packet);
         m_phyRxEndTrace(packet);
 
         //
         // Trace sinks will expect complete packets, not packets without some of the
         // headers.
         //
         Ptr<Packet> originalPacket = packet->Copy();

         EthernetTrailer trailer;
        packet->RemoveTrailer(trailer);
        if (Node::ChecksumEnabled())
        {
            trailer.EnableFcs(true);
        }

        bool crcGood = trailer.CheckFcs(packet);
        if (!crcGood)
        {
            NS_LOG_INFO("CRC error on Packet " << packet);
            m_phyRxDropTrace(packet);
            return;
        }

        EthernetHeader header(false);
        packet->RemoveHeader(header);
        protocol = header.GetLengthType();

        PacketType packetType;

        if (header.GetDestination().IsBroadcast())
        {
            packetType = PACKET_BROADCAST;
        }
        else if (header.GetDestination().IsGroup())
        {
            packetType = PACKET_MULTICAST;
        }
        else if (header.GetDestination() == m_address)
        {
            packetType = PACKET_HOST;
        }
        else
        {
            packetType = PACKET_OTHERHOST;
        }
 
         //
         // Strip off the point-to-point protocol header and forward this packet
         // up the protocol stack.  Since this is a simple point-to-point link,
         // there is no difference in what the promisc callback sees and what the
         // normal receive callback sees.
         //
        //  ProcessHeader(packet, protocol);

        // if protocol is not set, the packet will not be forwarded up the stack after receiving callback is invoked
        // printf("BridgedPointToPointNetDevice::Receive: protocol = %u\n", protocol);
        if (!m_promiscCallback.IsNull())
        {
            m_macPromiscRxTrace(originalPacket);
            m_promiscCallback(this,
                            packet,
                            protocol,
                            header.GetSource(),
                            header.GetDestination(),
                            packetType);
        }

        m_macRxTrace(originalPacket);
        m_rxCallback(this, packet, protocol, GetRemote());
     }
 }
 
 Ptr<Queue<Packet>>
 BridgedPointToPointNetDevice::GetQueue() const
 {
     NS_LOG_FUNCTION(this);
     return m_queue;
 }
 
 void
 BridgedPointToPointNetDevice::NotifyLinkUp()
 {
     NS_LOG_FUNCTION(this);
     m_linkUp = true;
     m_linkChangeCallbacks();
 }
 
 void
 BridgedPointToPointNetDevice::SetIfIndex(const uint32_t index)
 {
     NS_LOG_FUNCTION(this);
     m_ifIndex = index;
 }
 
 uint32_t
 BridgedPointToPointNetDevice::GetIfIndex() const
 {
     return m_ifIndex;
 }
 
 Ptr<Channel>
 BridgedPointToPointNetDevice::GetChannel() const
 {
     return m_channel;
 }
 
 //
 // This is a point-to-point device, so we really don't need any kind of address
 // information.  However, the base class NetDevice wants us to define the
 // methods to get and set the address.  Rather than be rude and assert, we let
 // clients get and set the address, but simply ignore them.
 
 void
 BridgedPointToPointNetDevice::SetAddress(Address address)
 {
     NS_LOG_FUNCTION(this << address);
     m_address = Mac48Address::ConvertFrom(address);
 }
 
 Address
 BridgedPointToPointNetDevice::GetAddress() const
 {
     return m_address;
 }
 
 bool
 BridgedPointToPointNetDevice::IsLinkUp() const
 {
     NS_LOG_FUNCTION(this);
     return m_linkUp;
 }
 
 void
 BridgedPointToPointNetDevice::AddLinkChangeCallback(Callback<void> callback)
 {
     NS_LOG_FUNCTION(this);
     m_linkChangeCallbacks.ConnectWithoutContext(callback);
 }
 
 //
 // This is a point-to-point device, so every transmission is a broadcast to
 // all of the devices on the network.
 //
 bool
 BridgedPointToPointNetDevice::IsBroadcast() const
 {
     NS_LOG_FUNCTION(this);
     return true;
 }
 
 //
 // We don't really need any addressing information since this is a
 // point-to-point device.  The base class NetDevice wants us to return a
 // broadcast address, so we make up something reasonable.
 //
 Address
 BridgedPointToPointNetDevice::GetBroadcast() const
 {
     NS_LOG_FUNCTION(this);
     return Mac48Address("ff:ff:ff:ff:ff:ff");
 }
 
 bool
 BridgedPointToPointNetDevice::IsMulticast() const
 {
     NS_LOG_FUNCTION(this);
     return true;
 }
 
 Address
 BridgedPointToPointNetDevice::GetMulticast(Ipv4Address multicastGroup) const
 {
     NS_LOG_FUNCTION(this);
     return Mac48Address("01:00:5e:00:00:00");
 }
 
 Address
 BridgedPointToPointNetDevice::GetMulticast(Ipv6Address addr) const
 {
     NS_LOG_FUNCTION(this << addr);
     return Mac48Address("33:33:00:00:00:00");
 }
 
 bool
 BridgedPointToPointNetDevice::IsPointToPoint() const
 {
     NS_LOG_FUNCTION(this);
     return true;
 }
 
 bool
 BridgedPointToPointNetDevice::IsBridge() const
 {
     NS_LOG_FUNCTION(this);
     return false;
 }
 
 bool
 BridgedPointToPointNetDevice::Send(Ptr<Packet> packet, const Address& dest, uint16_t protocolNumber)
 {
    //  NS_LOG_FUNCTION(this << packet << dest << protocolNumber);
    //  NS_LOG_LOGIC("p=" << packet << ", dest=" << &dest);
    //  NS_LOG_LOGIC("UID is " << packet->GetUid());
 
    //  //
    //  // If IsLinkUp() is false it means there is no channel to send any packet
    //  // over so we just hit the drop trace on the packet and return an error.
    //  //
    //  if (IsLinkUp() == false)
    //  {
    //      m_macTxDropTrace(packet);
    //      return false;
    //  }
 
    //  //
    //  // Stick a point to point protocol header on the packet in preparation for
    //  // shoving it out the door.
    //  //
    //  AddHeader(packet, protocolNumber);
 
    //  m_macTxTrace(packet);
 
    //  //
    //  // We should enqueue and dequeue the packet to hit the tracing hooks.
    //  //
    //  if (m_queue->Enqueue(packet))
    //  {
    //      //
    //      // If the channel is ready for transition we send the packet right now
    //      //
    //      if (m_txMachineState == READY)
    //      {
    //          packet = m_queue->Dequeue();
    //          m_snifferTrace(packet);
    //          m_promiscSnifferTrace(packet);
    //          bool ret = TransmitStart(packet);
    //          return ret;
    //      }
    //      return true;
    //  }
 
    //  // Enqueue may fail (overflow)
 
    //  m_macTxDropTrace(packet);
    //  return false;
    return SendFrom(packet, m_address, dest, protocolNumber);
 }
 
 bool
 BridgedPointToPointNetDevice::SendFrom(Ptr<Packet> packet,
                                 const Address& src,
                                 const Address& dest,
                                 uint16_t protocolNumber)
 {
    NS_ASSERT(IsLinkUp());

    Mac48Address destination = Mac48Address::ConvertFrom(dest);
    Mac48Address source = Mac48Address::ConvertFrom(src);
    AddHeader(packet, source, destination, protocolNumber);

    m_macTxTrace(packet);

    //
    // Place the packet to be sent on the send queue.  Note that the
    // queue may fire a drop trace, but we will too.
    //

    if (m_queue->Enqueue(packet))
    {
        //
        // If the channel is ready for transition we send the packet right now
        //
        if (m_txMachineState == READY)
        {
            packet = m_queue->Dequeue();
            m_snifferTrace(packet);
            m_promiscSnifferTrace(packet);
            bool ret = TransmitStart(packet);
            return ret;
        }
        return true;
    }
 
     // Enqueue may fail (overflow)
 
     m_macTxDropTrace(packet);
     return false;
 }
 
 Ptr<Node>
 BridgedPointToPointNetDevice::GetNode() const
 {
     return m_node;
 }
 
 void
 BridgedPointToPointNetDevice::SetNode(Ptr<Node> node)
 {
     NS_LOG_FUNCTION(this);
     m_node = node;
 }
 
 bool
 BridgedPointToPointNetDevice::NeedsArp() const
 {
     NS_LOG_FUNCTION(this);
     return true;
 }
 
 void
 BridgedPointToPointNetDevice::SetReceiveCallback(NetDevice::ReceiveCallback cb)
 {
     m_rxCallback = cb;
 }
 
 void
 BridgedPointToPointNetDevice::SetPromiscReceiveCallback(NetDevice::PromiscReceiveCallback cb)
 {
     m_promiscCallback = cb;
 }
 
 bool
 BridgedPointToPointNetDevice::SupportsSendFrom() const
 {
     NS_LOG_FUNCTION(this);
     return true;
 }
 
 void
 BridgedPointToPointNetDevice::DoMpiReceive(Ptr<Packet> p)
 {
     NS_LOG_FUNCTION(this << p);
     Receive(p);
 }
 
 Address
 BridgedPointToPointNetDevice::GetRemote() const
 {
     NS_LOG_FUNCTION(this);
     NS_ASSERT(m_channel->GetNDevices() == 2);
     for (std::size_t i = 0; i < m_channel->GetNDevices(); ++i)
     {
         Ptr<NetDevice> tmp = m_channel->GetDevice(i);
         if (tmp != this)
         {
             return tmp->GetAddress();
         }
     }
     NS_ASSERT(false);
     // quiet compiler.
     return Address();
 }
 
 bool
 BridgedPointToPointNetDevice::SetMtu(uint16_t mtu)
 {
     NS_LOG_FUNCTION(this << mtu);
     m_mtu = mtu;
     return true;
 }
 
 uint16_t
 BridgedPointToPointNetDevice::GetMtu() const
 {
     NS_LOG_FUNCTION(this);
     return m_mtu;
 }
 
 uint16_t
 BridgedPointToPointNetDevice::PppToEther(uint16_t proto)
 {
     NS_LOG_FUNCTION_NOARGS();
     switch (proto)
     {
     case 0x0021:
         return 0x0800; // IPv4
     case 0x0057:
         return 0x86DD; // IPv6
     default:
         NS_ASSERT_MSG(false, "PPP Protocol number not defined!");
     }
     return 0;
 }
 
 uint16_t
 BridgedPointToPointNetDevice::EtherToPpp(uint16_t proto)
 {
     NS_LOG_FUNCTION_NOARGS();
     switch (proto)
     {
     case 0x0800:
         return 0x0021; // IPv4
     case 0x86DD:
         return 0x0057; // IPv6
     default:
         NS_ASSERT_MSG(false, "PPP Protocol number not defined!");
     }
     return 0;
 }
 
 } // namespace ns3
 