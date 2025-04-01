#ifndef CUDA_PACKET_H
#define CUDA_PACKET_H

#include <cuda_runtime.h>
#include <stdint.h>
#include <cstdio>
#include <atomic>
#include "ns3/core-module.h"
#include "ns3/cuda-helper.h"

namespace ns3{    
    // Constants
    constexpr uint32_t MAX_PACKET_SIZE = 2048; // Max size of a packet in bytes

    class CudaPacket{
        public:
            __host__ __device__ CudaPacket();
            __host__ __device__ ~CudaPacket();

            // Memory management
            __host__ __device__ void Allocate(uint32_t size);
            __host__ __device__ void Free();
            // assignment operations
            __device__ CudaPacket& operator=(const CudaPacket& other);
            // Packet operations
            __device__ void AddHeader(void* header, uint32_t headerSize);
            __device__ void AddTrailer(void* trailer, uint32_t trailerSize);
            __device__ void ExtractPayload(uint8_t* dstBuffer, uint32_t offset, uint32_t length) const;
            __host__ __device__ void RemoveHeader(uint32_t headerSize);
            __host__ __device__ uint32_t GetSize() const;
            __host__ __device__ uint32_t GetUid() const;
            __device__ void ComputeCRC();

            // Debugging
            __device__ void PrintContents() const;

            uint8_t* m_data;       // Pointer to packet data in GPU memory
            uint32_t ready;      // Flag to indicate if the packet is ready for processing
            uint32_t m_crc;        // CRC checksum (optional)
        private:
            uint32_t m_uid;          // Unique identifier for the packet
            uint32_t m_size;       // Current size of the packet
            uint32_t m_capacity;   // Maximum capacity of the packet
            // static uint32_t m_nextUid; // Next available unique identifier
    };
}

#endif /* CUDA_PACKET_H */