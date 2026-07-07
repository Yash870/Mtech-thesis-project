# 1. Safely initialize the main chip reset
deposit testbench_routing.pin_2 = 0

# 2. THE SURGICAL FIX: Clear the X-state on the exact physical wire driving the inverter.
deposit testbench_routing.dut.FE_OFN74_qspi_cs_n = 0

run
