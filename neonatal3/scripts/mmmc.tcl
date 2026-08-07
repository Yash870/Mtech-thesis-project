# =========================================================================
# MMMC VIEW DEFINITION — FIXED
# Changes from original:
#   - RC corners now use qrc_tech_file instead of cap_table
#   - OCV derating added via set_timing_derate
#   - Uncertainty tightened for hold paths
# =========================================================================

# ROOT_DIR is set by 01_import.tcl before init_design is called.
# Do not use [info script] here — it resolves to a temp path when
# Innovus loads this file internally.
if {![info exists ROOT_DIR]} {
    error "ROOT_DIR is not set. mmmc.tcl must be loaded via 01_import.tcl"
}
set MACRO_DIR [file join $ROOT_DIR macros]
set SYN_DIR   [file join $ROOT_DIR reports synthesis]

# -------------------------------------------------------------------------
# 1. RC Extraction Corners
# -------------------------------------------------------------------------
# FIX: Use qrc_tech_file (TLUPlus) instead of cap_table for accurate
#      post-route extraction. Locate these files under your PDK:
#      .../techfiles/qrc/  or  .../qrcTechFile/
#
# If QRC files are truly unavailable, keep cap_table but remove the
# -effortLevel low workaround in 06_routing.tcl and accept ~5% inaccuracy.
#
# Adjust the paths below to match your PDK installation:
set QRC_DIR "/vlsi/pdk/tsmc_gp_65_stdio/tcbn65gplushvt_200a/TSMCHOME/digital/Back_End/lef/tcbn65gplushvt_200a/techfiles/qrc"

if {[file exists ${QRC_DIR}/rcbest/qrcTechFile]} {
    create_rc_corner -name RC_BEST \
        -qrc_tech ${QRC_DIR}/rcbest/qrcTechFile \
        -preRoute_res 1.0 -preRoute_cap 1.0 \
        -postRoute_res 1.0 -postRoute_cap 1.0 -postRoute_xcap 1.0
    create_rc_corner -name RC_WORST \
        -qrc_tech ${QRC_DIR}/rcworst/qrcTechFile \
        -preRoute_res 1.0 -preRoute_cap 1.0 \
        -postRoute_res 1.0 -postRoute_cap 1.0 -postRoute_xcap 1.0
    puts "INFO: Using QRC tech files for RC corners."
} else {
    # Fallback: cap tables (less accurate, but functional)
    puts "WARNING: QRC tech files not found at ${QRC_DIR}. Falling back to cap tables."
    puts "WARNING: Post-route timing accuracy will be reduced."
    set CAPTABLE_DIR "/vlsi/pdk/tsmc_gp_65_stdio/tcbn65gplushvt_200a/TSMCHOME/digital/Back_End/lef/tcbn65gplushvt_200a/techfiles/captable"
    create_rc_corner -name RC_BEST \
        -cap_table ${CAPTABLE_DIR}/cln65g+_1p09m+alrdl_rcbest_top2.captable \
        -preRoute_res 1.0 -preRoute_cap 1.0 \
        -postRoute_res 1.0 -postRoute_cap 1.0 -postRoute_xcap 1.0
    create_rc_corner -name RC_WORST \
        -cap_table ${CAPTABLE_DIR}/cln65g+_1p09m+alrdl_rcworst_top2.captable \
        -preRoute_res 1.0 -preRoute_cap 1.0 \
        -postRoute_res 1.0 -postRoute_cap 1.0 -postRoute_xcap 1.0
}

# -------------------------------------------------------------------------
# 2. Timing Libraries (SS = worst-case setup, FF = worst-case hold)
# -------------------------------------------------------------------------
create_library_set -name MAX_TIMING -timing [list \
    /vlsi/pdk/tsmc_gp_65_stdio/tcbn65gplushvt_200a/TSMCHOME/digital/Front_End/timing_power_noise/CCS/tcbn65gplushvt_200a/tcbn65gplushvtwc_ccs.lib \
    ${MACRO_DIR}/picosoc_sram_2048x32/picosoc_sram_2048x32_nldm_ss_0p90v_0p90v_125c_syn.lib \
    ${MACRO_DIR}/pingpong_sram_4096x16/pingpong_sram_4096x16_nldm_ss_0p90v_0p90v_125c_syn.lib \
    ${MACRO_DIR}/pe_spad_1024x16_dp/pe_spad_1024x16_dp_nldm_ss_0p90v_0p90v_125c_syn.lib \
    ${MACRO_DIR}/lut_sram_1024x16/lut_sram_1024x16_nldm_ss_0p90v_0p90v_125c_syn.lib \
]

create_library_set -name MIN_TIMING -timing [list \
    /vlsi/pdk/tsmc_gp_65_stdio/tcbn65gplushvt_200a/TSMCHOME/digital/Front_End/timing_power_noise/CCS/tcbn65gplushvt_200a/tcbn65gplushvtbc_ccs.lib \
    ${MACRO_DIR}/picosoc_sram_2048x32/picosoc_sram_2048x32_nldm_ff_1p10v_1p10v_0c_syn.lib \
    ${MACRO_DIR}/pingpong_sram_4096x16/pingpong_sram_4096x16_nldm_ff_1p10v_1p10v_0c_syn.lib \
    ${MACRO_DIR}/pe_spad_1024x16_dp/pe_spad_1024x16_dp_nldm_ff_1p10v_1p10v_0c_syn.lib \
    ${MACRO_DIR}/lut_sram_1024x16/lut_sram_1024x16_nldm_ff_1p10v_1p10v_0c_syn.lib \
]

# -------------------------------------------------------------------------
# 3. Constraint Mode
# -------------------------------------------------------------------------
create_constraint_mode -name CONSTRAINTS \
    -sdc_files [list [file join $SYN_DIR hardware_constraints.sdc]]

# -------------------------------------------------------------------------
# 4. Delay Corners
# -------------------------------------------------------------------------
create_delay_corner -name MIN_DELAY -library_set {MIN_TIMING} -rc_corner {RC_BEST}
create_delay_corner -name MAX_DELAY -library_set {MAX_TIMING} -rc_corner {RC_WORST}

# -------------------------------------------------------------------------
# 5. Analysis Views
# -------------------------------------------------------------------------
create_analysis_view -name BEST_CASE  -constraint_mode {CONSTRAINTS} -delay_corner {MIN_DELAY}
create_analysis_view -name WORST_CASE -constraint_mode {CONSTRAINTS} -delay_corner {MAX_DELAY}

# -------------------------------------------------------------------------
# 6. Apply Views
# -------------------------------------------------------------------------
set_analysis_view -setup {WORST_CASE} -hold {BEST_CASE}

# -------------------------------------------------------------------------
# 7. OCV Derating — FIX (was using invalid Innovus flags)
# -------------------------------------------------------------------------
# Standard 65nm OCV values. Adjust if your PDK provides specific derate tables.
# -early  = fast corner, shrink delays (for hold analysis)
# -late   = slow corner, stretch delays (for setup analysis)
# Valid syntax: set_timing_derate [-early|-late] [-cell_delay|-net_delay] <value>
set_timing_derate -early 0.97 -cell_delay
set_timing_derate -late  1.03 -cell_delay

puts "INFO: MMMC setup complete with OCV derating (±3%)."
puts "INFO: Clock uncertainty is set in 01_import.tcl after init_design."

