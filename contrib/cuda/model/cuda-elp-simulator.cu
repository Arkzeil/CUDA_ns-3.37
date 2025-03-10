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
#include "ns3/cuda-net-device.h"

#include <unistd.h>

#include <cmath>

namespace ns3 {
    NS_LOG_COMPONENT_DEFINE("CudaELPSimulator");
    NS_OBJECT_ENSURE_REGISTERED(CudaELPSimulator);

    // __managed__ cudaEvent_t event;
    int eventCounter = 0;

    LookaheadTable<uint64_t> lookaheadTable;
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
        h_insertIndex = 0;
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
        printf("CPU current ts: %lu\n", m_currentTs);

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
        cudaMallocManaged(&safe_ts, sizeof(uint64_t));
        cudaMallocManaged(&d_safe_ts1, sizeof(uint64_t));
        cudaMallocManaged(&d_safe_ts2, sizeof(uint64_t));
        *safe_ts = UINT64_MAX;
        *d_safe_ts1 = UINT64_MAX;
        *d_safe_ts2 = UINT64_MAX;
        // cur_buffer_safe_ts = UINT64_MAX;
        cudaCheckErrors("stop and safe_ts cudaMallocManaged failed");
        // Allocate and initialize the event queue on the UMA
        cudaMallocManaged(&h_safeEventQueue1, DEVICE_QUEUE_LENGTH * sizeof(DeviceEvent));
        cudaMallocManaged(&h_safeEventQueue2, DEVICE_QUEUE_LENGTH * sizeof(DeviceEvent));
        // cudaMallocManaged(&d_eventQueue, DEVICE_QUEUE_LENGTH * sizeof(DeviceEvent));
        cudaMallocManaged(&d_nextEventQueue1, DEVICE_QUEUE_LENGTH * sizeof(DeviceEvent) * 3);
        cudaMallocManaged(&d_nextEventQueue2, DEVICE_QUEUE_LENGTH * sizeof(DeviceEvent) * 3);
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
        cudaMemset((void*)d_stop, 0, sizeof(int));
        cudaCheckErrors("ready flags cudaMemset failed");

        // Initialize the event buffer
        h_curHostBuf = h_safeEventQueue1;
        d_curHostBuf = h_safeEventQueue1;
        h_curDevBuf = d_nextEventQueue1;
        d_curDevBuf = d_nextEventQueue1;
        h_curHostBufRdy = h_bufrdy1;
        d_curHostBufRdy = h_bufrdy1;
        h_curDevBufRdy = d_bufrdy1;
        d_curDevBufRdy = d_bufrdy1;

        h_safe_ts = d_safe_ts1;
    }

    __host__ void CudaELPSimulator::ELP_Cleanup(){
        // Free the allocated memory
        cudaFree(h_safeEventQueue1);
        cudaFree(h_safeEventQueue2);
        // cudaFree(d_eventQueue);
        cudaFree(d_nextEventQueue1);
        cudaFree(d_nextEventQueue2);
        cudaFree((void*)h_bufrdy1);
        cudaFree((void*)h_bufrdy2);
        cudaFree((void*)d_bufrdy1);
        cudaFree((void*)d_bufrdy2);
        cudaFree(safe_ts);
        cudaFree(d_safe_ts1);
        cudaFree(d_safe_ts2);
        cudaFree((void*)d_stop);
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
        ((CudaUdpClient*)(ev->impl))->ELP_Send();
    }
    // Device functions to process different event types
    __device__ void ProcessType1(DeviceEvent* ev) {
        // Insert logic analogous to what your C++ ns-3 event might do
        // For example, a UDP send operation or a simulated network event.
        printf("Processing Type 1 event\n");
        ((CudaNetDevice*)(ev->impl))->D_TransmitComplete();
        // cudaSim->insert(ev->impl, 0, 0, 2);
        ev->type = -1;
    }

    __device__ void ProcessType2(DeviceEvent* ev) {
        // Different event processing logic
        printf("Processing Type 2 event\n");
        ((CudaNetDevice*)(ev->impl))->d_Receive((CudaPacket*)(ev->payload));
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
                printf("Unknown event type: %d\n", ev->type);
                break;
        }

        // Post-event processing can be added here as well.
    }

    // A persistent kernel that polls the device queue and executes events when their time is reached.
    __global__ void PersistentEventKernel(CudaELPSimulator *sim, 
                                        DeviceEvent* h_safeEventQueue1, DeviceEvent* h_safeEventQueue2, 
                                        DeviceEvent* d_nextEventQueue1, DeviceEvent* d_nextEventQueue2, 
                                        volatile int *h_bufrdy1, volatile int *h_bufrdy2,
                                        volatile int *d_bufrdy1, volatile int *d_bufrdy2,
                                        uint64_t* d_safe_ts1, uint64_t* d_safe_ts2, 
                                        volatile int* d_stop) {

        const int tid = threadIdx.x + blockIdx.x * blockDim.x;
        const int totalThreads = gridDim.x * blockDim.x;
        const int localThreadId = threadIdx.x;

        __shared__ uint64_t blockMin;

        // kernel initialization
        if(tid == 0) {
            *d_stop = false;
            // *d_safe_ts1 = UINT64_MAX;
            // *d_safe_ts2 = UINT64_MAX;
            // *d_eventCount = 100;
        }

        DeviceEvent* eventQueue;
        volatile int* h_bufrdy;
        volatile int* d_bufrdy;
        uint64_t* d_safe_ts;
        bool pos = 0;

        __syncthreads();
        
        // Loop forever or until a termination condition is met.
        while (!*d_stop) {
            // Each thread polls for an event to process.
            int index = tid;

            eventQueue = (!pos) ? h_safeEventQueue1 : h_safeEventQueue2;
            h_bufrdy = (!pos) ? h_bufrdy1 : h_bufrdy2;
            d_bufrdy = (!pos) ? d_bufrdy1 : d_bufrdy2;
            d_safe_ts = (!pos) ? d_safe_ts1 : d_safe_ts2;

            uint64_t localMin = *d_safe_ts; // Initialize to maximum double
            
            // check if kernel need to change next-event buffer to prevent deadlock 
            // if(tid == 0){
            //     if(*h_idle){
            //         *h_idle = 0;
            //     }
            // }
            // add syncthread?

            // Poll the buffer ready flag to check if the buffer is ready for reading.
            if(!(*h_bufrdy) ){
                // check if the other buffer is ready
                pos = !pos;
                continue;
            }

            if (index < DEVICE_QUEUE_LENGTH) {
                DeviceEvent* ev = &eventQueue[index];
                
                // (*d_safe_ts)++;
                // Process the event based on its type.
                if(ev->valid){
                    printf("tid: %d\n", tid);
                    ProcessOneEvent(ev);
                }
                // Mark the event as processed (or remove it from the queue).
                // if(ev->ts < *d_safe_ts)
                //     *d_safe_ts = ev->ts;
                
                index += totalThreads;
            }

            // find the minimum ts among all threads

            // Block-level reduction
            // if (localThreadId == 0) {
            //     blockMin = localMin;
            // }
            // __syncthreads();

            // for (int offset = blockDim.x / 2; offset > 0; offset /= 2) {
            //     if (localThreadId < offset) {
            //         if (blockMin > blockMin + offset) {
            //             blockMin = blockMin + offset;
            //         }
            //     }
            //     __syncthreads();
            // }

            // // Update global minimum (d_safe_ts)
            // if (localThreadId == 0) {
            //     atomicMin(reinterpret_cast<unsigned long long*>(d_safe_ts), blockMin);
            // }

            // check if the other buffer is ready
            pos = !pos;

            __syncthreads();        // wait for all threads of this block to finish
            __threadfence();        // ensure that all threads have finished before continuing
            // mark host buffer as consumed, and device buffer as ready for CPU to insert new events
            if(tid == 0){
                // if thest two lines are after ready flag and safe_ts update, new events in next-event buffer might not be able to inserted
                // into the event queue on time, and CPU will fetch next event, which might be CPU event, to execute
                // (it will be considered as safe, as safe_ts is updated)
                sim->ChangeDevQueue();
                __threadfence_system();
                // printf("pos: %d\n", pos);
                *h_bufrdy = 0;
                // *d_bufrdy = 0;
                // all events in current queue are processed 
                *d_safe_ts = UINT64_MAX;
            }
        }
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

    __host__ int CudaELPSimulator::h_insert(void* impl, uint64_t ts, int context, int type, uint64_t lookahead, void *payload){
        // the queue is still used by the kernel
        while(*h_curHostBufRdy);

        h_curHostBuf[h_insertIndex++] = DeviceEvent{impl, ts, context, 0, type, lookahead, true, payload, nullptr};
        // lookahead might be UINT64_MAX, so we need to check if it is valid
        if(lookahead != UINT64_MAX && ts + lookahead < *safe_ts)
            *safe_ts = ts + lookahead;
        if(lookahead != UINT64_MAX && ts + lookahead < *h_safe_ts)
            *h_safe_ts = ts + lookahead;
        printf("-------------------h_insert safe_ts: %lu----------------------\n", *safe_ts);
        printf("-----------------h_insert event counter: %d-------------------\n", ++eventCounter);
        // *h_curHostBufRdy = 1;
        // ChangeHostQueue();
        return 0;
    }

    __device__ int CudaELPSimulator::d_insert(void* impl, uint64_t delay, int context, int type, uint64_t lookahead, void *payload){
        int tid = threadIdx.x + blockIdx.x * blockDim.x;
        // we can't access variables of class object if member function is called by non-member __device__ function?
        // printf("tid: %d\n", tid);                    // Debugging
        tid *= 3;
        int index = tid;
        // the queue is still used by the host
        while(*d_curDevBufRdy);
        
        // printf("insert: %d\n", m_test);
        // printf("insert tid: %d\n", tid);
        // printf("lookahead: %lf\n", lookahead);
        
        // at least one evnet is inserted in this index 
        if(d_curDevBuf[tid].valid){
            // printf("--------------%p------------------\n", &d_curDevBuf[tid]);
            // DeviceEvent *cur = d_curDevBuf[tid].next;
            DeviceEvent *cur = &d_curDevBuf[++index];
            // cur = cur->next;
            while(cur->valid){
                cur = &d_curDevBuf[++index];
                if(index >= tid + 3){
                    printf("------------------Device queue is full-------------------\n");
                    return -1;
                }
            }

            cur->impl = impl;
            cur->ts = delay;
            cur->context = context;
            cur->uid = 3;
            cur->type = type;
            cur->lookahead = lookahead;
            cur->valid = true;
            cur->payload = payload;
            cur->next = nullptr;
            // printf("--------------type: %d------------------\n", cur->type);
            // find the non valid event or nullptr in the list
            // while(cur->next != nullptr && cur->next->valid){
            //     cur = cur->next;
            //     printf("--------------%p------------------\n", cur);
            // }

            // if(cur->next != nullptr && !(cur->next->valid)){
            //     cur->next->impl = impl;
            //     cur->next->ts = delay;
            //     cur->next->context = context;
            //     cur->next->uid = 3;
            //     cur->next->type = type;
            //     cur->next->lookahead = lookahead;
            //     cur->next->valid = true;
            //     cur->next->payload = payload;
            //     cur->next->next = nullptr;    
            // }
            // else{
            //     DeviceEvent *newEvent;
            //     cudaMalloc(&newEvent, sizeof(DeviceEvent));
                
            //     // Initialize the new event
            //     newEvent->impl = impl;
            //     newEvent->ts = delay;
            //     newEvent->context = context;
            //     newEvent->uid = 3;
            //     newEvent->type = type;
            //     newEvent->lookahead = lookahead;
            //     newEvent->valid = true;
            //     newEvent->payload = payload;
            //     newEvent->next = nullptr;

            //     // Insert the new event at the end of the list
            //     cur->next = newEvent;

            //     printf("--------------%p------------------\n", cur->next);
            //     printf("--------------type: %d------------------\n", cur->next->type);
            // }
        }
        else
            d_curDevBuf[tid] = DeviceEvent{impl, delay, context, 3, type, lookahead, true, payload, nullptr};
        // *d_curDevBufRdy = 1;
        // how can we change the queue if index are determine by the kernel?
        // ChangeDevQueue();
        return 0;
    }

    bool CudaELPSimulator::is_safe(Scheduler::Event *ev){
        // safe
        uint64_t ts = ev->key.m_ts;
        uint64_t lookahead = (ev->key.m_uid == EventId::UID::RESERVED) ? ((HostEvent*)(ev->impl))->lookahead : UINT64_MAX;
        printf("ts: %lu\n", ts);
        printf("lookahead: %lu\n", lookahead);

        if(ts < *safe_ts){
            // cur_buffer_safe_ts is specific to the current buffer, so it should be determined independently
            // but it still can only be updated if current event is safe, because if current event is not safe
            // the value it store might be invalid(as next time this function is called, it might not be same event)
            // if(lookahead != UINT64_MAX && ts + lookahead < cur_buffer_safe_ts)
            //     cur_buffer_safe_ts = ts + lookahead;
            // what happen if ts + lookahead overflow?
            // add a condition to prevent it
            if(lookahead != UINT64_MAX && ts + lookahead < *safe_ts){
                *safe_ts = ts + lookahead;
            }
            return true;
        }
        return false;
        // return true;
    }

    void CudaELPSimulator::ELP_ProcessOneEvent(){
        Scheduler::Event next = m_events->RemoveNext();
        m_unscheduledEvents--;
        m_eventCount++;

        NS_ASSERT(next.key.m_ts >= m_currentTs);
        m_currentTs = next.key.m_ts;
        m_currentContext = next.key.m_context;

        // printf("current ts: %lu\n", m_currentTs);

        HostEvent* h_ev = (HostEvent*)next.impl;
        h_insert(h_ev->obj, next.key.m_ts, next.key.m_context, h_ev->type, h_ev->lookahead, h_ev->payload);
        printf("-----------------h_ev type: %d-----------------\n", h_ev->type);
        // printf("h_ev obj: %p\n", h_ev->obj);
        // printf("h_ev address: %p\n", h_ev);
        delete h_ev;
        // change the current event queue if condition is met
        if(h_insertIndex == DEVICE_QUEUE_LENGTH){
            *h_curHostBufRdy = 1;
            // printf("Host buffer ready: %p\n", h_curHostBufRdy);
            ChangeHostQueue();
            h_insertIndex = 0;
            // cur_buffer_safe_ts = UINT64_MAX;
        }
    }

    __device__ void CudaELPSimulator::ChangeDevQueue(){
        printf("Changing device queue\n");
        *d_curDevBufRdy = 1;
        d_curDevBuf = (d_curDevBuf == d_nextEventQueue2) ? d_nextEventQueue1 : d_nextEventQueue2;
        d_curDevBufRdy = (d_curDevBuf == d_nextEventQueue2) ? d_bufrdy2 : d_bufrdy1;
    }

    __host__ void CudaELPSimulator::ChangeHostQueue(){
        h_curHostBuf = (h_curHostBuf == h_safeEventQueue2) ? h_safeEventQueue1 : h_safeEventQueue2;
        // as h_curHostBuf already inverted, the corresponding ready flag should also be changed based on the new buffer
        h_curHostBufRdy = (h_curHostBuf == h_safeEventQueue2) ? h_bufrdy2 : h_bufrdy1;
        // the safe_ts should also be changed based on the new buffer
        h_safe_ts = (h_curHostBuf == h_safeEventQueue2) ? d_safe_ts2 : d_safe_ts1;
    }

    __host__ void CudaELPSimulator::ELP_ScheduleDevEvent(){
        bool pos = 0;
        // DeviceEvent* eventQueue =2002000000 (!pos) ? d_nextEventQueue1 : d_nextEventQueue2;
        // volatile int* h_bufrdy = (!pos) ? h_bufrdy1 : h_bufrdy2;
        // volatile int* d_bufrdy = (!pos) ? d_bufrdy1 : d_bufrdy2;
        // the queue is still used by the kernel
        if(*d_bufrdy1 == 0 && *d_bufrdy2 == 0)
            return;
        // what if both are ready?
        h_curDevBufRdy = (*d_bufrdy1 == 1) ? d_bufrdy1 : d_bufrdy2;
        h_curDevBuf = (*d_bufrdy1 == 1) ? d_nextEventQueue1 : d_nextEventQueue2;
        // while(!(*h_curDevBufRdy));
        // printf("Inserting event\n");
        // DeviceEvent *next;
        DeviceEvent *cur;

        // h_next = (DeviceEvent*)malloc(sizeof(DeviceEvent));
        // insert valid event(generated by device)
        for(int i = 0; i < DEVICE_QUEUE_LENGTH * 3; i++){
            // DeviceEvent *ev = (DeviceEvent*)malloc(sizeof(DeviceEvent));
            // cudaMemcpy(ev, &h_curDevBuf[i], sizeof(DeviceEvent), cudaMemcpyDeviceToHost);
            DeviceEvent *ev = &h_curDevBuf[i];
            if(__glibc_unlikely(ev->valid)){
                // printf("true, ts: %lf\n", ev->ts);
                ELP_Schedule(ev->context, Time(NanoSeconds(ev->ts)), ev->impl, ev->type, ev->lookahead, ev->payload);
                ev->valid = false;
                
                for(int j = 0; j < 3; j++){
                    cur = &h_curDevBuf[i + j];
                    if(__glibc_unlikely(cur->valid)){
                        // printf("true, ts: %lf\n", ev->ts);
                        ELP_Schedule(cur->context, Time(NanoSeconds(cur->ts)), cur->impl, cur->type, cur->lookahead, cur->payload);
                        cur->valid = false;
                    }
                }
                // while(next != nullptr){
                //     cudaPointerAttributes attr;
                //     cudaError_t err = cudaPointerGetAttributes(&attr, next);
                //     printf("attr: %d\n", attr.type);
                //     if(err != cudaSuccess){
                //         printf("Error: %s\n", cudaGetErrorString(err));
                //     }
                    
                //     cudaMemcpy(h_next, next, sizeof(DeviceEvent), cudaMemcpyDeviceToHost);
                //     cudaCheckErrors("D2H cudaMemcpy failed");
                //     printf("-----------------schedule dev type: %d-------------------\n", h_next->type);

                //     if(__glibc_unlikely(h_next->valid)){
                //         // printf("true, ts: %lf\n", ev->ts);
                //         ELP_Schedule(h_next->context, Time(NanoSeconds(h_next->ts)), h_next->impl, h_next->type, h_next->lookahead, h_next->payload);
                //         h_next->valid = false;
                //     }
                //     // mark it as invalid
                //     cudaMemcpy(next, h_next, sizeof(DeviceEvent), cudaMemcpyHostToDevice);
                //     cudaCheckErrors("H2D cudaMemcpy failed");
                    
                //     next = h_next->next;
                // }
            }
        }
        // this line might be slower than kernel
        *h_curDevBufRdy = 0;

        h_curDevBuf = (h_curDevBuf == d_nextEventQueue1) ? d_nextEventQueue2 : d_nextEventQueue1;
        h_curDevBufRdy = (h_curDevBuf == d_nextEventQueue1) ? d_bufrdy1 : d_bufrdy2;

        if(*h_curDevBufRdy == 1){
            // insert valid event(generated by device)
            for(int i = 0; i < DEVICE_QUEUE_LENGTH; i++){
                DeviceEvent *ev = &h_curDevBuf[i];
                if(__glibc_unlikely(ev->valid)){
                    // printf("true, ts: %lf\n", ev->ts);
                    ELP_Schedule(ev->context, Time(NanoSeconds(ev->ts)), ev->impl, ev->type, ev->lookahead, ev->payload);
                    ev->valid = false;
                    
                    for(int j = 0; j < 3; j++){
                        cur = &h_curDevBuf[i + j];
                        if(__glibc_unlikely(cur->valid)){
                            // printf("true, ts: %lf\n", ev->ts);
                            ELP_Schedule(cur->context, Time(NanoSeconds(cur->ts)), cur->impl, cur->type, cur->lookahead, cur->payload);
                            cur->valid = false;
                        }
                    }
                    // while(next != nullptr){
                    //     cudaPointerAttributes attr;
                    //     cudaError_t err = cudaPointerGetAttributes(&attr, next);
                    //     printf("attr: %d\n", attr.type);
                    //     if(err != cudaSuccess){
                    //         printf("Error: %s\n", cudaGetErrorString(err));
                    //     }
                        
                    //     cudaMemcpy(h_next, next, sizeof(DeviceEvent), cudaMemcpyDeviceToHost);
                    //     cudaCheckErrors("D2H cudaMemcpy failed");
                    //     printf("-----------------schedule dev type: %d-------------------\n", h_next->type);

                    //     if(__glibc_unlikely(h_next->valid)){
                    //         // printf("true, ts: %lf\n", ev->ts);
                    //         ELP_Schedule(h_next->context, Time(NanoSeconds(h_next->ts)), h_next->impl, h_next->type, h_next->lookahead, h_next->payload);
                    //         h_next->valid = false;
                    //     }
                    //     // mark it as invalid
                    //     cudaMemcpy(next, h_next, sizeof(DeviceEvent), cudaMemcpyHostToDevice);
                    //     cudaCheckErrors("H2D cudaMemcpy failed");
                        
                    //     next = h_next->next;
                    // }
                }
            }
            *h_curDevBufRdy = 0;
        }
    }

    void CudaELPSimulator::ELP_Run(){
        NS_LOG_FUNCTION(this);
        // Set the current threadId as the main threadId
        m_mainThreadId = std::this_thread::get_id();
        ProcessEventsWithContext();
        m_stop = false;
        volatile uint64_t lookahead;
        volatile uint64_t safe_ts1;
        volatile uint64_t safe_ts2;
        // Launch the persistent event processing kernel
        PersistentEventKernel<<<1, 32, 0, streamK>>>(this, 
                                                    h_safeEventQueue1, h_safeEventQueue2,  
                                                    d_nextEventQueue1, d_nextEventQueue2, 
                                                    h_bufrdy1, h_bufrdy2, 
                                                    d_bufrdy1, d_bufrdy2,
                                                    d_safe_ts1, d_safe_ts2, 
                                                    d_stop);
        printf("Kernel launched\n");
        cudaCheckErrors("kernel launch failed");

        while (!m_events->IsEmpty() && !m_stop){
            // check if there's any event generated by the device. Insert into queue if there's one
            ELP_ScheduleDevEvent();

            Scheduler::Event next = m_events->PeekNext();
            // printf("Next event: %lu\n", next.key.m_ts);

            if(!is_safe(&next)){
                uint64_t old = *safe_ts;
                // synchronize with the device safe_ts
                // should I use async?
                cudaMemcpyAsync((void*)&safe_ts1, d_safe_ts1, sizeof(uint64_t), cudaMemcpyDeviceToHost, streamC);
                cudaMemcpyAsync((void*)&safe_ts2, d_safe_ts2, sizeof(uint64_t), cudaMemcpyDeviceToHost, streamC);
                cudaStreamSynchronize(streamC);
                cudaCheckErrors("safe_ts cudaMemcpyAsync failed");
                // get the smaller buffer time stamp of 2 buffers, but larger than host safe_ts as the new safe_ts
                // to ensure that the scenario that one buffer is empty but kernel is executing another buffer
                // will there be a race condition between host and kernel?
                // so we just check those with the buffer ready flag?
                // if(safe_ts1 > *safe_ts || safe_ts2 > *safe_ts)
                //     *safe_ts = (safe_ts1 < safe_ts2) ? safe_ts1 : safe_ts2;
                
                
                if(h_curHostBuf == h_safeEventQueue1){
                    // check 1: check if the safe_ts of another buffer which is execuing by GPU is larger than the current safe_ts
                    // if so, we should use it as the new safe_ts
                    if(safe_ts2 > *safe_ts)
                        *safe_ts = safe_ts2;
                    // check 2: if the safe_ts of current buffer is smaller, we should use it as it stands for the smallest ts of events 
                    // to be processed in the buffer
                    if(safe_ts1 < *safe_ts)
                        *safe_ts = safe_ts1;
                    printf("safe ts: %lu\n", *safe_ts);
                }
                else{
                    // check 1: check if the safe_ts of another buffer which is execuing by GPU is larger than the current safe_ts
                    // if so, we should use it as the new safe_ts
                    if(safe_ts1 > *safe_ts)
                        *safe_ts = safe_ts1;
                    // check 2: if the safe_ts of current buffer is smaller, we should use it as it stands for the smallest ts of events 
                    // to be processed in the buffer
                    if(safe_ts2 < *safe_ts)
                        *safe_ts = safe_ts2;
                    printf("safe ts: %lu\n", *safe_ts);
                }

                if(old == *safe_ts){
                    // if the safe_ts is not updated, it probably means that the safe-event buffer condition is not met
                    // thus CPU still holding the safe-event buffer but kernel is idle 
                    // this would potentially lead to deadlock(if condition of changing buffer is not met)
                    // so we change safe-event buffer to make kernel see the new events
                    *h_curHostBufRdy = 1;
                    // printf("Host buffer ready: %p\n", h_curHostBufRdy);
                    ChangeHostQueue();
                    h_insertIndex = 0;
                }
                
                // if(*safe_ts > cur_buffer_safe_ts)
                //     *safe_ts = cur_buffer_safe_ts;
                // if(h_bufrdy1 == 0)
                //     if(safe_ts1 > *safe_ts)
                //         *safe_ts = safe_ts1;
                // if(h_bufrdy2 == 0)
                //     if(safe_ts2 > *safe_ts)
                //         *safe_ts = safe_ts2;
                
                continue;
                // swap the event queues to insert the next event generated by the kernel
            }
            // GPU event, insert into safe event queue
            if(__glibc_likely(next.key.m_uid == EventId::UID::RESERVED)){
                ELP_ProcessOneEvent();
                // m_events->RemoveNext();
                printf("CUDA event, safe ts: %lu\n", *safe_ts);
                // sleep(1);
            }
            // Host event, process it on CPU directly
            else{
                printf("Host event, safe ts: %lu\n", *safe_ts);
                ProcessOneEvent();
            }
        }

        // If the simulator stopped naturally by lack of events, make a
        // consistency test to check that we didn't lose any events along the way.
        // printf("m_events->IsEmpty(): %d\n", m_events->IsEmpty());
        // printf("m_unscheduledEvents: %d\n", m_unscheduledEvents);
        NS_ASSERT(!m_events->IsEmpty() || m_unscheduledEvents == 0);
        // need some kind of synchronization here otherwise the kernel will not see the new event
        sleep(1);
        int stop = 1;
        cudaMemcpyAsync((void*)d_stop, &stop, sizeof(int), cudaMemcpyHostToDevice, streamC);
        cudaCheckErrors("stop cudaMemcpyAsync failed");

        // Wait for the kernel to finish
        cudaStreamSynchronize(streamK);
        printf("Kernel finished\n");
        cudaStreamSynchronize(streamC);
        printf("Stream finished\n");
    }

    // take a event from the device event queue and insert it into the host queue
    __host__ void CudaELPSimulator::ELP_Schedule(uint32_t context, const Time &delay, void *obj, int type, uint64_t lookahead, void *payload){
        NS_LOG_FUNCTION(this << delay.GetTimeStep());
        NS_ASSERT_MSG(m_mainThreadId == std::this_thread::get_id(),
                    "Simulator::Schedule Thread-unsafe invocation!");

        NS_ASSERT_MSG(delay.IsPositive(), "CudaELPSimulator::Schedule(): Negative delay");
        Time tAbsolute = delay + TimeStep(m_currentTs);

        Scheduler::Event ev;
        HostEvent *h_ev;
        // cudaMallocManaged(&h_ev, sizeof(HostEvent));
        h_ev = new HostEvent();
        // printf("h_ev address: %p\n", h_ev);
        h_ev->obj = obj;
        h_ev->type = type;
        h_ev->lookahead = lookahead;
        h_ev->payload = payload;
        // printf("lookahead: %lf\n", lookahead);
        // printf("-----------------h_ev type: %d-------------------\n", h_ev->type);

        // make ev.impl point to the host event(which carry the information of the device event)
        // Not a good way to do this, can be modified in the future(best way is probably to use member function pointer like in ns3,
        // but I am not sure if it's achievable in CUDA and unified memory)
        ev.impl = (EventImpl*)h_ev;
        ev.key.m_ts = (uint64_t)tAbsolute.GetTimeStep();
        ev.key.m_context = context;
        // mark the event as CUDA event
        ev.key.m_uid = EventId::UID::RESERVED;
        // m_uid++;
        m_unscheduledEvents++;
        printf("ts: %lu, context: %d\n", ev.key.m_ts, ev.key.m_context);
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