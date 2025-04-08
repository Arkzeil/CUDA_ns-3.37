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
#include <cooperative_groups.h>

#include <vector>
#include <unordered_map>

#define DEVICE_QUEUE_LENGTH 2048
#define EVENT_KINDS 3
#define MAX_NEW_EVENTS 3
#define DEVICE_EV_ID_OFFSET 1000000
#define TPB 64  // Threads per block (block size)
#define MAX_PACKET_PER_THREAD 4
#define WARP_SIZE 32

namespace ns3
{
    void testSend(void* obj);

    // Forward
    class Scheduler;
    class CudaPacket;

    // packet buffer for device-side
    extern CudaPacket* d_threadBuffer;
    extern uint8_t* d_packetRawBuffer;
    extern size_t pitch;

    // a 2d table to store the lookahead time for each pair of node number
    // the value is actually the delay between the two nodes, need to add the packet transmission time
    template <typename T>
    class LookaheadTable {
        public:
            LookaheadTable() = default;
            
            // Add a value for a specific source-destination pair
            void addValue(uint32_t source, uint32_t destination, const T& value) {
                uint32_t key = makeKey(source, destination);
                nodeValues[key][destination].push_back(value);
            }
            
            // Get all values for a specific source-destination pair
            const std::vector<T>& getValues(uint32_t source, uint32_t destination) const {
                uint32_t key = makeKey(source, destination);
                
                // Check if source exists
                auto srcIt = nodeValues.find(key);
                if (srcIt == nodeValues.end()) {
                    static const std::vector<T> empty;
                    return empty;
                }
                
                // Check if destination exists
                auto destIt = srcIt->second.find(destination);
                if (destIt == srcIt->second.end()) {
                    static const std::vector<T> empty;
                    return empty;
                }
                
                return destIt->second;
            }
            
            // Get a specific value at an index for a source-destination pair
            T getValue(uint32_t source, uint32_t destination, uint32_t index = 0) const {
                const auto& values = getValues(source, destination);
                
                if (index >= values.size()) {
                    throw std::out_of_range("Index out of range for source-destination pair");
                }
                
                return values[index];
            }
            
            // Check if a source-destination pair exists
            bool hasConnection(uint32_t source, uint32_t destination) const {
                uint32_t key = makeKey(source, destination);
                
                auto srcIt = nodeValues.find(key);
                if (srcIt == nodeValues.end()) {
                    return false;
                }
                
                return srcIt->second.find(destination) != srcIt->second.end();
            }
            
            // Get the number of values for a source-destination pair
            uint32_t countValues(uint32_t source, uint32_t destination) const {
                return getValues(source, destination).size();
            }
            
            // Clear all values
            void clear() {
                nodeValues.clear();
            }
            
            // Get all source nodes
            std::vector<uint32_t> getAllSourceNodes() const {
                std::vector<uint32_t> sources;
                for (const auto& pair : nodeValues) {
                    sources.push_back(pair.first);
                }
                return sources;
            }
            
            // Get all destination nodes for a given source
            std::vector<uint32_t> getDestinationsForSource(uint32_t source) const {
                std::vector<uint32_t> destinations;
                uint32_t key = makeKey(source, 0);
                
                auto srcIt = nodeValues.find(key);
                if (srcIt != nodeValues.end()) {
                    for (const auto& destPair : srcIt->second) {
                        destinations.push_back(destPair.first);
                    }
                }
                return destinations;
            }
        private:
            // Use a hash map to store values indexed by source-destination pairs
            std::unordered_map<uint32_t, std::unordered_map<uint32_t, std::vector<T>>> nodeValues;
            
            // Helper function to create a key for the hash map
            uint32_t makeKey(uint32_t source, uint32_t destination) const {
                // Simple hash combining function
                return source;
            }
    };

    extern LookaheadTable<uint64_t> lookaheadTable;

    // A simplified device-side event structure
    struct DeviceEvent {
        void *impl;   // pointer to the event implementation
        uint64_t ts;    // event timestamp, assuming to be nanosecond
        int context;  // event context
        uint32_t uid;      // unique id
        int type;     // event type identifier
        uint64_t lookahead; // lookahead time
        bool valid;  // a flag to indicate if the event is valid
        void *payload; // event-specific payload(usually a pointer to a packet)
        DeviceEvent *next; // pointer to the next event(used for send, which will bring a chain of events)
        // Add any additional event-specific payload here.
        // For example, a union of data for different event types.
    };

    struct HostEvent{
        void *obj;
        int type;
        uint64_t lookahead;
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
            void ELP_Test(void *obj);
            __host__ void componentMethod();
            __host__ void ELP_Init();
            __host__ void ELP_Cleanup();
            __host__ void ELP_Run();
            __host__ void ELP_Schedule(uint32_t context, const Time &delay, void *obj, int type, uint64_t lookahead, void *payload);
            // void test(void *obj);
            __host__ __device__ void print_test() const;
            __device__ void deviceMethod(void *obj, int func_id);
            // for host to insert an safe event for device to execute
            __host__ int h_insert(void* impl, uint64_t ts, int context, uint32_t UID, int type, uint64_t lookahead, void* payload);
            __host__ int h_insert_sort(void* impl, uint64_t ts, int context, uint32_t UID, int type, uint64_t lookahead, void* payload);
            // for device to insert an event for host to schedule
            __device__ DeviceEvent* d_insert(void* impl, uint64_t delay, int context, int type, uint64_t lookahead, void* payload);
            __device__ void ChangeDevQueue();
            
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

            __host__ bool is_safe(Scheduler::Event *ev);
            
            __host__ void ChangeHostQueue();
            __host__ void ELP_ProcessOneEvent();
            __host__ void ELP_ScheduleDevEvent();

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
            // multi processors count
            int mp;

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
            // to save current buffer that host and device are using, containing the pointer to the buffer and the flag
            DeviceEvent* h_curHostBuf;
            // DeviceEvent* d_curHostBuf;
            DeviceEvent* h_curDevBuf;
            DeviceEvent* d_curDevBuf;
            volatile int* h_curHostBufRdy;
            // volatile int* d_curHostBufRdy;
            volatile int* h_curDevBufRdy;
            volatile int* d_curDevBufRdy;
            // a index for host to insert into correct location of host buffer
            volatile uint32_t h_insertIndex;
            // safe timestamp for both host and device to check if the event is safe to be executed
            volatile uint64_t *safe_ts;
            volatile uint64_t *d_safe_ts1;
            volatile uint64_t *d_safe_ts2;
            // to store the safe timestamp of CPU current writing buffer, need to be reset when the buffer is changed
            // uint64_t cur_buffer_safe_ts;
            // used for host to update the safe timestamp for h_safeEventQueue, containing the pointer to the ts
            volatile uint64_t *h_safe_ts;
            // a stop flag for device to check if the simulation is finished
            volatile int *d_stop;
            // a flag to let CPU notify that it's idle and GPU need to release device buffer
            // volatile int *h_idle;
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
    __global__ void PersistentEventKernel(CudaELPSimulator *sim, 
        DeviceEvent* h_safeEventQueue1, DeviceEvent* h_safeEventQueue2, 
        DeviceEvent* d_nextEventQueue1, DeviceEvent* d_nextEventQueue2, 
        volatile int *h_bufrdy1, volatile int *h_bufrdy2,
        volatile int *d_bufrdy1, volatile int *d_bufrdy2,
        volatile uint64_t* d_safe_ts1, volatile uint64_t* d_safe_ts2, 
        volatile int* d_stop);
} // namespace ns3

#endif // CUDA_ELP_SIMULATOR_H