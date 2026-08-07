import os
import re

# ==============================================================================
# 1. FILE PATHS & HELPERS
# ==============================================================================
DIR = "/home/veeresh/veeresh/mithin_rms/golden_final"

def hex_to_signed(hex_str, bits):
    val = int(hex_str.strip(), 16)
    return val - (1 << bits) if val & (1 << (bits - 1)) else val

def read_hex(filename, bits):
    filepath = os.path.join(DIR, filename)
    with open(filepath, 'r') as f:
        return [hex_to_signed(line, bits) for line in f if line.strip()]

def get_l1_params():
    with open(os.path.join(DIR, "hardware_quant_params.txt"), 'r') as f:
        content = f.read()
    
    mult = int(re.search(r"`define LAYER_1_CONV_QAT_MULT\s+32'h([0-9A-Fa-f]+)", content).group(1), 16)
    shift = int(re.search(r"`define LAYER_1_CONV_QAT_SHIFT\s+6'h([0-9A-Fa-f]+)", content).group(1), 16)
    z_out = int(re.search(r"`define LAYER_1_CONV_ZERO_POINT\s+16'h([0-9A-Fa-f]+)", content).group(1), 16)
    return mult, shift, z_out

# ==============================================================================
# 2. HARDWARE MATH REPLICA (qat_requantizer.v)
# ==============================================================================
def hardware_qat(accum, qat_mult, qat_shift, z_out):
    product = accum * qat_mult
    
    # Verilog logic: assign total_shift = 31 + qat_shift;
    total_shift = 31 + qat_shift 
    
    # Verilog logic: rounding_val = (1 << (total_shift - 1))
    rounding_val = (1 << (total_shift - 1)) if total_shift > 0 else 0
    
    round_product = product + rounding_val
    
    # Verilog logic: Arithmetic Right Shift (>>>)
    shifted_val = round_product >> total_shift 
    
    val_with_zp = shifted_val + z_out
    
    # Verilog logic: Clamp to int16
    if val_with_zp > 32767: return 32767
    if val_with_zp < -32768: return -32768
    return val_with_zp

# ==============================================================================
# 3. RUN BIT-ACCURATE SIMULATION
# ==============================================================================
print("Loading Hex Files...")
ifmap   = read_hex("seizure_1.hex", 16)               # 15 * 90 = 1350
weights = read_hex("layer_1_conv_weights.hex", 16)    # 32 * 270 = 8640
biases  = read_hex("layer_1_conv_bias.hex", 32)       # 32

Z_IN = 15
MULT, SHIFT, Z_OUT = get_l1_params()

print(f"Hardware Params -> Mult: {hex(MULT)}, Shift: {SHIFT}, Z_out: {Z_OUT}")
print("Simulating PE Array...")

hw_out = [0] * 480 # 15 timesteps * 32 filters

for f_idx in range(32):
    w_start = f_idx * 270
    bias = biases[f_idx]
    
    # TIMESTEP 0 (LPAD: skips first 90 weights)
    accum = sum((ifmap[i] - Z_IN) * weights[w_start + 90 + i] for i in range(180)) + bias
    hw_out[0 * 32 + f_idx] = hardware_qat(accum, MULT, SHIFT, Z_OUT)
    
    # TIMESTEP 1 to 13 (FULL)
    ws = 0
    for t in range(1, 14):
        accum = sum((ifmap[ws + i] - Z_IN) * weights[w_start + i] for i in range(270)) + bias
        hw_out[t * 32 + f_idx] = hardware_qat(accum, MULT, SHIFT, Z_OUT)
        ws += 90
        
    # TIMESTEP 14 (RPAD: skips last 90 weights)
    # ws is now 1170
    accum = sum((ifmap[1170 + i] - Z_IN) * weights[w_start + i] for i in range(180)) + bias
    hw_out[14 * 32 + f_idx] = hardware_qat(accum, MULT, SHIFT, Z_OUT)

# ==============================================================================
# 4. EXPORT TRUE GOLDEN
# ==============================================================================
out_path = os.path.join(DIR, "true_hardware_golden.hex")
with open(out_path, "w") as f:
    for val in hw_out:
        f.write(f"{val & 0xFFFF:04x}\n")

print(f"SUCCESS: Bit-Accurate Golden File saved to {out_path}")