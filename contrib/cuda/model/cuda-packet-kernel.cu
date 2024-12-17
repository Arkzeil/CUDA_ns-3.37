#include "cuda-packet-kernel.cuh"
// #include "cuda-ipv4-routing.h"
#include <iostream>

__global__ void OffloadToGpuKernel(int numPackets, int packetSize, RoutingTable* d_routingTable, int tableSize) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    if (idx < numPackets) {
        // Step 1: Generate Packet
        uint8_t packet[1500]; // Local packet buffer
        UdpHeader* udpHeader = reinterpret_cast<UdpHeader*>(packet);
        udpHeader->srcPort = 1234;
        udpHeader->destPort = 8080;
        udpHeader->length = packetSize;
        udpHeader->checksum = 0;

        for (int i = sizeof(UdpHeader); i < packetSize; ++i) {
            packet[i] = static_cast<uint8_t>(idx % 256);
        }

        // Step 2: Routing Lookup
        uint16_t destAddr = udpHeader->destPort; // Simplified lookup key
        int nextHop = -1;
        for (int i = 0; i < tableSize; ++i) {
            if (d_routingTable[i].destAddr == destAddr) {
                nextHop = d_routingTable[i].nextHop;
                break;
            }
        }

        // Step 3: Queue Packet for Transmission
        if (nextHop != -1) { // Valid route found
            int queuePos = atomicAdd(&tail, packetSize);
            if (queuePos < sizeof(gpuPacketQueue)) {
                memcpy(&gpuPacketQueue[queuePos], packet, packetSize);
            }
        }
        if(idx == 0)
            printf("Queue status: head=%d, tail=%d\n", head, tail);
    }
}