# Basys3 SoC Redundant UART Link

Vivado project and final source delivery for a redundant dual-channel UART/RS-422 link targeting the Basys3 Artix-7 device (`xc7a35tcpg236-1`).

## Final integrated system

```text
STM32 Sender
  ├─ UART / RS-422 Channel A ─┐
  └─ UART / RS-422 Channel B ─┤
                              ▼
                         Basys3 SoC
                  ┌───────────────────────────┐
                  │ redundant_link_core       │
                  │ sensor_guard_ip           │
                  │ voltage_display_ip        │
                  │ MicroBlaze V + AXI/IRQ    │
                  └───────────────────────────┘
                              │
                       Selected UART output
                              ▼
                       STM32 Receiver
```

The data path performs dual UART reception, frame parsing, CRC and sequence checking, pair matching, channel-health tracking, failover/recovery, selected-frame forwarding, sensor monitoring, and FND voltage display. MicroBlaze V configures the AXI peripherals and manages interrupts, event logs, and Sensor Guard status.

## Final source delivery

The source snapshot used for the final hardware demonstration is under [`final_delivery/`](final_delivery/README.md).

It includes:

- clean source package for `redundant_link_core`
- clean source package for `sensor_guard_ip`
- clean source package for `voltage_display_ip`
- final Vivado integration description, wrapper, and XDC
- final Vitis application changes including Sensor Guard support
- reference to the complete final STM32 sender/receiver projects

## Key configuration

- STM32 ↔ Basys3: `115200 8N1`
- MicroBlaze V console: `9600 8N1`
- Frame period: `100 ms`
- Pair wait timeout: `10 ms`
- Channel timeout: `300 ms`
- Failure threshold: `3`
- Recovery threshold: `5`

## AXI address map

- Redundant Link Core: `0x00010000-0x00010FFF`
- Sensor Guard IP: `0x00020000-0x00020FFF`
- AXI UARTLite: `0x40600000`
- AXI INTC: `0x41200000`

## Verification status

- Final Vivado 2024.2 implementation completed with 0 failed routes.
- Setup timing: WNS `+0.137 ns`, TNS `0`.
- Hold timing: WHS `+0.007 ns`, THS `0`.
- Bitstream and hardware XSA were generated.
- MicroBlaze V application was built and executed on the Basys3.
- The complete integrated system was used for the final hardware demonstration video.

Generated Vivado `.runs`, `.cache`, `.sim`, `.Xil`, Vitis build outputs, and STM32 Debug object files are not treated as authoritative source files.
