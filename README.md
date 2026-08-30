# Direct-Mapped L1 Cache with AMBA AXI4-Lite Interface

## Project Summary
This repository contains the cycle-accurate RTL design and verification environment for a standalone Direct-Mapped Level 1 (L1) Cache. It is written in SystemVerilog (SV), the IP block features a custom-built AMBA AXI4-Lite master controller to bridge fast, localized CPU memory requests with a slower, standardized main memory bus. The project emphasizes protocol-level verification, utilizing SystemVerilog Assertions (SVA) to formally prove bus handshake compliance and prevent deadlocks. xilinx vivado has been used for the verification and timing report.

## The Role of an L1 Cache in Computer Architecture
In modern computing, the speed of a CPU vastly outpaces the latency of main memory (DRAM). An L1 cache acts as the critical bridge between the two, sitting directly adjacent to the processor core. Built from highly responsive SRAM, its primary job is to hide main memory latency by exploiting two principles:
* **Temporal Locality:** If a memory location is accessed, it is highly likely to be accessed again soon.
* **Spatial Locality:** If a memory location is accessed, nearby memory locations will likely be needed next.

When the CPU requests data, the cache checks if it holds a local copy (a "hit"). If not (a "miss"), the cache stalls the CPU, fetches a larger "block" or "line" of data from main memory over the AXI bus, and stores it locally for future instant access.

## Architecture & Design Specifications
* **Mapping Strategy:** Direct-Mapped
* **Cache Line Size:** 128-bit (4 × 32-bit words per line)
* **Word Extraction:** Byte-offset combinational logic for unaligned word reads.
* **Write Policy:** Write-Through, No-Write-Allocate. 
  * *Write-Through:* On a write hit, data is written to both the cache SRAM and main memory simultaneously, ensuring strict data coherence without requiring complex dirty-bit tracking.
  * *No-Write-Allocate:* On a write miss, the request bypasses the cache entirely and writes directly to main memory over the AXI bus, preventing cache pollution.

## AXI4-Lite Protocol & State Machine
The cache controller manages CPU pipeline stalls by dropping `req_ready_cpu` during cache misses. Concurrently, the AXI4-Lite Finite State Machine (FSM) independently manages transactions across the 5 standard AMBA channels:
1. **Read Address:** Transmits the burst-aligned address for a cache line fill.
2. **Read Data:** Receives the 128-bit line from main memory.
3. **Write Address:** Transmits the exact target address for write-throughs.
4. **Write Data:** Transmits the 32-bit word payload.
5. **Write Response:** Acknowledges the successful physical write to main memory.

## Verification & SVA Integration
The design is rigorously verified against protocol violations using a custom memory slave testbench and temporal logic.
* **SystemVerilog Assertions (SVA):** Implemented concurrent assertions to continuously monitor the bus. 
* **Golden Rule Check:** Formally verified that if the CPU asserts a request (`req_valid_cpu`) while the cache is busy (`!req_ready_cpu`), the CPU is forbidden from dropping the valid signal or changing the address (`$past(req_addr_cpu)`) until the cache is ready.
* **Race Condition Mitigation:** Testbench stimulus leverages non-blocking assignments (`<=`) to align with the SVA Preponed sampling region, ensuring deterministic simulation behavior.

## Tools & Environment
* **Hardware Description Language:** SystemVerilog (SV)
* **Simulation:** Xilinx Vivado 2018.2 (XSim)
* **Synthesis & Timing Analysis:** Xilinx Vivado

## Simulation Quickstart
1. Clone the repository and load the `.sv` files into a Vivado project.
2. Set the top-level simulation module to `cache_tb`.
3. To enable SVA evaluation in older Vivado versions (e.g., 2018.2), run the following in the Tcl console:
   ```tcl
   set_property -name {xsim.elaborate.xelab.more_options} -value {-assert} -objects [get_filesets sim_1]
   launch_simulation
   run 1000ns ```

## Author
Avik Tapadar