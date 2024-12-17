#ifndef CUDA_PACKET_KERNEL_H
#define CUDA_PACKET_KERNEL_H

#include <cuda_runtime.h>
#include <stdint.h>


struct UdpHeader {
    uint16_t srcPort;
    uint16_t destPort;
    uint16_t length;
    uint16_t checksum;
};

struct RoutingTable {
    uint16_t destAddr;
    uint16_t nextHop;
};

// Shared memory queue for packets (GPU-based circular buffer)
__device__ uint8_t gpuPacketQueue[1024 * 1500]; // 1024 packets of max size 1500 bytes
__device__ int head = 0, tail = 0; // Queue pointers for packet queue

__global__ void OffloadToGpuKernel(int numPackets, int packetSize, RoutingTable* d_routingTable, int tableSize);

#endif // CUDA_PACKET_KERNEL_H