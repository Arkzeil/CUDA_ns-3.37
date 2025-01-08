#include "cuda-helper.h"
#include <stdio.h>

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
}
