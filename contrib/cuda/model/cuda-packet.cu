#include "cuda-packet.h"

namespace ns3{
    // uint32_t CudaPacket::m_nextUid = 0;
    // global packet id counter
    __managed__ uint32_t g_packetUidCounter = 0;

    __host__ __device__ CudaPacket::CudaPacket()
        : m_data(nullptr), m_size(0), m_capacity(MAX_PACKET_SIZE), m_crc(0) {
        // #ifdef __CUDA_ARCH__
        // m_data = static_cast<uint8_t*>(malloc(m_capacity));
        // #endif
        m_uid = g_packetUidCounter++;
        // printf("*------------------------------------------------*\n");
    }

    __host__ __device__ CudaPacket::~CudaPacket() {
        Free();
    }

    __device__ void CudaPacket::Allocate(uint32_t size) {
        if (size > m_capacity) {
            printf("Error: Packet size exceeds maximum capacity\n");
            return;
        }
        if (m_data == nullptr) {
            // m_data = static_cast<uint8_t*>(malloc(m_capacity));
            cudaMalloc((void**)&m_data, m_capacity);
        }
        m_size = size;
    }

    __host__ __device__ void CudaPacket::Free() {
        if (m_data != nullptr) {
            cudaFree(m_data);
            m_data = nullptr;
        }
        m_size = 0;
    }

    __device__ CudaPacket& CudaPacket::operator=(const CudaPacket& other) {
        if (this != &other) {
            m_size = other.m_size;
            m_capacity = other.m_capacity;
            m_crc = other.m_crc;
            m_uid = other.m_uid;

            // Copy packet data
            if (m_data != nullptr) {
                free(m_data);
            }
            cudaMalloc((void**)&m_data, m_capacity);
            memcpy(m_data, other.m_data, m_size);
        }
        return *this;
    }

    __device__ void CudaPacket::AddHeader(const uint8_t* header, uint32_t headerSize) {
        if (headerSize + m_size > m_capacity) {
            printf("Error: Adding header exceeds packet capacity\n");
            return;
        }
        // memmove(m_data + headerSize, m_data, m_size); // Shift existing data
        memcpy(m_data + headerSize, m_data, m_size); // Shift existing data
        memcpy(m_data, header, headerSize);          // Copy header
        m_size += headerSize;
    }

    __device__ void CudaPacket::AddTrailer(const uint8_t* trailer, uint32_t trailerSize) {
        if (m_size + trailerSize > m_capacity) {
            printf("Error: Adding trailer exceeds packet capacity\n");
            return;
        }
        memcpy(m_data + m_size, trailer, trailerSize); // Append trailer
        m_size += trailerSize;
    }

    __device__ void CudaPacket::ExtractPayload(uint8_t* dstBuffer, uint32_t offset, uint32_t length) const {
        if (offset + length > m_size) {
            printf("Error: Extracting payload exceeds packet size\n");
            return;
        }
        memcpy(dstBuffer, m_data + offset, length);
    }

    __host__ __device__ uint32_t CudaPacket::GetSize() const {
        return m_size;
    }

    __host__ __device__ uint32_t CudaPacket::GetUid() const {
        return m_uid;
    }

    __device__ void CudaPacket::ComputeCRC() {
        // Simple CRC computation (placeholder)
        m_crc = 0;
        for (uint32_t i = 0; i < m_size; i++) {
            m_crc ^= m_data[i];
        }
    }

    __device__ void CudaPacket::PrintContents() const {
        printf("Packet contents: ");
        for (uint32_t i = 0; i < m_size; i++) {
            printf("%02X ", m_data[i]);
        }
        printf("\n");
    }
}