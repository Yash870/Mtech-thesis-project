# ####################################################################

#  Created by Genus(TM) Synthesis Solution 20.12-s150_1 on Mon May 25 07:54:25 IST 2026

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
set_clock_gating_check -setup 0.0 
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
set_dont_use false [get_lib_cells tcbn65gplushvttc_ccs/CKLHQD12HVT]
set_dont_use false [get_lib_cells tcbn65gplushvttc_ccs/CKLHQD16HVT]
set_dont_use false [get_lib_cells tcbn65gplushvttc_ccs/CKLHQD1HVT]
set_dont_use false [get_lib_cells tcbn65gplushvttc_ccs/CKLHQD20HVT]
set_dont_use false [get_lib_cells tcbn65gplushvttc_ccs/CKLHQD24HVT]
set_dont_use false [get_lib_cells tcbn65gplushvttc_ccs/CKLHQD2HVT]
set_dont_use false [get_lib_cells tcbn65gplushvttc_ccs/CKLHQD3HVT]
set_dont_use false [get_lib_cells tcbn65gplushvttc_ccs/CKLHQD4HVT]
set_dont_use false [get_lib_cells tcbn65gplushvttc_ccs/CKLHQD6HVT]
set_dont_use false [get_lib_cells tcbn65gplushvttc_ccs/CKLHQD8HVT]
set_dont_use false [get_lib_cells tcbn65gplushvttc_ccs/CKLNQD12HVT]
set_dont_use false [get_lib_cells tcbn65gplushvttc_ccs/CKLNQD16HVT]
set_dont_use false [get_lib_cells tcbn65gplushvttc_ccs/CKLNQD1HVT]
set_dont_use false [get_lib_cells tcbn65gplushvttc_ccs/CKLNQD20HVT]
set_dont_use false [get_lib_cells tcbn65gplushvttc_ccs/CKLNQD24HVT]
set_dont_use false [get_lib_cells tcbn65gplushvttc_ccs/CKLNQD2HVT]
set_dont_use false [get_lib_cells tcbn65gplushvttc_ccs/CKLNQD3HVT]
set_dont_use false [get_lib_cells tcbn65gplushvttc_ccs/CKLNQD4HVT]
set_dont_use false [get_lib_cells tcbn65gplushvttc_ccs/CKLNQD6HVT]
set_dont_use false [get_lib_cells tcbn65gplushvttc_ccs/CKLNQD8HVT]
set_clock_uncertainty -setup 1.0 [get_clocks clk_16mhz]
set_clock_uncertainty -hold 0.5 [get_clocks clk_16mhz]
