## ============================================================================
## Basys3 Constraints - Redundant UART/RS-422 Link SoC
##
## Expected external top-level port names:
##   clk, reset_p
##   rs422_rx_a, rs422_rx_b, rs422_tx_out
##   led[15:0], seg[6:0], dp, an[3:0]
##
## Important:
##   - AXI4-Lite and irq remain inside the Block Design and are not FPGA pins.
##   - The three JA signals are 3.3 V single-ended logic between the FPGA and
##     external RS-422 transceivers. Do not connect RS-422 differential A/B
##     wires directly to the Basys3 Pmod pins.
## ============================================================================

## 100 MHz board clock
set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.000 -waveform {0.000 5.000} [get_ports clk]

## Active-high reset: center pushbutton BTNC
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports reset_p]

## ----------------------------------------------------------------------------
## Pmod JA - RS-422 transceiver logic-side signals
##
## JA pin 1 (FPGA J1): Receiver A logic output -> FPGA
## JA pin 2 (FPGA L2): Receiver B logic output -> FPGA
## JA pin 3 (FPGA J2): FPGA -> Transmitter logic input
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN J1 IOSTANDARD LVCMOS33 } [get_ports rs422_rx_a]
set_property -dict { PACKAGE_PIN L2 IOSTANDARD LVCMOS33 } [get_ports rs422_rx_b]
set_property -dict { PACKAGE_PIN J2 IOSTANDARD LVCMOS33 } [get_ports rs422_tx_out]

## UART idle is logic-high. Pull-ups prevent floating inputs when a receiver
## module is disconnected or not powered.
set_property PULLUP true [get_ports rs422_rx_a]
set_property PULLUP true [get_ports rs422_rx_b]

## Conservative output setting for the short FPGA-to-transceiver logic trace.
set_property DRIVE 8 [get_ports rs422_tx_out]
set_property SLEW SLOW [get_ports rs422_tx_out]

## ----------------------------------------------------------------------------
## 16 user LEDs - active-high
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN V19 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports {led[4]}]
set_property -dict { PACKAGE_PIN U15 IOSTANDARD LVCMOS33 } [get_ports {led[5]}]
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports {led[6]}]
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports {led[7]}]
set_property -dict { PACKAGE_PIN V13 IOSTANDARD LVCMOS33 } [get_ports {led[8]}]
set_property -dict { PACKAGE_PIN V3 IOSTANDARD LVCMOS33 } [get_ports {led[9]}]
set_property -dict { PACKAGE_PIN W3 IOSTANDARD LVCMOS33 } [get_ports {led[10]}]
set_property -dict { PACKAGE_PIN U3 IOSTANDARD LVCMOS33 } [get_ports {led[11]}]
set_property -dict { PACKAGE_PIN P3 IOSTANDARD LVCMOS33 } [get_ports {led[12]}]
set_property -dict { PACKAGE_PIN N3 IOSTANDARD LVCMOS33 } [get_ports {led[13]}]
set_property -dict { PACKAGE_PIN P1 IOSTANDARD LVCMOS33 } [get_ports {led[14]}]
set_property -dict { PACKAGE_PIN L1 IOSTANDARD LVCMOS33 } [get_ports {led[15]}]

## ----------------------------------------------------------------------------
## Four-digit seven-segment display - active-low
##
## status_display.v uses:
##   seg[6:0] = {g, f, e, d, c, b, a}
## Therefore seg[0] drives segment A and seg[6] drives segment G.
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN W7 IOSTANDARD LVCMOS33 } [get_ports {seg[0]}]
set_property -dict { PACKAGE_PIN W6 IOSTANDARD LVCMOS33 } [get_ports {seg[1]}]
set_property -dict { PACKAGE_PIN U8 IOSTANDARD LVCMOS33 } [get_ports {seg[2]}]
set_property -dict { PACKAGE_PIN V8 IOSTANDARD LVCMOS33 } [get_ports {seg[3]}]
set_property -dict { PACKAGE_PIN U5 IOSTANDARD LVCMOS33 } [get_ports {seg[4]}]
set_property -dict { PACKAGE_PIN V5 IOSTANDARD LVCMOS33 } [get_ports {seg[5]}]
set_property -dict { PACKAGE_PIN U7 IOSTANDARD LVCMOS33 } [get_ports {seg[6]}]
set_property -dict { PACKAGE_PIN V7 IOSTANDARD LVCMOS33 } [get_ports dp]

set_property -dict { PACKAGE_PIN U2 IOSTANDARD LVCMOS33 } [get_ports {an[0]}]
set_property -dict { PACKAGE_PIN U4 IOSTANDARD LVCMOS33 } [get_ports {an[1]}]
set_property -dict { PACKAGE_PIN V4 IOSTANDARD LVCMOS33 } [get_ports {an[2]}]
set_property -dict { PACKAGE_PIN W4 IOSTANDARD LVCMOS33 } [get_ports {an[3]}]

## Basys3 configuration-bank voltage
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]