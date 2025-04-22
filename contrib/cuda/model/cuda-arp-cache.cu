#include "cuda-arp-cache.h"
#include "ns3/cuda-packet.h"
#include "ns3/cuda-ipv4-interface.h"
#include "ns3/cuda-elp-simulator.h"
#include "ns3/cuda-helper.h"

namespace ns3{
    CudaArpCache::CudaArpCache() : m_entryCount(0) {
        // Constructor
        printf("CudaArpCache initialized\n");
        cudaMallocManaged(&m_entries, sizeof(Entry) * MAX_CACHE_SIZE);
    }

    CudaArpCache::~CudaArpCache() {
        // Destructor
        printf("CudaArpCache destroyed\n");
    }

    void CudaArpCache::AddEntry(uint32_t ip, MACAddress mac) {
        // Add an entry to the ARP cache
        if (m_entryCount < MAX_CACHE_SIZE) {
            m_entries[m_entryCount].ip = ip;
            m_entries[m_entryCount++].mac = mac;
        } else {
            // Cache is full, handle accordingly
            printf("ARP cache is full\n");
        }
    }
    bool CudaArpCache::Lookup(uint32_t ip, MACAddress& mac) const {
        // Lookup an entry in the ARP cache
        for (uint32_t i = 0; i < m_entryCount; i++) {
            if (m_entries[i].ip == ip) {
                mac = m_entries[i].mac;
                return true; // Entry found
            }
        }
        return false;
    }
    void CudaArpCache::RemoveEntry(uint32_t ip) {
        // Remove an entry from the ARP cache
        for (uint32_t i = 0; i < m_entryCount; i++) {
            if (m_entries[i].ip == ip) {
                // Shift entries to remove the entry
                for (uint32_t j = i; j < m_entryCount - 1; j++) {
                    m_entries[j] = m_entries[j + 1];
                }
                m_entryCount--;
                return;
            }
        }
    }
    void CudaArpCache::Clear() {
        // Clear the ARP cache
        m_entryCount = 0;
    }

    void CudaArpCache::SetDevice(CudaNetDevice* device, CudaIpv4Interface* interface) {
        // Set the node
        m_device = device;
        m_interface = interface;
    }
    CudaNetDevice* CudaArpCache::GetDevice() const {
        // Get the node
        return m_device;
    }

    CudaIpv4Interface* CudaArpCache::GetInterface() const {
        // Get the node
        return m_interface;
    }
}