#ifndef CUDA_NODE_H
#define CUDA_NODE_H

#include "ns3/node.h"
#include "cuda_runtime.h"

namespace ns3 {

class GpuNode : public Node {
public:
    static TypeId GetTypeId(void);

    GpuNode();
    virtual ~GpuNode();

    // Initialize GPU memory for the node
    void InitializeGpuMemory();

    // Synchronize state back to CPU if needed
    void SynchronizeCpuState();

private:
    uint8_t* d_nodeMemory; // GPU memory for node-specific data
};

} // namespace ns3

#endif // GPU_NODE_H
