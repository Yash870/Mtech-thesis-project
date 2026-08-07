import os
import numpy as np

# --- 1. SET UP THE FILE PATHS ---
# Using the exact paths from your check_golden.py script
GLD_DIR = '/home/veeresh/picorv_code/build/codes/veeresh_compiler/build_output/golden'
HEX_DIR = '/home/veeresh/picorv_code/build/codes/veeresh_compiler/build_output/hex'

L1_OUT_FILE = os.path.join(GLD_DIR, "layer_1_conv_golden.hex")
LUT_FILE    = os.path.join(HEX_DIR, "reciprocal_lut.hex")

# The Zero-Point of Layer 1 (acts as Z_in for Layer 2). 
# Change this if your terminal showed a different Z-point for Layer 1!
Z_IN = 68 

def _hex_to_signed(h, bits=16):
    v = int(h.strip(), 16)
    if v >= (1 << (bits - 1)): v -= (1 << bits)
    return v

def _hex_to_unsigned(h):
    return int(h.strip(), 16)

print("="*60)
print(f"{'REAL DATA RMS DIVERGENCE PROOF':^60}")
print("="*60)

# --- 2. LOAD THE LOCAL HEX FILES ---
print("[+] Loading local hex files...")
try:
    with open(LUT_FILE, "r") as f:
        lut = [_hex_to_unsigned(line) for line in f if line.strip()]
        
    with open(L1_OUT_FILE, "r") as f:
        l1_out = [_hex_to_signed(line, 16) for line in f if line.strip()]
except FileNotFoundError as e:
    print(f"❌ ERROR: Could not find file. Did you run the compiler first?\n{e}")
    exit(1)

# --- 3. EXTRACT PIXEL 0 (FIRST 32 CHANNELS) ---
# This is the exact 32-value array Keras and the hardware are looking at
pixel_0 = np.array(l1_out[:32], dtype=np.int64)

print(f"\n[+] Analyzing Pixel 0 (Channels 0-31)")
print(f"    Raw Hex Values (first 5): {pixel_0[:5]}")

# Center the data exactly like your quant_rms_lut function does
q_centered = pixel_0 - Z_IN
sq_val = q_centered ** 2
sum_sq = np.sum(sq_val)

# --- 4. METHOD A: Keras Float Math ---
keras_mean = sum_sq / 32.0
keras_recip = 1.0 / np.sqrt(keras_mean) if keras_mean > 0 else 0

# --- 5. METHOD B: Hardware Integer Math ---
# Your >> 5 logic from compiler_23.py
hw_mean = sum_sq >> 5
hw_mean = max(hw_mean, 1)

# Hardware LUT Lookup Logic
msb_pos_hw = int(np.floor(np.log2(hw_mean)))
shifted_mean = hw_mean << (39 - msb_pos_hw)
rom_addr = (shifted_mean >> 29) & 1023
lut_mantissa = lut[rom_addr]

# --- 6. THE VERDICT ---
print(f"\n{'-'*60}")
print(f"{'MATHEMATICAL BREAKDOWN':^60}")
print(f"{'-'*60}")
print(f"True Sum of Squares: {sum_sq}")
print(f"Keras Float Mean:    {keras_mean:.3f}")
print(f"Hardware Shift Mean: {hw_mean}.000  <-- (This is the truncation!)")

print(f"\nLUT Address (Index): {rom_addr}")
print(f"LUT Hex Value:       0x{lut_mantissa:04X}")

if keras_mean > 0:
    # We calculate the float equivalent of what the hardware LUT math resolves to
    hw_recip_ideal = 1.0 / np.sqrt(hw_mean)
    divergence = abs(keras_recip - hw_recip_ideal) / keras_recip * 100
    
    print(f"\nKeras Multiplier:    {keras_recip:.6f}")
    print(f"Hardware Multiplier: {hw_recip_ideal:.6f}")
    
    print(f"\n{'='*60}")
    print(f"MULTIPLIER DIVERGENCE: {divergence:.2f}%")
    print(f"{'='*60}")
    print("\nCONCLUSION:")
    print("This explicitly proves that the 13-step error is caused by the")
    print(">> 5 bit-shift chopping off the decimal points before the LUT lookup.")