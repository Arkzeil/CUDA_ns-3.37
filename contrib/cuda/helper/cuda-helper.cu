#include "cuda-helper.h"
#include <stdio.h>
#include "ns3/cuda-net-device.h"
#include "ns3/simulator.h"
#include "ns3/cuda-packet.h"
#include "ns3/cuda-elp-simulator.h"

namespace ns3
{
    __managed__ CudaELPSimulator* cudaSim = nullptr;
    __device__ CudaELPSimulator* cudaSim_d = nullptr;
    __managed__ int device_id = 0;

    bool InitCUDA(cudaDeviceProp &prop) {
        int count;
        /* 取得支援 CUDA 的裝置的數目，如果系統上沒有支援 CUDA 的裝置，則它會傳回 1，
        而 device 0 會是一個模擬的裝置，但不支援 CUDA 1.0 以上的功能。
        */
        printf("----------------InitCUDA, make sure CUDA is available-------------------\n");
        cudaGetDeviceCount(&count);
        if(count == 0) {
            fprintf(stderr, "There is no device.\n");
            return false;
        }

        /* 要確定系統上是否有支援 CUDA 的裝置，需要對每個 device 呼叫 cudaGetDeviceProperties 函式，
        取得裝置的各項資料，並判斷裝置支援的 CUDA 版本（prop.major 和 prop.minor 分別代表裝置支援
        的版本號碼，例如 1.0 則 prop.major 為 1 而 prop.minor 為 0）
        透過 cudaGetDeviceProperties 函式可以取得許多資料，除了裝置支援的 CUDA 版本之外，還有裝置的名稱、
        記憶體的大小、最大的 thread 數目、執行單元的時脈等等。
        */
        int i;
        for(i = 0; i < count; i++) {
            //cudaDeviceProp prop;
            if(cudaGetDeviceProperties(&prop, i) == cudaSuccess) {
                printf("Device name: %s\n", prop.name );
                printf("Peak clock: %dkHz\n", prop.clockRate);
                printf("Device memory: %ld\n", prop.totalGlobalMem );
                printf("Memory per-block: %ld\n", prop.sharedMemPerBlock );
                printf("Register per-block: %d\n", prop.regsPerBlock );
                printf("Warp size: %d\n", prop.warpSize );
                printf("Memory pitch: %ld\n", prop.memPitch );
                printf("Constant Memory: %ld\n", prop.totalConstMem );
                printf("Max thread per-block: %d\n", prop.maxThreadsPerBlock );
                printf("Max thread dim: ( %d, %d, %d )\n", prop.maxThreadsDim[0], prop.maxThreadsDim[1], prop.maxThreadsDim[2] );
                printf("Max grid size: ( %d, %d, %d )\n", prop.maxGridSize[0], prop.maxGridSize[1], prop.maxGridSize[2] );
                printf("Ver: %d.%d\n", prop.major, prop.minor );
                printf("Clock: %d\n", prop.clockRate );
                printf("textureAlignment: %ld\n", prop.textureAlignment );

                printf("device supports memory pools: %d\n", prop.memoryPoolsSupported);
                printf("device supports memory pool handle types: %d\n", prop.memoryPoolSupportedHandleTypes);
        
                if(prop.major >= 1) {
                    break;
                }
            }
        }

        if(i == count) {
            fprintf(stderr, "There is no device supporting CUDA 1.x.\n");
            return false;
        }

        // int driverVersion = 0;  
        // int deviceSupportsMemoryPools = 0;  
        // int poolSupportedHandleTypes = 0;  
        // cudaDriverGetVersion(&driverVersion);  
        // if (driverVersion >= 11020) {  
        //     cudaDeviceGetAttribute(&deviceSupportsMemoryPools,  
        //                             cudaDevAttrMemoryPoolsSupported, device);  
        // }  
        // if (deviceSupportsMemoryPools != 0) {  
        //     // `device` supports the Stream Ordered Memory Allocator  
        // }  
        
        // if (driverVersion >= 11030) {  
        //     cudaDeviceGetAttribute(&poolSupportedHandleTypes,  
        //             cudaDevAttrMemoryPoolSupportedHandleTypes, device);  
        // }  
        // if (poolSupportedHandleTypes & cudaMemHandleTypePosixFileDescriptor) {  
        //     // Pools on the specified device can be created with posix file descriptor-based IPC  
        // }  
        /* 在找到支援 CUDA 1.0 以上的裝置之後，就可以呼叫 cudaSetDevice 函式，把它設為目前要使用的裝置。 */
        cudaSetDevice(i);

        cudaGetDevice(&device_id);

        int d;
        cudaGetDevice(&d);

        int pma = 0;
        cudaDeviceGetAttribute(&pma, cudaDevAttrPageableMemoryAccess, d);
        printf("Full Unified Memory Support: %s\n", pma == 1? "YES" : "NO");
        
        int cma = 0;
        cudaDeviceGetAttribute(&cma, cudaDevAttrConcurrentManagedAccess, d);
        printf("CUDA Managed Memory with full support: %s\n", cma == 1? "YES" : "NO");

        int device = 0;
        printf("CUDA device properties pageableMemoryAccess: %d\n", prop.pageableMemoryAccess);
        printf("CUDA device properties hostNativeAtomicSupported: %d\n", prop.hostNativeAtomicSupported);
        printf("CUDA device properties pageableMemoryAccessUsesHostPageTables: %d\n", prop.pageableMemoryAccessUsesHostPageTables);
        printf("CUDA device properties directManagedMemAccessFromHost: %d\n", prop.directManagedMemAccessFromHost);
        printf("CUDA device properties concurrentManagedAccess: %d\n", prop.concurrentManagedAccess);
        printf("CUDA device properties pageableMemoryAccess: %d\n", prop.pageableMemoryAccess);
        printf("CUDA device properties managedMemory: %d\n", prop.managedMemory);
        printf("CUDA device properties concurrentManagedAccess: %d\n", prop.concurrentManagedAccess);
        printf("CUDA device properties managedMemory: %d\n", prop.managedMemory);

        printf("----------------InitCUDA, CUDA check completed-------------------\n");

        return true;
    }

    int debug_printf(const char *format, ...) {
        va_list args;
        int chars_printed = 0;

        va_start(args, format);

        if (debug_print) {  // Check the flag before printing
            chars_printed = vprintf(format, args); // Use vprintf for variable arguments
        }

        va_end(args);
        return chars_printed;
    }
/* ... */
    void checkCudaErr(){
        cudaError_t err = cudaGetLastError();
        if (err != cudaSuccess) 
            printf("Error: %s\n", cudaGetErrorString(err));
    }

    __host__ __device__ uint16_t ones_complement_sum(uint32_t sum) {
        // Fold 32-bit sum to 16-bit
        while (sum >> 16) {
            sum = (sum & 0xFFFF) + (sum >> 16);
        }
        return (uint16_t)~sum;
    }

    __host__ void InitCudaSim(){
        // Ptr<SimulatorImpl> sim = Simulator::GetImplementation();// Get the global simulator object
        // cudaSim = dynamic_cast<ns3::CudaELPSimulator*>(GetPointer(sim));
        // CudaELPSimulator* cudaSim = static_cast<CudaELPSimulator*>(GetPointer(Simulator::GetImplementation()));
        cudaSim = (CudaELPSimulator*)GetPointer(Simulator::GetImplementation());
        printf("cudaSim Init: %p\n", cudaSim);

        // cudaMalloc((void**)&cudaSim_d, sizeof(CudaELPSimulator));
        // cudaMemcpy(cudaSim_d, cudaSim, sizeof(CudaELPSimulator), cudaMemcpyHostToDevice);
    }

    CUDA_cb_data::CUDA_cb_data(): 
    empty(true), next(nullptr), packetBuffer(nullptr), packet(nullptr), func_id(-1) {
        cudaMallocManaged((void**)&packetBuffer, 256);
        checkCudaErr();
        // cudaHostAlloc(&h_packet, sizeof(CudaPacket), cudaHostAllocDefault);
    }

    CUDA_cb_data::CUDA_cb_data(uint32_t packet_size): 
    empty(true), next(nullptr), packet(nullptr), func_id(-1) {
        cudaMallocManaged((void**)&packetBuffer, packet_size);
        this->packetSize = packet_size;
    }

    CUDA_cb_data::CUDA_cb_data(uint32_t context, void* dst, uint8_t* packetBuffer, uint32_t packetSize, Time sendTime, float delay): 
    empty(true), next(nullptr), packet(nullptr), func_id(-1) {
        this->context = context;
        this->dst = dst;
        this->packetBuffer = packetBuffer;
        this->packetSize = packetSize;
        this->sendTime = sendTime;
        this->delay = delay;
    }

    CUDA_cb_data::~CUDA_cb_data() {
        cudaFree(packetBuffer);
    }

    __host__ __device__ void CUDA_cb_data::init() {
        empty = true;
        next = nullptr;
        dst = nullptr;
        packet = nullptr;
        func_id = -1;
        packetSize = 0;
        delay = 0;
    }

    __host__ void CUDA_cb_data::init_pkt() {
        cudaMallocManaged(&packet, sizeof(CudaPacket));
        checkCudaErr();
        new(packet) CudaPacket();
    }

    void CUDA_cb_data::addNext(uint8_t length) {
        CUDA_cb_data* cur = this;
        for(int i = 0; i < length; i++){
            if(cur->next == nullptr)
                cur->next = new CUDA_cb_data();
            cur = cur->next;
        }
        // next = new CUDA_cb_data();
    }

    void CUDART_CB Cuda_ScheduleCallBack(cudaStream_t stream, cudaError_t status, void* data){
        CUDA_cb_data* cbData = static_cast<CUDA_cb_data*>(data);
        // printf("CUDA callback running in thread: %ld\n", std::this_thread::get_id());
        if(cbData == nullptr){
            printf("Callback data is null\n");
            return;
        }
        if(cbData->empty){
            printf("Callback data is empty\n");
            return;
        }
        while(cbData != nullptr){
            CudaNetDevice* device = (CudaNetDevice*)cbData->dst;
            Time delay = Seconds(cbData->delay);

            switch(cbData->func_id){
                case -1:
                    printf("Function: None\n");
                    break;
                case 0:
                    // printf("Callback function 0\n");
                    printf("Function: Receive, delay: %f, dst: %d\n", cbData->delay, device->GetNode()->GetId());
                    // printf("packet id: %d\n", cbData->packet->GetUid());
                    Simulator::ScheduleWithContext(device->GetNode()->GetId(), delay, [device, cbData](){
                        device->Receive(cbData->packet);
                    });
                    break;
                case 1:
                    // printf("Callback function 1\n");
                    printf("Function: TransmitComplete, delay: %f, target:%d\n", cbData->delay, device->GetNode()->GetId());
                    Simulator::ScheduleWithContext(device->GetNode()->GetId(), delay, [device, stream](){
                        device->TransmitComplete(stream);
                    });
                    break;
                default:
                    printf("Unknown function id\n");
                    break;
            }

            CUDA_cb_data* next = cbData->next;
            // delete cbData;
            cudaFree(cbData);
            cbData = next;
        }
    }
}
