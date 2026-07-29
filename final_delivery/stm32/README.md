# STM32 Demonstration Projects

The complete STM32CubeIDE projects used for the final hardware demonstration are stored in [`stm_setting.zip`](stm_setting.zip).

The archive contains both STM32F411RE projects:

- **Sender** — samples the 12-bit ADC, creates the custom frame, transmits identical frames through UART channels A/B every 100 ms, and supports fault-injection modes.
- **Receiver** — receives the Basys3 selected output, parses the frame, verifies CRC/sequence/timeout behavior, restores ADC/voltage data, and prints status to the PC terminal.

The `.ioc`, `Core/Inc`, `Core/Src`, startup, linker, HAL/CMSIS, and CubeIDE project configuration files are retained in the archive.
