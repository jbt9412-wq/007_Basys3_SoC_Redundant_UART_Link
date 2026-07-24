# Basys3 SoC Redundant UART Link

Vivado project snapshot for a redundant dual-channel UART/RS-422 link targeting
the Basys3 Artix-7 device (`xc7a35tcpg236-1`).

## Project structure

- `redundant_link.xpr`: Vivado project
- `redundant_link.srcs/sources_1/new/`: synthesizable RTL
- `redundant_link.srcs/sim_1/new/`: self-checking testbenches
- `redundant_link.srcs/constrs_1/new/`: Basys3 pin and timing constraints

The data path includes dual UART receivers, frame parsing, CRC and sequence
checking, frame FIFOs, pair matching, channel health tracking, decision and
duplicate filtering, output buffering, and UART transmission.

The management path includes event arbitration, an event FIFO, AXI4-Lite
registers, interrupt generation, and the Basys3 LED/7-segment status display.

## Register map

The AXI4-Lite register bank uses 32-bit registers at 4-byte-aligned offsets from
`0x00` through `0x40`. See `axi_lite_regs.v` for field definitions.

## Verification status

This repository preserves the current Vivado workspace exactly as uploaded.
RTL and testbench source files were not modified as part of publication.

- 14 of 15 standalone module testbenches passed in Vivado Simulator 2024.2.
- `tb_channel_health_mgr` currently reports two failures.
- `redundant_link_core` currently has interface-version mismatches with several
  lower-level modules and does not complete static elaboration.
- No synthesis, timing, or DRC reports were present in the workspace at upload
  time.

## Generated files

Vivado-generated `.runs`, `.cache`, `.sim`, `.Xil`, and related output
directories are intentionally excluded. Re-run synthesis and implementation
locally to regenerate build products and reports.
