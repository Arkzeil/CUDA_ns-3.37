#include "cuda-node.h"

namespace ns3 {

    NS_LOG_COMPONENT_DEFINE("CudaNode");
    NS_OBJECT_ENSURE_REGISTERED(CudaNode);

    TypeId CudaNode::GetTypeId(void) {
        static TypeId tid = TypeId("ns3::CudaNode")
            .SetParent<Node>()
            .SetGroupName("Network");
        return tid;
    }

    CudaNode::CudaNode(): d_nodeMemory(nullptr), m_deviceCount(0), m_devices(), m_id(0) {
        // Allocate GPU memory for node
        cudaMalloc(&d_nodeMemory, 1024); // Example size, adjust as needed
    }

    CudaNode::~CudaNode() {
        cudaFree(d_nodeMemory);
    }

    void CudaNode::InitializeGpuMemory() {
        // Initialize node-specific data on GPU
    }

    void CudaNode::SynchronizeCpuState() {
        // Synchronize GPU state back to CPU if needed
    }

    uint32_t CudaNode::AddDevice(CudaNetDevice* device) {
        // Add a device to the node
        m_devices.push_back(device);
        m_deviceCount++;
        return 0;
    }

} // namespace ns3
