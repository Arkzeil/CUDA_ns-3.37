#include "cuda-packet-kernel.cuh"
#include <iostream>

struct UdpHeader {
    uint16_t srcPort;
    uint16_t destPort;
    uint16_t length;
    uint16_t checksum;
};

__global__ void GenerateUdpPackets(uint8_t* packetBuffer, int packetSize, int numPackets) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    if (idx < numPackets) {
        printf("Generating packet %d\n", idx);
        // Calculate the packet offset
        uint8_t* packet = packetBuffer + idx * packetSize;

        // Fill UDP Header
        UdpHeader* udpHeader = reinterpret_cast<UdpHeader*>(packet);
        udpHeader->srcPort = 1234;
        udpHeader->destPort = 8080;
        udpHeader->length = packetSize;
        udpHeader->checksum = 0; // Simplified (no checksum computation)

        // Fill Packet Payload
        for (int i = sizeof(UdpHeader); i < packetSize; ++i) {
            packet[i] = static_cast<uint8_t>(idx % 256); // Example payload data
        }
    }
}