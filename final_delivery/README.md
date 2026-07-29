# Final Source Delivery

This directory contains the source snapshot used for the final Basys3 SoC redundant UART/RS-422 hardware demonstration.

## Included packages

- `redundant_link_core_source.zip` — redundant-link RTL, AXI register bank, interrupt/event logic, constraints, and self-checking testbenches.
- `sensor_guard_ip_source.zip` — sensor guard AXI IP source and testbench.
- `voltage_display_ip_source.zip` — voltage conversion and FND display IP source, packaged-IP metadata, and testbench.
- `vitis/redundant_link_app/src/` — final MicroBlaze V application changes used for link initialization, Sensor Guard configuration, AXI readback verification, interrupt/event logging, and status output.
- `vivado/` — final integrated Block Design, top wrapper, and Basys3 constraints.
- The complete STM32 sender/receiver CubeIDE projects used for the demonstration are retained in the repository root as `stm_setting.zip`.

Generated Vivado/Vitis/STM32 caches, run directories, object files, and temporary backups are intentionally excluded from this delivery folder.

## Final system

STM32 Sender transmits the same ADC frame through UART channels A and B at 115200 8N1. The Basys3 validates and compares both channels, applies failover/recovery policy, forwards the selected frame, monitors the selected sensor value, and displays voltage on the FND. MicroBlaze V manages AXI configuration, interrupts, event logging, and Sensor Guard status. STM32 Receiver validates and displays the selected output frame.

## Key AXI addresses

- Redundant Link Core: `0x00010000`
- Sensor Guard IP: `0x00020000`
- AXI UARTLite: `0x40600000`
- AXI INTC: `0x41200000`

## Communication settings

- STM32 ↔ Basys3 data link: `115200 8N1`
- MicroBlaze V console: `9600 8N1`
- Frame period: `100 ms`
- Pair wait timeout: `10 ms`
- Channel timeout: `300 ms`
- Fail threshold: `3 consecutive failures`
- Recovery threshold: `5 matching valid frames`
