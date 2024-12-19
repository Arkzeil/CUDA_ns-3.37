#include "cuda-node.h"

namespace ns3 {

NS_OBJECT_ENSURE_REGISTERED(GpuNode);

TypeId GpuNode::GetTypeId(void) {
    static TypeId tid = TypeId("ns3::GpuNode")
        .SetParent<Node>()
        .SetGroupName("Network");
    return tid;
}

GpuNode::GpuNode() {
    // Allocate GPU memory for node
    cudaMalloc(&d_nodeMemory, 1024); // Example size, adjust as needed
}

GpuNode::~GpuNode() {
    cudaFree(d_nodeMemory);
}

void GpuNode::InitializeGpuMemory() {
    // Initialize node-specific data on GPU
}

void GpuNode::SynchronizeCpuState() {
    // Synchronize GPU state back to CPU if needed
}

} // namespace ns3
