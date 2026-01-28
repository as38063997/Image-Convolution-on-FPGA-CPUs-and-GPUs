# Image Convolution on FPGA, CPUs, and GPUs

**Course:** ECE 1756 – Reconfigurable Computing  
**Institution:** University of Toronto  
**Term:** Fall 2025  
**Author:** Kuan-Yu Chang  

## Overview
This project implements and evaluates a **3×3 image convolution engine** across three computing platforms:
- **FPGA (Intel Arria 10 GX)**
- **CPU (Intel Core i7-11700)**
- **GPU (NVIDIA RTX 3070)**

The goal is to compare **performance, power efficiency, and area efficiency** between hardware-accelerated and general-purpose computing approaches. The FPGA implementation emphasizes **deep pipelining and parallelism**, while the CPU and GPU implementations rely on software optimization and parallel execution models.

---

## Key Features
- Fully pipelined **FPGA convolution engine**
- Processes **512-pixel-wide images** of arbitrary height
- **1 pixel per cycle throughput** after pipeline fill
- Parallel **9-multiplier datapath** with multi-level adder tree
- Detailed comparison against optimized CPU and GPU implementations

---

## FPGA Design

### Architecture
- **Input buffering:**  
  A serial-in/parallel-out (SIPO) shift register stores pixels across image rows to support overlapping 3×3 windows.
- **Datapath:**  
  - 9 parallel multipliers  
  - 3-level adder tree  
  - Fully pipelined to ensure correct timing and high throughput
- **Control logic:**  
  Pixel and row counters manage padding and output validity
- **Output:**  
  Results are clamped to 8-bit grayscale values (0–255)

### Performance (FPGA)
| Metric | Value |
|------|------|
| Max Frequency | **442.28 MHz** |
| ALM Usage | 2,220 |
| DSP Usage | 9 |
| Throughput (single module) | **7.47 GOPS** |
| Throughput (full device, est.) | **1.25 TOPS** |
| Dynamic Power (single module) | **108 mW** |
| Energy Efficiency | **104.4 GOPS/W** |

---

## CPU & GPU Implementations

### CPU
- Nested-loop convolution with optional vectorization
- Tested with compiler optimizations (`O2`, `O3`)
- Multi-threaded execution using 4 threads

### GPU
- CUDA-based convolution
- Uses thread blocks and shared memory
- Optimized for data reuse and parallel execution

### Runtime Comparison (512×512 image, 64 filters)
| Platform | Runtime |
|--------|--------|
| FPGA | **~0.6 ms** |
| GPU | ~0.49 ms |
| CPU (O3, 4 threads) | ~33.8 ms |

---

## Evaluation Summary
- **FPGA** delivers the **highest energy and area efficiency**
- **GPU** offers strong performance but at significantly higher power
- **CPU** performance improves with optimization but remains limited by general-purpose overhead

The FPGA outperforms CPU and GPU in efficiency because it executes **only the operations required for convolution**, without control-flow or scheduling overhead :contentReference[oaicite:0]{index=0}.

---

