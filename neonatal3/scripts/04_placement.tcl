# =========================================================================
# 04_PLACEMENT.TCL  —  Neonatal Seizure Detection ASIC
# Die: 1400x1400 um  Core: 1340x1340 um  Utilization: ~80%
# =========================================================================

puts "--- Starting Standard Cell Placement ---"

set SCRIPT_DIR [file dirname [file normalize [info script]]]
set ROOT_DIR [file normalize [file join $SCRIPT_DIR ".."]]
set OUT_DIR [file join $ROOT_DIR innovus_output]

# Speed up the run
setMultiCpuUsage -localCpu 4

# -------------------------------------------------------------------------
# 1. Congestion and Density Rules
# -------------------------------------------------------------------------
# Core utilization ~80% — max_density 0.75 cap gives hold buffer headroom.
# If routeDesign fails with congestion, increase die to 1450x1450.
setPlaceMode -place_global_uniform_density true
setPlaceMode -place_global_max_density 0.75
setPlaceMode -place_global_cong_effort high

# Prevent standard cells from hiding under low-level power stripes
setPlaceMode -place_detail_preroute_as_obs {1 2}

# -------------------------------------------------------------------------
# 2. Cell Padding for Clock Trees
# -------------------------------------------------------------------------
# Add a physical 2-site "bubble" around all clock cells.
set clock_cells {BUFFD1HVT BUFFD0HVT BUFFD12HVT BUFFD16HVT BUFFD2HVT BUFFD3HVT BUFFD4HVT BUFFD6HVT BUFFD8HVT CKBD1HVT CKBD0HVT CKBD12HVT CKBD16HVT CKBD2HVT CKBD3HVT CKBD4HVT CKBD6HVT CKBD8HVT CKND1HVT CKND0HVT CKND12HVT CKND16HVT CKND2HVT CKND3HVT CKND4HVT CKND6HVT CKND8HVT INVD1HVT INVD0HVT INVD12HVT INVD16HVT INVD2HVT INVD3HVT INVD4HVT INVD6HVT INVD8HVT}

foreach cell $clock_cells {
    # Using catch so it silently skips any cells not present in your specific library
    catch {specifyCellPad $cell 2}
}

# -------------------------------------------------------------------------
# 3. Run Placement & Optimization
# -------------------------------------------------------------------------
puts "--- Running placeDesign ---"
placeDesign

puts "--- Running optDesign -preCTS ---"
optDesign -preCTS

# -------------------------------------------------------------------------
# 4. Save and Report
# -------------------------------------------------------------------------
saveDesign ${OUT_DIR}/DBS/04_placement.enc

puts "--- Generating Reports ---"
timeDesign -preCTS -outDir ${OUT_DIR}/REPORTS/preCTS_timing
reportCongestion -hotspot > ${OUT_DIR}/REPORTS/congestion_post_place.rpt

puts "======================================================="
puts " SUCCESS: Placement and Pre-CTS Optimization Complete! "
puts "======================================================="
