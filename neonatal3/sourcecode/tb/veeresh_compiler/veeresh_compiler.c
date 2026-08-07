#include <stdint.h>

#define ACC_CMD(f7, f3, rs1, rs2) asm volatile (".insn r 0x2b, %1, %0, x0, %2, %3" :: "i"(f7), "i"(f3), "r"(rs1), "r"(rs2))
#define ACC_CMD_RD(f7, f3, rd, rs1) asm volatile (".insn r 0x2b, %2, %1, %0, %3, x0" : "=r"(rd) : "i"(f7), "i"(f3), "r"(rs1))
#define ACC_CMD_RD_RS2(f7, f3, rd, rs1, rs2) asm volatile (".insn r 0x2b, %2, %1, %0, %3, %4" : "=r"(rd) : "i"(f7), "i"(f3), "r"(rs1), "r"(rs2))


#define DISPATCH_PE(f7, pe, rs1, rs2) do { \
    uint32_t _a=(rs1),_b=(rs2); switch((uint32_t)(pe)){ \
    case 0:ACC_CMD(f7,0,_a,_b);break; case 1:ACC_CMD(f7,1,_a,_b);break; \
    case 2:ACC_CMD(f7,2,_a,_b);break; case 3:ACC_CMD(f7,3,_a,_b);break; \
    case 4:ACC_CMD(f7,4,_a,_b);break; case 5:ACC_CMD(f7,5,_a,_b);break; \
    case 6:ACC_CMD(f7,6,_a,_b);break; case 7:ACC_CMD(f7,7,_a,_b);break; \
}} while(0)

#define NUM_PES 8U

static inline void acc_load_ifmap    (uint32_t pe, uint32_t s, uint32_t e) { DISPATCH_PE(0x01, pe, s, e); }
static inline void acc_load_weight   (uint32_t pe, uint32_t s, uint32_t e) { DISPATCH_PE(0x02, pe, s, e); }
static inline void acc_load_bias     (uint32_t pe, uint32_t a)             { uint32_t z=0; DISPATCH_PE(0x03, pe, a, z); }
static inline void acc_load_qat      (uint32_t pe, uint32_t m, uint32_t s) { DISPATCH_PE(0x04, pe, m, s); }
static inline void acc_load_z_in     (uint32_t pe, uint32_t z)             { uint32_t zero=0; DISPATCH_PE(0x12, pe, z, zero); }
static inline void acc_set_end_val   (uint32_t pe, uint32_t v)             { uint32_t z=0; DISPATCH_PE(0x05, pe, v, z); }
static inline void acc_set_start_val (uint32_t pe, uint32_t v)             { uint32_t z=0; DISPATCH_PE(0x0A, pe, v, z); }
static inline void acc_load_iw_counter(uint32_t pe)                        { uint32_t z=0; DISPATCH_PE(0x11, pe, z, z); }
static inline void acc_start_conv    (uint32_t r)                          { uint32_t z=0; ACC_CMD(0x07, 0, r, z); }
static inline void acc_clear         (void)                                { uint32_t z=0; ACC_CMD(0x08, 0, z, z); }
static inline void acc_set_active_pes(uint32_t w)                          { uint32_t z=0; ACC_CMD(0x09, 0, w, z); }
static inline void acc_swap_pp       (uint32_t v)                          { uint32_t z=0; ACC_CMD(0x0E, 0, v, z); }
static inline void acc_maxpool       (uint32_t r, uint32_t w)              { ACC_CMD(0x06, 0, r, w); }
static inline void acc_start_rms     (uint32_t rs1, uint32_t rs2)          { ACC_CMD(0x10, 0, rs1, rs2); }
static inline uint32_t acc_sigmoid(uint32_t rs1, uint32_t rs2)             { uint32_t r; ACC_CMD_RD_RS2(0x0F, 0, r, rs1, rs2); return r; }
static inline uint32_t acc_read_result(uint32_t a)                         { uint32_t r; ACC_CMD_RD(0x0D, 0, r, a); return r; }



static void load_weights(uint32_t w_start_base, uint32_t in_ch, uint32_t kernel_end, uint32_t pad_end, uint32_t variant) {
    uint32_t w_start = w_start_base; 
    uint32_t weight_stride = kernel_end + 1U;
    for (uint32_t p = 0U; p < NUM_PES; p++) {
        uint32_t s, e;
        if (variant == 1U) { s = w_start + in_ch; e = w_start + kernel_end; } 
        else if (variant == 2U) { s = w_start; e = w_start + pad_end; } 
        else { s = w_start; e = w_start + kernel_end; }
        acc_load_weight(p, s, e);
        w_start += weight_stride; 
    }
}

// Software multiplication to bypass missing RV32I hardware multiplier(for conv layer)
static inline uint32_t soft_mul(uint32_t a, uint32_t b) {
    uint32_t res = 0;
    while (b > 0) {
        if (b & 1) res += a;
        a <<= 1;
        b >>= 1;
    }
    return res;
}
static void run_conv_batch_generic(uint32_t w_start_base, uint32_t bias_offset, uint32_t out_offset, 
                                   uint32_t in_ch, uint32_t k_size, uint32_t seq_len, uint32_t out_ch, uint32_t pad_l, uint32_t relu_en) {
    uint32_t p, t;
    uint32_t pp_base = out_offset;
    
    uint32_t weight_stride = soft_mul(k_size, in_ch);

    // Load Bias
    for (p = 0U; p < NUM_PES; p++) { 
        acc_load_bias(p, bias_offset + p); 
        acc_load_bias(p, bias_offset + p); 
    }

    // Dynamic Sliding Window
    for (t = 0U; t < seq_len; t++) {
        int32_t start_idx = (int32_t)t - (int32_t)pad_l;
        int32_t end_idx = start_idx + (int32_t)k_size - 1;

        uint32_t skip_front = 0;
        uint32_t skip_back = 0;
        uint32_t valid_start_idx;

        if (start_idx < 0) {
            skip_front = (uint32_t)(-start_idx);
            valid_start_idx = 0;
        } else {
            valid_start_idx = (uint32_t)start_idx;
        }

        if (end_idx >= (int32_t)seq_len) {
            skip_back = (uint32_t)(end_idx - (int32_t)seq_len + 1);
        }

        uint32_t active_k_size = k_size - skip_front - skip_back;
        
        uint32_t ifmap_len = soft_mul(active_k_size, in_ch) - 1U;
        uint32_t ifmap_start = soft_mul(valid_start_idx, in_ch);
        uint32_t ifmap_end = ifmap_start + ifmap_len;

        uint32_t w_start = w_start_base + soft_mul(skip_front, in_ch);
        uint32_t w_ptr = w_start;

        for (p = 0U; p < NUM_PES; p++) {
            acc_load_weight(p, w_ptr, w_ptr + ifmap_len);
            w_ptr += weight_stride;
        }

        for (p = 0U; p < NUM_PES; p++) {
            acc_set_end_val(p, ifmap_len);
            acc_load_ifmap(p, ifmap_start, ifmap_end);
            acc_load_iw_counter(p);
        }

        // THE FIX: Pass relu_en to the hardware instead of hardcoded 0U!
        acc_start_conv(relu_en);

        for (p = 0U; p < NUM_PES; p++) {
            acc_read_result(pp_base + p);
        }
        pp_base += out_ch;
    }
}

static void run_dense_batch(uint32_t w_start, uint32_t bias_offset, uint32_t out_offset, uint32_t kernel_end, uint32_t active_pes, uint32_t relu_en) {
    uint32_t p;
    uint32_t in_ch = kernel_end + 1U;
    uint32_t w_ptr = w_start;

    for (p = 0U; p < NUM_PES; p++) { 
        if (p < active_pes) {
            acc_load_bias(p, bias_offset + p); 
            acc_load_bias(p, bias_offset + p); 
            acc_load_weight(p, w_ptr, w_ptr + kernel_end);
            w_ptr += in_ch;
            
            acc_set_end_val(p, kernel_end); 
            acc_load_ifmap(p, 0U, kernel_end); 
            acc_load_iw_counter(p); 
        } else {
            acc_load_bias(p, 0U); 
            acc_load_bias(p, 0U);
            acc_load_weight(p, 0U, 0U);
            acc_set_end_val(p, 0U);
            acc_load_ifmap(p, 0U, 0U);
            acc_load_iw_counter(p);
        }
    }

    // Pass the raw 1U or 0U. The decoder cleanly routes rs1[0] to control[17]!
    acc_start_conv(relu_en);

    for (p = 0U; p < active_pes; p++) {
        acc_read_result(out_offset + p);
    }
}

int main(void) {
    acc_set_active_pes(0x00000018U); 
    for (uint32_t p = 0U; p < NUM_PES; p++) {
        acc_set_start_val(p, 0U);
    }

    /* --- LAYER_1_CONV --- */
    acc_swap_pp(0U);
    for(uint32_t p=0; p<8; p++) { acc_load_qat(p, 0x441E706BU, (((uint32_t)0x26 << 16) | 0x0F5BU)); }
    { uint32_t ws = 0U, bias_ptr = 0U, out_ptr = 0U;
      for (uint32_t b=0; b<4U; b++) {
          run_conv_batch_generic(ws, bias_ptr, out_ptr, 90U, 3U, 15U, 32U, 1U, 1U);
          ws += 2160U; bias_ptr += 8U; out_ptr += 8U; } }

    /* --- LAYER_2_RMS --- */
    acc_swap_pp(1U);
    acc_load_qat(0U, 0x74B26FF1U, (((uint32_t)0x32 << 16) | 0x5B36U));
    acc_load_weight(0U, 8640U, 8671U);

    { uint32_t start_idx = 0U;
      for (uint32_t t = 0U; t < 15U; t++) {
          acc_load_ifmap(0U, start_idx, start_idx + 31U);
          acc_set_start_val(0U, 0U);
          acc_set_end_val(0U, 31U);
          acc_load_iw_counter(0U);
          acc_start_rms(start_idx, 0U);
          start_idx += 32U; } }

    /* --- LAYER_3_POOL --- */
    acc_swap_pp(1U);
    { uint32_t rd=0U, wr=0U, stride=32U, ps=7U;
      acc_maxpool((stride << 12) | rd, (ps << 12) | wr); 
    }
    /* --- LAYER_4_CONV --- */
    acc_swap_pp(1U);
    for(uint32_t p=0; p<8; p++) { acc_load_qat(p, 0x4E3B674FU, (((uint32_t)0x27 << 16) | 0x365EU)); }
    { uint32_t ws = 8672U, bias_ptr = 32U, out_ptr = 0U;
      for (uint32_t b=0; b<8U; b++) {
          run_conv_batch_generic(ws, bias_ptr, out_ptr, 32U, 3U, 7U, 64U, 1U, 1U);
          ws += 768U; bias_ptr += 8U; out_ptr += 8U; } }

    /* --- LAYER_5_RMS --- */
    acc_swap_pp(1U);
    acc_load_qat(0U, 0x4983AECBU, (((uint32_t)0x31 << 16) | 0x5E43U));
    acc_load_weight(0U, 14816U, 14879U);

    { uint32_t start_idx = 0U;
      for (uint32_t t = 0U; t < 7U; t++) {
          acc_load_ifmap(0U, start_idx, start_idx + 63U);
          acc_set_start_val(0U, 0U);
          acc_set_end_val(0U, 63U);
          acc_load_iw_counter(0U);
          acc_start_rms(start_idx, 1U);
          start_idx += 64U; } }

    /* --- LAYER_6_POOL --- */
    acc_swap_pp(1U);
    { uint32_t rd=0U, wr=0U, stride=64U, ps=3U;
      acc_maxpool((stride << 12) | rd, (ps << 12) | wr); 
    }
    /* --- LAYER_7_CONV --- */
    acc_swap_pp(1U);
    for(uint32_t p=0; p<8; p++) { acc_load_qat(p, 0x6C4561A8U, (((uint32_t)0x28 << 16) | 0x435DU)); }
    { uint32_t ws = 14880U, bias_ptr = 96U, out_ptr = 0U;
      for (uint32_t b=0; b<16U; b++) {
          run_conv_batch_generic(ws, bias_ptr, out_ptr, 64U, 2U, 3U, 128U, 0U, 1U);
          ws += 1024U; bias_ptr += 8U; out_ptr += 8U; } }

    /* --- LAYER_8_RMS --- */
    acc_swap_pp(1U);
    acc_load_qat(0U, 0x4CB740ABU, (((uint32_t)0x31 << 16) | 0x5D46U));
    acc_load_weight(0U, 31264U, 31391U);

    { uint32_t start_idx = 0U;
      for (uint32_t t = 0U; t < 3U; t++) {
          acc_load_ifmap(0U, start_idx, start_idx + 127U);
          acc_set_start_val(0U, 0U);
          acc_set_end_val(0U, 127U);
          acc_load_iw_counter(0U);
          acc_start_rms(start_idx, 2U);
          start_idx += 128U; } }

    /* --- LAYER_9_DENSE --- */
    acc_swap_pp(1U);
    for(uint32_t p=0; p<8; p++) { acc_load_qat(p, 0x563E999FU, (((uint32_t)0x28 << 16) | 0x4645U)); }
    run_dense_batch(31392U, 224U, 0U, 383U, 8U, 1U);
    run_dense_batch(34464U, 232U, 8U, 383U, 8U, 1U);

    /* --- LAYER_10_DENSE --- */
    acc_swap_pp(1U);
    for(uint32_t p=0; p<8; p++) { acc_load_qat(p, 0x43780689U, (((uint32_t)0x26 << 16) | 0x4599U)); }
    run_dense_batch(37536U, 240U, 0U, 15U, 1U, 0U);

    /* --- SIGMOID_FINAL --- */
    acc_swap_pp(1U);
    volatile uint32_t final_outputs[1];
    for (uint32_t i = 0; i < 1; i++) {
        uint32_t rs1 = (i << 20) | (13U << 16) | 0x7151U;
        uint32_t rs2 = 0xFFFC466CU;
        final_outputs[i] = acc_sigmoid(rs1, rs2);
    }

    *((volatile uint32_t*)0x03000000) = 0x1;
    acc_clear();
    while (1) asm volatile ("wfi");
    return 0;
}
