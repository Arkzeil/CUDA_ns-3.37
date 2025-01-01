#ifndef CUDA_NODE_H
#define CUDA_NODE_H

#include "ns3/node.h"
#include "ns3/log.h"
#include "ns3/uinteger.h"
#include "cuda_runtime.h"
#include "cuda-net-device.h"
#include "helper.h"

namespace ns3 {

class CudaNode : public Node, public Managed{
    public:
        static TypeId GetTypeId(void);

        CudaNode();
        virtual ~CudaNode();

        // Initialize GPU memory for the node
        void InitializeGpuMemory();

        // Synchronize state back to CPU if needed
        void SynchronizeCpuState();

        uint32_t AddDevice(CudaNetDevice* device);

    private:
        uint8_t* d_nodeMemory; // GPU memory for node-specific data
        uint32_t m_deviceCount; // Number of devices attached to the node
        std::vector<CudaNetDevice*> m_devices; // List of devices attached to the node
        uint32_t m_id; // Node ID
};

} // namespace ns3

#endif // GPU_NODE_H
