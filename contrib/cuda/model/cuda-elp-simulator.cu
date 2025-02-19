#include "cuda-elp-simulator.h"

#include "ns3/assert.h"
#include "ns3/channel.h"
#include "ns3/event-impl.h"
#include "ns3/log.h"
#include "ns3/node-container.h"
#include "ns3/pointer.h"
#include "ns3/ptr.h"
#include "ns3/scheduler.h"
#include "ns3/simulator.h"
#include "ns3/log.h"

#include "ns3/cuda-helper.h"
#include "ns3/cuda-udp-client.h"
#include "ns3/cuda-udp-server.h"
#include "ns3/cuda-p2p-channel.h"

#include <unistd.h>

#include <cmath>

namespace ns3 {
    NS_LOG_COMPONENT_DEFINE("CudaELPSimulator");
    NS_OBJECT_ENSURE_REGISTERED(CudaELPSimulator);

    // __managed__ cudaEvent_t event;
    // to record how many block has completed
    __device__ volatile int blkcnt1 = 0;
    __device__ volatile int blkcnt2 = 0;

    // __managed__ CudaELPSimulator* cudaSim_local = nullptr;

    TypeId CudaELPSimulator::GetTypeId() {
        static TypeId tid = TypeId("ns3::CudaELPSimulator")
                        .SetParent<SimulatorImpl>()
                        .SetGroupName("cuda")
                        .AddConstructor<CudaELPSimulator>();
        return tid;
    }

    void CudaELPComponent::mymethod() {
        // This method is called from the main ns-3 simulation thread.
        // It can be used to launch the CUDA kernel or perform other operations.
        // For example, you might launch the kernel with a specific block size and grid size.
        // PersistentEventKernel<<<1, 32>>>(d_eventCount, eventCounter, 100);
        printf("Hello from mymethod\n");
    }
    
    CudaELPSimulator::CudaELPSimulator() {
        NS_LOG_FUNCTION(this);
        m_stop = false;
        m_uid = EventId::UID::VALID;
        m_currentUid = EventId::UID::INVALID;
        m_currentTs = 0;
        m_currentContext = Simulator::NO_CONTEXT;
        m_unscheduledEvents = 0;
        m_eventCount = 0;
        m_eventsWithContextEmpty = true;
        m_mainThreadId = std::this_thread::get_id();

        // cudaSim = this;
        printf("This: %p\n", this);
        m_test = 69;
    }

    CudaELPSimulator::~CudaELPSimulator() {
        NS_LOG_FUNCTION(this);
        printf("CudaELPSimulator destroyed\n");
    }

    void CudaELPSimulator::DoDispose() {
        NS_LOG_FUNCTION(this);
        ProcessEventsWithContext();

        while (!m_events->IsEmpty())
        {
            Scheduler::Event next = m_events->RemoveNext();
            next.impl->Unref();
        }
        m_events = nullptr;
        SimulatorImpl::DoDispose();
    }

    void CudaELPSimulator::Destroy() {
        NS_LOG_FUNCTION(this);
        while (!m_destroyEvents.empty())
        {
            Ptr<EventImpl> ev = m_destroyEvents.front().PeekEventImpl();
            m_destroyEvents.pop_front();
            NS_LOG_LOGIC("handle destroy " << ev);
            if (!ev->IsCancelled())
            {
                ev->Invoke();
            }
        }
    }

    void CudaELPSimulator::SetScheduler(ObjectFactory schedulerFactory)
    {
        NS_LOG_FUNCTION(this << schedulerFactory);
        Ptr<Scheduler> scheduler = schedulerFactory.Create<Scheduler>();

        if (m_events)
        {
            while (!m_events->IsEmpty())
            {
                Scheduler::Event next = m_events->RemoveNext();
                scheduler->Insert(next);
            }
        }
        m_events = scheduler;
    }

    // System ID for non-distributed simulation is always zero
    uint32_t CudaELPSimulator::GetSystemId() const
    {   
        print_test();
        return 0;
    }

    void CudaELPSimulator::ProcessOneEvent()
    {
        Scheduler::Event next = m_events->RemoveNext();

        PreEventHook(EventId(next.impl, next.key.m_ts, next.key.m_context, next.key.m_uid));

        NS_ASSERT(next.key.m_ts >= m_currentTs);
        m_unscheduledEvents--;
        m_eventCount++;

        NS_LOG_LOGIC("handle " << next.key.m_ts);
        m_currentTs = next.key.m_ts;
        m_currentContext = next.key.m_context;
        m_currentUid = next.key.m_uid;
        next.impl->Invoke();
        next.impl->Unref();

        ProcessEventsWithContext();
    }

    bool CudaELPSimulator::IsFinished() const
    {
        return m_events->IsEmpty() || m_stop;
    }

    void CudaELPSimulator::ProcessEventsWithContext()
    {
        if (m_eventsWithContextEmpty)
        {
            return;
        }

        // swap queues
        EventsWithContext eventsWithContext;
        {
            std::unique_lock lock{m_eventsWithContextMutex};
            m_eventsWithContext.swap(eventsWithContext);
            m_eventsWithContextEmpty = true;
        }
        while (!eventsWithContext.empty())
        {
            EventWithContext event = eventsWithContext.front();
            eventsWithContext.pop_front();
            Scheduler::Event ev;
            ev.impl = event.event;
            ev.key.m_ts = m_currentTs + event.timestamp;
            ev.key.m_context = event.context;
            ev.key.m_uid = m_uid;
            m_uid++;
            m_unscheduledEvents++;
            m_events->Insert(ev);
        }
    }

    // Device functions to process different event types
    __device__ void ProcessType0(DeviceEvent* ev) {
        // Insert logic analogous to what your C++ ns-3 event might do
        // For example, a UDP send operation or a simulated network event.
        printf("Processing Type 0 event\n");
    }
    // Device functions to process different event types
    __device__ void ProcessType1(DeviceEvent* ev) {
        // Insert logic analogous to what your C++ ns-3 event might do
        // For example, a UDP send operation or a simulated network event.
        printf("Processing Type 1 event\n");
        cudaSim->insert(ev->impl, 0, 0, 0);
    }

    __device__ void ProcessType2(DeviceEvent* ev) {
        // Different event processing logic
        printf("Processing Type 2 event\n");
        ((CudaUdpClient*)(ev->impl))->test();
    }

    // General device function that processes an event based on its type.
    __device__ void ProcessOneEvent(DeviceEvent* ev) {
        // You might include pre-event hooks here if needed.
        // For example: PreEventHook(ev->ts, ev->context, ev->uid);
        
        // Dispatch to the appropriate handler.
        switch (ev->type) {
            case -1:
                // No event
                break;
            case 0:
                ProcessType0(ev);
                break;
            case 1:
                ProcessType1(ev);
                break;
            case 2:
                ProcessType2(ev);
                break;
            default:
                // Handle unknown event type
                break;
        }

        // Post-event processing can be added here as well.
    }

   // A persistent kernel that polls the device queue and executes events when their time is reached.
    __global__ void PersistentEventKernel(DeviceEvent* d_eventQueue, int* d_eventCount, double* d_safe_ts, int* d_stop) {
        const int tid = threadIdx.x + blockIdx.x * blockDim.x;
        const int totalThreads = gridDim.x * blockDim.x;

        if(tid == 0) {
            *d_stop = false;
        }

        __syncthreads();
        
        // Loop forever or until a termination condition is met.
        while (!*d_stop) {
            // Each thread polls for an event to process.
            int index = tid;
            if (index < *d_eventCount && index < DEVICE_QUEUE_LENGTH) {
                DeviceEvent* ev = &d_eventQueue[index];
                
                // (*d_safe_ts)++;
                // Process the event based on its type.
                ProcessOneEvent(ev);
                // Mark the event as processed (or remove it from the queue).
                // For simplicity, we assume the host will later clean up processed events.
                if(ev->ts < *d_safe_ts)
                    *d_safe_ts = ev->ts;
                
                index += totalThreads;
            }
            // else{
            //     cudaStreamWaitEvent(0, event);
            // }
            // Optionally, add a delay or yield to avoid busy waiting.
            __syncthreads();
        }
    }

    __host__ void CudaELPSimulator::componentMethod() {
        // This method is called from the main ns-3 simulation thread.
        // It can be used to launch the CUDA kernel or perform other operations.
        // For example, you might launch the kernel with a specific block size and grid size.
        // PersistentEventKernel<<<1, 32>>>(d_eventCount, eventCounter, 100);
        elpComponent.mymethod();
    }

    void CudaELPSimulator::test(void *obj){
        cudaStream_t streamK;
        cudaStream_t streamC;
        cudaStreamCreate(&streamK);
        cudaStreamCreate(&streamC);

        // cudaSim = this;
        printf("This: %p\n", this);
        printf("test: %d\n", m_test);

        // cudaEventCreate(&event);
        int *h_buf1, *d_buf1, *h_buf2, *d_buf2;
        volatile int *m_bufrdy1, *m_bufrdy2;
        // Allocate the ready flags on the device
        // cudaMallocManaged(&h_buf1, sizeof(int));
        // cudaMallocManaged(&h_buf2, sizeof(int));
        cudaMallocManaged(&m_bufrdy1, sizeof(int));
        cudaMallocManaged(&m_bufrdy2, sizeof(int));
        cudaCheckErrors("ready flag cudaMallocManaged failed");
        // Allocate the buffers on the device
        // cudaMalloc(&d_buf1, 1024 * sizeof(int));
        // cudaMalloc(&d_buf2, 1024 * sizeof(int));
        // checkCudaErr();
        // Allocate and initialize the stop flag on the device
        cudaMallocManaged(&d_stop, sizeof(int));
        cudaMallocManaged(&safe_ts, sizeof(double));
        cudaMemset(safe_ts, 1, sizeof(double));
        cudaCheckErrors("stop and safe_ts cudaMallocManaged failed");
        // Allocate and initialize the event queue on the UMA
        cudaMallocManaged(&h_safeEventQueue1, DEVICE_QUEUE_LENGTH * sizeof(DeviceEvent));
        cudaMallocManaged(&h_safeEventQueue2, DEVICE_QUEUE_LENGTH * sizeof(DeviceEvent));
        cudaMallocManaged(&d_eventQueue, DEVICE_QUEUE_LENGTH * sizeof(DeviceEvent));
        // cudaMemset(d_eventQueue, 0, 100 * sizeof(DeviceEvent));
        cudaCheckErrors("queue cudaMallocManaged failed");

        // Allocate and initialize the event counter on the device
        cudaMallocManaged(&eventCounter, sizeof(int));
        cudaMemset(eventCounter, 0, sizeof(int));
        cudaCheckErrors("counter cudaMallocManaged failed");
        // Allocate and initialize the simulation time on the device
        // cudaMallocManaged(&d_simulationTime, sizeof(double));
        // cudaMemcpy(d_simulationTime, &m_currentTs, sizeof(double), cudaMemcpyHostToDevice);
        // checkCudaErr();
        // Launch the persistent event processing kernel
        PersistentEventKernel<<<1, 32, 0, streamK>>>(d_eventQueue, eventCounter, safe_ts, d_stop);
        printf("Kernel launched\n");
        cudaCheckErrors("kernel launch failed");

        double currentSimTime = 0.0;
        bool simulationFinished = false;

        // cudaMemcpyToSymbolAsync(d_simulationTime, &currentSimTime, sizeof(double), 0, cudaMemcpyHostToDevice);
        printf("Simulation time: %f\n", currentSimTime);

        while(!simulationFinished){
            // insert event
            DeviceEvent ev;
            ev.type = 1;
            ev.ts = 0.0;
            ev.context = 0;
            ev.uid = 0;
            ev.impl = obj;

            printf("Inserting event\n");
            cudaMemcpyAsync(&d_eventQueue[0], &ev, sizeof(DeviceEvent), cudaMemcpyHostToDevice, streamC);
            cudaCheckErrors("queue cudaMemcpyAsync failed");
            ev.type = 2;
            cudaMemcpyAsync(&d_eventQueue[1], &ev, sizeof(DeviceEvent), cudaMemcpyHostToDevice, streamC);
            cudaCheckErrors("queue cudaMemcpyAsync failed");
            printf("Events inserted\n");

            // cudaMemset(eventCounter, 2, sizeof(int));
            cudaMemcpyAsync(eventCounter, &(ev.type), sizeof(int), cudaMemcpyHostToDevice, streamC);
            // checkCudaErr();

            // cudaEventRecord(event, stream);
            // insert(d_eventQueue, ev.impl, eventCounter, 100, ev.ts, ev.context, ev.uid, ev.type);
            simulationFinished = true;
        }

        // cudaMemset(d_stop, true, sizeof(bool));
        // cudaMemset(d_stop, 1, sizeof(int));
        
        // sleep(3);

        int stop = 1;
        cudaMemcpyAsync(d_stop, &stop, sizeof(int), cudaMemcpyHostToDevice, streamC);
        cudaCheckErrors("stop cudaMemcpyAsync failed");
        printf("Simulation finished\n");

        // Wait for the kernel to finish
        cudaStreamSynchronize(streamK);
        printf("Kernel finished\n");
        cudaStreamSynchronize(streamC);
        printf("Stream finished\n");
        // printf("safe_ts: %f\n", *safe_ts);
        // Free the streams
        cudaStreamDestroy(streamK);
        cudaStreamDestroy(streamC);
        // Free the allocated memory
        cudaFree(h_safeEventQueue1);
        cudaFree(h_safeEventQueue2);
        cudaFree(d_eventQueue);
        cudaFree(eventCounter);
        cudaFree(safe_ts);
        cudaFree(d_stop);
    }

    void CudaELPSimulator::print_test() const{
        printf("cuda_sim: %p\n", cudaSim);
        printf("print_test: %p\n", this);
        printf("print_test: %d\n", m_test);
    }

    __device__ void CudaELPSimulator::deviceMethod(void *obj, int func_id){
        printf("Hello from deviceMethod\n");
        ((CudaP2PChannel*)obj)->test();
    }

    __device__ void CudaELPSimulator::insert(void* impl, double delay, int context, uint32_t type){
        int tid = threadIdx.x + blockIdx.x * blockDim.x;
        printf("safe_ts: %f\n", *safe_ts);
        // we can't access variables of class object if member function is called by non-member __device__ function?
        // printf("tid: %d\n", tid);                    // Debugging
        // d_eventQueue[tid] = DeviceEvent{impl, delay, context, type};
    }

    void CudaELPSimulator::Run()
    {
        NS_LOG_FUNCTION(this);
        // Set the current threadId as the main threadId
        m_mainThreadId = std::this_thread::get_id();
        ProcessEventsWithContext();
        m_stop = false;

        while (!m_events->IsEmpty() && !m_stop)
        {
            ProcessOneEvent();
        }

        printf("This Run: %p\n", this);
        printf("Run test: %d\n", m_test);

        // If the simulator stopped naturally by lack of events, make a
        // consistency test to check that we didn't lose any events along the way.
        NS_ASSERT(!m_events->IsEmpty() || m_unscheduledEvents == 0);
    }

    void CudaELPSimulator::Stop()
    {
        NS_LOG_FUNCTION(this);
        m_stop = true;
    }

    void CudaELPSimulator::Stop(const Time& delay)
    {
        NS_LOG_FUNCTION(this << delay.GetTimeStep());
        Simulator::Schedule(delay, &Simulator::Stop);
    }

    //
    // Schedule an event for a _relative_ time in the future.
    //
    EventId CudaELPSimulator::Schedule(const Time& delay, EventImpl* event)
    {
        NS_LOG_FUNCTION(this << delay.GetTimeStep() << event);
        NS_ASSERT_MSG(m_mainThreadId == std::this_thread::get_id(),
                    "Simulator::Schedule Thread-unsafe invocation!");

        NS_ASSERT_MSG(delay.IsPositive(), "CudaELPSimulator::Schedule(): Negative delay");
        Time tAbsolute = delay + TimeStep(m_currentTs);

        Scheduler::Event ev;
        ev.impl = event;
        ev.key.m_ts = (uint64_t)tAbsolute.GetTimeStep();
        ev.key.m_context = GetContext();
        ev.key.m_uid = m_uid;
        m_uid++;
        m_unscheduledEvents++;
        m_events->Insert(ev);
        return EventId(event, ev.key.m_ts, ev.key.m_context, ev.key.m_uid);
    }

    void CudaELPSimulator::ScheduleWithContext(uint32_t context, const Time& delay, EventImpl* event)
    {
        NS_LOG_FUNCTION(this << context << delay.GetTimeStep() << event);

        if (m_mainThreadId == std::this_thread::get_id())
        {
            Time tAbsolute = delay + TimeStep(m_currentTs);
            Scheduler::Event ev;
            ev.impl = event;
            ev.key.m_ts = (uint64_t)tAbsolute.GetTimeStep();
            ev.key.m_context = context;
            ev.key.m_uid = m_uid;
            m_uid++;
            m_unscheduledEvents++;
            m_events->Insert(ev);
        }
        else
        {
            EventWithContext ev;
            ev.context = context;
            // Current time added in ProcessEventsWithContext()
            ev.timestamp = delay.GetTimeStep();
            ev.event = event;
            {
                std::unique_lock lock{m_eventsWithContextMutex};
                m_eventsWithContext.push_back(ev);
                m_eventsWithContextEmpty = false;
            }
        }
    }

    EventId CudaELPSimulator::ScheduleNow(EventImpl* event)
    {
        NS_ASSERT_MSG(m_mainThreadId == std::this_thread::get_id(),
                    "Simulator::ScheduleNow Thread-unsafe invocation!");

        return Schedule(Time(0), event);
    }

    EventId CudaELPSimulator::ScheduleDestroy(EventImpl* event)
    {
        NS_ASSERT_MSG(m_mainThreadId == std::this_thread::get_id(),
                    "Simulator::ScheduleDestroy Thread-unsafe invocation!");

        EventId id(Ptr<EventImpl>(event, false), m_currentTs, 0xffffffff, 2);
        m_destroyEvents.push_back(id);
        m_uid++;
        return id;
    }

    Time CudaELPSimulator::Now() const
    {
        // Do not add function logging here, to avoid stack overflow
        return TimeStep(m_currentTs);
    }

    Time CudaELPSimulator::GetDelayLeft(const EventId& id) const
    {
        if (IsExpired(id))
        {
            return TimeStep(0);
        }
        else
        {
            return TimeStep(id.GetTs() - m_currentTs);
        }
    }

    void CudaELPSimulator::Remove(const EventId& id)
    {
        if (id.GetUid() == EventId::UID::DESTROY)
        {
            // destroy events.
            for (DestroyEvents::iterator i = m_destroyEvents.begin(); i != m_destroyEvents.end(); i++)
            {
                if (*i == id)
                {
                    m_destroyEvents.erase(i);
                    break;
                }
            }
            return;
        }
        if (IsExpired(id))
        {
            return;
        }
        Scheduler::Event event;
        event.impl = id.PeekEventImpl();
        event.key.m_ts = id.GetTs();
        event.key.m_context = id.GetContext();
        event.key.m_uid = id.GetUid();
        m_events->Remove(event);
        event.impl->Cancel();
        // whenever we remove an event from the event list, we have to unref it.
        event.impl->Unref();

        m_unscheduledEvents--;
    }

    void CudaELPSimulator::Cancel(const EventId& id)
    {
        if (!IsExpired(id))
        {
            id.PeekEventImpl()->Cancel();
        }
    }

    bool CudaELPSimulator::IsExpired(const EventId& id) const
    {
        if (id.GetUid() == EventId::UID::DESTROY)
        {
            if (id.PeekEventImpl() == nullptr || id.PeekEventImpl()->IsCancelled())
            {
                return true;
            }
            // destroy events.
            for (DestroyEvents::const_iterator i = m_destroyEvents.begin(); i != m_destroyEvents.end();
                i++)
            {
                if (*i == id)
                {
                    return false;
                }
            }
            return true;
        }
        if (id.PeekEventImpl() == nullptr || id.GetTs() < m_currentTs ||
            (id.GetTs() == m_currentTs && id.GetUid() <= m_currentUid) ||
            id.PeekEventImpl()->IsCancelled())
        {
            return true;
        }
        else
        {
            return false;
        }
    }

    Time CudaELPSimulator::GetMaximumSimulationTime() const
    {
        return TimeStep(0x7fffffffffffffffLL);
    }

    uint32_t CudaELPSimulator::GetContext() const
    {
        return m_currentContext;
    }

    uint64_t CudaELPSimulator::GetEventCount() const
    {
        return m_eventCount;
    }
}