#ifndef CUDA_ELP_SIMULATOR_H
#define CUDA_ELP_SIMULATOR_H

#include "ns3/event-impl.h"
#include "ns3/ptr.h"
#include "ns3/scheduler.h"
#include "ns3/simulator-impl.h"
#include "helper.h"

#include <list>
#include <mutex>
#include <thread>
#include <cuda_runtime.h>

#define DEVICE_QUEUE_LENGTH 2048

namespace ns3
{
    // Forward
    class Scheduler;

    // A simplified device-side event structure
    struct DeviceEvent {
        void *impl;   // pointer to the event implementation
        double ts;    // event timestamp, assuming to be second (so using double to store floating point)
        int context;  // event context
        uint32_t uid;      // unique id
        int type;     // event type identifier
        bool valid;  // a flag to indicate if the event is valid
        void *payload; // event-specific payload(usually a pointer to a packet)
        // Add any additional event-specific payload here.
        // For example, a union of data for different event types.
    };

    struct HostEvent{
        void *obj;
        int type;
        void *payload;
    };

    class CudaELPComponent {
        public:
            void mymethod();
            // ... other methods
    };

    class CudaELPSimulator : public SimulatorImpl, public Managed{
        public:
            static TypeId GetTypeId();

            CudaELPSimulator();
            ~CudaELPSimulator() override;

            void Destroy() override;
            bool IsFinished() const override;
            void Stop() override;
            void Stop(const Time &delay) override;
            EventId Schedule(const Time &delay, EventImpl *event) override;
            void ScheduleWithContext(uint32_t context, const Time &delay, EventImpl *event) override;
            EventId ScheduleNow(EventImpl *event) override;
            EventId ScheduleDestroy(EventImpl *event) override;
            void Remove(const EventId &id) override;
            void Cancel(const EventId &id) override;
            bool IsExpired(const EventId &id) const override;
            
            __host__ void componentMethod();
            __host__ bool is_safe(uint64_t ts);
            __host__ void ELP_Init();
            __host__ void ELP_Cleanup();
            __host__ void ELP_Run();
            __host__ void ELP_Schedule(const Time &delay, void *obj, int type, void *payload);
            void test(void *obj);
            __host__ __device__ void print_test() const;
            __device__ void deviceMethod(void *obj, int func_id);
            // for host to insert an safe event for device to execute
            __host__ void h_insert(void* impl, double delay, int context, int type, int nodeID);
            // for device to insert an event for host to schedule
            __device__ void d_insert(void* impl, double delay, int context, int type, void* payload);
            
            void Run() override;
            Time Now() const override;
            Time GetDelayLeft(const EventId &id) const override;
            Time GetMaximumSimulationTime() const override;
            void SetScheduler(ObjectFactory schedulerFactory) override;
            uint32_t GetSystemId() const override;
            uint32_t GetContext() const override;
            uint64_t GetEventCount() const override;

        private:
            void DoDispose() override;

            void ProcessOneEvent();
            void ProcessEventsWithContext();

            __host__ void ELP_ProcessOneEvent();

            struct EventWithContext
            {
                uint32_t context;
                uint64_t timestamp;
                EventImpl *event;
            };
            typedef std::list<struct EventWithContext> EventsWithContext;
            EventsWithContext m_eventsWithContext;
            bool m_eventsWithContextEmpty;
            std::mutex m_eventsWithContextMutex;

            // struct DestroyEvents
            // {
            //     EventId PeekEventImpl() const;
            // };
            typedef std::list<EventId> DestroyEvents;
            DestroyEvents m_destroyEvents;
            bool m_stop;
            Ptr<Scheduler> m_events;

            // CUDA specific members
            cudaStream_t streamK;
            cudaStream_t streamC;

            CudaELPComponent elpComponent;
            // these are ping-pong buffers for host to save the events and device to fetch
            DeviceEvent* h_safeEventQueue1;
            DeviceEvent* h_safeEventQueue2;
            // this is a array for device-side to check if there is any event to be executed
            // DeviceEvent* d_eventQueue;
            // these are ping-pong buffers for device-side to store the next event to be scheduled on host
            DeviceEvent* d_nextEventQueue1;
            DeviceEvent* d_nextEventQueue2;
            // flags fot ping-pong buffers to indicate if the buffer is ready to be read
            volatile int *h_bufrdy1;
            volatile int *h_bufrdy2;
            volatile int *d_bufrdy1;
            volatile int *d_bufrdy2;
            // to save current chosen buffer
            DeviceEvent* h_eventQueue;
            DeviceEvent* d_eventQueue;
            volatile int* h_bufrdy;
            volatile int* d_bufrdy;
            // safe timestamp for both host and device to check if the event is safe to be executed
            double *safe_ts;
            // a stop flag for device to check if the simulation is finished
            int *d_stop;
            int* eventCounter;
            uint32_t m_test;
            uint32_t d_uid;

            uint32_t m_uid;
            uint32_t m_currentUid;
            // the unit is in nanoseconds
            uint64_t m_currentTs;
            uint32_t m_currentContext;
            uint64_t m_eventCount;
            int m_unscheduledEvents;

            std::thread::id m_mainThreadId;
    };
} // namespace ns3

#endif // CUDA_ELP_SIMULATOR_H