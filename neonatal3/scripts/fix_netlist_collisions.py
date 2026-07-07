#!/usr/bin/env python3
"""
fix_netlist_collisions.py — Fix Innovus net name collisions in hardware_routed.v.

Innovus re-used picorv32-scope net names (n_0..n_3685) for decoder_acc gates
inside the hardware module (lines 103785-170075). This renames those bare n_XXX
nets to dac_n_XXX within that zone and inserts wire declarations at line 92212
(after last wire decl in hardware module, safely before first gate).

Usage:
    python3 fix_netlist_collisions.py \
        ../innovus_output/EXPORTS/hardware_routed_innovus.v \
        ../innovus_output/EXPORTS/hardware_routed.v
"""

import re
import sys

INFILE  = sys.argv[1]
OUTFILE = sys.argv[2]

# Collision zone (1-based line numbers in original file)
ZONE_START = 103785
ZONE_END   = 170075

# Max picorv32 net index — n_0..n_3685 are picorv32 scope
MAX_PICORV32_IDX = 3685

# Insert wire declarations after this line (last wire decl in hardware module)
WIRE_INSERT_AFTER = 92212

# Matches bare n_NNN — negative lookbehind/ahead prevents matching inside
# longer identifiers like FE_OFN1_n_123 or csa_tree_n_456
NET_RE = re.compile(r'(?<![A-Za-z0-9_])n_(\d+)(?![A-Za-z0-9_])')

# Matches gate output pins only (used for collision discovery pass)
OUTPUT_RE = re.compile(r'\.ZN?\(n_(\d+)\)')

def is_collision(idx):
    return 0 <= idx <= MAX_PICORV32_IDX

def rename_net(m):
    idx = int(m.group(1))
    if is_collision(idx):
        return f'dac_n_{idx}'
    return m.group(0)

print(f"Reading {INFILE}...")
with open(INFILE, 'r') as f:
    lines = f.readlines()
print(f"  {len(lines)} lines read.")

# Pass 1: collect all collision net indices driven in the zone
new_nets = set()
for i in range(ZONE_START - 1, ZONE_END):   # 0-based indexing
    for m in OUTPUT_RE.finditer(lines[i]):
        idx = int(m.group(1))
        if is_collision(idx):
            new_nets.add(idx)
print(f"  Found {len(new_nets)} unique collision nets → will rename to dac_n_XXX.")

# Build wire declaration lines (one list element per line for correct line counting)
wire_decl_lines = [f'   wire dac_n_{i};\n' for i in sorted(new_nets)]
n_inserted = len(wire_decl_lines)
print(f"  Inserting {n_inserted} wire declarations after line {WIRE_INSERT_AFTER}.")

# Pass 2: build output line list
out = []
for i, line in enumerate(lines):
    lineno = i + 1  # 1-based

    if lineno == WIRE_INSERT_AFTER:
        out.append(line)
        out.extend(wire_decl_lines)   # extend keeps one element per line
        continue

    if ZONE_START <= lineno <= ZONE_END:
        line = NET_RE.sub(rename_net, line)

    out.append(line)

print(f"Writing {OUTFILE}...")
with open(OUTFILE, 'w') as f:
    f.writelines(out)
print(f"  Done. Output: {len(out)} lines (expected {len(lines) + n_inserted}).")

# Pass 3: verify — rescan zone in output list (zone shifted by n_inserted lines)
# After insertion, original ZONE_START..ZONE_END shifted up by n_inserted
out_zone_start = ZONE_START + n_inserted
out_zone_end   = ZONE_END   + n_inserted
print("Verifying: scanning output zone for remaining collisions...")
remaining = 0
for i in range(out_zone_start - 1, out_zone_end):   # 0-based
    for m in OUTPUT_RE.finditer(out[i]):
        idx = int(m.group(1))
        if is_collision(idx):
            remaining += 1
            if remaining <= 5:
                print(f"  STILL COLLIDING line {i+1}: {out[i].rstrip()}")
print(f"  Remaining collisions in zone: {remaining}")
if remaining == 0:
    print("  PASS — all collisions fixed.")
else:
    print("  FAIL — collisions remain, check ZONE_START/ZONE_END constants.")
print("Done.")
