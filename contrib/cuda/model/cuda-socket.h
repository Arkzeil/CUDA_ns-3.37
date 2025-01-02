#ifndef CUDA_SOCKET_H
#define CUDA_SOCKET_H

#include "ns3/socket.h"
#include "ns3/node.h"
#include "ns3/udp-l4-protocol.h"
#include "ns3/ipv4-end-point.h"
#include <cuda_runtime.h>
#include <queue>
#include "helper.h"
#include "cuda-net-device.h"

namespace ns3{
    class CudaUdpL4Protocol;

    class CudaSocket : public Socket, public Managed{
        public:
            static TypeId GetTypeId(void);
            
            CudaSocket();
            virtual ~CudaSocket();
            // must be static to be called from other classes
            static CudaSocket *CreateSocket(Ptr<Node> node);
            int FinishBind();
            int Bind() override;
            int Bind(const Address& address) override;
            int Bind6() override;
            int Close() override;
            int Connect(const Address& address) override;
            int Listen() override;
            int ShutdownRecv() override;
            int ShutdownSend() override;
            int Send(Ptr<Packet> p, uint32_t flags) override;
            __device__ void Send(const uint8_t* d_buffer, uint32_t size);
            Ptr<Packet> Recv(uint32_t maxSize, uint32_t flags) override;
            Ptr<Packet> RecvFrom(uint32_t maxSize, uint32_t flags, Address& fromAddress) override;
            int GetSockName(Address& address) const override;
            
            uint32_t GetTxAvailable() const override;
            int SendTo(Ptr<Packet> p, uint32_t flags, const Address& address) override;
            uint32_t GetRxAvailable() const override;
            enum SocketErrno GetErrno() const override;
            enum SocketType GetSocketType() const override;
            Ptr<Node> GetNode() const override;
            void SetUdp(CudaUdpL4Protocol *udp);
            void SetNode(Ptr<Node> node);
            int GetPeerName(Address& address) const override;
            bool SetAllowBroadcast(bool allowBroadcast) override;
            bool GetAllowBroadcast() const override;

            // void SetRecvCallback(Callback<void, Ptr<Socket>> receivedData) override;
        private:
            uint8_t* d_sendBuffer;
            cudaStream_t m_cudaStream;
            CudaNetDevice *m_netDevice;
            // Connections to other layers of TCP/IP
            static Ipv4EndPoint* m_endPoint;  //!< the IPv4 endpoint
            // Ipv6EndPoint* m_endPoint6; //!< the IPv6 endpoint
            static Ptr<Node> m_node;          //!< the associated node
            static CudaUdpL4Protocol *m_udp;  //!< the associated UDP L4 protocol
            Callback<void, Ipv4Address, uint8_t, uint8_t, uint8_t, uint32_t>
                m_icmpCallback; //!< ICMP callback
            // Callback<void, Ipv6Address, uint8_t, uint8_t, uint8_t, uint32_t>
            //     m_icmpCallback6; //!< ICMPv6 callback

            Address *m_defaultAddress;                      //!< Default address
            uint16_t *m_defaultPort;                        //!< Default port
            // TracedCallback<Ptr<const Packet>> m_dropTrace; //!< Trace for dropped packets

            mutable enum SocketErrno m_errno; //!< Socket error code
            bool m_shutdownSend;              //!< Send no longer allowed
            bool m_shutdownRecv;              //!< Receive no longer allowed
            bool m_connected;                 //!< Connection established
            bool m_allowBroadcast;            //!< Allow send broadcast packets

            std::queue<std::pair<Ptr<Packet>, Address>> m_deliveryQueue; //!< Queue for incoming packets
            uint32_t m_rxAvailable; //!< Number of available bytes to be received

            // Socket attributes
            uint32_t m_rcvBufSize;    //!< Receive buffer size
            uint8_t m_ipMulticastTtl; //!< Multicast TTL
            int32_t m_ipMulticastIf;  //!< Multicast Interface
            bool m_ipMulticastLoop;   //!< Allow multicast loop
            bool m_mtuDiscover;       //!< Allow MTU discovery

            // Send function
            void SendToNetDevice(const uint8_t* d_buffer, uint32_t size);
    };
}

#endif // CUDA_SOCKET_H