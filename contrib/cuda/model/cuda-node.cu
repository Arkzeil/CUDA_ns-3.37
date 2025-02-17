#include "cuda-node.h"

#include "ns3/application.h"
#include "ns3/net-device.h"
#include "ns3/node-list.h"

#include "ns3/assert.h"
#include "ns3/boolean.h"
#include "ns3/global-value.h"
#include "ns3/log.h"
#include "ns3/object-vector.h"
#include "ns3/packet.h"
#include "ns3/simulator.h"
#include "ns3/uinteger.h"

namespace ns3 {

    NS_LOG_COMPONENT_DEFINE("Cuda_Node");

    NS_OBJECT_ENSURE_REGISTERED(Cuda_Node);

    /**
     * \relates Cuda_Node
     * \anchor GlobalValueChecksumEnabled
     * \brief A global switch to enable all checksums for all protocols.
     */
    static GlobalValue g_checksumEnabled =
        GlobalValue("ChecksumEnabled",
                    "A global switch to enable all checksums for all protocols",
                    BooleanValue(false),
                    MakeBooleanChecker());

    TypeId
    Cuda_Node::GetTypeId()
    {
        static TypeId tid =
            TypeId("ns3::Cuda_Node")
                .SetParent<Object>()
                .SetGroupName("Network")
                .AddConstructor<Cuda_Node>()
                .AddAttribute("DeviceList",
                            "The list of devices associated to this Cuda_Node.",
                            ObjectVectorValue(),
                            MakeObjectVectorAccessor(&Cuda_Node::m_devices),
                            MakeObjectVectorChecker<NetDevice>())
                .AddAttribute("ApplicationList",
                            "The list of applications associated to this Cuda_Node.",
                            ObjectVectorValue(),
                            MakeObjectVectorAccessor(&Cuda_Node::m_applications),
                            MakeObjectVectorChecker<Application>())
                .AddAttribute("Id",
                            "The id (unique integer) of this Cuda_Node.",
                            TypeId::ATTR_GET, // allow only getting it.
                            UintegerValue(0),
                            MakeUintegerAccessor(&Cuda_Node::m_id),
                            MakeUintegerChecker<uint32_t>())
                .AddAttribute(
                    "SystemId",
                    "The systemId of this node: a unique integer used for parallel simulations.",
                    TypeId::ATTR_GET | TypeId::ATTR_SET,
                    UintegerValue(0),
                    MakeUintegerAccessor(&Cuda_Node::m_sid),
                    MakeUintegerChecker<uint32_t>());
        return tid;
    }

    Cuda_Node::Cuda_Node()
        : m_id(0),
        m_sid(0)
    {
        NS_LOG_FUNCTION(this);
        Construct();
    }

    Cuda_Node::Cuda_Node(uint32_t sid)
        : m_id(0),
        m_sid(sid)
    {
        NS_LOG_FUNCTION(this << sid);
        Construct();
    }

    void
    Cuda_Node::Construct()
    {
        NS_LOG_FUNCTION(this);
        m_id = Cuda_NodeList::Add(this);
    }

    Cuda_Node::~Cuda_Node()
    {
        NS_LOG_FUNCTION(this);
    }

    uint32_t
    Cuda_Node::GetId() const
    {
        NS_LOG_FUNCTION(this);
        return m_id;
    }

    Time
    Cuda_Node::GetLocalTime() const
    {
        NS_LOG_FUNCTION(this);
        return Simulator::Now();
    }

    uint32_t
    Cuda_Node::GetSystemId() const
    {
        NS_LOG_FUNCTION(this);
        return m_sid;
    }

    uint32_t
    Cuda_Node::AddDevice(Ptr<NetDevice> device)
    {
        NS_LOG_FUNCTION(this << device);
        uint32_t index = m_devices.size();
        m_devices.push_back(device);
        device->SetCuda_Node(this);
        device->SetIfIndex(index);
        device->SetReceiveCallback(MakeCallback(&Cuda_Node::NonPromiscReceiveFromDevice, this));
        Simulator::ScheduleWithContext(GetId(), Seconds(0.0), &NetDevice::Initialize, device);
        NotifyDeviceAdded(device);
        return index;
    }

    Ptr<NetDevice>
    Cuda_Node::GetDevice(uint32_t index) const
    {
        NS_LOG_FUNCTION(this << index);
        NS_ASSERT_MSG(index < m_devices.size(),
                    "Device index " << index << " is out of range (only have " << m_devices.size()
                                    << " devices).");
        return m_devices[index];
    }

    uint32_t
    Cuda_Node::GetNDevices() const
    {
        NS_LOG_FUNCTION(this);
        return m_devices.size();
    }

    uint32_t
    Cuda_Node::AddApplication(Ptr<Application> application)
    {
        NS_LOG_FUNCTION(this << application);
        uint32_t index = m_applications.size();
        m_applications.push_back(application);
        application->SetCuda_Node(this);
        Simulator::ScheduleWithContext(GetId(), Seconds(0.0), &Application::Initialize, application);
        return index;
    }

    Ptr<Application>
    Cuda_Node::GetApplication(uint32_t index) const
    {
        NS_LOG_FUNCTION(this << index);
        NS_ASSERT_MSG(index < m_applications.size(),
                    "Application index " << index << " is out of range (only have "
                                        << m_applications.size() << " applications).");
        return m_applications[index];
    }

    uint32_t
    Cuda_Node::GetNApplications() const
    {
        NS_LOG_FUNCTION(this);
        return m_applications.size();
    }

    void
    Cuda_Node::DoDispose()
    {
        NS_LOG_FUNCTION(this);
        m_deviceAdditionListeners.clear();
        m_handlers.clear();
        for (std::vector<Ptr<NetDevice>>::iterator i = m_devices.begin(); i != m_devices.end(); i++)
        {
            Ptr<NetDevice> device = *i;
            device->Dispose();
            *i = nullptr;
        }
        m_devices.clear();
        for (std::vector<Ptr<Application>>::iterator i = m_applications.begin();
            i != m_applications.end();
            i++)
        {
            Ptr<Application> application = *i;
            application->Dispose();
            *i = nullptr;
        }
        m_applications.clear();
        Object::DoDispose();
    }

    void
    Cuda_Node::DoInitialize()
    {
        NS_LOG_FUNCTION(this);
        for (std::vector<Ptr<NetDevice>>::iterator i = m_devices.begin(); i != m_devices.end(); i++)
        {
            Ptr<NetDevice> device = *i;
            device->Initialize();
        }
        for (std::vector<Ptr<Application>>::iterator i = m_applications.begin();
            i != m_applications.end();
            i++)
        {
            Ptr<Application> application = *i;
            application->Initialize();
        }

        Object::DoInitialize();
    }

    void
    Cuda_Node::RegisterProtocolHandler(ProtocolHandler handler,
                                uint16_t protocolType,
                                Ptr<NetDevice> device,
                                bool promiscuous)
    {
        NS_LOG_FUNCTION(this << &handler << protocolType << device << promiscuous);
        struct Cuda_Node::ProtocolHandlerEntry entry;
        entry.handler = handler;
        entry.protocol = protocolType;
        entry.device = device;
        entry.promiscuous = promiscuous;

        // On demand enable promiscuous mode in netdevices
        if (promiscuous)
        {
            if (!device)
            {
                for (std::vector<Ptr<NetDevice>>::iterator i = m_devices.begin(); i != m_devices.end();
                    i++)
                {
                    Ptr<NetDevice> dev = *i;
                    dev->SetPromiscReceiveCallback(MakeCallback(&Cuda_Node::PromiscReceiveFromDevice, this));
                }
            }
            else
            {
                device->SetPromiscReceiveCallback(MakeCallback(&Cuda_Node::PromiscReceiveFromDevice, this));
            }
        }

        m_handlers.push_back(entry);
    }

    void
    Cuda_Node::UnregisterProtocolHandler(ProtocolHandler handler)
    {
        NS_LOG_FUNCTION(this << &handler);
        for (ProtocolHandlerList::iterator i = m_handlers.begin(); i != m_handlers.end(); i++)
        {
            if (i->handler.IsEqual(handler))
            {
                m_handlers.erase(i);
                break;
            }
        }
    }

    bool
    Cuda_Node::ChecksumEnabled()
    {
        NS_LOG_FUNCTION_NOARGS();
        BooleanValue val;
        g_checksumEnabled.GetValue(val);
        return val.Get();
    }

    bool
    Cuda_Node::PromiscReceiveFromDevice(Ptr<NetDevice> device,
                                Ptr<const Packet> packet,
                                uint16_t protocol,
                                const Address& from,
                                const Address& to,
                                NetDevice::PacketType packetType)
    {
        NS_LOG_FUNCTION(this << device << packet << protocol << &from << &to << packetType);
        return ReceiveFromDevice(device, packet, protocol, from, to, packetType, true);
    }

    bool
    Cuda_Node::NonPromiscReceiveFromDevice(Ptr<NetDevice> device,
                                    Ptr<const Packet> packet,
                                    uint16_t protocol,
                                    const Address& from)
    {
        NS_LOG_FUNCTION(this << device << packet << protocol << &from);
        return ReceiveFromDevice(device,
                                packet,
                                protocol,
                                from,
                                device->GetAddress(),
                                NetDevice::PacketType(0),
                                false);
    }

    bool
    Cuda_Node::ReceiveFromDevice(Ptr<NetDevice> device,
                            Ptr<const Packet> packet,
                            uint16_t protocol,
                            const Address& from,
                            const Address& to,
                            NetDevice::PacketType packetType,
                            bool promiscuous)
    {
        NS_LOG_FUNCTION(this << device << packet << protocol << &from << &to << packetType
                            << promiscuous);
        NS_ASSERT_MSG(Simulator::GetContext() == GetId(),
                    "Received packet with erroneous context ; "
                        << "make sure the channels in use are correctly updating events context "
                        << "when transferring events from one node to another.");
        NS_LOG_DEBUG("Cuda_Node " << GetId() << " ReceiveFromDevice:  dev " << device->GetIfIndex()
                            << " (type=" << device->GetInstanceTypeId().GetName() << ") Packet UID "
                            << packet->GetUid());
        bool found = false;

        for (ProtocolHandlerList::iterator i = m_handlers.begin(); i != m_handlers.end(); i++)
        {
            if (!i->device || (i->device == device))
            {
                if (i->protocol == 0 || i->protocol == protocol)
                {
                    if (promiscuous == i->promiscuous)
                    {
                        i->handler(device, packet, protocol, from, to, packetType);
                        found = true;
                    }
                }
            }
        }
        return found;
    }

    void
    Cuda_Node::RegisterDeviceAdditionListener(DeviceAdditionListener listener)
    {
        NS_LOG_FUNCTION(this << &listener);
        m_deviceAdditionListeners.push_back(listener);
        // and, then, notify the new listener about all existing devices.
        for (std::vector<Ptr<NetDevice>>::const_iterator i = m_devices.begin(); i != m_devices.end();
            ++i)
        {
            listener(*i);
        }
    }

    void
    Cuda_Node::UnregisterDeviceAdditionListener(DeviceAdditionListener listener)
    {
        NS_LOG_FUNCTION(this << &listener);
        for (DeviceAdditionListenerList::iterator i = m_deviceAdditionListeners.begin();
            i != m_deviceAdditionListeners.end();
            i++)
        {
            if ((*i).IsEqual(listener))
            {
                m_deviceAdditionListeners.erase(i);
                break;
            }
        }
    }

    void
    Cuda_Node::NotifyDeviceAdded(Ptr<NetDevice> device)
    {
        NS_LOG_FUNCTION(this << device);
        for (DeviceAdditionListenerList::iterator i = m_deviceAdditionListeners.begin();
            i != m_deviceAdditionListeners.end();
            i++)
        {
            (*i)(device);
        }
    }


} // namespace ns3
