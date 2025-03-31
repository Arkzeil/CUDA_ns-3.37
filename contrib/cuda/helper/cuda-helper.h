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

#include <stdio.h>
#include <stdarg.h>

namespace ns3
{

// Each class should be documented using Doxygen,
// and have an \ingroup cuda directive
    #define debug_print 1
    
    // #define CHECKSUM_ENABLED
    
    #ifdef CHECKSUM_ENABLED
        #define CHECKSUM_CHECK
    #endif

    #define cudaCheckErrors(msg) \
                            do { \
                                cudaError_t __err = cudaGetLastError(); \
                                if (__err != cudaSuccess) { \
                                    fprintf(stderr, "Fatal error: %s (%s at %s:%d)\n", \
                                        msg, cudaGetErrorString(__err), \
                                        __FILE__, __LINE__); \
                                    fprintf(stderr, "*** FAILED - ABORTING\n"); \
                                    exit(1); \
                                } \
                            } while (0)
/* ... */
    bool InitCUDA(cudaDeviceProp &prop);
    // Alternative function to printf with a conditional output flag
    int debug_printf(const char *format, ...);
    void checkCudaErr();
    __host__ __device__ uint16_t ones_complement_sum(uint32_t sum);
    __host__ void InitCudaSim();

    class CudaPacket;
    class CudaELPSimulator;

    extern __managed__ CudaELPSimulator* cudaSim;
    extern __device__ CudaELPSimulator* cudaSim_d;
    extern __managed__ int device_id;

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
            __host__ void init_pkt();
            void addNext(uint8_t length);

            bool empty;
            uint32_t context;
            void* dst;
            int32_t func_id;
            // DeviceCallback callback;
            CudaPacket* packet;
            uint8_t* packetBuffer;
            uint32_t packetSize;
            Time sendTime;
            double delay;
            CUDA_cb_data* next;
            // CudaSocket* socket;
            // Ptr<Packet> packet;
    };

    void CUDART_CB Cuda_ScheduleCallBack(cudaStream_t stream, cudaError_t status, void* data);

    
    template <typename T1, typename T2>
    class CudaPair: public Managed{
        public:
            T1 first;
            T2 second;

            // Default constructor
            __host__ __device__
            CudaPair() : first(), second() {}

            // Parameterized constructor
            __host__ __device__
            CudaPair(const T1& a, const T2& b) : first(a), second(b) {}

            // Copy constructor
            __host__ __device__
            CudaPair(const CudaPair& other) : first(other.first), second(other.second) {}

            // Assignment operator
            __host__ __device__
            CudaPair& operator=(const CudaPair& other) {
                if (this != &other) {
                    first = other.first;
                    second = other.second;
                }
                return *this;
            }

            // Equality operator
            __host__ __device__
            bool operator==(const CudaPair& other) const {
                return (first == other.first) && (second == other.second);
            }

            // Less-than operator for sorting
            __host__ __device__
            bool operator<(const CudaPair& other) const {
                return first < other.first || (first == other.first && second < other.second);
            }
    };
    
    template <typename T1, typename T2>
    class Cuda_PairList: public Managed{
        public:
            CudaPair<T1, T2>* pair_elements;

            __host__  Cuda_PairList() : pair_elements(nullptr), m_size(0), m_capacity(0) {
                cudaMallocManaged(&front, sizeof(int));
                cudaMallocManaged(&rear, sizeof(int));
                *front = 0;
                *rear = 0;
            } // Default constructor

            __host__  Cuda_PairList(int capacity) : m_size(0), m_capacity(capacity) {
                cudaMallocManaged(&front, sizeof(int));
                cudaMallocManaged(&rear, sizeof(int));
                *front = 0;
                *rear = 0;
                pair_elements = new CudaPair<T1, T2>[capacity];
            } // Parameterized constructor

            __host__ __device__ ~Cuda_PairList(){
                delete[] pair_elements;
            }

            __host__ __device__ bool Add(T1 key, T2 protocol){
                if(m_size < m_capacity){
                    #ifdef __CUDA_ARCH__
                        if ((*rear + 1) == *front) {
                            return false; // Queue full
                        }
                        int t_rear = atomicAdd(rear, 1) & (m_capacity - 1);
                        pair_elements[t_rear] = CudaPair(key, protocol);
                        // int t_rear = *rear & (m_capacity - 1);
                        // *rear++;
                        // pair_elements[t_rear] = CudaPair(key, protocol);
                    #else
                        if ((*rear + 1) == *front) {
                            return false; // Queue full
                        }
                        pair_elements[(*rear)++] = CudaPair(key, protocol);
                    #endif

                    return true;
                }
                return false;
            }
            // this function is not ready
            __host__ __device__ void Remove(T1 key){
                for(int i = 0; i < m_size; i++){
                    if(pair_elements[i].first == key){
                        #ifdef __CUDA_ARCH__
                            pair_elements[i] = pair_elements[atomicSub(rear, 1) & (m_capacity - 1)];
                        #else
                            pair_elements[i] = pair_elements[(*rear)--];
                        #endif

                        break;
                    }
                }
            }
            // many thread might access this function at the same time
            // __host__ __device__ CudaPair<T1, T2> front(){
            //     return pair_elements[0];
            // }

            // __host__ __device__ CudaPair<T1, T2> back(){
            //     return pair_elements[m_size - 1];
            // }

            __host__ __device__ CudaPair<T1, T2> pop_front(){
                #ifdef __CUDA_ARCH__
                    if (*front == *rear) {
                        return CudaPair<T1, T2>(nullptr, 0); // Queue empty
                    }
                    int t_front = atomicAdd(front, 1) & (m_capacity - 1);
                    return pair_elements[t_front];
                    // int t_front = *front & (m_capacity - 1);
                    // *front++;
                    // return pair_elements[t_front];
                #else
                    if (*front == *rear) {
                        return CudaPair<T1, T2>(nullptr, 0); // Queue empty
                    }
                    return pair_elements[front++];
                #endif
            }

            __host__ __device__ T2 Get(T1 key){
                for(int i = 0; i < m_size; i++){
                    if(pair_elements[i].first == key){
                        return pair_elements[i].protocol;
                    }
                }
                return nullptr;
            }

            __host__ __device__ bool empty(){
                return *front == *rear;
            }
            
        private:
            int m_size;
            int m_capacity;
            int* front;
            int* rear;
    };

    template <typename T>
    class CudaList {
        public:
            struct Node {
                T data;        // The data stored in the node
                Node* next;    // Pointer to the next node

                __host__ __device__
                Node() : next(nullptr) {}

                __host__ __device__
                Node(T& value) : data(value), next(nullptr) {}
            };

            Node* head; // Head of the list

            __host__ __device__
            CudaList() : head(nullptr) {}

            __host__ __device__
            ~CudaList() {
                // Destructor is host-only since it requires memory deallocation
                // Ensure proper cleanup on the host
            }

            // Add a new element to the front of the list
            __host__ __device__
            void PushFront(T& value) {
                Node* newNode = CreateNode(value);
                newNode->next = head;
                head = newNode;
            }

            // Add a new element to the back of the list
            __host__ __device__
            void PushBack(T& value) {
                Node* newNode = CreateNode(value);

                if (!head) {
                    head = newNode;
                    return;
                }

                Node* current = head;
                while (current->next) {
                    current = current->next;
                }
                current->next = newNode;
            }

            // Remove the first element from the list
            __host__ __device__
            bool PopFront() {
                if (!head) return false;

                Node* temp = head;
                head = head->next;
                DestroyNode(temp);
                return true;
            }

            // Check if the list is empty
            __host__ __device__
            bool IsEmpty() const {
                return head == nullptr;
            }

            // Traverse the list and apply a callback function to each element
            template <typename Callback>
            __host__ __device__
            void Traverse(Callback callback) const {
                Node* current = head;
                while (current) {
                    callback(current->data);
                    current = current->next;
                }
            }

        private:
            // Utility function to create a new node
            __host__ __device__
            Node* CreateNode(T& value) {
        #ifdef __CUDA_ARCH__
                // On the device, use `cudaMalloc`
                Node* newNode = (Node*)malloc(sizeof(Node));
        #else
                // On the host, use regular `new`
                Node* newNode = new Node(value);
        #endif
                if (newNode) {
                    newNode->data = value;
                    newNode->next = nullptr;
                }
                return newNode;
            }

            // Utility function to destroy a node
            __host__ __device__
            void DestroyNode(Node* node) {
        #ifdef __CUDA_ARCH__
                // On the device, use `free`
                free(node);
        #else
                // On the host, use `delete`
                delete node;
        #endif
            }
    };
}

#endif /* CUDA_HELPER_H */
