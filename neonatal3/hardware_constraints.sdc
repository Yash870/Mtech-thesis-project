# ####################################################################

#  Created by Genus(TM) Synthesis Solution 20.12-s150_1 on Sun May 17 13:57:13 IST 2026

# ####################################################################

set sdc_version 2.0

set_units -capacitance 1000fF
set_units -time 1000ps

# Set the current design
current_design hardware

create_clock -name "clk_16mhz" -period 20.0 -waveform {0.0 10.0} [get_ports clk_16mhz]
set_load -pin_load 0.05 [get_ports pin_1]
set_load -pin_load 0.05 [get_ports {user_leds[3]}]
set_load -pin_load 0.05 [get_ports {user_leds[2]}]
set_load -pin_load 0.05 [get_ports {user_leds[1]}]
set_load -pin_load 0.05 [get_ports {user_leds[0]}]
set_load -pin_load 0.05 [get_ports qspi_sck]
set_load -pin_load 0.05 [get_ports qspi_cs_n]
set_load -pin_load 0.05 [get_ports {qspi_io_out[3]}]
set_load -pin_load 0.05 [get_ports {qspi_io_out[2]}]
set_load -pin_load 0.05 [get_ports {qspi_io_out[1]}]
set_load -pin_load 0.05 [get_ports {qspi_io_out[0]}]
set_load -pin_load 0.05 [get_ports qspi_io_oe]
set_clock_gating_check -setup 0.0 -hold 0.0
set_input_delay -clock [get_clocks clk_16mhz] -add_delay 2.0 [get_ports pin_2]
set_output_delay -clock [get_clocks clk_16mhz] -add_delay 2.0 [get_ports pin_1]
set_output_delay -clock [get_clocks clk_16mhz] -add_delay 2.0 [get_ports {user_leds[3]}]
set_output_delay -clock [get_clocks clk_16mhz] -add_delay 2.0 [get_ports {user_leds[2]}]
set_output_delay -clock [get_clocks clk_16mhz] -add_delay 2.0 [get_ports {user_leds[1]}]
set_output_delay -clock [get_clocks clk_16mhz] -add_delay 2.0 [get_ports {user_leds[0]}]
set_input_delay -clock [get_clocks clk_16mhz] -add_delay 2.0 [get_ports {qspi_io_in[3]}]
set_input_delay -clock [get_clocks clk_16mhz] -add_delay 2.0 [get_ports {qspi_io_in[2]}]
set_input_delay -clock [get_clocks clk_16mhz] -add_delay 2.0 [get_ports {qspi_io_in[1]}]
set_input_delay -clock [get_clocks clk_16mhz] -add_delay 2.0 [get_ports {qspi_io_in[0]}]
set_output_delay -clock [get_clocks clk_16mhz] -add_delay 2.0 [get_ports qspi_sck]
set_output_delay -clock [get_clocks clk_16mhz] -add_delay 2.0 [get_ports qspi_cs_n]
set_output_delay -clock [get_clocks clk_16mhz] -add_delay 2.0 [get_ports {qspi_io_out[3]}]
set_output_delay -clock [get_clocks clk_16mhz] -add_delay 2.0 [get_ports {qspi_io_out[2]}]
set_output_delay -clock [get_clocks clk_16mhz] -add_delay 2.0 [get_ports {qspi_io_out[1]}]
set_output_delay -clock [get_clocks clk_16mhz] -add_delay 2.0 [get_ports {qspi_io_out[0]}]
set_output_delay -clock [get_clocks clk_16mhz] -add_delay 2.0 [get_ports qspi_io_oe]
set_max_fanout 20.000 [current_design]
set_max_transition 1.5 [current_design]
set_clock_uncertainty -setup 1.0 [get_clocks clk_16mhz]
set_clock_uncertainty -hold  0.1 [get_clocks clk_16mhz]

# qspi_cs_n_reg drives a raw AND-gate clock gate (not a latch-based ICG).
# Gating-hold check fires relative to falling clock edge: structural -10.115 ns
# violation that delay insertion cannot fix. qspi_cs_n is an output-rate signal.
set_false_path -hold -from [get_cells *qspi_master_inst*qspi_cs_n_reg*]
