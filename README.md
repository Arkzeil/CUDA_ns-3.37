# Parallel ns-3 Network Simulations on GPU 

## Intorduction
This repository implements a GPU-accelerated ns-3 network simulator based on Event-Level Parallelism (ELP). 
While many network simulators, including ns-3, are inherently single-threaded and limited in scalability, this project leverages the massive number of cores in a GPU (such as the NVIDIA H100) to execute safe simulation events in parallel.

## Implementation
The implementation resides within the `contrib/*` directory. 
This implementation serves as a proof of concept of GPU-accelerated event-level parallelism in network simulation.

To support event-level parallelism on the GPU, we need to execute a wide range of ns-3 simulation events entirely inside CUDA kernels—without any
CPU-side intervention once the kernel is launched. This includes:
+ Packet forwarding and header handling logic
+ Bridge logic for multi-interface forwarding
+ UDP send/receive application logic
+ Other network stack objects and processing logics, e.g., net device, socket, channel, etc.

**Acknowledgement**: This repository is derived from the original [ns-3 GitHub implementation](https://github.com/nsnam/ns-3-dev-git/tree/ns-3.37).

## Environments
The following information states the environment of our testbed:
+ OS: Ubuntu 20.04
+ Kernel Version: 5.15
+ ns-3 Version: 3.37 (-0s optimization)
+ nvcc: 12.8
+ GCC: 9.4.0
