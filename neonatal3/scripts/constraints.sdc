## =========================================================================
## 1. CLOCK DEFINITIONS
## =========================================================================

# System Clock (16 MHz target based on top module clk_16mhz)
set SYS_CLK_NAME "clk_16mhz"
# Period internally in nanoseconds: 1/16MHz = 62.5ns
set SYS_CLK_PERIOD 20.0

create_clock -name "$SYS_CLK_NAME" -period "$SYS_CLK_PERIOD" -waveform "0 [expr $SYS_CLK_PERIOD/2]" [get_ports clk_16mhz]

# Standard Units
set_units -time 1.0ns
set_units -capacitance 1.0pF

# Margins 
# (Since 16MHz is very slow, we can use generous margins, but we keep setup robust)
set SETUP 1.0
set HOLD  0.5
set INDELAY  2.0
set OUTDELAY 2.0

# Clock Uncertainty (Jitter margin)
set_clock_uncertainty -setup $SETUP [get_clocks $SYS_CLK_NAME]
set_clock_uncertainty -hold  $HOLD  [get_clocks $SYS_CLK_NAME]


## =========================================================================
## 2. I/O DELAY DEFINITIONS (Relative to System Clock)
## =========================================================================

# --- UART INTERFACE ---
# UART RX (Input)
set_input_delay -clock [get_clocks $SYS_CLK_NAME] -add_delay $INDELAY [get_ports pin_2]

# UART TX (Output)
set_output_delay -clock [get_clocks $SYS_CLK_NAME] -add_delay $OUTDELAY [get_ports pin_1]


# --- LED INTERFACE ---
# User LEDs (Output)
set_output_delay -clock [get_clocks $SYS_CLK_NAME] -add_delay $OUTDELAY [get_ports {user_leds[*]}]


# --- QSPI FLASH INTERFACE ---
# QSPI Inputs
set_input_delay -clock [get_clocks $SYS_CLK_NAME] -add_delay $INDELAY [get_ports {qspi_io_in[*]}]

# QSPI Outputs
set_output_delay -clock [get_clocks $SYS_CLK_NAME] -add_delay $OUTDELAY [get_ports qspi_sck]
set_output_delay -clock [get_clocks $SYS_CLK_NAME] -add_delay $OUTDELAY [get_ports qspi_cs_n]
set_output_delay -clock [get_clocks $SYS_CLK_NAME] -add_delay $OUTDELAY [get_ports {qspi_io_out[*]}]
set_output_delay -clock [get_clocks $SYS_CLK_NAME] -add_delay $OUTDELAY [get_ports qspi_io_oe]


## =========================================================================
## 3. OPERATING CONDITIONS / DESIGN RULES
## =========================================================================

# Set default load on all outputs (50fF standard)
set_load 0.05 [all_outputs]

# Set maximum transition times to ensure good signal integrity
set_max_transition 1.5 [current_design]

# Set maximum fanout limits
set_max_fanout 20 [current_design]
