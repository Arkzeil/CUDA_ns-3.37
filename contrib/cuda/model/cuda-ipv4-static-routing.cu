#include "cuda-ipv4-static-routing.h"

namespace ns3{
    CudaIpv4StaticRouting::CudaIpv4StaticRouting(uint32_t capacity) {
        m_capacity = capacity;
        m_size = 0;
        
        // Allocate memory on the device for route entries
        cudaMallocManaged((void**)&m_routes, sizeof(RouteEntry) * capacity);
        
        // Initialize memory to zero
        cudaMemset(m_routes, 0, sizeof(RouteEntry) * capacity);
    }

    CudaIpv4StaticRouting::~CudaIpv4StaticRouting() {
        // Free memory on the device
        cudaFree(m_routes);
    }

    __host__ __device__ bool CudaIpv4StaticRouting::AddRoute(uint32_t network, uint32_t netmask, uint32_t netdevIndex, uint32_t priority) {
        // Ensure network address is properly masked
        network = applyNetmask(network, netmask);
        
        // Check if we already have this route (network/netmask combination)
        for (uint32_t i = 0; i < m_size; i++) {
            if (m_routes[i].network == network && m_routes[i].netmask == netmask) {
                // Update existing entry
                m_routes[i].netdevIndex = netdevIndex;
                m_routes[i].priority = priority;
                return true;
            }
        }
        
        // Add new entry if we have space
        if (m_size < m_capacity) {
            #ifdef __CUDA_ARCH__
                uint32_t idx = atomicAdd(&m_size, 1);
            #else
                uint32_t idx = m_size++;
            #endif
            
            if (idx < m_capacity) {
                m_routes[idx].network = network;
                m_routes[idx].netmask = netmask;
                m_routes[idx].netdevIndex = netdevIndex;
                m_routes[idx].priority = priority;
                return true;
            }
            
            // If we reach here, another thread filled the container
            #ifdef __CUDA_ARCH__
                atomicSub(&m_size, 1);
            #else
                m_size--;
            #endif
        }
        
        return false; // Container is full or add failed
    }

    __host__ __device__ bool CudaIpv4StaticRouting::LookupRoute(uint32_t destIp, uint32_t* netdevIndex) {
        uint32_t bestMatchPrefixLen = 0;
        int32_t bestMatchIndex = -1;
        uint32_t bestMatchPriority = 0;
        bool foundMatch = false;
        
        // Check all routes
        for (uint32_t i = 0; i < m_size; i++) {
            uint32_t maskedDest = applyNetmask(destIp, m_routes[i].netmask);
            // printf("ip: %d, maskedDest: %d, network: %d\n", destIp, maskedDest, m_routes[i].network);
            
            // If this route matches the destination
            if (maskedDest == m_routes[i].network) {
                uint32_t prefixLen = getPrefixLength(m_routes[i].netmask);
                uint32_t priority = m_routes[i].priority;
                
                // Is this a better match?
                // 1. First match found
                // 2. Longer prefix (more specific route)
                // 3. Same prefix but higher priority
                if (!foundMatch || 
                    (prefixLen > bestMatchPrefixLen) || 
                    (prefixLen == bestMatchPrefixLen && priority > bestMatchPriority)) {
                    bestMatchPrefixLen = prefixLen;
                    bestMatchIndex = i;
                    bestMatchPriority = priority;
                    foundMatch = true;
                }
            }
        }
        
        // If we found a matching route
        if (bestMatchIndex >= 0) {
            *netdevIndex = m_routes[bestMatchIndex].netdevIndex;
            return true;
        }
        
        return false; // No matching route found
    }

    __host__ __device__ bool CudaIpv4StaticRouting::RemoveRoute(uint32_t network, uint32_t netmask) {
        // Ensure network address is properly masked
        network = applyNetmask(network, netmask);
        
        for (uint32_t i = 0; i < m_size; i++) {
            if (m_routes[i].network == network && m_routes[i].netmask == netmask) {
                // Move the last element to this position (if not already the last)
                if (i < m_size - 1) {
                    m_routes[i] = m_routes[m_size - 1];
                }
                
                // Decrease size
                #ifdef __CUDA_ARCH__
                    atomicSub(&m_size, 1);
                #else
                    m_size--;
                #endif

                return true;
            }
        }
        
        return false; // Route not found
    }

    __host__ __device__ uint32_t CudaIpv4StaticRouting::size() const{
        return m_size;
    }

    __host__ __device__ void CudaIpv4StaticRouting::clear() {
        m_size = 0;
    }

    __host__ __device__ bool CudaIpv4StaticRouting::getRouteAtIndex(uint32_t index, RouteEntry* entry) {
        if (index >= m_size) {
            return false;
        }
        
        *entry = m_routes[index];
        return true;
    }

    __host__ bool CudaIpv4StaticRouting::addDefaultRoute(uint32_t netdevIndex, uint32_t priority) {
        // Default route has network 0.0.0.0 and netmask 0.0.0.0
        return AddRoute(0, 0, netdevIndex, priority);
    }

    __host__ uint32_t CudaIpv4StaticRouting::applyNetmask(uint32_t address, uint32_t netmask) {
        return address & netmask;
    }

    __host__ inline uint32_t CudaIpv4StaticRouting::getPrefixLength(uint32_t netmask) {
        uint32_t count = 0;
        for (int i = 31; i >= 0; i--) {
            if ((netmask >> i) & 0x1) {
                count++;
            } else {
                break;
            }
        }
        return count;
    }
}