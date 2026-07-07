import os
import logging

# --- SUPPRESS ALL TENSORFLOW WARNINGS & CUDA SPAM ---
# This MUST happen before importing tensorflow!
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'  
os.environ["CUDA_VISIBLE_DEVICES"] = "-1"

import numpy as np
import pandas as pd
import tensorflow as tf
import tf_keras
from sklearn.preprocessing import StandardScaler

# Shut up the Python-level TF logger too
tf.get_logger().setLevel('ERROR')
logging.getLogger('tensorflow').setLevel(logging.FATAL)

# --- Configuration ---
MODEL_PATH = '/home/veeresh/veeresh/mithin_rms/golden_final/qat_model'
CSV_PATH   = '/home/veeresh/veeresh/mithin_rms/neonatal/features_16bit_quant.csv'
GLD_DIR    = '/home/veeresh/picorv_code/build/codes/veeresh_compiler/build_output/golden'

# --- Utilities ---
def _hex_to_signed(h, bits=16):
    v = int(h.strip(), 16)
    if v >= (1 << (bits - 1)): v -= (1 << bits)
    return v

def read_hex_tensor(path, shape, bits=16):
    vals = []
    with open(path, "r") as f:
        for line in f:
            s = line.strip()
            if s: vals.append(_hex_to_signed(s, bits))
    return np.array(vals, dtype=np.int32).reshape(shape)

def get_out_scales(layer, prev_S, prev_Z):
    """Safely extracts scales, inheriting from previous layer if it's a Pool layer."""
    out_min, out_max = None, None
    for w in layer.weights:
        if "output_min" in w.name or ("post_activation" in w.name and "min" in w.name):
            out_min = float(w.numpy())
        elif "output_max" in w.name or ("post_activation" in w.name and "max" in w.name):
            out_max = float(w.numpy())
            
    if out_min is not None and out_max is not None and out_max != out_min:
        S_out = (out_max - out_min) / 255.0
        Z_out = int(np.clip(np.round(0 - out_min / S_out), 0, 255))
        return S_out, Z_out
    return prev_S, prev_Z

# --- The Verifier ---
def run_verification():
    print("\n" + "=" * 75)
    print(f"{'KERAS VS. HARDWARE QAT VERIFICATION ENGINE':^75}")
    print("=" * 75)

    model = tf_keras.models.load_model(MODEL_PATH)
    
    # Extract Base Input Scales
    in_min = min([float(w.numpy()) for w in model.layers[0].weights if "min" in w.name])
    in_max = max([float(w.numpy()) for w in model.layers[0].weights if "max" in w.name])
    current_S = (in_max - in_min) / 255.0
    current_Z = int(np.clip(np.round(0 - in_min / current_S), 0, 255))

    df = pd.read_csv(CSV_PATH)
    labels = df['label'].values
    non_seizure_indices = np.where(labels == 0)[0]
    seizure_indices = np.where(labels == 1)[0]
    X = df.drop(columns=['label', 'patient_id'], errors='ignore').values.astype(np.float32)
    n_features = X.shape[1] // 15
    X = StandardScaler().fit_transform(X.reshape(-1, n_features)).reshape((X.shape[0], 15, n_features))
    
    # Use X[0] to perfectly match what compiler is generating
    raw_input = X[seizure_indices[0]]
    
    layer_outputs = [layer.output for layer in model.layers]
    probe_model = tf_keras.models.Model(inputs=model.input, outputs=layer_outputs)
    
    keras_activations = probe_model.predict(np.expand_dims(raw_input, axis=0), verbose=0)

    print(f"{'LAYER NAME':<20} | {'Max(abs(error))':<15} | {'Eq.no of values':<17} ")
    print("-" * 75)
    
    layer_idx = 1
    
    for i, layer in enumerate(model.layers):
        name = layer.name.upper()
        keras_out = keras_activations[i][0] # Remove batch dimension
        
        if any(x in name for x in ["DROPOUT", "FLATTEN", "INPUT", "QUANTIZE"]):
            if "FLATTEN" in name: keras_out = keras_out.flatten()
            continue
            
        hw_name = ""
        if "CONV" in name: hw_name = f"layer_{layer_idx}_conv"
        elif "RMS" in name: hw_name = f"layer_{layer_idx}_rms"
        elif "POOL" in name: hw_name = f"layer_{layer_idx}_pool"
        elif "DENSE" in name: hw_name = f"layer_{layer_idx}_dense"
        else: continue
            
        # Update the scales (Pooling will safely inherit the RMS scales)
        current_S, current_Z = get_out_scales(layer, current_S, current_Z)
            
        hex_file = os.path.join(GLD_DIR, f"{hw_name}_golden.hex")
        if not os.path.exists(hex_file):
            print(f"{hw_name:<20} | {'Missing Hex File':<15} | {'-':<17} | ❌")
            layer_idx += 1
            continue
            
        hw_quantized = read_hex_tensor(hex_file, keras_out.shape, bits=16)
        
        # Dequantize hardware integer to floating point
        hw_float = (hw_quantized.astype(np.float32) - current_Z) * current_S
        
        # Calculate Absolute Error
        abs_error = np.abs(keras_out - hw_float)
        max_abs_err = abs_error.max()
        
        # Calculate how many hardware "steps" it is off by
        max_steps_err = max_abs_err / current_S if current_S != 0 else 0.0
        
        
        print(f"{hw_name:<20} | {max_abs_err:>15.6f} | {max_steps_err:>11.2f}")
        
        layer_idx += 1

    # =================================================================
    # FINAL CLASSIFICATION REPORT
    # =================================================================
    print("\n" + "=" * 75)
    print(f"{'FINAL CLASSIFICATION RESULTS':^75}")
    print("=" * 75)

    # 1. Get Keras Perfect Probability
    keras_final_prob = float(keras_activations[-1][0].flatten()[0])
    keras_class = "SEIZURE DETECTED" if keras_final_prob > 0.5 else "NO SEIZURE"

    # 2. Get Hardware Hex Probability from the Sigmoid Golden File
    sig_hex_path = os.path.join(GLD_DIR, "layer_11_sigmoid_golden.hex")
    
    if os.path.exists(sig_hex_path):
        with open(sig_hex_path, "r") as f:
            lines = f.readlines()
            if lines:
                hw_sig_val = int(lines[0].strip(), 16)
                
                # User defined threshold: > 16'h8000 is a Seizure (0x8000 = 32768)
                hw_class = "SEIZURE DETECTED" if hw_sig_val > 0x8000 else "NO SEIZURE"
                hw_prob_approx = hw_sig_val / 65535.0
                
                print(f"Keras Float Probability:   {keras_final_prob:.4f}          -> {keras_class}")
                print(f"Hardware Hex Output:       0x{hw_sig_val:04X} ({hw_prob_approx:.4f}) -> {hw_class}")
            else:
                print("Hardware Sigmoid Hex file is empty.")
    else:
        print(f"Keras Float Probability:   {keras_final_prob:.4f}  ->  {keras_class}")
        print("[!] Hardware 'layer_11_sigmoid_golden.hex' not found.")
        
    print("=" * 75 + "\n")

if __name__ == "__main__":
    run_verification()