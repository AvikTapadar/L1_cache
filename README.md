# Direct-Mapped L1 Cache with AXI4-Lite Interface

## Overview
This repository contains the RTL design and verification environment for a cycle-accurate, Direct-Mapped L1 Cache. It features a custom AXI4-Lite master controller to bridge standard CPU memory requests to a main memory bus. This module was designed as a critical subsystem for a custom SoC integrating a 5-stage pipelined RISC-V processor and a Systolic Array accelerator.

## Architecture Highlights
* **Mapping:** Direct-Mapped
* **Line Size:** 128-bit (4 x 32-bit words per line)
* **Write Policy:** Write-Through, No-Write-Allocate
* **Addressing:** Byte-offset logic for unaligned word extraction
* **Bus Interface:** AMBA AXI4-Lite Master (32-bit address/data)

## Protocol Handling & State Machines
The cache controller manages memory stalls using `req_ready_cpu` to exert back-pressure on the pipeline during cache misses. The AXI4-Lite FSM independently manages the 5 standard channels:
1. Read Address (`AR`)
2. Read Data (`R`)
3. Write Address (`AW`)
4. Write Data (`W`)
5. Write Response (`B`)

## Verification Strategy
Verified using **SystemVerilog Assertions (SVA)** in Xilinx Vivado (XSim) and Cadence Xcelium. 
* Designed a custom memory slave testbench to emulate AXI transaction delays.
* Implemented concurrent temporal assertions to formally verify valid/ready handshakes.
* **Key Assertion:** Ensured the CPU `req_valid_cpu` and `req_addr_cpu` signals are held constant during wait states (`!req_ready_cpu`), preventing protocol deadlocks.

## Tools Used
* **Simulation:** Vivado 2018.2 Simulator (XSim), Cadence Xcelium
* **Synthesis & Implementation:** Xilinx Vivado
* **Languages:** SystemVerilog (IEEE 1800-2012)

## How to Run Simulation (Vivado)
1. Clone the repository and add `.sv` files to a new Vivado project.
2. Ensure the top-level simulation module is set to `cache_tb`.
3. In the Tcl console, enable SVA and run:
   ```tcl
   launch_simulation
   run 1000ns
   ```