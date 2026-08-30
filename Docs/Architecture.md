# Architecture Specification: L1 Cache & AXI4-Lite Bridge

## 1. System Context & Motivation
This IP block was architected to serve as the primary memory interface for a custom virtual SoC containing a 5-stage pipelined RISC-V processor and a Systolic Array matrix accelerator. Because the accelerators and CPU require deterministic, low-latency data access, this module bridges the high-speed local pipeline with a higher-latency, industry-standard AMBA AXI4-Lite main memory bus.

## 2. Cache Datapath Specifications

| Parameter | Specification | Architectural Rationale |
| :--- | :--- | :--- |
| **Mapping** | Direct-Mapped | Minimizes hit latency and combinational logic depth, ideal for single-cycle RISC-V pipeline stages. |
| **Line Size** | 128-bit (4 Words) | Optimizes spatial locality without incurring excessive AXI burst-transfer penalties. |
| **Write Policy** | Write-Through | Guarantees absolute coherence with main memory; eliminates the need for dirty-bit tracking and complex eviction state machines. |
| **Miss Policy** | No-Write-Allocate | Write misses bypass the cache SRAM directly to the AXI bus, preventing cache pollution from single-use data streams. |
| **Alignment** | Byte-Offset Multiplexing | Extracts the specific 32-bit word from the 128-bit line using `addr[3:2]` routing. |

## 3. AXI4-Lite Control Path & FSM
The bridge operates a strict Finite State Machine (FSM) to translate internal pipeline requests into valid AXI4-Lite transactions. It utilizes full decoupling of the address and data channels.

* **Read Operation (Cache Miss):** 
  The FSM drops `req_ready_cpu` to stall the processor. It asserts `ARVALID` with the requested memory address. Upon `ARREADY`, it waits for `RVALID`, latches the 128-bit cache line into the SRAM, updates the Tag Array, and reasserts `req_ready_cpu` to feed the hit data back to the core.
* **Write Operation (Write-Through):**
  The FSM updates the local SRAM (on a hit) and simultaneously asserts `AWVALID` and `WVALID`. The master remains in a wait state until the memory slave asserts `BVALID` on the Write Response channel, ensuring the physical write completed before resuming CPU execution.

## 4. Physical Implementation & Static Timing Analysis (STA)
The RTL has been synthesized and physically implemented using Xilinx Vivado to verify silicon readiness and combinational logic delays.

* **Target Frequency:** 100 MHz (10.000 ns Clock Period)
* **Worst Negative Slack (WNS):** +2.978 ns
* **Worst Hold Slack (WHS):** +0.132 ns
* **Total Negative Slack (TNS):** 0.000 ns
* **Failing Endpoints:** 0 / 428

The positive setup slack (+2.978 ns) confirms that the longest combinational path (the byte-offset multiplexer tree and AXI state transition logic) fully evaluates in ~7 ns, providing significant thermal and voltage margin for physical FPGA deployment.