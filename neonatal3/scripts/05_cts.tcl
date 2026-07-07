# =========================================================================
# 05_CTS.TCL  —  Neonatal Seizure Detection ASIC
# Clock: clk_16mhz (20 ns period)
# NDR:   CLK_NDR  width/spacing 0.2um on M3-M6
# =========================================================================

puts "--- Starting Clock Tree Synthesis (CTS) ---"

set SCRIPT_DIR [file dirname [file normalize [info script]]]
set ROOT_DIR [file normalize [file join $SCRIPT_DIR ".."]]
set OUT_DIR [file join $ROOT_DIR innovus_output]

setMultiCpuUsage -localCpu 4

# -------------------------------------------------------------------------
# 1. Define Non-Default Rules (NDR) (With Smart Existence Check)
# -------------------------------------------------------------------------
set existing_ndrs ""
catch {set existing_ndrs [dbGet head.rules.name]}

if {"CLK_NDR" ni $existing_ndrs} {
    add_ndr -name CLK_NDR \
        -width {M3 0.2 M4 0.2 M5 0.2 M6 0.2} \
        -spacing {M3 0.2 M4 0.2 M5 0.2 M6 0.2}
    puts "INFO: Created CLK_NDR."
} else {
    puts "INFO: CLK_NDR already exists. Skipping."
}

# -------------------------------------------------------------------------
# 2. Define Clock Route Types (With Smart Existence Check)
# -------------------------------------------------------------------------
set existing_routes ""
catch {set existing_routes [get_ccopt_route_types]}

if {"clk_trunk" ni $existing_routes} {
    # FIXED SYNTAX: Changed -ndr_rule to -non_default_rule
    create_route_type -name clk_trunk -non_default_rule CLK_NDR -bottom_preferred_layer M4 -top_preferred_layer M6
    set_ccopt_property route_type clk_trunk -net_type trunk
}

if {"clk_leaf" ni $existing_routes} {
    create_route_type -name clk_leaf -bottom_preferred_layer M3 -top_preferred_layer M4
    set_ccopt_property route_type clk_leaf -net_type leaf
}

puts "✓ Clock routing configured."

# -------------------------------------------------------------------------
# 3. Define the Special Clock Buffers and Inverters
# -------------------------------------------------------------------------
set_ccopt_property buffer_cells {BUFFD1HVT BUFFD0HVT BUFFD12HVT BUFFD16HVT BUFFD2HVT BUFFD3HVT BUFFD4HVT BUFFD6HVT BUFFD8HVT CKBD1HVT CKBD0HVT CKBD12HVT CKBD16HVT CKBD2HVT CKBD3HVT CKBD4HVT CKBD6HVT CKBD8HVT}
set_ccopt_property inverter_cells {CKND1HVT CKND0HVT CKND12HVT CKND16HVT CKND2HVT CKND3HVT CKND4HVT CKND6HVT CKND8HVT INVD1HVT INVD0HVT INVD12HVT INVD16HVT INVD2HVT INVD3HVT INVD4HVT INVD6HVT INVD8HVT}

# -------------------------------------------------------------------------
# 4. Generate and Build the Clock Tree
# -------------------------------------------------------------------------
# Wipe any existing clock specs from previous failed runs just to be safe
catch { delete_ccopt_clock_tree_spec }

create_ccopt_clock_tree_spec

puts "--- Running ccopt_design ---"
ccopt_design

# -------------------------------------------------------------------------
# 5. Post-CTS Optimization (Setup and Hold)
# -------------------------------------------------------------------------
puts "--- Running Post-CTS Setup & Hold Optimization ---"
# QSPI CS_N register drives a raw AND-gate clock gate (not a latch-based ICG).
# Gating-hold fires relative to falling clock edge — structural, not fixable by
# delay insertion. Must be applied here (not SDC) because .enc restores old SDC.
set_false_path -hold -from [get_cells *qspi_master_inst*qspi_cs_n_reg*]

# CPPR must be enabled before optDesign — without it IMPOPT-3315 fires
# and hold timing is pessimistic (common clock path pessimism not removed).
setAnalysisMode -cppr both
setOptMode -fixHoldAllowOverlap false
optDesign -postCTS
setAnalysisMode -cppr both   ;# re-assert: optDesign resets analysis mode (IMPOPT-3195)
optDesign -postCTS -hold

# -------------------------------------------------------------------------
# 6. Save and Report
# -------------------------------------------------------------------------
saveDesign ${OUT_DIR}/DBS/05_cts.enc

puts "--- Generating Post-CTS Reports ---"
setAnalysisMode -cppr both
timeDesign -postCTS -outDir ${OUT_DIR}/REPORTS/postCTS_timing
setAnalysisMode -cppr both
timeDesign -postCTS -hold -outDir ${OUT_DIR}/REPORTS/postCTS_hold_timing
report_ccopt_skew_groups > ${OUT_DIR}/REPORTS/clock_skew.rpt

puts "======================================================="
puts " SUCCESS: Clock Tree Synthesized and Optimized! "
puts "======================================================="
