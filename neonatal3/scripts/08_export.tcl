# =========================================================================
# 08_EXPORT.TCL  —  Neonatal Seizure Detection ASIC
# RC extraction + all exports: SPEF, SDF, Verilog netlists, GDSII
#
# Pre-requisite: source scripts/07_signoff_final.tcl first.
#                Design must already be loaded in Innovus memory.
#
# What this script does (in order):
#   1. RC extraction + SPEF (rcworst + rcbest corners)
#   2. SDF export
#   3. Verilog netlist export (with + without PG)
#   4. GDSII streamout (skips gracefully if layermap/GDS not found)
#   5. saveDesign DBS/final.enc  <-- TRUE FINAL DATABASE
# =========================================================================

puts "========================================================="
puts " 08_EXPORT: RC Extraction + All Exports"
puts "========================================================="

set SCRIPT_DIR  [file dirname [file normalize [info script]]]
set ROOT_DIR    [file normalize [file join $SCRIPT_DIR ".."]]
set OUT_DIR     [file join $ROOT_DIR innovus_output]
set EXPORT_DIR  [file join $OUT_DIR EXPORTS]

# Create export directory upfront
file mkdir $EXPORT_DIR

setMultiCpuUsage -localCpu 4

# =========================================================================
# SECTION 1 — RC Extraction + SPEF
# =========================================================================
# setDesignMode -process 65 : required for extractor accuracy (IMPEXT-3530).
#
# QRC tech file check:
#   - If QRC tech file found at PDK path: use effortLevel medium
#     (full field-solver extraction — highest accuracy).
#   - If not found: fall back to effortLevel low (cap-table based).
#     Cap-table extraction is acceptable for signoff on this process node.
#     WARNING printed to Innovus log so it is traceable.
#
# Two SPEF corners written:
#   RC_WORST : max resistance + max capacitance → use for setup STA
#   RC_BEST  : min resistance + min capacitance → use for hold STA
# =========================================================================
puts "-> \[SECTION 1\] RC extraction..."
setDesignMode -process 65

set QRC_DIR "/vlsi/pdk/tsmc_gp_65_stdio/tcbn65gplushvt_200a/TSMCHOME/digital/Back_End/lef/tcbn65gplushvt_200a/techfiles/qrc"
if {[file exists ${QRC_DIR}/rcworst/qrcTechFile]} {
    setExtractRCMode -engine postRoute -effortLevel medium
    puts "INFO: QRC tech file found — using effortLevel medium."
} else {
    setExtractRCMode -engine postRoute -effortLevel low
    puts "WARNING: QRC tech file not found — using cap-table extraction (effortLevel low)."
}
extractRC

puts "-> \[SECTION 1\] Writing SPEF..."
rcOut -spef [file join $EXPORT_DIR hardware_rcworst.spef] -rc_corner RC_WORST
rcOut -spef [file join $EXPORT_DIR hardware_rcbest.spef]  -rc_corner RC_BEST
puts "INFO: SPEF written — hardware_rcworst.spef + hardware_rcbest.spef"

# =========================================================================
# SECTION 2 — SDF Export
# =========================================================================
# write_sdf : exports annotated timing delays for gate-level simulation.
# -edges check_edge : uses check-edge annotation — correct for Xcelium
#   and most standard simulators.
# NOTE: SDF-808 warning ("high performance mode") is benign — safe to ignore.
# =========================================================================
puts "-> \[SECTION 2\] Writing SDF..."
write_sdf -edges check_edge [file join $EXPORT_DIR hardware.sdf]
puts "INFO: SDF written — hardware.sdf"

# =========================================================================
# SECTION 3 — Verilog Netlist Export
# =========================================================================
# Two netlists exported:
#   hardware_routed.v    : signal nets only.
#                          Use this for functional gate-level simulation (GLS).
#   hardware_routed_pg.v : includes explicit VDD/VSS supply ports.
#                          Use this for power-aware GLS or LVS.
# =========================================================================
puts "-> \[SECTION 3\] Writing Verilog netlists..."
saveNetlist [file join $EXPORT_DIR hardware_routed.v]
saveNetlist [file join $EXPORT_DIR hardware_routed_pg.v] -includePowerGround
puts "INFO: Netlists written — hardware_routed.v + hardware_routed_pg.v"

# =========================================================================
# SECTION 4 — GDSII Streamout
# =========================================================================
# Merges standard cell GDS + all macro GDS files into final hardware.gds.
#
# Layermap search order:
#   1. Environment variable TSMC65_MAP_FILE (set externally to override)
#   2. PDK standard locations (checked in order below)
#   If no layermap found: streamOut skipped with WARNING — not an error.
#
# Macro GDS list:
#   - picosoc_sram_2048x32
#   - pingpong_sram_4096x16
#   - pe_spad_1024x16_dp
#   - lut_sram_1024x16
# Missing macro GDS: excluded from merge with WARNING (design still streams
#   out, but that macro will be a black box in the final GDS).
# =========================================================================
puts "-> \[SECTION 4\] Streaming out GDSII..."
setStreamOutMode -snapToMGrid true

# Locate layermap file
set map_file ""
if {[info exists ::env(TSMC65_MAP_FILE)] && [file exists $::env(TSMC65_MAP_FILE)]} {
    set map_file $::env(TSMC65_MAP_FILE)
    puts "INFO: Using layermap from env TSMC65_MAP_FILE: $map_file"
} else {
    foreach candidate [list \
        /vlsi/pdk/tsmc_gp_65_stdio/tsmcN65_layermap.txt \
        /vlsi/pdk/tsmc_gp_65_stdio/tsmcN65.map \
    ] {
        if {[file exists $candidate]} {
            set map_file $candidate
            puts "INFO: Layermap found: $map_file"
            break
        }
    }
}

# Standard cell GDS
set gds_stdcell "/vlsi/pdk/tsmc_gp_65_stdio/tcbn65gplushvt_200a/TSMCHOME/digital/Back_End/gds/tcbn65gplushvt_200a/tcbn65gplushvt.gds"

# Macro GDS files
set macro_gds_list [list \
    [file join $ROOT_DIR macros picosoc_sram_2048x32  picosoc_sram_2048x32.gds]  \
    [file join $ROOT_DIR macros pingpong_sram_4096x16 pingpong_sram_4096x16.gds] \
    [file join $ROOT_DIR macros pe_spad_1024x16_dp    pe_spad_1024x16_dp.gds]    \
    [file join $ROOT_DIR macros lut_sram_1024x16      lut_sram_1024x16.gds]      \
]

# Build merge list: start with stdcell, add macros if they exist
set merge_list [list $gds_stdcell]
foreach mgds $macro_gds_list {
    if {[file exists $mgds]} {
        lappend merge_list $mgds
        puts "INFO: Merging macro GDS: $mgds"
    } else {
        puts "WARNING: Macro GDS not found (excluded from merge): $mgds"
    }
}

# Guard: skip streamOut if layermap or stdcell GDS missing
if {$map_file eq ""} {
    puts "WARNING: No layermap file found. Set env TSMC65_MAP_FILE and rerun."
    puts "WARNING: Skipping GDS streamOut."
} elseif {![file exists $gds_stdcell]} {
    puts "WARNING: Standard cell GDS not found at: $gds_stdcell"
    puts "WARNING: Skipping GDS streamOut."
} else {
    streamOut [file join $EXPORT_DIR hardware.gds] \
        -structureName hardware \
        -mode ALL \
        -mapFile $map_file \
        -merge $merge_list
    puts "INFO: GDSII written — hardware.gds"
}

# =========================================================================
# SECTION 5 — Save True Final Database
# =========================================================================
# Saved after all exports complete.
# This is the definitive final state of the design including all RC data.
# Distinct from 07_signoff_final.enc (pre-export checkpoint).
# =========================================================================
puts "-> \[SECTION 5\] Saving final database..."
saveDesign ${OUT_DIR}/DBS/final.enc
puts "INFO: Saved — DBS/final.enc"

puts "========================================================="
puts " 08_EXPORT: COMPLETE"
puts "---------------------------------------------------------"
puts "  All exports in: EXPORTS/"
puts "    hardware_rcworst.spef — RC parasitics, worst corner (setup STA)"
puts "    hardware_rcbest.spef  — RC parasitics, best corner  (hold STA)"
puts "    hardware.sdf          — timing delays for GLS backannotation"
puts "    hardware_routed.v     — gate-level netlist (no PG)"
puts "    hardware_routed_pg.v  — gate-level netlist (with PG)"
puts "    hardware.gds          — GDSII layout (if layermap found)"
puts "  Final database: DBS/final.enc"
puts "---------------------------------------------------------"
puts "  Next: run post-route GLS — source xrun_routed.glv"
puts "========================================================="
