#ifndef UDP_SEND_KERNEL_H
#define UDP_SEND_KERNEL_H

#include <stdio.h>
#include <time.h>
#include <cuda.h>
#include <cuda_runtime.h>

#define HEADER_SIZE 8
#define UDP_HEADER_SIZE 8
#define IP_HEADER_SIZE 20

namespace ns3 {
    namespace cuda{
        struct GpuSocketInfo {
            uint16_t srcPort;
            uint16_t dstPort;
            uint32_t srcIp;
            uint32_t dstIp;
            uint32_t gatewayIp;
            uint32_t subnetMask;
            uint16_t udpLength;   // Precomputed length of UDP header and payload
            uint32_t packetSize;
            uint32_t maxPackets;
            _Float32 interval;
        };

        struct GpuNetDevice {
            uint32_t uid;           // Unique identifier for the device
            uint32_t mtu;           // Maximum transmission unit
            uint8_t macAddress[6];  // MAC address
            uint64_t bandwidth;     // Link bandwidth in bits per second (is actually set by using device's data rate)
            uint32_t queueCapacity; // Maximum queue size (in packets)
            uint32_t queueSize;     // Current queue occupancy
            float tokenRate;        // Rate at which tokens are replenished
            float tokens;           // Current tokens available
            uint64_t lastUpdateTime; // Last time the tokens were updated
        };

        struct PacketQueue {
            uint32_t head;
            uint32_t tail;
            uint32_t size;
            uint32_t capacity;
            uint8_t *packets; // Circular buffer for packet storage
        };

        extern GpuSocketInfo *d_socketInfo;
        extern GpuNetDevice *d_netDevice;
        extern uint32_t packet_globalUid; //!< Global counter of packets Uid
        extern uint32_t device_Uid; //!< Global counter of devices Uid

        __host__ void SaveSocketInfoToCuda(const GpuSocketInfo &socketInfo);
        __host__ void SaveDeviceInfoToCuda(const GpuNetDevice &netDevice);
        __global__ void GenerateUdpHeaders(GpuSocketInfo *socketInfo, uint8_t *headers, size_t numPackets);
        // __global__ void GeneratePacket(size_t payloadSize);
        __global__ void GenerateIpUdpPackets(GpuSocketInfo *socketInfo, uint8_t *packets, size_t payloadSize, size_t numPackets);
        __global__ void udpSendKernel(char *packets, int *metadata, int numPackets);
        __global__ void AssemblePacketKernel(uint8_t *ipHeader, uint8_t *udpHeader, uint8_t *payload, uint8_t *packet, uint32_t payloadSize);
    }
}

#endif