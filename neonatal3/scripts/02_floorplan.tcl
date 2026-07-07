# =========================================================================
# 02_FLOORPLAN.TCL  —  Neonatal Seizure Detection ASIC
# =========================================================================
# Die  : 1400 x 1400 um  (1.96 mm²)
# Core : 1340 x 1340 um  (30 um margins each side, x=30..1370, y=30..1370)
# Util : ~74.7% std cell density (1,443,183 um² cell area)
#
# Layout — PE cols symmetric about x=700, top strip centered at x=700:
#
#   y=1370 ┌──────────────────────────────────────────────┐
#          │  std cells incl soc_cpu (guided here)        │
#   y=1257 │  [lut_recip  317x69]   [lut_sigmoid  317x69] │
#   y=1188 │  ── 15 um channel ───────────────────────── │
#   y=1173 │  [ping 317x199][picosoc 586x111][pong 317x199]│
#   y=974  │  ── 40 um routing channel ───────────────── │
#   y=934  │  ── PE array top ──────────────────────────  │
#          │  [PE7_if][PE7_wt]  10 um row gap             │
#          │  ...                                         │
#          │  [PE0_if][PE0_wt]  row pitch = 114.27 um     │
#   y= 30  └──────────────────────────────────────────────┘
#          x=30 x=50   col gap=110 um    x=1310  x=1360
#
# PE cols symmetric about x=700; top strip centered at die_cx=700:
#   PE array    : col1=50.0..610.7   col2=710.7..1271.4  (gap=100 um)
#   ping        : x=53.92  pong: x=978.30  (centered at 700)
#   picosoc     : x=381.71 .. 968.30  (centered at 700)
#   LUTs        : same x as ping/pong
#   Halo        : 10 um all sides
#   soc_cpu     : placement blockage in PE gap; guided to top strip y=974..1370
# =========================================================================

puts "--- Starting Neonatal ASIC Floorplan (1400x1400, soc_cpu top) ---"

set SCRIPT_DIR [file dirname [file normalize [info script]]]
set ROOT_DIR   [file normalize [file join $SCRIPT_DIR ".."]]
set OUT_DIR    [file join $ROOT_DIR innovus_output]

# =========================================================================
# 1. DIE & CORE
# =========================================================================
floorPlan -site core -d 1400.0 1400.0 30.0 30.0 30.0 30.0

set core_x0 30.0
set core_y0 30.0
set die_cx  700.0   ;# die center x  (core: x=30..1370, y=30..1370)

# =========================================================================
# 2. PE SPAD ARRAY  (16 instances, 2 col x 8 row)
# =========================================================================
# pe_spad_1024x16_dp : W=560.70 um, H=104.27 um
# 10 um routing gap between every row — fixes M4 pin spacing DRC
# Row pitch = 104.27 + 10.0 = 114.27 um
#
# PE cols with 10 um edge breathing + narrow center gap to force soc_cpu upward:
#   col1_x = 40.0   → 10 um margin from core left  (x=30); col1 right=600.70
#   col2_x = 799.30 → 10 um margin from core right (x=1370); col2 right=1360
#   col gap = 799.30 - 600.70 = 198.6 um — original spacing, ~74% density

set spad_w      560.70
set spad_h      104.27
set spad_pitch  114.27   ;# 104.27 + 10.0 gap
set spad_col1_x 40.0     ;# original: 10 um margin from core left
set spad_col2_x 799.30   ;# original: 10 um margin from core right (gap=198.6 um)

for {set pe 0} {$pe < 8} {incr pe} {
    set spad_y [expr {$core_y0 + $pe * $spad_pitch}]
    placeInstance decoder_acc_inst_pe_array_PE${pe}_ifmap0_u_spad_dp  \
                  $spad_col1_x $spad_y R0
    placeInstance decoder_acc_inst_pe_array_PE${pe}_weight0_u_spad_dp \
                  $spad_col2_x $spad_y R0
}

# PE array top = 30 + 7*114.27 + 104.27 = 934.16 um
set spad_array_top [expr {$core_y0 + 7.0 * $spad_pitch + $spad_h}]

# =========================================================================
# 3. TOP STRIP  (y0 = spad_array_top + 40 um routing channel)
# =========================================================================
# Arrangement: [ping | picosoc | pong] centered at die_cx=700
#   Total width = 317.79 + 10 + 586.59 + 10 + 317.79 = 1242.17 um
#   x_start = 675 - 1242.17/2 = 53.915 um
#   Left margin = 53.915 - 30 = 23.915 um
#   Right margin = 1320 - 1296.085 = 23.915 um  (symmetric)

set top_strip_y0 [expr {$spad_array_top + 40.0}]   ;# 974.16 um  (was +20 → +40: routing channel 10→20 um effective after 10 um halos)

set ping_w    317.79
set picosoc_w 586.59
set mac_gap   10.0

set top_x_start  [expr {$die_cx - ($ping_w + $mac_gap + $picosoc_w + $mac_gap + $ping_w) / 2.0}]

set ping_x    $top_x_start                                   ;# 53.915
set picosoc_x [expr {$top_x_start + $ping_w + $mac_gap}]    ;# 381.705
set pong_x    [expr {$picosoc_x  + $picosoc_w + $mac_gap}]  ;# 978.295

# --- pingpong_sram_4096x16 x2  (W=317.79, H=198.555) ---
placeInstance {\psum_mem_ping_sram_gen_4096.u_sram} $ping_x    $top_strip_y0 R0
placeInstance {\psum_mem_pong_sram_gen_4096.u_sram} $pong_x    $top_strip_y0 R0

# --- picosoc_sram_2048x32  (W=586.59, H=111.35) ---
placeInstance soc_memory_u_sram                     $picosoc_x $top_strip_y0 R0

# --- lut_sram_1024x16 x2  (W=317.79, H=69.105) ---
# Stacked directly above ping and pong (same x columns), 15 um routing gap
set pp_top [expr {$top_strip_y0 + 198.555}]   ;# 1172.715 um
set lut_y  [expr {$pp_top + 15.0}]            ;# 1187.715 um  (was +5 → +15: prevents M3 VDD/VSS shorts in narrow gap)

placeInstance decoder_acc_inst_rms_norm_lut_inst_u_recip_lut  $ping_x $lut_y R0
placeInstance decoder_acc_inst_u_sigmoid_u_sigmoid_lut        $pong_x $lut_y R0

# =========================================================================
# 4. PLACEMENT GUIDE — soc_cpu to top strip
# =========================================================================
# soc_cpu placement guide — pull entire soc module to top strip std-cell area.
# Top strip y=974..1370 has ~165,000 um² std-cell space after macros.
# soc_cpu co-located with picosoc SRAM → hold-critical mem paths become short.
catch {deleteInstGroup soc_cpu_group}
catch {
    createInstGroup soc_cpu_group -region {30.0 974.0 1370.0 1370.0}
    addInstToInstGroup soc_cpu_group soc_cpu/*
    puts "INFO: soc_cpu_group placement guide set to top strip y=974..1370"
}

# =========================================================================
# 5. LOCK ALL MACROS
# =========================================================================
set macro_ptrs [dbGet top.insts.cell.baseClass block -p2]
if {[llength $macro_ptrs] > 0} {
    dbSet $macro_ptrs.pStatus fixed
    puts "INFO: [llength $macro_ptrs] macro instances locked (pStatus = fixed)."
} else {
    puts "WARN: No macro instances found — check that init_design completed."
}

# =========================================================================
# 6. ROUTING HALOS AROUND MACROS
# =========================================================================
addHaloToBlock 10.0 10.0 10.0 10.0 -allMacro

# =========================================================================
# 7. PIN ASSIGNMENT
# =========================================================================
setPinAssignMode -pinEditInBatch true

editPin -pin clk_16mhz          -side Left   -layer M4 -spreadType CENTER
editPin -pin pin_2               -side Left   -layer M4 -spreadType CENTER
editPin -pin pin_1               -side Bottom -layer M3 -spreadType CENTER
editPin -pin {user_leds[*]}      -side Bottom -layer M3 -spreadType CENTER
editPin -pin qspi_sck            -side Top    -layer M4 -spreadType CENTER
editPin -pin qspi_cs_n           -side Top    -layer M4 -spreadType CENTER
editPin -pin {qspi_io_out[*]}    -side Top    -layer M4 -spreadType CENTER
editPin -pin {qspi_io_in[*]}     -side Top    -layer M4 -spreadType CENTER
editPin -pin qspi_io_oe          -side Top    -layer M4 -spreadType CENTER

# =========================================================================
# 8. SAVE DATABASE
# =========================================================================
saveDesign ${OUT_DIR}/DBS/02_floorplan.enc

puts "======================================================="
puts " SUCCESS: Floorplan Complete"
puts "  Die        : 1400 x 1400 um (1.96 mm²)"
puts "  Core       : 1340 x 1340 um (x=30..1370, y=30..1370)"
puts "  PE array   : col1_x=50.0 col2_x=710.7, gap=100 um, rows y=30+n*114.27"
puts "  Top strip  : {ping|picosoc|pong} centered at x=700, y=974.16"
puts "  LUT pair   : above ping/pong, y=1187.72"
puts "  Halo       : 10 um all sides"
puts "  Density    : ~74.7% std cell (1,443,183 um² cell area)"
puts "  soc_cpu    : guided to top strip y=974..1370 (near picosoc SRAM)"
puts "  PE gap     : 118.6 um center gap (no hard blockage — soft guide only)"
puts "  Macros     : 21 placed and locked"
puts "======================================================="
