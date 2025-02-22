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
        d_uid = 0;
        ELP_Init();
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

        // Free the allocated memory
        ELP_Cleanup();
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
        printf("Processing event\n");
        Scheduler::Event next = m_events->RemoveNext();

        PreEventHook(EventId(next.impl, next.key.m_ts, next.key.m_context, next.key.m_uid));

        NS_ASSERT(next.key.m_ts >= m_currentTs);
        m_unscheduledEvents--;
        m_eventCount++;
        printf("handle\n");
        NS_LOG_LOGIC("handle " << next.key.m_ts);
        m_currentTs = next.key.m_ts;
        m_currentContext = next.key.m_context;
        m_currentUid = next.key.m_uid;
        next.impl->Invoke();
        next.impl->Unref();

        printf("Event processed\n");

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

    __host__ void CudaELPSimulator::componentMethod() {
        // This method is called from the main ns-3 simulation thread.
        // It can be used to launch the CUDA kernel or perform other operations.
        // For example, you might launch the kernel with a specific block size and grid size.
        // PersistentEventKernel<<<1, 32>>>(d_eventCount, eventCounter, 100);
        elpComponent.mymethod();
    }

    __host__ void CudaELPSimulator::ELP_Init(){
        cudaStreamCreate(&streamK);
        cudaStreamCreate(&streamC);
        cudaCheckErrors("stream creation failed");
        // Allocate and initialize the stop flag on the device
        cudaMallocManaged(&d_stop, sizeof(int));
        cudaMallocManaged(&safe_ts, sizeof(double));
        cudaMemset(safe_ts, 1, sizeof(double));
        cudaCheckErrors("stop and safe_ts cudaMallocManaged failed");
        // Allocate and initialize the event queue on the UMA
        cudaMallocManaged(&h_safeEventQueue1, DEVICE_QUEUE_LENGTH * sizeof(DeviceEvent));
        cudaMallocManaged(&h_safeEventQueue2, DEVICE_QUEUE_LENGTH * sizeof(DeviceEvent));
        // cudaMallocManaged(&d_eventQueue, DEVICE_QUEUE_LENGTH * sizeof(DeviceEvent));
        cudaMallocManaged(&d_nextEventQueue1, DEVICE_QUEUE_LENGTH * sizeof(DeviceEvent));
        cudaMallocManaged(&d_nextEventQueue2, DEVICE_QUEUE_LENGTH * sizeof(DeviceEvent));
        // cudaMemset(d_eventQueue, 0, 100 * sizeof(DeviceEvent));
        cudaCheckErrors("queue cudaMallocManaged failed");
        cudaMallocManaged(&h_bufrdy1, sizeof(int));
        cudaMallocManaged(&h_bufrdy2, sizeof(int));
        cudaMallocManaged(&d_bufrdy1, sizeof(int));
        cudaMallocManaged(&d_bufrdy2, sizeof(int));
        cudaCheckErrors("ready flags cudaMallocManaged failed");
        
        cudaMemset((void*)h_bufrdy1, 0, sizeof(int));
        cudaMemset((void*)h_bufrdy2, 0, sizeof(int));
        cudaMemset((void*)d_bufrdy1, 0, sizeof(int));
        cudaMemset((void*)d_bufrdy2, 0, sizeof(int));
        cudaCheckErrors("ready flags cudaMemset failed");

        // Allocate and initialize the event counter on the device
        cudaMallocManaged(&eventCounter, sizeof(int));
        cudaCheckErrors("counter cudaMallocManaged failed");

        // Initialize the event buffer
        h_eventQueue = h_safeEventQueue1;
        d_eventQueue = d_nextEventQueue1;
        h_bufrdy = h_bufrdy1;
        d_bufrdy = d_bufrdy1;
    }

    __host__ void CudaELPSimulator::ELP_Cleanup(){
        // Free the allocated memory
        cudaFree(h_safeEventQueue1);
        cudaFree(h_safeEventQueue2);
        // cudaFree(d_eventQueue);
        cudaFree(d_nextEventQueue1);
        cudaFree(d_nextEventQueue2);
        cudaFree(eventCounter);
        cudaFree(safe_ts);
        cudaFree(d_stop);
        cudaCheckErrors("cleanup cudaFree failed");
        // Free the streams
        cudaStreamDestroy(streamK);
        cudaStreamDestroy(streamC);
        cudaCheckErrors("stream destroy failed");
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
        // cudaSim->insert(ev->impl, 0, 0, 2);
        ev->type = -1;
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
                // mark as processed
                ev->valid = false;
                break;
            case 1:
                ProcessType1(ev);
                ev->valid = false;
                break;
            case 2:
                ProcessType2(ev);
                // mark as processed
                ev->valid = false;
                break;
            default:
                // Handle unknown event type
                break;
        }

        // Post-event processing can be added here as well.
    }

    // A persistent kernel that polls the device queue and executes events when their time is reached.
    __global__ void PersistentEventKernel(DeviceEvent* h_safeEventQueue1, DeviceEvent* h_safeEventQueue2, 
                                        DeviceEvent* d_nextEventQueue1, DeviceEvent* d_nextEventQueue2, 
                                        volatile int *h_bufrdy1, volatile int *h_bufrdy2,
                                        volatile int *d_bufrdy1, volatile int *d_bufrdy2,
                                        int* d_eventCount, double* d_safe_ts, int* d_stop) {

        const int tid = threadIdx.x + blockIdx.x * blockDim.x;
        const int totalThreads = gridDim.x * blockDim.x;

        if(tid == 0) {
            *d_stop = false;
            *d_eventCount = 100;
        }

        DeviceEvent* eventQueue;
        volatile int* h_bufrdy;
        volatile int* d_bufrdy;
        bool pos = 0;

        __syncthreads();
        
        // Loop forever or until a termination condition is met.
        while (!*d_stop) {
            // Each thread polls for an event to process.
            int index = tid;

            eventQueue = (!pos) ? h_safeEventQueue1 : h_safeEventQueue2;
            h_bufrdy = (!pos) ? h_bufrdy1 : h_bufrdy2;
            d_bufrdy = (!pos) ? d_bufrdy1 : d_bufrdy2;
            
            // Poll the buffer ready flag to check if the buffer is ready for reading.
            if(!(*h_bufrdy) ){
                // check if the other buffer is ready
                pos = !pos;
                continue;
            }

            if (index < *d_eventCount && index < DEVICE_QUEUE_LENGTH) {
                DeviceEvent* ev = &eventQueue[index];
                
                // (*d_safe_ts)++;
                // Process the event based on its type.
                if(ev->valid){
                    printf("event count: %d\n", *d_eventCount);
                    printf("tid: %d\n", tid);
                    ProcessOneEvent(ev);
                }
                // Mark the event as processed (or remove it from the queue).
                // For simplicity, we assume the host will later clean up processed events.
                if(ev->ts < *d_safe_ts)
                    *d_safe_ts = ev->ts;
                
                index += totalThreads;
            }
            // else{
            //     cudaStreamWaitEvent(0, event);
            // }
            // check if the other buffer is ready
            pos = !pos;
            // Optionally, add a delay or yield to avoid busy waiting.
            if(tid == 0){
                // printf("pos: %d\n", pos);
                *h_bufrdy = 0;
                *d_bufrdy = 0;
            }
            __syncthreads();
        }
    }

    

    void CudaELPSimulator::test(void *obj){
        // printf("Current ts: %lu\n", m_currentTs);
        // cudaSim = this;
        // printf("This: %p\n", this);
        // printf("test: %d\n", m_test);

        // cudaEventCreate(&event);
        
        // ELP_Init();
        
        bool pos = 0;
        
        // Launch the persistent event processing kernel
        PersistentEventKernel<<<1, 32, 0, streamK>>>(h_safeEventQueue1, h_safeEventQueue2,  
                                                    d_nextEventQueue1, d_nextEventQueue2, 
                                                    h_bufrdy1, h_bufrdy2, 
                                                    d_bufrdy1, d_bufrdy2,
                                                    eventCounter, safe_ts, d_stop);
        printf("Kernel launched\n");
        cudaCheckErrors("kernel launch failed");

        bool simulationFinished = false;
        // int count = 0;

        while(!simulationFinished){
            h_eventQueue = (!pos) ? h_safeEventQueue1 : h_safeEventQueue2;
            h_bufrdy = (!pos) ? h_bufrdy1 : h_bufrdy2;
            d_bufrdy = (!pos) ? d_bufrdy1 : d_bufrdy2;

            // insert event
            DeviceEvent ev;
            ev.type = 1;
            ev.ts = 0.0;
            ev.context = 0;
            ev.uid = 0;
            ev.impl = obj;
            ev.valid = true;

            printf("Inserting event\n");
            // wait for the buffer to be ready(still processing by the kernel)
            while(*h_bufrdy);

            cudaMemcpyAsync(&h_eventQueue[3], &ev, sizeof(DeviceEvent), cudaMemcpyHostToDevice, streamC);
            cudaCheckErrors("queue cudaMemcpyAsync failed");
            
            ev.type = 2;
            cudaMemcpyAsync(&h_eventQueue[1], &ev, sizeof(DeviceEvent), cudaMemcpyHostToDevice, streamC);
            cudaCheckErrors("queue cudaMemcpyAsync failed");
            /****************************************************************************** */
            // if this line is faster than the memcpy, the kernel will not see the new event
            /****************************************************************************** */
            cudaStreamSynchronize(streamC);
            *h_bufrdy = 1;

            printf("Events inserted\n");

            pos = !pos;
            // cudaEventRecord(event, stream);
            // insert(d_eventQueue, ev.impl, eventCounter, 100, ev.ts, ev.context, ev.uid, ev.type);
            // if(count++ == 2)
            simulationFinished = true;
        }
        
        sleep(1);

        int stop = 1;
        cudaMemcpyAsync(d_stop, &stop, sizeof(int), cudaMemcpyHostToDevice, streamC);
        cudaCheckErrors("stop cudaMemcpyAsync failed");

        // Wait for the kernel to finish
        cudaStreamSynchronize(streamK);
        printf("Kernel finished\n");
        cudaStreamSynchronize(streamC);
        printf("Stream finished\n");
        // printf("safe_ts: %f\n", *safe_ts);
        printf("next event: %d\n", d_nextEventQueue1[0].type);
    }

    __host__ __device__ void CudaELPSimulator::print_test() const{
        printf("cuda_sim: %p\n", cudaSim);
        printf("print_test: %p\n", this);
        printf("print_test: %d\n", m_test);
    }

    __device__ void CudaELPSimulator::deviceMethod(void *obj, int func_id){
        printf("Hello from deviceMethod\n");
        ((CudaP2PChannel*)obj)->test();
    }

    __host__ void CudaELPSimulator::h_insert(void* impl, double delay, int context, int type, int nodeID){
        while(*h_bufrdy);
        h_eventQueue[nodeID] = DeviceEvent{impl, delay, context, 0, type, true};
        *h_bufrdy = 1;
    }

    __device__ void CudaELPSimulator::d_insert(void* impl, double delay, int context, int type, void *payload){
        int tid = threadIdx.x + blockIdx.x * blockDim.x;
        printf("insert: %d\n", m_test);
        // we can't access variables of class object if member function is called by non-member __device__ function?
        // printf("tid: %d\n", tid);                    // Debugging
        d_eventQueue[tid] = DeviceEvent{impl, delay, context, 0, type, true, payload};
    }

    bool CudaELPSimulator::is_safe(uint64_t ts){
        // return ts < *safe_ts;
        return true;
    }

    void CudaELPSimulator::ELP_ProcessOneEvent(){
        Scheduler::Event next = m_events->RemoveNext();
        m_unscheduledEvents--;
        m_eventCount++;
        // change the current event queue if condition is met
        // h_insert(next.impl, next.key.m_ts, next.key.m_context, d_uid++, 0);
    }

    void CudaELPSimulator::ELP_Run(){
        NS_LOG_FUNCTION(this);
        // Set the current threadId as the main threadId
        m_mainThreadId = std::this_thread::get_id();
        ProcessEventsWithContext();
        m_stop = false;
        // Launch the persistent event processing kernel
        PersistentEventKernel<<<1, 32, 0, streamK>>>(h_safeEventQueue1, h_safeEventQueue2,  
                                                    d_nextEventQueue1, d_nextEventQueue2, 
                                                    h_bufrdy1, h_bufrdy2, 
                                                    d_bufrdy1, d_bufrdy2,
                                                    eventCounter, safe_ts, d_stop);
        printf("Kernel launched\n");
        cudaCheckErrors("kernel launch failed");

        while (!m_events->IsEmpty() && !m_stop){
            Scheduler::Event next = m_events->PeekNext();
            printf("Next event: %lu\n", next.key.m_ts);

            while(!is_safe(next.key.m_ts)){
                // synchronize with the device
                // cudaStreamSynchronize(streamC);
                // swap the event queues to insert the next event generated by the kernel
            }

            if(__glibc_likely(next.key.m_uid == EventId::UID::RESERVED)){
                ELP_ProcessOneEvent();
                // m_events->RemoveNext();
                printf("CUDA event\n");
            }
            else
                ProcessOneEvent();
        }

        // If the simulator stopped naturally by lack of events, make a
        // consistency test to check that we didn't lose any events along the way.
        printf("m_events->IsEmpty(): %d\n", m_events->IsEmpty());
        printf("m_unscheduledEvents: %d\n", m_unscheduledEvents);
        NS_ASSERT(!m_events->IsEmpty() || m_unscheduledEvents == 0);

        int stop = 1;
        cudaMemcpyAsync(d_stop, &stop, sizeof(int), cudaMemcpyHostToDevice, streamC);
        cudaCheckErrors("stop cudaMemcpyAsync failed");

        // Wait for the kernel to finish
        cudaStreamSynchronize(streamK);
        printf("Kernel finished\n");
        cudaStreamSynchronize(streamC);
        printf("Stream finished\n");
    }

    // take a event from the device event queue and insert it into the host queue
    __host__ void CudaELPSimulator::ELP_Schedule(const Time &delay, void *obj, int type, void *payload){
        NS_LOG_FUNCTION(this << delay.GetTimeStep());
        NS_ASSERT_MSG(m_mainThreadId == std::this_thread::get_id(),
                    "Simulator::Schedule Thread-unsafe invocation!");

        NS_ASSERT_MSG(delay.IsPositive(), "CudaELPSimulator::Schedule(): Negative delay");
        Time tAbsolute = delay + TimeStep(m_currentTs);

        Scheduler::Event ev;
        HostEvent h_ev;
        h_ev.obj = obj;
        h_ev.type = type;
        h_ev.payload = nullptr;
        // make ev.impl point to the host event(which carry the information of the device event)
        // Not a good way to do this, can be modified in the future(best way is probably to use member function pointer like in ns3)
        ev.impl = (EventImpl*)&h_ev;
        ev.key.m_ts = (uint64_t)tAbsolute.GetTimeStep();
        ev.key.m_context = GetContext();
        // mark the event as CUDA event
        ev.key.m_uid = EventId::UID::RESERVED;
        // m_uid++;
        m_unscheduledEvents++;
        m_events->Insert(ev);
        // return EventId(event, ev.key.m_ts, ev.key.m_context, ev.key.m_uid);
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

        // printf("This Run: %p\n", this);
        // printf("Run test: %d\n", m_test);

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