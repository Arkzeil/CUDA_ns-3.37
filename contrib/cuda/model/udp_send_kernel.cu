#include "udp_send_kernel.h"

namespace ns3{
    namespace cuda{
        GpuSocketInfo *d_socketInfo = nullptr;  // Socket information in device memory (global)
        GpuNetDevice *d_netDevice = nullptr;    // Network device information in device memory (should not be global)
        uint32_t packet_globalUid = 0; //!< Global counter of packets Uid
        uint32_t device_Uid = 0; //!< Global counter of devices Uid


        __device__ bool Enqueue(PacketQueue *queue, uint8_t *packet, uint32_t packetSize) {
            if (queue->size >= queue->capacity) {
                return false; // Queue full, packet dropped
            }

            // Copy packet to the queue
            memcpy(&queue->packets[queue->tail * packetSize], packet, packetSize);
            queue->tail = (queue->tail + 1) % queue->capacity;
            queue->size++;
            return true;
        }

        __device__ bool Dequeue(PacketQueue *queue, uint8_t *packet, uint32_t packetSize) {
            if (queue->size == 0) {
                return false; // Queue empty
            }

            // Copy packet from the queue
            memcpy(packet, &queue->packets[queue->head * packetSize], packetSize);
            queue->head = (queue->head + 1) % queue->capacity;
            queue->size--;
            return true;
        }

        __host__ void SaveSocketInfoToCuda(const GpuSocketInfo &socketInfo){
            // static GpuSocketInfo *d_socketInfo = nullptr;
            // d_socketInfo = nullptr;

            if (!d_socketInfo) {
                cudaMalloc((void**)&d_socketInfo, sizeof(GpuSocketInfo));
            }
            cudaMemcpy(d_socketInfo, &socketInfo, sizeof(GpuSocketInfo), cudaMemcpyHostToDevice);
        }

        __host__ void SaveDeviceInfoToCuda(const GpuNetDevice &netDevice){
            // static GpuNetDevice *d_netDevice = nullptr;
            // d_netDevice = nullptr;

            if (!d_netDevice) {
                cudaMalloc((void**)&d_netDevice, sizeof(GpuNetDevice));
            }
            // printf("allocating device memory\n");
            cudaMemcpy(d_netDevice, &netDevice, sizeof(GpuNetDevice), cudaMemcpyHostToDevice);

            // printf("Device info saved to CUDA\n");
            printf("Device uid: %d\n", netDevice.uid);
            printf("Device mtu: %d\n", netDevice.mtu);
            for(int i = 0; i < 6; i++){
                printf("%d:", netDevice.macAddress[i]);
            }
            printf("\nDevice bandwidth: %lu\n", netDevice.bandwidth);
            printf("Device queue capacity: %d\n", netDevice.queueCapacity);
            printf("Device queue size: %d\n", netDevice.queueSize);
            printf("Device token rate: %f\n", netDevice.tokenRate);
            printf("Device token: %f\n", netDevice.tokens);
            printf("Device lastupdate time: %ld\n", netDevice.lastUpdateTime);
        }

        __device__ uint32_t GetNextHop(uint32_t dstIp, uint32_t srcIp, uint32_t subnetMask, uint32_t gatewayIp) {
            if ((dstIp & subnetMask) == (srcIp & subnetMask)) {
                return dstIp;  // Local destination
            } else {
                return gatewayIp;  // Route via gateway
            }
        }

        __device__ void ConstructEthernetHeader(uint8_t *packet, uint8_t *srcMac, uint8_t *dstMac) {
            memcpy(packet, dstMac, 6);  // Destination MAC
            memcpy(packet + 6, srcMac, 6);  // Source MAC
            packet[12] = 0x08;  // Type: IPv4
            packet[13] = 0x00;
        }

        // __global__ void GenerateUdpHeaders(GpuSocketInfo *socketInfo, uint8_t *headers, size_t numPackets) {
        //     int packetIdx = blockIdx.x * blockDim.x + threadIdx.x;
        //     if (packetIdx < numPackets) {
        //         // Get header buffer for the packet
        //         uint8_t *header = &headers[packetIdx * HEADER_SIZE];

        //         // Fill static fields from socket info
        //         GpuSocketInfo info = *socketInfo;
        //         header[0] = (info.srcPort >> 8) & 0xFF;  // Source port (high byte)
        //         header[1] = info.srcPort & 0xFF;         // Source port (low byte)
        //         header[2] = (info.dstPort >> 8) & 0xFF;  // Destination port (high byte)
        //         header[3] = info.dstPort & 0xFF;         // Destination port (low byte)

        //         // Fill dynamic fields
        //         uint16_t length = HEADER_SIZE + PAYLOAD_SIZE;
        //         header[4] = (length >> 8) & 0xFF;  // Length (high byte)
        //         header[5] = length & 0xFF;         // Length (low byte)

        //         // Compute checksum (simplified example)
        //         uint16_t checksum = info.checksumBase + packetIdx;
        //         header[6] = (checksum >> 8) & 0xFF;  // Checksum (high byte)
        //         header[7] = checksum & 0xFF;         // Checksum (low byte)
        //     }
        // }

        // __global__ void GeneratePacket(size_t payloadSize) {
            // int threadId = blockIdx.x * blockDim.x + threadIdx.x;

            // // Retrieve socket information from the CUDA context
            // __shared__ GpuSocketInfo socketInfo;
            // if (threadId == 0) {
            //     socketInfo = *d_socketInfo;  // Assume `d_socketInfo` is already initialized
            // }
            // __syncthreads();

            // // Construct UDP header
            // uint8_t header[HEADER_SIZE];
            // header[0] = (socketInfo.srcPort >> 8) & 0xFF;  // Source port (high byte)
            // header[1] = socketInfo.srcPort & 0xFF;         // Source port (low byte)
            // header[2] = (socketInfo.dstPort >> 8) & 0xFF;  // Destination port (high byte)
            // header[3] = socketInfo.dstPort & 0xFF;         // Destination port (low byte)
            // header[4] = (payloadSize >> 8) & 0xFF;         // Length (high byte)
            // header[5] = payloadSize & 0xFF;                // Length (low byte)

            // Simulate payload generation (can remain virtual)
            // ProcessPayload(payloadSize);
        // }

        __global__ void GenerateIpUdpPackets(
            GpuSocketInfo *socketInfo, uint8_t *packets, size_t payloadSize, size_t numPackets) {
            int packetIdx = blockIdx.x * blockDim.x + threadIdx.x;
            if (packetIdx < numPackets) {
                // Pointer to the packet buffer for this packet
                uint8_t *packet = &packets[packetIdx * (IP_HEADER_SIZE + UDP_HEADER_SIZE + payloadSize)];

                // Construct IP header
                packet[0] = 0x45;  // Version (IPv4) and Header Length
                packet[1] = 0;     // Type of Service (ToS)
                uint16_t totalLength = IP_HEADER_SIZE + socketInfo->udpLength;
                packet[2] = (totalLength >> 8) & 0xFF;
                packet[3] = totalLength & 0xFF;
                packet[4] = 0; packet[5] = 0;  // Identification
                packet[6] = 0x40; packet[7] = 0;  // Flags and Fragment Offset
                packet[8] = 64;  // Time to Live (TTL)
                packet[9] = 17;  // Protocol (UDP)

                // Source IP
                uint32_t srcIp = socketInfo->srcIp;
                packet[12] = (srcIp >> 24) & 0xFF;
                packet[13] = (srcIp >> 16) & 0xFF;
                packet[14] = (srcIp >> 8) & 0xFF;
                packet[15] = srcIp & 0xFF;

                // Destination IP
                uint32_t dstIp = socketInfo->dstIp;
                packet[16] = (dstIp >> 24) & 0xFF;
                packet[17] = (dstIp >> 16) & 0xFF;
                packet[18] = (dstIp >> 8) & 0xFF;
                packet[19] = dstIp & 0xFF;

                // Checksum (set to 0 in simplified implementation)
                packet[10] = 0; packet[11] = 0;

                // Construct UDP header (similar to earlier kernel)
                uint8_t *udpHeader = &packet[IP_HEADER_SIZE];
                udpHeader[0] = (socketInfo->srcPort >> 8) & 0xFF;  // Source port (high byte)
                udpHeader[1] = socketInfo->srcPort & 0xFF;         // Source port (low byte)
                udpHeader[2] = (socketInfo->dstPort >> 8) & 0xFF;  // Destination port (high byte)
                udpHeader[3] = socketInfo->dstPort & 0xFF;         // Destination port (low byte)
                udpHeader[4] = (socketInfo->udpLength >> 8) & 0xFF;  // Length (high byte)
                udpHeader[5] = socketInfo->udpLength & 0xFF;         // Length (low byte)
                udpHeader[6] = 0; udpHeader[7] = 0;  // Checksum (simplified to 0)
                
                // Simulated payload (optional: add patterns or data)
                uint8_t *payload = &packet[IP_HEADER_SIZE + UDP_HEADER_SIZE];
                for (size_t i = 0; i < payloadSize; ++i) {
                    payload[i] = 0;  // Zero-fill payload for simplicity
                }
            }
        }

        __global__ void udpSendKernel(char *packets, int *metadata, int numPackets) {
            int idx = blockIdx.x * blockDim.x + threadIdx.x;
            if (idx < numPackets) {
                // Example: Process packet metadata and populate packet buffer
                packets[idx] = metadata[idx]; // Simplified
            }
        }

        __global__ void AssemblePacketKernel(uint8_t *ipHeader, uint8_t *udpHeader, uint8_t *payload, uint8_t *packet, uint32_t payloadSize) {
            // Concatenate IP, UDP headers, and payload
            int idx = threadIdx.x;
            // printf("idx: %d\n", idx);
            if (idx < 20) {
                packet[idx] = ipHeader[idx];
            } else if (idx < 28) {
                packet[idx] = udpHeader[idx - 20];
            } else if (idx < 28 + payloadSize) {
                packet[idx] = payload[idx - 28];
            }
        }
    }
}

