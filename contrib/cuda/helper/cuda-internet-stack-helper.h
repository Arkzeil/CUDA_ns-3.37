#ifndef CUDA_INTERNET_STACK_HELPER_H
#define CUDA_INTERNET_STACK_HELPER_H

#include "ns3/internet-stack-helper.h"
#include <cuda_runtime.h>

namespace ns3{
    class Node;
    class Ipv4RoutingHelper;
    class Ipv6RoutingHelper;
    
    class Cuda_InternetStackHelper: public InternetStackHelper{
        public:
            Cuda_InternetStackHelper();
            ~Cuda_InternetStackHelper();
            void Reset();
            void SetTcp(const std::string tid);
            void SetRoutingHelper(const Ipv4RoutingHelper& routing);
            void SetRoutingHelper(const Ipv6RoutingHelper& routing);
            void SetIpv4StackInstall(bool enable);
            void SetIpv6StackInstall(bool enable);
            void SetIpv4ArpJitter(bool enable);
            void SetIpv6NsRsJitter(bool enable);
            void Install(std::string nodeName) const;
            void Install(Ptr<Node> node) const;
            void Install(NodeContainer c) const;
            void InstallAll() const;
        private:
            /**
             * \brief Initialize the helper to its default values
             */
            void Initialize();

            /**
             * \brief TCP objects factory
             */
            ObjectFactory m_tcpFactory;

            /**
             * \brief IPv4 routing helper.
             */
            const Ipv4RoutingHelper* m_routing;

            /**
             * \brief IPv6 routing helper.
             */
            const Ipv6RoutingHelper* m_routingv6;

            /**
             * \brief create an object from its TypeId and aggregates it to the node
             * \param node the node
             * \param typeId the object TypeId
             */
            static void CreateAndAggregateObjectFromTypeId(Ptr<Node> node, const std::string typeId);

            /**
             * \brief IPv4 install state (enabled/disabled) ?
             */
            bool m_ipv4Enabled;

            /**
             * \brief IPv6 install state (enabled/disabled) ?
             */
            bool m_ipv6Enabled;

            /**
             * \brief IPv4 ARP Jitter state (enabled/disabled) ?
             */
            bool m_ipv4ArpJitterEnabled;

            /**
             * \brief IPv6 IPv6 NS and RS Jitter state (enabled/disabled) ?
             */
            bool m_ipv6NsRsJitterEnabled;
    };
}

#endif // CUDA_INTERNET_STACK_HELPER_H