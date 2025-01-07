#ifndef CUDA_INTERNET_STACK_HELPER_H
#define CUDA_INTERNET_STACK_HELPER_H

#include "ns3/internet-stack-helper.h"
#include "ns3/cuda-ipv4-l3-protocol.h"
#include "ns3/cuda-udp-l4-protocol.h"
#include "ns3/cuda-ipv4-interface.h"

namespace ns3{
    class Cuda_InternetStackHelper: public InternetStackHelper{
        public:
            Cuda_InternetStackHelper();
            ~Cuda_InternetStackHelper() override;
            void Install(Ptr<Node> node) const override;
            void InstallAll() const override;
            void CreateAndAggregateObjectFromTypeId(Ptr<Node> node, const std::string typeId);
            void Install(std::string nodeName) const;
            void Install(NodeContainer nodes);
    };
}

#endif // CUDA_INTERNET_STACK_HELPER_H