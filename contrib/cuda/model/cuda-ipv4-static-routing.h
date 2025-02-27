#ifndef CUDA_IPV4_STATIC_ROUTING_H
#define CUDA_IPV4_STATIC_ROUTING_H

#include <cuda_runtime.h>
#include <stdint.h>

#include "helper.h"

// Maximum entries our routing table can hold
#define MAX_ROUTE_ENTRIES 32

namespace ns3{
    // Route entry structure
    struct RouteEntry {
        uint32_t network;      // Network address (e.g., 192.168.1.0)
        uint32_t netmask;      // Network mask (e.g., 255.255.255.0)
        uint32_t netdevIndex;  // Output interface index
        uint32_t priority;     // Route priority (higher value = higher priority)
    };

    class CudaIpv4StaticRouting: public Managed {
        public:
            CudaIpv4StaticRouting(uint32_t capacity = MAX_ROUTE_ENTRIES);
            ~CudaIpv4StaticRouting();

            // Add a static route to the routing table
            __host__ __device__ bool AddRoute(uint32_t network, uint32_t netmask, uint32_t netdevIndex, uint32_t priority = 0);

            // Find the best matching route for an IP address (device function)
            __host__ __device__ bool LookupRoute(uint32_t destIp, uint32_t* netdevIndex);

            // Remove a route entry (device function)
            __host__ __device__ bool RemoveRoute(uint32_t network, uint32_t netmask);

            // Get the route at the specified index
            // RouteEntry GetRoute(uint32_t index);
            // Get current number of routes (device function)
            __host__ __device__ uint32_t size() const;
            // Reset the routing table (device function)
            __host__ __device__ void clear();
            // Get route entry at specific index (device function)
            __host__ __device__ bool getRouteAtIndex(uint32_t index, RouteEntry* entry);
            // Add default route (device function)
            __host__ bool addDefaultRoute(uint32_t netdevIndex, uint32_t priority = 0);
        
        private:
            // Helper function to apply netmask
            __host__ __device__ inline uint32_t applyNetmask(uint32_t address, uint32_t netmask);
            // Helper function to count the number of leading 1s in the netmask (prefix length)
            __host__ __device__ inline uint32_t getPrefixLength(uint32_t netmask);

            RouteEntry* m_routes;   // Array of route entries
            uint32_t m_size;        // Current number of entries
            uint32_t m_capacity;    // Maximum capacity
    };
}

#endif // CUDA_IPV4_STATIC_ROUTING_H