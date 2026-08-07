import os
import math
import numpy as np

# --- BYPASS CUDA CRASH ---
os.environ.setdefault("CUDA_VISIBLE_DEVICES", "-1")
os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")
os.environ.setdefault("TF_ENABLE_ONEDNN_OPTS", "0")
import tensorflow as tf
import tf_keras

# ==============================================================================
# 1. CONFIGURATION & DIRECTORIES
# ==============================================================================
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.environ.get('MNIST_MODEL_PATH', os.path.join(SCRIPT_DIR, 'mnist_model'))
MNIST_INDEX = int(os.environ.get('MNIST_INDEX', '0'))
MNIST_START = int(os.environ.get('MNIST_START', str(MNIST_INDEX)))
MNIST_COUNT = int(os.environ.get('MNIST_COUNT', '1'))
MNIST_CALIB_SAMPLES = int(os.environ.get('MNIST_CALIB_SAMPLES', '1000'))

OUT_DIR = os.path.join(SCRIPT_DIR, 'build_output')
HEX_DIR = os.path.join(OUT_DIR, 'hex')
SRC_DIR = SCRIPT_DIR
GLD_DIR = os.path.join(OUT_DIR, 'golden')
CASES_DIR = os.environ.get('MNIST_CASES_DIR', os.path.join(OUT_DIR, 'mnist_cases'))

LAYER_RANGES = {}

for d in [HEX_DIR, GLD_DIR]:
    os.makedirs(d, exist_ok=True)

# ==============================================================================
# 2. UTILITIES & LUT GENERATION
# ==============================================================================
def to_hex16(val): return f"{int(val) & 0xFFFF:04X}\n"
def to_hex32(val): return f"{int(val) & 0xFFFFFFFF:08X}\n"

def generate_reciprocal_lut(num_entries=1024):
    lut = []
    with open(os.path.join(HEX_DIR, "reciprocal_lut.hex"), "w") as f:
        for addr in range(num_entries):
            real_value = 1.0 + (addr / num_entries)
            reciprocal = 1.0 / real_value
            scaled_recip = min(int(round(reciprocal * 65535)), 65535)
            lut.append(scaled_recip)
            f.write(f"{scaled_recip:04X}\n")
    return lut

def generate_standard_sigmoid_lut(num_entries=1024, range_min=-8.0, range_max=8.0):
    lut = []
    step = (range_max - range_min) / num_entries
    with open(os.path.join(HEX_DIR, "sigmoid_lut.hex"), "w") as f:
        for addr in range(num_entries):
            x = range_min + (addr * step)
            sig = 1.0 / (1.0 + math.exp(-x))
            val = min(int(round(sig * 65535)), 65535)
            lut.append(val)
            f.write(to_hex16(val))
    return lut

recip_lut = generate_reciprocal_lut()
sig_lut = generate_standard_sigmoid_lut()

def reciprocal_via_lut_bitwise(x_value, lut=recip_lut):
    if x_value <= 0: return 0.0, 0
    SCALE_BITS = 40
    x_fixed = int(x_value * (1 << SCALE_BITS))
    if x_fixed == 0: return 0.0, 0
    
    msb_pos = x_fixed.bit_length() - 1
    k = msb_pos - SCALE_BITS
    
    x_norm_fixed = x_fixed >> k if k >= 0 else x_fixed << (-k)
    addr = (x_norm_fixed - (1 << SCALE_BITS)) >> (SCALE_BITS - 10)
    addr = min(max(addr, 0), 1023)
    return lut[addr], k

def calc_hardware_multiplier(S_in, S_w, S_out):
    M_float = (S_in * S_w) / S_out if S_out != 0 else 0
    if M_float == 0: return 0, 0
    shift = 0
    M0 = M_float
    while M0 < 0.5:
        M0 *= 2
        shift += 1
    mult = int(np.round(M0 * (1 << 31)))
    return mult, shift

def hardware_requantize(acc_array, mult, shift, z_out):
    # Match the Verilog 75-bit shift logic exactly!
    c_shift = shift + 31
    
    # Use int64 to securely hold the massive product
    acc_64 = acc_array.astype(np.int64)
    mult_64 = np.int64(mult)
    
    # 1. Product (75-bit equivalent)
    product = acc_64 * mult_64
    
    # 2. Add the exact rounding value used in Verilog
    rounding_val = (1 << (c_shift - 1)) if c_shift > 0 else 0
    round_product = product + rounding_val
    
    # 3. Single Arithmetic Right Shift
    shifted = round_product >> c_shift
    
    # 4. Zero Point addition and Clamp
    result = shifted + z_out
    return np.clip(result, 0, 255).astype(np.uint8)

# ==============================================================================
# 3. NUMPY INFERENCE SIMULATOR
# ==============================================================================
def get_cnn(layer):
    w_float, b_float = None, None
    w_min, w_max, post_min, post_max, out_min, out_max = None, None, None, None, None, None
    for w in layer.weights:
        n = w.name.lower()
        if ("kernel" in n or "scale" in n) and "min" not in n and "max" not in n: w_float = w.numpy()
        elif "bias" in n and "min" not in n and "max" not in n: b_float = w.numpy()
        elif ("kernel" in n or "scale" in n) and "min" in n: w_min = float(w.numpy())
        elif ("kernel" in n or "scale" in n) and "max" in n: w_max = float(w.numpy())
        elif ("post_activation" in n or "pre_activation" in n) and "min" in n: post_min = float(w.numpy())
        elif ("post_activation" in n or "pre_activation" in n) and "max" in n: post_max = float(w.numpy())
        elif "output" in n and "min" in n: out_min = float(w.numpy())
        elif "output" in n and "max" in n: out_max = float(w.numpy())

    if w_float is not None:
        if w_min is None: w_min = float(np.min(w_float))
        if w_max is None: w_max = float(np.max(w_float))
        if w_min == w_max:
            w_min -= 1.0
            w_max += 1.0

    if out_min is None: out_min = post_min
    if out_max is None: out_max = post_max
    if (out_min is None or out_max is None) and layer.name in LAYER_RANGES:
        out_min, out_max = LAYER_RANGES[layer.name]
    if out_min is None: out_min = 0.0
    if out_max is None: out_max = 1.0
    if out_min == out_max:
        out_min -= 1.0
        out_max += 1.0
    return w_float, b_float, w_min, w_max, post_min, post_max, out_min, out_max

def quantize_weights_symmetric(w_float, w_min, w_max, num_bits=8):
    q_min, q_max = -(1 << (num_bits - 1)), (1 << (num_bits - 1)) - 1
    scale = (w_max - w_min) / (q_max - q_min) if (w_max - w_min) != 0 else 1.0
    zero_point = np.clip(np.round(q_min - w_min / scale), q_min, q_max).astype(np.int8)
    clamped = np.clip(w_float, w_min, w_max)
    w_int = np.clip(np.round(clamped / scale + zero_point), q_min, q_max).astype(np.int8)
    return w_int, scale, zero_point

# def quantized_cnn(q_input, S_in, Z_in, layer):
#     w_f, b_f, w_min, w_max, _, _, o_min, o_max = get_cnn(layer)
#     q_filter, S_f, _ = quantize_weights_symmetric(w_f, w_min, w_max)
#     S_b = S_in * S_f
#     q_bias = np.round(b_f / S_b).astype(np.int32) if b_f is not None else None

#     in_x, filt_x, num_f = q_input.shape[0], q_filter.shape[0], q_filter.shape[-1]
#     pad_l = (filt_x - 1) // 2
#     pad_r = (filt_x - 1) - pad_l
#     padded = np.pad(q_input, ((pad_l, pad_r), (0, 0)), 'constant', constant_values=Z_in)

#     S_out = (o_max - o_min) / 255.0 if o_max != o_min else 1.0
#     Z_out = int(np.clip(np.round(0 - o_min / S_out), 0, 255)) if o_max != o_min else 0
#     output = np.zeros((in_x, num_f), dtype=np.int32)

#     for i in range(in_x):
#         for j in range(num_f):
#             patch = padded[i:i + filt_x, :].astype(np.int32)
#             filt = q_filter[:, :, j].astype(np.int32)
#             output[i, j] = np.sum((patch - Z_in) * filt) + (q_bias[j] if q_bias is not None else 0)

#     mult, shift = calc_hardware_multiplier(S_in, S_f, S_out)
#     return hardware_requantize(output, mult, shift, Z_out), S_out, Z_out

def quantized_cnn(q_input, S_in, Z_in, layer):
    w_f, b_f, w_min, w_max, _, _, o_min, o_max = get_cnn(layer)
    q_filter, S_f, _ = quantize_weights_symmetric(w_f, w_min, w_max)
    S_b = S_in * S_f
    q_bias = np.round(b_f / S_b).astype(np.int32) if b_f is not None else None

    in_x, filt_x, num_f = q_input.shape[0], q_filter.shape[0], q_filter.shape[-1]
    pad_l = (filt_x - 1) // 2
    pad_r = (filt_x - 1) - pad_l
    padded = np.pad(q_input, ((pad_l, pad_r), (0, 0)), 'constant', constant_values=Z_in)

    S_out = (o_max - o_min) / 255.0 if o_max != o_min else 1.0
    Z_out = int(np.clip(np.round(0 - o_min / S_out), 0, 255)) if o_max != o_min else 0
    output = np.zeros((in_x, num_f), dtype=np.int32)

    for i in range(in_x):
        for j in range(num_f):
            patch = padded[i:i + filt_x, :].astype(np.int32)
            filt = q_filter[:, :, j].astype(np.int32)
            output[i, j] = np.sum((patch - Z_in) * filt) + (q_bias[j] if q_bias is not None else 0)

    mult, shift = calc_hardware_multiplier(S_in, S_f, S_out)
    q_out = hardware_requantize(output, mult, shift, Z_out)
    
    # THE FIX: QAT FakeQuant enforces a 0.0 lower bound for uint8. Clamp to Z_out!
    q_out = np.maximum(q_out, Z_out)
    
    return q_out, S_out, Z_out

def quant_rms_lut(q_input, S_in, Z_in, layer):
    scale, s_min, s_max, o_min, o_max = None, 0.0, 0.0, 0.0, 0.0
    for w in layer.weights:
        n = w.name.lower()
        if "scale_min" in n: s_min = float(w.numpy())
        elif "scale_max" in n: s_max = float(w.numpy())
        elif "output_min" in n: o_min = float(w.numpy())
        elif "output_max" in n: o_max = float(w.numpy())
        elif "scale" in n: scale = w.numpy()

    S_s = (s_max - s_min) / 255.0 if s_max != s_min else 1.0
    Z_s = int(np.clip(np.round(0 - s_min / S_s), 0, 255))
    q_scale = np.clip(np.round(scale / S_s + Z_s), 0, 255).astype(np.uint8)

    S_out = (o_max - o_min) / 255.0 if o_max != o_min else 1.0
    Z_out = int(np.clip(np.round(0 - o_min / S_out), 0, 255))

    # Safely reshape the array based on dynamic channel count
    channels = q_scale.shape[0]
    original_shape = q_input.shape
    q_reshaped = q_input.astype(np.int64).reshape(-1, channels)
    
    q_centered = q_reshaped - Z_in
    sq_val = q_centered ** 2
    
    # RESTORED: Your original sum and >> logic
    sum_sq = np.sum(sq_val, axis=-1, keepdims=True).astype(np.int64)
    if channels == 32:
        lut_mean_in = sum_sq >> 5
    elif channels == 64:
        lut_mean_in = sum_sq >> 6
    else:
        lut_mean_in = sum_sq >> 7
        
    lut_mean_in = np.maximum(lut_mean_in, 1) 
    
    msb_pos_hw = np.floor(np.log2(lut_mean_in)).astype(np.int64)
    shifted_mean = lut_mean_in << (39 - msb_pos_hw)
    rom_addr = (shifted_mean >> 29) & 1023
    lut_mantissa = np.array([recip_lut[addr] for addr in rom_addr.flatten()]).reshape(rom_addr.shape)
    
    # RESTORED: Multiplying the SQUARED pixel by mantissa
    full_mant_prod = sq_val * lut_mantissa

    cur_x_norm = full_mant_prod >> msb_pos_hw
    
    q_w_signed = q_scale.astype(np.int64) - Z_s
    gamma_prod = cur_x_norm * q_w_signed
    
    M_float = S_s / (S_out * 65535.0) if S_out != 0 else 0
    mult, shift = calc_hardware_multiplier(1.0, M_float, 1.0) 
    
    q_out = hardware_requantize(gamma_prod, mult, shift, Z_out)
    
    # # ADD THIS TO PRINT PYTHON'S EXACT MATH FOR PIXEL 0
    # print("\n--- PYTHON BATCH 0 TRACE ---")
    # print(f"Sum of Squares (Python): {sum_sq[0][0]}")
    # print(f"LUT Mean In: {lut_mean_in[0][0]}")
    # print(f"Mantissa: {lut_mantissa[0][0]}")
    # print(f"K (MSB Pos): {msb_pos_hw[0][0]}")
    # print(f"X Norm 0: {cur_x_norm[0][0]}")
    # print(f"Gamma Weight 0: {q_w_signed[0]}")
    # print(f"Gamma Product 0: {gamma_prod[0][0]}")
    # print(f"Mult: {mult}, Shift: {shift}, Z_out: {Z_out}")
    # print(f"Final Requantized Output 0: {q_out.flatten()[0]}")
    # print("----------------------------\n")

    return q_out.reshape(original_shape), S_out, Z_out, S_s

def max_pool(input, pool_size):
    in_x, channels = input.shape
    out_x = in_x // pool_size
    output = np.zeros((out_x, channels))
    for i in range(out_x):
        output[i, :] = np.max(input[i*pool_size:(i+1)*pool_size, :], axis=0)
    return output

def quant_dense(q_input, S_in, Z_in, layer, relu=False):
    w_f, b_f, w_min, w_max, _, _, o_min, o_max = get_cnn(layer)
    max_abs = max(abs(w_min if w_min else 0), abs(w_max if w_max else 0))
    S_f = max_abs / 127.0 if max_abs != 0 else 1.0
    q_kernel = np.clip(np.round(w_f / S_f), -127, 127).astype(np.int8)
    S_b = S_in * S_f
    q_bias = np.round(b_f / S_b).astype(np.int32) if b_f is not None else None
    S_out = (o_max - o_min) / 255.0 if o_max != o_min else 1.0
    Z_out = int(np.clip(np.round(0 - (o_min / S_out)), 0, 255))

    acc = (q_input.astype(np.int32) - Z_in) @ q_kernel.astype(np.int32)
    if q_bias is not None: acc += q_bias

    mult, shift = calc_hardware_multiplier(S_in, S_f, S_out)
    q_out = hardware_requantize(acc, mult, shift, Z_out)
    if relu: q_out = np.maximum(q_out, Z_out)
    return np.clip(q_out, 0, 255).astype(np.uint8), S_out, Z_out

# ==============================================================================
# 4. HARDWARE PARAM EXTRACTION & C-GENERATORS
# ==============================================================================
class HardwareState:
    def __init__(self):
        self.w_ptr = 0
        self.b_ptr = 0
        self.pp = 0
        self.seq_len = 0
        self.channels = 0
        self.flattened = False

def get_weight_scale(layer):
    w_f, b_f, w_min, w_max, *_ = get_cnn(layer)
    if "conv" in layer.name.lower():
        _, s, _ = quantize_weights_symmetric(w_f, w_min, w_max)
        return float(s)
    elif "dense" in layer.name.lower():
        max_abs = max(abs(w_min if w_min else 0), abs(w_max if w_max else 0))
        return (max_abs / 127.0) if max_abs != 0 else 1.0
    elif "rms" in layer.name.lower():
        return (w_max - w_min) / 255.0 if w_max != w_min else 1.0
    return 1.0

class SigmoidLayer:
    def __init__(self, name, s_out, z_out, num_elements):
        self.name = name
        M_float = s_out * 64.0
        B_float = 512.0 - (z_out * s_out * 64.0)
        self.scale_bits = min(math.floor(math.log2(32767.0 / abs(M_float))), 16) if M_float != 0 else 0
        self.m_int = int(round(M_float * (1 << self.scale_bits)))
        self.b_int = int(round(B_float * (1 << self.scale_bits)))
        self.num_elements = num_elements

    def generate_c_code(self):
        c = f"\n    /* --- {self.name} --- */\n"
        c += f"    acc_swap_pp(1U);\n"
        
        # THE FIX: Declare the array as 'volatile'. 
        # GCC is now legally required to execute acc_sigmoid and write the result here.
        c += f"    volatile uint32_t final_outputs[{self.num_elements}];\n"
        
        c += f"    for (uint32_t i = 0; i < {self.num_elements}; i++) {{\n"
        c += f"        uint32_t rs1 = (i << 20) | ({self.scale_bits}U << 16) | 0x{self.m_int & 0xFFFF:04X}U;\n"
        c += f"        uint32_t rs2 = 0x{self.b_int & 0xFFFFFFFF:08X}U;\n"
        
        c += f"        final_outputs[i] = acc_sigmoid(rs1, rs2);\n"
        c += f"    }}\n"
        return c

def generate_conv_c(name, hw, in_ch, out_ch, k_size, S_in, S_w, S_out, Z_out, Z_in, is_first_layer=False):
    M_float = (S_in * S_w) / S_out if S_out != 0 else 0
    shift, M0 = 0, M_float
    if M0 > 0:
        while M0 < 0.5: M0 *= 2; shift += 1
    mult = int(np.round(M0 * (1 << 31)))
    
    c_shift = shift + 31
    packed_z = ((Z_in & 0xFF) << 8) | (Z_out & 0xFF)
    qsz = f"(((uint32_t)0x{c_shift:02X} << 16) | 0x{packed_z:04X}U)"
    qm = f"0x{mult:08X}U"
    
    # Calculate Keras 'SAME' left padding dynamically
    pad_l = (k_size - 1) // 2 
    batches = math.ceil(out_ch / 8)
    
    swap_val = 0 if is_first_layer else 1
    
    c = f"\n    /* --- {name} --- */\n    acc_swap_pp({swap_val}U);\n"
    c += f"    for(uint32_t p=0; p<8; p++) {{ acc_load_qat(p, {qm}, {qsz}); }}\n"
    
    c += f"    {{ uint32_t ws = {hw.w_ptr}U, bias_ptr = {hw.b_ptr}U, out_ptr = 0U;\n" 
    c += f"      for (uint32_t b=0; b<{batches}U; b++) {{\n"
    c += f"          run_conv_batch_generic(ws, bias_ptr, out_ptr, {in_ch}U, {k_size}U, {hw.seq_len}U, {out_ch}U, {pad_l}U, 1U);\n"
    c += f"          ws += {8 * in_ch * k_size}U; bias_ptr += 8U; out_ptr += 8U; }} }}\n"
    
    hw.w_ptr += in_ch * k_size * out_ch; hw.b_ptr += out_ch
    hw.channels = out_ch
    
    # Make sure we keep the Ping-Pong tracking!
    hw.pp = 1 - hw.pp 
    return c

def generate_rms_c(name, hw, channels, elements, S_s, S_out, Z_out, Z_in):
    M_float = S_s / (S_out * 65535.0) if S_out != 0 else 0
    
    shift, M0 = 0, M_float
    if M0 > 0:
        while M0 < 0.5: 
            M0 *= 2
            shift += 1
    mult = int(np.round(M0 * (1 << 31)))

    c_shift = shift + 31 
    # FIX: PACK BOTH Z_IN AND Z_OUT INTO 16 BITS
    packed_z = ((Z_in & 0xFF) << 8) | (Z_out & 0xFF)
    qsz = f"(((uint32_t)0x{c_shift:02X} << 16) | 0x{packed_z:04X}U)"
    qm = f"0x{mult:08X}U"
    
    timesteps = elements // channels
    me = 0 if channels == 32 else (1 if channels == 64 else 2)
    w_start = hw.w_ptr
    w_end = w_start + channels - 1

    c = f"\n    /* --- {name} --- */\n"
    c += f"    acc_swap_pp(1U);\n"
    c += f"    acc_load_qat(0U, {qm}, {qsz});\n"
    c += f"    acc_load_weight(0U, {w_start}U, {w_end}U);\n\n"
    c += f"    {{ uint32_t start_idx = 0U;\n"
    c += f"      for (uint32_t t = 0U; t < {timesteps}U; t++) {{\n"
    c += f"          acc_load_ifmap(0U, start_idx, start_idx + {channels - 1}U);\n"
    c += f"          acc_set_start_val(0U, 0U);\n"
    c += f"          acc_set_end_val(0U, {channels - 1}U);\n"
    c += f"          acc_load_iw_counter(0U);\n"
    c += f"          acc_start_rms(start_idx, {me}U);\n"
    c += f"          start_idx += {channels}U; }} }}\n"

    hw.w_ptr += channels
    return c

def generate_pool_c(name, hw):
    pairs = hw.seq_len // 2
    c_code = f"""
    /* --- {name} --- */
    acc_swap_pp(1U);
    {{ uint32_t rd=0U, wr=0U, stride={hw.channels}U, ps={pairs}U;
      acc_maxpool((stride << 12) | rd, (ps << 12) | wr); 
    }}"""
    hw.seq_len = pairs
    return c_code

def generate_dense_c(name, hw, in_ch, out_ch, S_in, S_w, S_out, Z_out, Z_in, relu=False):
    M_float = (S_in * S_w) / S_out if S_out != 0 else 0
    shift, M0 = 0, M_float
    if M0 > 0:
        while M0 < 0.5: M0 *= 2; shift += 1
    mult = int(np.round(M0 * (1 << 31)))
    
    c_shift = shift + 31
    packed_z = ((Z_in & 0xFF) << 8) | (Z_out & 0xFF)
    qsz = f"(((uint32_t)0x{c_shift:02X} << 16) | 0x{packed_z:04X}U)"
    qm = f"0x{mult:08X}U"
    batches = math.ceil(out_ch / 8)
    
    c = f"\n    /* --- {name} --- */\n    acc_swap_pp(1U);\n"
    c += f"    for(uint32_t p=0; p<8; p++) {{ acc_load_qat(p, {qm}, {qsz}); }}\n"
    
    relu_val = "1U" if relu else "0U"
    
    for b in range(batches):
        active_pes = min(8, out_ch - b * 8)
        ws = hw.w_ptr + b * 8 * in_ch
        b_ptr = hw.b_ptr + b * 8
        out_ptr = b * 8
        c += f"    run_dense_batch({ws}U, {b_ptr}U, {out_ptr}U, {in_ch-1}U, {active_pes}U, {relu_val});\n"
    
    hw.w_ptr += in_ch * out_ch; hw.b_ptr += out_ch
    hw.channels = out_ch; hw.seq_len = 1; hw.pp = 1 - hw.pp; hw.flattened = True
    return c

# ==============================================================================
# 5. ORCHESTRATION ENGINE
# ==============================================================================

C_FIRMWARE_HEADER = '#include <stdint.h>\n\n#define ACC_CMD(f7, f3, rs1, rs2) asm volatile (".insn r 0x2b, %1, %0, x0, %2, %3" :: "i"(f7), "i"(f3), "r"(rs1), "r"(rs2))\n#define ACC_CMD_RD(f7, f3, rd, rs1) asm volatile (".insn r 0x2b, %2, %1, %0, %3, x0" : "=r"(rd) : "i"(f7), "i"(f3), "r"(rs1))\n#define ACC_CMD_RD_RS2(f7, f3, rd, rs1, rs2) asm volatile (".insn r 0x2b, %2, %1, %0, %3, %4" : "=r"(rd) : "i"(f7), "i"(f3), "r"(rs1), "r"(rs2))\n\n\n#define DISPATCH_PE(f7, pe, rs1, rs2) do { \\\\\n    uint32_t _a=(rs1),_b=(rs2); switch((uint32_t)(pe)){ \\\\\n    case 0:ACC_CMD(f7,0,_a,_b);break; case 1:ACC_CMD(f7,1,_a,_b);break; \\\\\n    case 2:ACC_CMD(f7,2,_a,_b);break; case 3:ACC_CMD(f7,3,_a,_b);break; \\\\\n    case 4:ACC_CMD(f7,4,_a,_b);break; case 5:ACC_CMD(f7,5,_a,_b);break; \\\\\n    case 6:ACC_CMD(f7,6,_a,_b);break; case 7:ACC_CMD(f7,7,_a,_b);break; \\\\\n}} while(0)\n\n#define NUM_PES 8U\n\nstatic inline void acc_load_ifmap    (uint32_t pe, uint32_t s, uint32_t e) { DISPATCH_PE(0x01, pe, s, e); }\nstatic inline void acc_load_weight   (uint32_t pe, uint32_t s, uint32_t e) { DISPATCH_PE(0x02, pe, s, e); }\nstatic inline void acc_load_bias     (uint32_t pe, uint32_t a)             { uint32_t z=0; DISPATCH_PE(0x03, pe, a, z); }\nstatic inline uint32_t acc_first_n_f3(uint32_t count)                      { return (count <= 1U) ? 0U : ((count >= NUM_PES) ? (NUM_PES - 1U) : (count - 1U)); }\nstatic inline void acc_load_ifmap_first_n(uint32_t count, uint32_t s, uint32_t e) { DISPATCH_PE(0x13, acc_first_n_f3(count), s, e); }\nstatic inline void acc_load_weight_first_n(uint32_t count, uint32_t s, uint32_t e){ DISPATCH_PE(0x14, acc_first_n_f3(count), s, e); }\nstatic inline void acc_load_bias_first_n(uint32_t count, uint32_t a)             { uint32_t z=0; DISPATCH_PE(0x15, acc_first_n_f3(count), a, z); }\nstatic inline void acc_load_qat      (uint32_t pe, uint32_t m, uint32_t s) { DISPATCH_PE(0x04, pe, m, s); }\nstatic inline void acc_load_z_in     (uint32_t pe, uint32_t z)             { uint32_t zero=0; DISPATCH_PE(0x12, pe, z, zero); }\nstatic inline void acc_set_end_val   (uint32_t pe, uint32_t v)             { uint32_t z=0; DISPATCH_PE(0x05, pe, v, z); }\nstatic inline void acc_set_start_val (uint32_t pe, uint32_t v)             { uint32_t z=0; DISPATCH_PE(0x0A, pe, v, z); }\nstatic inline void acc_load_iw_counter(uint32_t pe)                        { uint32_t z=0; DISPATCH_PE(0x11, pe, z, z); }\nstatic inline void acc_start_conv    (uint32_t r)                          { uint32_t z=0; ACC_CMD(0x07, 0, r, z); }\nstatic inline void acc_clear         (void)                                { uint32_t z=0; ACC_CMD(0x08, 0, z, z); }\nstatic inline void acc_set_active_pes(uint32_t w)                          { uint32_t z=0; ACC_CMD(0x09, 0, w, z); }\nstatic inline void acc_swap_pp       (uint32_t v)                          { uint32_t z=0; ACC_CMD(0x0E, 0, v, z); }\nstatic inline void acc_maxpool       (uint32_t r, uint32_t w)              { ACC_CMD(0x06, 0, r, w); }\nstatic inline void acc_start_rms     (uint32_t rs1, uint32_t rs2)          { ACC_CMD(0x10, 0, rs1, rs2); }\nstatic inline uint32_t acc_sigmoid(uint32_t rs1, uint32_t rs2)             { uint32_t r; ACC_CMD_RD_RS2(0x0F, 0, r, rs1, rs2); return r; }\nstatic inline int32_t  acc_tanh   (uint32_t rs1, uint32_t rs2)             { int32_t r; ACC_CMD_RD_RS2(0x16, 0, r, rs1, rs2); return r; }\nstatic inline uint32_t acc_read_result(uint32_t a)                         { uint32_t r; ACC_CMD_RD(0x0D, 0, r, a); return r; }\n\n\n\nstatic void load_weights(uint32_t w_start_base, uint32_t in_ch, uint32_t kernel_end, uint32_t pad_end, uint32_t variant) {\n    uint32_t w_start = w_start_base; \n    uint32_t weight_stride = kernel_end + 1U;\n    for (uint32_t p = 0U; p < NUM_PES; p++) {\n        uint32_t s, e;\n        if (variant == 1U) { s = w_start + in_ch; e = w_start + kernel_end; } \n        else if (variant == 2U) { s = w_start; e = w_start + pad_end; } \n        else { s = w_start; e = w_start + kernel_end; }\n        acc_load_weight(p, s, e);\n        w_start += weight_stride; \n    }\n}\n\n// Software multiplication to bypass missing RV32I hardware multiplier(for conv layer)\nstatic inline uint32_t soft_mul(uint32_t a, uint32_t b) {\n    uint32_t res = 0;\n    while (b > 0) {\n        if (b & 1) res += a;\n        a <<= 1;\n        b >>= 1;\n    }\n    return res;\n}\nstatic void run_conv_batch_generic(uint32_t w_start_base, uint32_t bias_offset, uint32_t out_offset, \n                                   uint32_t in_ch, uint32_t k_size, uint32_t seq_len, uint32_t out_ch, uint32_t pad_l, uint32_t relu_en) {\n    uint32_t p, t;\n    uint32_t pp_base = out_offset;\n    \n    uint32_t weight_stride = soft_mul(k_size, in_ch);\n\n    // Load Bias\n    for (p = 0U; p < NUM_PES; p++) { \n        acc_load_bias(p, bias_offset + p); \n        acc_load_bias(p, bias_offset + p); \n    }\n\n    // Dynamic Sliding Window\n    for (t = 0U; t < seq_len; t++) {\n        int32_t start_idx = (int32_t)t - (int32_t)pad_l;\n        int32_t end_idx = start_idx + (int32_t)k_size - 1;\n\n        uint32_t skip_front = 0;\n        uint32_t skip_back = 0;\n        uint32_t valid_start_idx;\n\n        if (start_idx < 0) {\n            skip_front = (uint32_t)(-start_idx);\n            valid_start_idx = 0;\n        } else {\n            valid_start_idx = (uint32_t)start_idx;\n        }\n\n        if (end_idx >= (int32_t)seq_len) {\n            skip_back = (uint32_t)(end_idx - (int32_t)seq_len + 1);\n        }\n\n        uint32_t active_k_size = k_size - skip_front - skip_back;\n        \n        uint32_t ifmap_len = soft_mul(active_k_size, in_ch) - 1U;\n        uint32_t ifmap_start = soft_mul(valid_start_idx, in_ch);\n        uint32_t ifmap_end = ifmap_start + ifmap_len;\n\n        uint32_t w_start = w_start_base + soft_mul(skip_front, in_ch);\n        uint32_t w_ptr = w_start;\n\n        for (p = 0U; p < NUM_PES; p++) {\n            acc_load_weight(p, w_ptr, w_ptr + ifmap_len);\n            w_ptr += weight_stride;\n        }\n\n        for (p = 0U; p < NUM_PES; p++) {\n            acc_set_end_val(p, ifmap_len);\n            acc_load_ifmap(p, ifmap_start, ifmap_end);\n            acc_load_iw_counter(p);\n        }\n\n        // THE FIX: Pass relu_en to the hardware instead of hardcoded 0U!\n        acc_start_conv(relu_en);\n\n        for (p = 0U; p < NUM_PES; p++) {\n            acc_read_result(pp_base + p);\n        }\n        pp_base += out_ch;\n    }\n}\n\nstatic void run_dense_batch(uint32_t w_start, uint32_t bias_offset, uint32_t out_offset, uint32_t kernel_end, uint32_t active_pes, uint32_t relu_en) {\n    uint32_t p;\n    uint32_t in_ch = kernel_end + 1U;\n    uint32_t w_ptr = w_start;\n\n    for (p = 0U; p < NUM_PES; p++) { \n        if (p < active_pes) {\n            acc_load_bias(p, bias_offset + p); \n            acc_load_bias(p, bias_offset + p); \n            acc_load_weight(p, w_ptr, w_ptr + kernel_end);\n            w_ptr += in_ch;\n            \n            acc_set_end_val(p, kernel_end); \n            acc_load_ifmap(p, 0U, kernel_end); \n            acc_load_iw_counter(p); \n        } else {\n            acc_load_bias(p, 0U); \n            acc_load_bias(p, 0U);\n            acc_load_weight(p, 0U, 0U);\n            acc_set_end_val(p, 0U);\n            acc_load_ifmap(p, 0U, 0U);\n            acc_load_iw_counter(p);\n        }\n    }\n\n    // Pass the raw 1U or 0U. The decoder cleanly routes rs1[0] to control[17]!\n    acc_start_conv(relu_en);\n\n    for (p = 0U; p < active_pes; p++) {\n        acc_read_result(out_offset + p);\n    }\n}\n\nint main(void) {\n    acc_set_active_pes(0x00000018U); \n    for (uint32_t p = 0U; p < NUM_PES; p++) {\n        acc_set_start_val(p, 0U);\n    }\n'
C_FIRMWARE_TAIL = """
    *((volatile uint32_t*)0x03000000) = 0x1;
    acc_clear();
    while (1) asm volatile ("wfi");
    return 0;
}
"""


def _write_values(path, values, writer):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        for value in values:
            f.write(writer(value))


def _copy_active_to_case(idx):
    case_dir = os.path.join(CASES_DIR, str(idx))
    hex_dir = os.path.join(case_dir, "hex")
    gld_dir = os.path.join(case_dir, "golden")
    os.makedirs(hex_dir, exist_ok=True)
    os.makedirs(gld_dir, exist_ok=True)

    for name in ["mnist_input.hex"]:
        src = os.path.join(HEX_DIR, name)
        dst = os.path.join(hex_dir, name)
        with open(src, "r") as fi, open(dst, "w") as fo:
            fo.write(fi.read())

    for name in ["expected_scores.hex", "expected_class.hex", "expected_argmax.hex"]:
        src = os.path.join(GLD_DIR, name)
        dst = os.path.join(gld_dir, name)
        with open(src, "r") as fi, open(dst, "w") as fo:
            fo.write(fi.read())


def load_context():
    print("=" * 60)
    print(f"{'FULL MNIST 10-CLASS COMPILER':^60}")
    print("=" * 60)
    print("[+] Loading 10-class MNIST Keras model and MNIST data once...")

    model = tf_keras.models.load_model(MODEL_PATH)

    try:
        from tf_keras.datasets import mnist
    except Exception:
        from tensorflow.keras.datasets import mnist

    (x_train, y_train), (x_test, y_test) = mnist.load_data()
    x_train = x_train.astype(np.float32) / 255.0
    x_test = x_test.astype(np.float32) / 255.0

    input_shape = tuple(model.input_shape[1:])
    if input_shape == (28, 28):
        calib_input = x_train[:MNIST_CALIB_SAMPLES]
    elif input_shape == (28, 28, 1):
        calib_input = x_train[:MNIST_CALIB_SAMPLES][..., np.newaxis]
    else:
        raise ValueError(f"Unsupported MNIST model input shape {input_shape}. Use input shape (28, 28) for Conv1D.")

    LAYER_RANGES.clear()
    probe_outputs = [layer.output for layer in model.layers if 'input' not in layer.name.lower()]
    if probe_outputs:
        probe = tf_keras.models.Model(inputs=model.input, outputs=probe_outputs)
        acts = probe.predict(calib_input, verbose=0)
        if not isinstance(acts, list):
            acts = [acts]
        probe_layers = [layer for layer in model.layers if 'input' not in layer.name.lower()]
        for layer, act in zip(probe_layers, acts):
            arr = np.asarray(act, dtype=np.float32)
            lo = float(np.min(arr))
            hi = float(np.max(arr))
            if lo == hi:
                lo -= 1.0
                hi += 1.0
            LAYER_RANGES[layer.name] = (lo, hi)

    in_min = float(np.min(calib_input))
    in_max = float(np.max(calib_input))
    if in_min == in_max:
        in_min, in_max = 0.0, 1.0
    S_input = (in_max - in_min) / 255.0
    Z_input = int(np.clip(np.round(0 - in_min / S_input), 0, 255))

    return {
        "model": model,
        "x_test": x_test,
        "y_test": y_test,
        "input_shape": input_shape,
        "in_min": in_min,
        "in_max": in_max,
        "S_input": S_input,
        "Z_input": Z_input,
    }


def compile_one(ctx, idx, write_case=True, write_firmware=True, write_globals=True, write_layer_golden=False):
    model = ctx["model"]
    x_test = ctx["x_test"]
    y_test = ctx["y_test"]

    if idx < 0 or idx >= len(x_test):
        raise ValueError(f"MNIST index must be in [0, {len(x_test)-1}], got {idx}")

    if ctx["input_shape"] == (28, 28):
        raw_input = x_test[idx]
    else:
        raw_input = x_test[idx][..., np.newaxis]
    if len(raw_input.shape) != 2:
        raise ValueError("This hardware compiler expects a 2-D sequence input, e.g. MNIST as 28 timesteps x 28 features.")

    true_class = int(y_test[idx])
    S_act = ctx["S_input"]
    Z_act = ctx["Z_input"]
    q_act = np.clip(np.round(np.clip(raw_input, ctx["in_min"], ctx["in_max"]) / S_act + Z_act), 0, 255).astype(np.uint8)

    _write_values(os.path.join(HEX_DIR, "mnist_input.hex"), q_act.flatten(), to_hex16)
    with open(os.path.join(GLD_DIR, "expected_class.hex"), "w") as f:
        f.write(f"{true_class:08X}\n")

    hw = HardwareState()
    hw.seq_len, hw.channels = q_act.shape
    c_blocks = []
    layer_idx = 1
    global_weights = []
    global_biases = []

    for layer in model.layers:
        k_name = layer.name.upper()
        if any(x in k_name for x in ["DROPOUT", "FLATTEN", "INPUT", "QUANTIZE"]):
            if "FLATTEN" in k_name:
                q_act = q_act.reshape(-1)
            continue

        if "CONV" in k_name:
            name = f"LAYER_{layer_idx}_CONV"
            q_act_next, S_out, Z_out = quantized_cnn(q_act, S_act, Z_act, layer)
            S_w = get_weight_scale(layer)
            w_f, b_f, w_min, w_max, *_ = get_cnn(layer)
            q_w, _, _ = quantize_weights_symmetric(w_f, w_min, w_max)
            q_b = np.round(b_f / (S_act * S_w)).astype(np.int32)

            global_weights.extend(q_w.transpose(2, 0, 1).flatten())
            global_biases.extend(q_b)
            if write_layer_golden:
                _write_values(os.path.join(GLD_DIR, f"{name.lower()}_golden.hex"), q_act_next.flatten(), to_hex16)

            in_ch = layer.input_shape[2]
            k_size = layer.layer.get_config()['kernel_size'][0] if hasattr(layer, 'layer') else layer.kernel_size[0]
            c_blocks.append(generate_conv_c(name, hw, in_ch, q_w.shape[-1], k_size, S_act, S_w, S_out, Z_out, Z_act, layer_idx == 1))
            q_act, S_act, Z_act = q_act_next, S_out, Z_out
            layer_idx += 1

        elif "RMS" in k_name:
            name = f"LAYER_{layer_idx}_RMS"
            q_act_next, S_out, Z_out, S_s = quant_rms_lut(q_act, S_act, Z_act, layer)
            S_scale = get_weight_scale(layer)
            w_f = [w.numpy() for w in layer.weights if "scale" in w.name.lower() and "min" not in w.name.lower()][0]
            w_min = [float(w.numpy()) for w in layer.weights if "scale_min" in w.name.lower()][0]
            Z_scale = int(np.clip(np.round(0 - w_min / S_scale), 0, 255))
            q_w = np.clip(np.round(w_f / S_scale + Z_scale), 0, 255).astype(np.uint8)
            global_weights.extend((q_w.astype(np.int32) - Z_scale).flatten())
            if write_layer_golden:
                _write_values(os.path.join(GLD_DIR, f"{name.lower()}_golden.hex"), q_act_next.flatten(), to_hex16)
            c_blocks.append(generate_rms_c(name, hw, q_act.shape[-1], q_act.size, S_s, S_out, Z_out, Z_act))
            q_act, S_act, Z_act = q_act_next, S_out, Z_out
            layer_idx += 1

        elif "POOL" in k_name:
            name = f"LAYER_{layer_idx}_POOL"
            q_act = max_pool(q_act, 2)
            if write_layer_golden:
                _write_values(os.path.join(GLD_DIR, f"{name.lower()}_golden.hex"), q_act.flatten(), to_hex16)
            c_blocks.append(generate_pool_c(name, hw))
            layer_idx += 1

        elif "DENSE" in k_name:
            name = f"LAYER_{layer_idx}_DENSE"
            is_last = layer == model.layers[-1]
            q_act_next, S_out, Z_out = quant_dense(q_act, S_act, Z_act, layer, relu=not is_last)
            S_w = get_weight_scale(layer)
            w_f, b_f, w_min, w_max, *_ = get_cnn(layer)
            max_abs = max(abs(w_min if w_min else 0), abs(w_max if w_max else 0))
            S_f = max_abs / 127.0 if max_abs != 0 else 1.0
            q_w = np.clip(np.round(w_f / S_f), -127, 127).astype(np.int8)
            q_b = np.round(b_f / (S_act * S_f)).astype(np.int32) if b_f is not None else None

            global_weights.extend(q_w.T.flatten())
            if q_b is not None:
                global_biases.extend(q_b)
            if write_layer_golden:
                _write_values(os.path.join(GLD_DIR, f"{name.lower()}_golden.hex"), q_act_next.flatten(), to_hex16)

            c_blocks.append(generate_dense_c(name, hw, q_w.shape[0], q_w.shape[-1], S_act, S_w, S_out, Z_out, Z_act, relu=not is_last))
            q_act, S_act, Z_act = q_act_next, S_out, Z_out
            layer_idx += 1

            if is_last:
                scores = q_act_next.flatten().astype(np.uint16)
                if scores.size != 10:
                    raise ValueError(f"Full MNIST expects 10 final outputs, got {scores.size}")
                predicted_class = int(np.argmax(scores))
                _write_values(os.path.join(GLD_DIR, "expected_scores.hex"), scores, to_hex16)
                with open(os.path.join(GLD_DIR, "expected_argmax.hex"), "w") as f:
                    f.write(f"{predicted_class:08X}\n")

    if write_globals:
        _write_values(os.path.join(HEX_DIR, "global_weights.hex"), global_weights, to_hex16)
        _write_values(os.path.join(HEX_DIR, "global_bias.hex"), global_biases, to_hex32)

    if write_firmware:
        c_firmware = C_FIRMWARE_HEADER.replace(chr(92) + chr(92) + "\n", chr(92) + "\n")
        for block in c_blocks:
            c_firmware += block
        c_firmware += C_FIRMWARE_TAIL
        with open(os.path.join(SRC_DIR, "veeresh_compiler.c"), "w") as f:
            f.write(c_firmware)

    if write_case:
        _copy_active_to_case(idx)

    return int(np.argmax(q_act.flatten())), true_class


def compile_network():
    ctx = load_context()
    os.makedirs(CASES_DIR, exist_ok=True)
    end = MNIST_START + MNIST_COUNT
    correct = 0

    print(f"[+] Preparing MNIST samples {MNIST_START}..{end - 1} in one Python process")
    for n, idx in enumerate(range(MNIST_START, end)):
        write_once = (n == 0)
        pred, true_class = compile_one(
            ctx,
            idx,
            write_case=True,
            write_firmware=write_once,
            write_globals=write_once,
            write_layer_golden=write_once,
        )
        correct += int(pred == true_class)
        if n < 5 or ((n + 1) % 100 == 0) or (idx == end - 1):
            print(f"[MNIST_PREP] sample={idx} predicted={pred} true={true_class} correct={int(pred == true_class)}")

    print(f"[OK] Prepared {MNIST_COUNT} MNIST samples under {CASES_DIR}")
    print(f"[OK] Golden class_correct={correct}/{MNIST_COUNT}")
    print(f"[OK] Firmware source: {os.path.join(SRC_DIR, 'veeresh_compiler.c')}")


if __name__ == "__main__":
    compile_network()
