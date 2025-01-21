#ifndef CUDA_HELPER_H
#define CUDA_HELPER_H

#include <cuda_runtime.h>
#include "ns3/core-module.h"
#include "../model/helper.h"
#include "ns3/nstime.h"

#include <queue>
#include <mutex>
#include <functional>
#include <condition_variable>
#include <thread>

namespace ns3
{

// Each class should be documented using Doxygen,
// and have an \ingroup cuda directive

/* ... */
    bool InitCUDA(cudaDeviceProp &prop);
    void checkCudaErr();

    class DeviceCallback {
        public:
            using MemberFunction = void (*) (void*); // A generic function pointer type

            __device__ DeviceCallback() : m_object(nullptr), m_function(nullptr) {}

            __device__ void Set(void* object, MemberFunction function) {
                m_object = object;
                m_function = function;
            }

            __device__ void Execute() const {
                if (m_object && m_function) {
                    m_function(m_object); // Call the function with the object as a parameter
                }
            }

        private:
            void* m_object;          // Pointer to the object
            MemberFunction m_function; // Pointer to the function
    };

    class EventDispatcher {
        public:
            static EventDispatcher& GetInstance(){
                static EventDispatcher instance;
                return instance;
            }

            void Dispatch(uint32_t nodeId, Time scheduleTime, std::function<void()> func){
                {
                    std::lock_guard<std::mutex> lock(m_mutex);
                    m_eventQueue.push({nodeId, scheduleTime, func});
                }
                m_cv.notify_one();  // Wake up the worker thread
            }

            void StartWorker(){
                m_workerThread = std::thread(&EventDispatcher::ProcessEvents, this);
            }

            void StopWorker(){
                {
                    std::lock_guard<std::mutex> lock(m_mutex);
                    m_stop = true;
                }
                m_cv.notify_one();
                m_workerThread.join();
            }

        private:
            struct Event{
                uint32_t nodeId;                    // context
                Time scheduleTime;
                std::function<void()> func;
            };

            std::queue<Event> m_eventQueue;
            std::mutex m_mutex;
            std::condition_variable m_cv;
            std::thread m_workerThread;
            bool m_stop = false;

            EventDispatcher(){}

            ~EventDispatcher(){
                if(m_stop == false)
                    StopWorker(); 
            }

            void ProcessEvents(){
                while (true){
                    Event event;

                    {
                        std::unique_lock<std::mutex> lock(m_mutex);
                        m_cv.wait(lock, [this] { return !m_eventQueue.empty() || m_stop; });

                        if (m_stop) return;

                        event = m_eventQueue.front();
                        m_eventQueue.pop();
                    }

                    // Schedule event execution safely in the ns-3 main thread
                    Simulator::ScheduleWithContext(event.nodeId, event.scheduleTime, event.func);
                }
            }
    };

    class CUDA_cb_data: public Managed{
        public:
            CUDA_cb_data();
            CUDA_cb_data(uint32_t packet_size);
            CUDA_cb_data(uint32_t context, void* dst, uint8_t* packetBuffer, uint32_t packetSize, Time sendTime, float delay);
            ~CUDA_cb_data();

            __host__ __device__ void init();
            void addNext(uint8_t length);

            bool empty;
            uint32_t context;
            void* dst;
            int32_t func_id;
            // DeviceCallback callback;
            uint8_t* packetBuffer;
            uint32_t packetSize;
            Time sendTime;
            float delay;
            CUDA_cb_data* next;
            // CudaSocket* socket;
            // Ptr<Packet> packet;
    };

    void CUDART_CB Cuda_ScheduleCallBack(cudaStream_t stream, cudaError_t status, void* data);
}

#endif /* CUDA_HELPER_H */
