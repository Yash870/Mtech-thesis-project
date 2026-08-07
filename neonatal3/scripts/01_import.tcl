# =========================================================================
# 01_IMPORT.TCL
# =========================================================================

setMultiCpuUsage -localCpu 4

# Resolve project paths from this script location for portability.
set SCRIPT_DIR [file dirname [file normalize [info script]]]
set ROOT_DIR [file normalize [file join $SCRIPT_DIR ".."]]

proc _require_file {path} {
    if {![file exists $path]} {
        error "Required file not found: $path"
    }
}

# =========================================================================
# 1. DIRECTORY SETUP (Creates folders outside the current directory)
# =========================================================================
set OUT_DIR [file join $ROOT_DIR innovus_output]
file mkdir ${OUT_DIR}
file mkdir ${OUT_DIR}/DBS
file mkdir ${OUT_DIR}/REPORTS

# Macro directory (project-local, portable across systems)
set MACRO_DIR [file join $ROOT_DIR macros]
set SYN_DIR [file join $ROOT_DIR reports synthesis]

# =========================================================================
# 2. DESIGN IMPORT VARIABLES
# =========================================================================
set init_gnd_net {VSS}
set init_pwr_net {VDD}
set init_verilog [file join $SYN_DIR hardware_netlist.v]
set init_top_cell {hardware}

# Standard Cell LEF, Tech/Routing LEFs, AND Macro LEFs
set init_lef_file [list \
    /vlsi/pdk/tsmc_gp_65_stdio/tcbn65gplushvt_200a/TSMCHOME/digital/Back_End/lef/tcbn65gplushvt_200a/lef/tcbn65gplushvt_9lmT2.lef \
    /vlsi/pdk/tsmc_gp_65_stdio/tpan65gpgv2od3_200b/TSMCHOME/digital/Back_End/lef/tpan65gpgv2od3_200a/mt/9lm/lef/antenna_9lm.lef \
    /vlsi/pdk/tsmc_gp_65_stdio/tpbn65v_200b/TSMCHOME/digital/Back_End/lef/tpbn65v_200b/wb/9m/9M_6X2Z/lef/tpbn65v_9lm.lef \
    [file join $MACRO_DIR picosoc_sram_2048x32  picosoc_sram_2048x32.lef]  \
    [file join $MACRO_DIR pingpong_sram_4096x16 pingpong_sram_4096x16.lef] \
    [file join $MACRO_DIR pe_spad_1024x16_dp    pe_spad_1024x16_dp.lef]    \
    [file join $MACRO_DIR lut_sram_1024x16      lut_sram_1024x16.lef]      \
]

# Keep MMMC pointed to your scripts folder
set init_mmmc_file [file join $SCRIPT_DIR mmmc.tcl]

# Fast fail on missing mandatory inputs.
_require_file $init_verilog
_require_file $init_mmmc_file
foreach lef $init_lef_file {
    _require_file $lef
}

# =========================================================================
# 3. EXECUTE IMPORT & SAVE
# =========================================================================
# Import the design into Innovus
init_design

# -------------------------------------------------------------------------
# ICG cells: ARM .lib ships with dont_use true — clear it so Innovus keeps
# and optimizes CKLHQD*/CKLNQD* cells already in the netlist from Genus.
# Lib names: tcbn65gplushvtwc_ccs (WC) and tcbn65gplushvtbc_ccs (BC).
# Pattern tcbn65gplushvt*/CKLHQD* matches both — lowercase hvt, wildcard on wc/bc suffix.
# Previous attempt *HVT/CKLHQD* failed: uppercase HVT ≠ lowercase hvt on Linux (TCLCMD-917).
set_dont_use false [get_lib_cells tcbn65gplushvt*/CKLHQD*]
set_dont_use false [get_lib_cells tcbn65gplushvt*/CKLNQD*]

# SRAM macros: ARM .lib dont_use true prevents timing opt through SRAM ports.
set_dont_use false [get_lib_cells *picosoc_sram_2048x32*]
set_dont_use false [get_lib_cells *pingpong_sram_4096x16*]
set_dont_use false [get_lib_cells *pe_spad_1024x16_dp*]
set_dont_use false [get_lib_cells *lut_sram_1024x16*]

# Path groups: must be interactive Innovus commands — Innovus ignores
# group_path inside SDC constraint files (TA-976 warning).
# set_interactive_constraint_modes required in MMMC: tells Innovus which
# constraint mode receives these commands (TCLCMD-1048 without it).
# Note: -clock_gating_pins not supported in Innovus 21.12 all_registers (IMPTCM-48).
set_interactive_constraint_modes {CONSTRAINTS}
group_path -name reg2reg -from [all_registers] -to [all_registers]

# Post-import sanity check — catches unresolved cells, missing ports, power net issues
checkDesign -noHtml -netlist

# Clock uncertainty — must be set here, NOT in mmmc.tcl
# (clock clk_16mhz is defined in the SDC which is not yet loaded when mmmc.tcl executes)
set_clock_uncertainty -setup 1.0 [get_clocks clk_16mhz]
set_clock_uncertainty -hold  0.5 [get_clocks clk_16mhz]

# Save the initial database
saveDesign ${OUT_DIR}/DBS/01_imported.enc

puts "======================================================="
puts " SUCCESS: Design Imported and Saved to ${OUT_DIR}/DBS"
puts "======================================================="
