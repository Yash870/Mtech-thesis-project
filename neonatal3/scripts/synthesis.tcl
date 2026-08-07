# ==============================================================================
# 1. SET PROJECT NAME
# ==============================================================================
suppress_messages {LBR-9 LBR-40 LBR-518 PHYS-279}
set BASENAME "hardware"
# Kill DISPLAY so super-thread sub-processes don't crash on missing X server
catch { array unset env DISPLAY }
catch { array unset env XAUTHORITY }
# Prevent Server Crashes (OOM) by limiting parallel jobs
set_attribute auto_super_thread false /
set_attribute super_thread_servers {} /
set_attribute max_cpus_per_server 1 /

# Catch super-threading crashes just in case
#set_attribute super_thread_debug_directory ../reports/st_debug /
#set_attribute auto_super_thread true /
#set_attribute max_cpus_per_server 2 /

# ==============================================================================
# 2. SET LIBRARY PATHS (Using Absolute Paths for Safety)
# ==============================================================================
# Assuming you run your script from a directory alongside the source folder
set_attribute init_hdl_search_path {/home/users/2035ayush/Ayush/neonatal/sourcecode/rtl}

# Define the exact absolute path to your macros folder
set MACRO_DIR "/home/users/2035ayush/Ayush/neonatal/macros"

# Combined Search Paths (TSMC + Macros)
set_attribute init_lib_search_path [list \
    /vlsi/pdk/tsmc_gp_65_stdio/tcbn65gplushvt_200a/TSMCHOME/digital/Front_End/verilog/tcbn65gplushvt_200a/ \
    ${MACRO_DIR}/picosoc_sram_2048x32 \
    ${MACRO_DIR}/pingpong_sram_4096x16 \
    ${MACRO_DIR}/pe_spad_1024x16_dp \
    ${MACRO_DIR}/lut_sram_1024x16 \
]

# Combined Library Files (TSMC Typical + Macro Corners)
set_attribute library [list \
    /vlsi/pdk/tsmc_gp_65_stdio/tcbn65gplushvt_200a/TSMCHOME/digital/Front_End/timing_power_noise/CCS/tcbn65gplushvt_200a/tcbn65gplushvttc_ccs.lib \
    ${MACRO_DIR}/picosoc_sram_2048x32/picosoc_sram_2048x32_nldm_tt_1p00v_1p00v_25c_syn.lib \
    ${MACRO_DIR}/pingpong_sram_4096x16/pingpong_sram_4096x16_nldm_tt_1p00v_1p00v_25c_syn.lib \
    ${MACRO_DIR}/pe_spad_1024x16_dp/pe_spad_1024x16_dp_nldm_tt_1p00v_1p00v_25c_syn.lib \
    ${MACRO_DIR}/lut_sram_1024x16/lut_sram_1024x16_nldm_tt_1p00v_1p00v_25c_syn.lib \
]

# Combined LEF Files (TSMC Physical + Macro Physical)
set_attribute lef_library [list \
    /vlsi/pdk/tsmc_gp_65_stdio/tcbn65gplushvt_200a/TSMCHOME/digital/Back_End/lef/tcbn65gplushvt_200a/lef/tcbn65gplushvt_9lmT2.lef \
    /vlsi/pdk/tsmc_gp_65_stdio/tpan65gpgv2od3_200b/TSMCHOME/digital/Back_End/lef/tpan65gpgv2od3_200a/mt/9lm/lef/antenna_9lm.lef \
    /vlsi/pdk/tsmc_gp_65_stdio/tpbn65v_200b/TSMCHOME/digital/Back_End/lef/tpbn65v_200b/wb/9m/9M_6X2Z/lef/tpbn65v_9lm.lef \
    ${MACRO_DIR}/picosoc_sram_2048x32/picosoc_sram_2048x32.lef \
    ${MACRO_DIR}/pingpong_sram_4096x16/pingpong_sram_4096x16.lef \
    ${MACRO_DIR}/pe_spad_1024x16_dp/pe_spad_1024x16_dp.lef \
    ${MACRO_DIR}/lut_sram_1024x16/lut_sram_1024x16.lef \
]

# ==============================================================================
# 3. CLOCK GATING
# ==============================================================================
# Disabled for first GLS pass — CG cells caused functional hang in zero-delay GLS
set_attribute lp_insert_clock_gating false

# ==============================================================================
# 4. READ & ELABORATE
# ==============================================================================
# Reading all the actual RTL files belonging to the top level hardware.v
read_hdl -sv { \
    counter.v \
    decoder_acc.v \
    handshake_muxF.v \
    maxpool.v \
    PE.v \
    picorv32.v \
    picosoc.v \
    ping_pong_controller.v \
    qat_requantizer.v \
    qat_requantizer_48b.v \
    qspi_master.v \
    reciprocal_lut.v \
    relu.v \
    RMS_PE.v \
    scratchpad_dual_port.v \
    scratchpad_sram.v \
    sigmoid_hardware.v \
    simpleuart.v \
    accelerator.v \
    hardware.v
}

elaborate ${BASENAME} 

# ==============================================================================
# 5. CONSTRAINTS
# ==============================================================================
# Ensure this constraint explicitly defines clock on the `clk` pin of hardware.v
read_sdc "../scripts/constraints.sdc"

# ==============================================================================
# 6. HIERARCHY PRESERVATION
# ==============================================================================
# Un-avoid clock-gate cells (needed if any module uses them for power).
# Clock gating insertion is still disabled by lp_insert_clock_gating false.
set_attribute avoid false [get_lib_cells */CKLHQD*]
set_attribute avoid false [get_lib_cells */CKLNQD*]

# ==============================================================================
# 6b. PREVENT PICORV32 FLATTENING ONLY
# ==============================================================================

# Keep cpu hierarchy boundary — prevents Genus from merging picorv32 into picosoc.
# No hdl_preserve: let Genus choose FF style freely (matches other working picorv32 projects).
set cpu_hier [find /designs/hardware -inst instances_hier/soc/instances_hier/cpu]
if {$cpu_hier != ""} {
    set_attribute ungroup_ok false $cpu_hier
    puts "ungroup_ok false: soc/cpu hierarchy preserved"
} else {
    puts "WARNING: soc/cpu not found — check elaboration hierarchy"
}

# ==============================================================================
# 7. SYNTHESIS STEPS
# ==============================================================================
puts "--- Starting Generic Synthesis ---"
# Try to set undriven-signal-to-0 attribute; command varies by Genus version.
# Using catch so the script does not abort if the attribute name differs.
foreach undriven_attr {
    undriven_signal
    hdl_undriven_signal_value
    undriven_output_port_value
} {
    if {![catch {set_attribute $undriven_attr constant_0 [get_designs *]} err]} {
        puts "Set undriven attribute '$undriven_attr' = constant_0"
        break
    }
}

# Preserve reset FFs — prevent Genus from removing FFs whose reset/set value
# is constant. optimize_constant_0_flops covers reset-to-0 FFs,
# optimize_constant_1_flops covers set-to-1 FFs (e.g. qspi_cs_n).
set_attribute optimize_constant_0_flops false /
set_attribute optimize_constant_1_flops false /

syn_gen

puts "--- Starting Mapping ---"
syn_map

# puts "--- Starting Optimization ---"
# syn_opt

insert_tiehilo_cells -hi TIEHHVT -lo TIELHVT

# ==============================================================================
# 8. REPORTS & OUTPUTS
# ==============================================================================
# Check that the ../reports/synthesis directory actually exists!
# mkdir -p ../reports/synthesis

report timing > ../reports/synthesis/timing.rpt
report area   > ../reports/synthesis/area.rpt
report gates  > ../reports/synthesis/gates.rpt
report power  > ../reports/synthesis/power.rpt
report summary > ../reports/synthesis/summary.rpt
report clock_gating > ../reports/synthesis/clk_gating.rpt

write_hdl -lec > ../reports/synthesis/${BASENAME}_netlist.v      
write_hdl -pg  > ../reports/synthesis/${BASENAME}_netlist_pwr.v
write_sdc      > ../reports/synthesis/${BASENAME}_constraints.sdc
write_sdf      > ../reports/synthesis/${BASENAME}_netlist.sdf 

write_do_lec -revised ../reports/synthesis/${BASENAME}_netlist.v -log ../reports/synthesis/rtl2final.log > rtl2final.do

puts "Final Runtime & Memory."
timestat FINAL
puts "============================"
puts "Synthesis Finished ........."
puts "============================"
exit
