#include "cuda-helper.h"
#include <stdio.h>
#include "ns3/cuda-net-device.h"
#include "ns3/simulator.h"

namespace ns3
{
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
        
                if(prop.major >= 1) {
                    break;
                }
            }
        }

        if(i == count) {
            fprintf(stderr, "There is no device supporting CUDA 1.x.\n");
            return false;
        }
        /* 在找到支援 CUDA 1.0 以上的裝置之後，就可以呼叫 cudaSetDevice 函式，把它設為目前要使用的裝置。 */
        cudaSetDevice(i);

        printf("----------------InitCUDA, CUDA check completed-------------------\n");

        return true;
    }
/* ... */
    void checkCudaErr(){
        cudaError_t err = cudaGetLastError();
        if (err != cudaSuccess) 
            printf("Error: %s\n", cudaGetErrorString(err));
    }

    CUDA_cb_data::CUDA_cb_data(): empty(true), next(nullptr), packetBuffer(nullptr), func_id(-1) {
        cudaMallocManaged((void**)&packetBuffer, 256);
    }

    CUDA_cb_data::CUDA_cb_data(uint32_t packet_size): empty(true), next(nullptr), func_id(-1) {
        cudaMallocManaged((void**)&packetBuffer, packet_size);
        this->packetSize = packet_size;
    }

    CUDA_cb_data::CUDA_cb_data(uint32_t context, void* dst, uint8_t* packetBuffer, uint32_t packetSize, Time sendTime, float delay): empty(true), next(nullptr), func_id(-1) {
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
        func_id = -1;
        packetSize = 0;
        delay = 0;
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
                    Simulator::ScheduleWithContext(device->GetNode()->GetId(), delay, [device, cbData](){
                        device->Receive(cbData->packetBuffer[0]);
                    });
                    break;
                case 1:
                    // printf("Callback function 1\n");
                    Simulator::ScheduleWithContext(device->GetNode()->GetId(), delay, [device, stream](){
                        device->TransmitComplete(stream);
                    });
                    break;
                default:
                    printf("Unknown function id\n");
                    break;
            }

            cbData = cbData->next;
        }
    }
}
