# =========================================================================
# 06_ROUTING.TCL  —  Neonatal Seizure Detection ASIC
# Signal routing, DRC cleanup, post-route timing closure, RC extraction
# Export (SPEF/SDF/GDS/netlist) handled by 07_signoff_export.tcl
#
# Pre-requisite: restoreDesign DBS/05_cts.enc hardware  (done manually)
# =========================================================================

puts "========================================================="
puts " ROUTING: Phase 1 - Configuration"
puts "========================================================="

set SCRIPT_DIR [file dirname [file normalize [info script]]]
set ROOT_DIR   [file normalize [file join $SCRIPT_DIR ".."]]
set OUT_DIR    [file join $ROOT_DIR innovus_output]

setMultiCpuUsage -localCpu 4

# Reload SDC to pick up corrected hold uncertainty (0.1 ns, was 0.5 ns).
# 0.5 ns double-counted with OCV ±3% already active in mmmc.tcl.
# 0.1 ns covers same-cycle crystal jitter only.
update_constraint_mode -name CONSTRAINTS \
    -sdc_files [list [file join $ROOT_DIR reports synthesis hardware_constraints.sdc]]

# QSPI AND-gate clock-gate hold — structural, must re-apply after SDC reload
set_false_path -hold -from [get_cells *qspi_master_inst*qspi_cs_n_reg*]

# =========================================================================
# ROUTING: Phase 2 - NanoRoute Configuration
# =========================================================================
puts ""
puts "========================================================="
puts " ROUTING: Phase 2 - NanoRoute Configuration"
puts "========================================================="
setNanoRouteMode -routeWithTimingDriven true
setNanoRouteMode -routeWithSiDriven false
setNanoRouteMode -drouteSearchAndRepair true
setNanoRouteMode -drouteUseMultiCutViaEffort high
setNanoRouteMode -droutePostRouteSwapVia true
setNanoRouteMode -droutePostRouteSpreadWire true
setNanoRouteMode -routeInsertAntennaDiode true

# Relax density cap so hold buffers have room to land
setPlaceMode -place_global_max_density 0.95

# Hold opt: allow overlap for tight areas, target clean 0 ns slack
setOptMode -fixHoldAllowOverlap true
setOptMode -holdTargetSlack 0.0

# =========================================================================
# ROUTING: Phase 3 - Route Design & DRC Cleanup
# =========================================================================
puts ""
puts "========================================================="
puts " ROUTING: Phase 3 - Route Design & DRC Cleanup"
puts "========================================================="
routeDesign
ecoRoute -fix_drc

# Fix dangling PG stripe endpoints (M5/M7 stripe stubs at macro
# boundaries that addStripe left without a via to M8 vertical stripes)
puts "Fixing dangling PG stripes..."
sroute -connect floatingStripe \
       -nets {VDD VSS} \
       -layerChangeRange {M1 M8} \
       -blockPinTarget nearestTarget

# =========================================================================
# ROUTING: Phase 4 - Post-Route Setup & Hold Optimization
# =========================================================================
puts ""
puts "========================================================="
puts " ROUTING: Phase 4 - Timing Closure"
puts "========================================================="
setDelayCalMode -SIAware false
setAnalysisMode -cppr both

puts "Optimizing Setup..."
optDesign -postRoute
setAnalysisMode -cppr both   ;# re-assert: optDesign resets mode (IMPOPT-3195)

puts "Optimizing Hold (pass 1)..."
optDesign -postRoute -hold
setAnalysisMode -cppr both   ;# re-assert (IMPOPT-3195)

puts "Optimizing Hold (pass 2 — closes residual violations from pass 1)..."
optDesign -postRoute -hold
setAnalysisMode -cppr both   ;# re-assert (IMPOPT-3195)

puts "Running final Setup polish..."
optDesign -postRoute -inc
setAnalysisMode -cppr both   ;# re-assert (IMPOPT-3195)

# Fix via-to-cell-blockage shorts introduced when optDesign inserts new
# cells whose M1 OBS overlaps existing vias. setOptMode -fixDRC true
# lets the incremental optimizer move those cells; ecoRoute re-routes.
puts "Running post-opt DRC cleanup..."
setOptMode -fixDRC true
optDesign -postRoute -inc
setAnalysisMode -cppr both   ;# re-assert (IMPOPT-3195)
ecoRoute -fix_drc

# =========================================================================
# ROUTING: Phase 5 - Verification & RC Extraction
# =========================================================================
puts ""
puts "========================================================="
puts " ROUTING: Phase 5 - Verification & RC Extraction"
puts "========================================================="
setExtractRCMode -engine postRoute -effortLevel low
extractRC

puts "Verifying Geometry (DRC)..."
verifyGeometry -report ${OUT_DIR}/REPORTS/postRoute_geometry.rpt

puts "Verifying Connectivity..."
verifyConnectivity -type all -report ${OUT_DIR}/REPORTS/postRoute_connectivity.rpt

puts "Generating Post-Route Timing Reports..."
setAnalysisMode -cppr both
timeDesign -postRoute      -outDir ${OUT_DIR}/REPORTS/postRoute_timing
setAnalysisMode -cppr both
timeDesign -postRoute -hold -outDir ${OUT_DIR}/REPORTS/postRoute_hold_timing

# =========================================================================
# ROUTING: Phase 6 - Save Design
# =========================================================================
saveDesign ${OUT_DIR}/DBS/06_routed.enc

puts "========================================================="
puts " SUCCESS: Routing & Timing Closure Complete!"
puts " Next: source scripts/07_signoff_export.tcl"
puts "========================================================="
