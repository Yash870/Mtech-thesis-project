# =========================================================================
# 03_POWER_GRID.TCL  —  Neonatal Seizure Detection ASIC
# =========================================================================
# Die  : 1400 x 1400 um
# Core : 1340 x 1340 um  (30 um margins)
# PG nets: VDD / VSS
# ARM SRAM PG pins: VDD/VSS (standard) + VDDPE/VDDCE/VSSE (ARM macro)
# =========================================================================

puts "--- Starting Power Planning ---"

set SCRIPT_DIR [file dirname [file normalize [info script]]]
set ROOT_DIR   [file normalize [file join $SCRIPT_DIR ".."]]
set OUT_DIR    [file join $ROOT_DIR innovus_output]

# =========================================================================
# 1. GLOBAL NET CONNECTIONS
# =========================================================================
# Standard cell PG pins
globalNetConnect VDD -type pgpin -pin VDD  -inst *
globalNetConnect VSS -type pgpin -pin VSS  -inst *

# ARM SRAM macro PG pins (VDDPE/VDDCE = core/periphery VDD, VSSE = VSS)
globalNetConnect VDD -type pgpin -pin VDDPE -inst *
globalNetConnect VDD -type pgpin -pin VDDCE -inst *
globalNetConnect VSS -type pgpin -pin VSSE  -inst *

# Tie-hi / tie-lo cells
globalNetConnect VDD -type tiehi -inst *
globalNetConnect VSS -type tielo -inst *

# =========================================================================
# 2. CORE POWER RINGS
# =========================================================================
# Ring runs along the core boundary on M7 (H) and M8 (V).
# Core ring corners: M7 meets M8 → only V78 via needed.
# FIX: was -stacked_via_bottom_layer M1 → forced M1-to-M8 stacked via
#      → IMPPP-532 ViaGen same-direction failures → 200+ DRC violations.
setAddRingMode -stacked_via_top_layer M8 -stacked_via_bottom_layer M7

addRing \
    -nets      {VDD VSS}    \
    -type      core_rings   \
    -follow    core         \
    -layer     {top M7 bottom M7 left M8 right M8} \
    -width     4.0          \
    -spacing   2.0          \
    -offset    2.0

# =========================================================================
# 3. MACRO POWER RINGS
# =========================================================================
# Individual ring around every macro (all 21 instances).
# Macro ring corners: M3 meets M2 → only V23 via needed.
# FIX: must set separate setAddRingMode before block rings — without it,
#      inherits the previous mode (was M1 bottom → IMPPP-532 on macro rings too).
setAddRingMode -stacked_via_top_layer M3 -stacked_via_bottom_layer M2

addRing \
    -nets      {VDD VSS}    \
    -type      block_rings  \
    -around    each_block   \
    -layer     {top M3 bottom M3 left M2 right M2} \
    -width     2.0          \
    -spacing   1.0          \
    -offset    1.0

# =========================================================================
# 4. ROUTING BLOCKAGES OVER MACRO BODIES  (M7/M8 only)
# =========================================================================
# Block upper metals (M7/M8) over each macro so signal router does not
# use that space.  -exceptpgnet lets VDD/VSS stripes still cross.
#
# M1-M4 are NOT blocked: macro pins live on those layers and must stay
# accessible for sroute and signal connections.
#
# -allMacro is not a valid flag in this Innovus version; iterate instead
# using bounding boxes from the database.

set macro_ptrs [dbGet top.insts.cell.baseClass block -p2]
set blk_margin 0.5
set blk_idx    0

foreach mp $macro_ptrs {
    set x1 [expr {[dbGet ${mp}.box_llx] + $blk_margin}]
    set y1 [expr {[dbGet ${mp}.box_lly] + $blk_margin}]
    set x2 [expr {[dbGet ${mp}.box_urx] - $blk_margin}]
    set y2 [expr {[dbGet ${mp}.box_ury] - $blk_margin}]
    catch {deleteRouteBlk -name m78_macro_${blk_idx}}
    createRouteBlk -box $x1 $y1 $x2 $y2 \
                   -layer {7 8}          \
                   -exceptpgnet          \
                   -name m78_macro_${blk_idx}
    incr blk_idx
}
puts "INFO: M7/M8 routing blockages created for ${blk_idx} macros."

# =========================================================================
# 5. VERTICAL POWER STRIPES  (M8)
# =========================================================================
# Reset ring mode — stripes use their own via rules, not addRing stacking.
setAddRingMode -reset

addStripe \
    -nets              {VDD VSS} \
    -layer             M8        \
    -direction         vertical  \
    -width             2.0       \
    -spacing           4.0       \
    -set_to_set_distance 80      \
    -start_offset      25

# =========================================================================
# 6. HORIZONTAL INTERMEDIATE STRIPES  (M5)
# =========================================================================
# FIX: was M4 horizontal — M4 is VERTICAL preferred in TSMC 65nm (M4=V).
#      Routing against preferred direction causes congestion + via stress.
#      M5 is HORIZONTAL preferred (M5=H) — correct layer for H stripes.
addStripe \
    -nets              {VDD VSS} \
    -layer             M5        \
    -direction         horizontal \
    -width             2.0       \
    -spacing           4.0       \
    -set_to_set_distance 80      \
    -start_offset      25

# =========================================================================
# 7. HORIZONTAL POWER STRIPES  (M7)
# =========================================================================
addStripe \
    -nets              {VDD VSS} \
    -layer             M7        \
    -direction         horizontal \
    -width             2.0       \
    -spacing           4.0       \
    -set_to_set_distance 80      \
    -start_offset      25

# =========================================================================
# 8. SPECIAL ROUTE  (connect macro PG pins to rings/stripes)
# =========================================================================
sroute \
    -connect        { blockPin corePin } \
    -layerChangeRange { M1 M8 }          \
    -blockPinTarget { nearestTarget }    \
    -nets           {VDD VSS}

sroute \
    -connect        { floatingStripe }   \
    -layerChangeRange { M1 M8 }          \
    -blockPinTarget { nearestTarget }    \
    -nets           {VDD VSS}

# =========================================================================
# 9. END CAPS
# =========================================================================
# DCAPHVT: TSMC 65nm GP HVT decap/endcap cell.
# If Innovus reports cell not found, check library for exact cell name
# (e.g. DCAP16HVT, DCAP8HVT) and update below.
setEndCapMode -reset
setEndCapMode -rightEdge DCAPHVT -leftEdge DCAPHVT
addEndCap -prefix CAP_

# =========================================================================
# 10. SAVE
# =========================================================================
saveDesign ${OUT_DIR}/DBS/03_power.enc

puts "======================================================="
puts " SUCCESS: Power Grid Complete"
puts "  Core rings  : M7 (H) / M8 (V), width=4um"
puts "  Macro rings : M3 (H) / M2 (V), width=2um  (21 macros)"
puts "  Stripes     : M8 vertical + M7/M5 horizontal, pitch=80um"
puts "  sroute      : blockPin + corePin connected"
puts "======================================================="
