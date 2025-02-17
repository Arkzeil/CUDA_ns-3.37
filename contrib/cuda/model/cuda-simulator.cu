/*
 * Copyright (c) 2005,2006 INRIA
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
 *
 * Author: Mathieu Lacage <mathieu.lacage@sophia.inria.fr>
 */
#include "cuda-simulator.h"

#include "ns3/assert.h"
#include "ns3/des-metrics.h"
#include "ns3/event-impl.h"
#include "ns3/global-value.h"
#include "ns3/log.h"
#include "ns3/map-scheduler.h"
#include "ns3/object-factory.h"
#include "ns3/ptr.h"
#include "ns3/scheduler.h"
#include "ns3/simulator-impl.h"
#include "ns3/string.h"

#include "ns3/core-config.h"

#include <cmath>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <list>
#include <vector>

/**
 * \file
 * \ingroup simulator
 * ns3::Simulator implementation, as well as implementation pointer,
 * global scheduler implementation.
 */

namespace ns3
{

// Note:  Logging in this file is largely avoided due to the
// number of calls that are made to these functions and the possibility
// of causing recursions leading to stack overflow
NS_LOG_COMPONENT_DEFINE("Cuda_Simulator");

/**
 * \ingroup simulator
 * \anchor GlobalValueSimulatorImplementationType
 * The specific simulator implementation to use.
 *
 * Must be derived from SimulatorImpl.
 */
static GlobalValue g_simTypeImpl =
    GlobalValue("Cuda_SimulatorImplementationType",
                "The object class to use as the simulator implementation",
                StringValue("ns3::DefaultSimulatorImpl"),
                MakeStringChecker());

/**
 * \ingroup scheduler
 * \anchor GlobalValueSchedulerType
 * The specific event scheduler implementation to use.
 *
 * Must be derived from Scheduler.
 */
static GlobalValue g_schedTypeImpl =
    GlobalValue("Cuda_SchedulerType",
                "The object class to use as the scheduler implementation",
                TypeIdValue(MapScheduler::GetTypeId()),
                MakeTypeIdChecker());

/**
 * \ingroup simulator
 * \brief Get the static SimulatorImpl instance.
 * \return The SimulatorImpl instance pointer.
 */
static SimulatorImpl**
PeekImpl()
{
    static SimulatorImpl* impl = nullptr;
    return &impl;
}

/**
 * \ingroup simulator
 * \brief Get the SimulatorImpl singleton.
 * \return The singleton pointer.
 * \see Cuda_Simulator::GetImplementation()
 */
static SimulatorImpl*
GetImpl()
{
    SimulatorImpl** pimpl = PeekImpl();
    /* Please, don't include any calls to logging macros in this function
     * or pay the price, that is, stack explosions.
     */
    if (*pimpl == nullptr)
    {
        {
            ObjectFactory factory;
            StringValue s;

            g_simTypeImpl.GetValue(s);
            factory.SetTypeId(s.Get());
            *pimpl = GetPointer(factory.Create<SimulatorImpl>());
        }
        {
            ObjectFactory factory;
            StringValue s;
            g_schedTypeImpl.GetValue(s);
            factory.SetTypeId(s.Get());
            (*pimpl)->SetScheduler(factory);
        }

        //
        // Note: we call LogSetTimePrinter _after_ creating the implementation
        // object because the act of creation can trigger calls to the logging
        // framework which would call the TimePrinter function which would call
        // Cuda_Simulator::Now which would call Cuda_Simulator::GetImpl, and, thus, get us
        // in an infinite recursion until the stack explodes.
        //
        LogSetTimePrinter(&DefaultTimePrinter);
        LogSetNodePrinter(&DefaultNodePrinter);
    }
    return *pimpl;
}

void
Cuda_Simulator::Destroy()
{
    NS_LOG_FUNCTION_NOARGS();

    SimulatorImpl** pimpl = PeekImpl();
    if (*pimpl == nullptr)
    {
        return;
    }
    /* Note: we have to call LogSetTimePrinter (0) below because if we do not do
     * this, and restart a simulation after this call to Destroy, (which is
     * legal), Cuda_Simulator::GetImpl will trigger again an infinite recursion until
     * the stack explodes.
     */
    LogSetTimePrinter(nullptr);
    LogSetNodePrinter(nullptr);
    (*pimpl)->Destroy();
    (*pimpl)->Unref();
    *pimpl = nullptr;
}

void
Cuda_Simulator::SetScheduler(ObjectFactory schedulerFactory)
{
    NS_LOG_FUNCTION(schedulerFactory);
    GetImpl()->SetScheduler(schedulerFactory);
}

bool
Cuda_Simulator::IsFinished()
{
    NS_LOG_FUNCTION_NOARGS();
    return GetImpl()->IsFinished();
}

void
Cuda_Simulator::Run()
{
    NS_LOG_FUNCTION_NOARGS();
    // Time::ClearMarkedTimes();
    GetImpl()->Run();
}

void
Cuda_Simulator::Stop()
{
    NS_LOG_FUNCTION_NOARGS();
    NS_LOG_LOGIC("stop");
    GetImpl()->Stop();
}

void
Cuda_Simulator::Stop(const Time& delay)
{
    NS_LOG_FUNCTION(delay);
    GetImpl()->Stop(delay);
}

Time
Cuda_Simulator::Now()
{
    /* Please, don't include any calls to logging macros in this function
     * or pay the price, that is, stack explosions.
     */
    return GetImpl()->Now();
}

Time
Cuda_Simulator::GetDelayLeft(const EventId& id)
{
    NS_LOG_FUNCTION(&id);
    return GetImpl()->GetDelayLeft(id);
}

EventId
Cuda_Simulator::Schedule(const Time& delay, const Ptr<EventImpl>& event)
{
    return DoSchedule(delay, GetPointer(event));
}

EventId
Cuda_Simulator::ScheduleNow(const Ptr<EventImpl>& ev)
{
    return DoScheduleNow(GetPointer(ev));
}

void
Cuda_Simulator::ScheduleWithContext(uint32_t context, const Time& delay, EventImpl* impl)
{
#ifdef ENABLE_DES_METRICS
    DesMetrics::Get()->TraceWithContext(context, Now(), delay);
#endif
    return GetImpl()->ScheduleWithContext(context, delay, impl);
}

EventId
Cuda_Simulator::ScheduleDestroy(const Ptr<EventImpl>& ev)
{
    return DoScheduleDestroy(GetPointer(ev));
}

EventId
Cuda_Simulator::DoSchedule(const Time& time, EventImpl* impl)
{
#ifdef ENABLE_DES_METRICS
    DesMetrics::Get()->Trace(Now(), time);
#endif
    return GetImpl()->Schedule(time, impl);
}

EventId
Cuda_Simulator::DoScheduleNow(EventImpl* impl)
{
#ifdef ENABLE_DES_METRICS
    DesMetrics::Get()->Trace(Now(), Time(0));
#endif
    return GetImpl()->ScheduleNow(impl);
}

EventId
Cuda_Simulator::DoScheduleDestroy(EventImpl* impl)
{
    return GetImpl()->ScheduleDestroy(impl);
}

void
Cuda_Simulator::Remove(const EventId& id)
{
    if (*PeekImpl() == nullptr)
    {
        return;
    }
    return GetImpl()->Remove(id);
}

void
Cuda_Simulator::Cancel(const EventId& id)
{
    if (*PeekImpl() == nullptr)
    {
        return;
    }
    return GetImpl()->Cancel(id);
}

bool
Cuda_Simulator::IsExpired(const EventId& id)
{
    if (*PeekImpl() == nullptr)
    {
        return true;
    }
    return GetImpl()->IsExpired(id);
}

Time
Now()
{
    return Cuda_Simulator::Now();
}

Time
Cuda_Simulator::GetMaximumSimulationTime()
{
    NS_LOG_FUNCTION_NOARGS();
    return GetImpl()->GetMaximumSimulationTime();
}

uint32_t
Cuda_Simulator::GetContext()
{
    return GetImpl()->GetContext();
}

uint64_t
Cuda_Simulator::GetEventCount()
{
    return GetImpl()->GetEventCount();
}

uint32_t
Cuda_Simulator::GetSystemId()
{
    NS_LOG_FUNCTION_NOARGS();

    if (*PeekImpl() != nullptr)
    {
        return GetImpl()->GetSystemId();
    }
    else
    {
        return 0;
    }
}

void
Cuda_Simulator::SetImplementation(Ptr<SimulatorImpl> impl)
{
    NS_LOG_FUNCTION(impl);
    if (*PeekImpl() != nullptr)
    {
        NS_FATAL_ERROR(
            "It is not possible to set the implementation after calling any Cuda_Simulator:: function. "
            "Call Cuda_Simulator::SetImplementation earlier or after Cuda_Simulator::Destroy.");
    }
    *PeekImpl() = GetPointer(impl);
    // Set the default scheduler
    ObjectFactory factory;
    StringValue s;
    g_schedTypeImpl.GetValue(s);
    factory.SetTypeId(s.Get());
    impl->SetScheduler(factory);
    //
    // Note: we call LogSetTimePrinter _after_ creating the implementation
    // object because the act of creation can trigger calls to the logging
    // framework which would call the TimePrinter function which would call
    // Cuda_Simulator::Now which would call Cuda_Simulator::GetImpl, and, thus, get us
    // in an infinite recursion until the stack explodes.
    //
    LogSetTimePrinter(&DefaultTimePrinter);
    LogSetNodePrinter(&DefaultNodePrinter);
}

Ptr<SimulatorImpl>
Cuda_Simulator::GetImplementation()
{
    NS_LOG_FUNCTION_NOARGS();
    return GetImpl();
}

} // namespace ns3
