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
        void *payload; // event-specific payload(usually a pointer to a packet)
        // Add any additional event-specific payload here.
        // For example, a union of data for different event types.
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
            __host__ bool is_safe();
            void test(void *obj);
            void print_test() const;
            __device__ void deviceMethod(void *obj, int func_id);
            __device__ void insert(void* impl, double delay, int context, uint32_t type);
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

            CudaELPComponent elpComponent;
            DeviceEvent* h_safeEventQueue1;
            DeviceEvent* h_safeEventQueue2;
            DeviceEvent* d_eventQueue;
            double *safe_ts;
            int *d_stop;
            int* eventCounter;
            uint32_t m_test;

            uint32_t m_uid;
            uint32_t m_currentUid;
            uint64_t m_currentTs;
            uint32_t m_currentContext;
            uint64_t m_eventCount;
            int m_unscheduledEvents;

            std::thread::id m_mainThreadId;
    };
} // namespace ns3

#endif // CUDA_ELP_SIMULATOR_H