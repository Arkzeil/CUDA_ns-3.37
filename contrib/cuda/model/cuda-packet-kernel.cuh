#ifndef CUDA_PACKET_KERNEL_H
#define CUDA_PACKET_KERNEL_H

#include <cuda_runtime.h>
#include <stdint.h>

__global__ void GenerateUdpPackets(uint8_t* packetBuffer, int packetSize, int numPackets);

#endif // CUDA_PACKET_KERNEL_H