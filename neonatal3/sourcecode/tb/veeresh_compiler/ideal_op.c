/**
 * neonatal_layer_1_opt.c
 *
 * Memory-optimised rebuild of neonatal_layer_1.c for the PicoRV32 (RISC-V I).
 *
 * KEY CHANGES vs. original:
 * ─────────────────────────────────────────────────────────────────────────────
 * 1. ELIMINATED 12 STATIC BATCH FUNCTIONS (b0_full/lpad/rpad … b3_full/lpad/rpad)
 *    All 96 hardcoded address-literal pairs have been replaced with runtime
 *    arithmetic.  On RV32I every 32-bit literal costs a lui+addi pair in .text;
 *    12 functions × 8 PEs × 2 literals = 192 instructions saved.
 *
 * 2. SINGLE PARAMETERISED WEIGHT-LOAD HELPER
 *    load_weights(batch, variant) computes start/end addresses for all 8 PEs
 *    using simple addition (no multiply hardware needed: stride is a constant
 *    shift / repeated add, hoisted out of the PE loop).
 *
 * 3. NO FUNCTION POINTERS
 *    The original run_batch() used three function-pointer arguments preventing
 *    any inlining and adding 3 extra loads from the stack on every call.
 *    run_batch_opt() takes a plain uint32_t batch_idx instead.
 *
 * 4. REGISTER-FRIENDLY LOOP VARIABLES
 *    All loop induction variables are uint32_t, kept in caller-saved registers
 *    where possible so GCC doesn't spill them to the stack.
 *
 * Everything else (instruction encoding, QAT parameters, padding logic,
 * pp-buffer addressing) is IDENTICAL to the original.
 * ─────────────────────────────────────────────────────────────────────────────
 */

#include <stdint.h>

/* ── Custom-instruction macros (unchanged) ─────────────────────────────────── */
#define ACC_CMD(f7, f3, rs1, rs2) \
    asm volatile (".insn r 0x2b, %1, %0, x0, %2, %3" :: "i"(f7), "i"(f3), "r"(rs1), "r"(rs2))
#define ACC_CMD_RD(f7, f3, rd, rs1) \
    asm volatile (".insn r 0x2b, %2, %1, %0, %3, x0" : "=r"(rd) : "i"(f7), "i"(f3), "r"(rs1))

/*
 * DISPATCH_PE: compile-time switch over pe so f3 is a literal for the assembler.
 * Kept identical to original — no change here.
 */
#define DISPATCH_PE(f7, pe, rs1, rs2) do { \
    uint32_t _a=(rs1),_b=(rs2); switch((uint32_t)(pe)){ \
    case 0:ACC_CMD(f7,0,_a,_b);break; case 1:ACC_CMD(f7,1,_a,_b);break; \
    case 2:ACC_CMD(f7,2,_a,_b);break; case 3:ACC_CMD(f7,3,_a,_b);break; \
    case 4:ACC_CMD(f7,4,_a,_b);break; case 5:ACC_CMD(f7,5,_a,_b);break; \
    case 6:ACC_CMD(f7,6,_a,_b);break; case 7:ACC_CMD(f7,7,_a,_b);break; \
}} while(0)

/* ── Accelerator API (unchanged) ───────────────────────────────────────────── */
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
static inline uint32_t acc_read_result(uint32_t a)                        { uint32_t r; ACC_CMD_RD(0x0D, 0, r, a); return r; }

/* ── Layer constants (unchanged) ───────────────────────────────────────────── */
#define KERNEL_END   269U   /* full kernel: 270 weight elements  */
#define PAD_END      179U   /* padded edge: 180 weight elements  */
#define NUM_FILTERS   32U   /* total output filters              */
#define NUM_PES        8U   /* processing elements               */
#define NUM_OUTPUTS   15U   /* output time-steps (SAME padding)  */
#define CH_STRIDE     90U   /* flat elements per time-step       */

/* Weight memory layout
 *   filter f  →  SRAM words [f270 .. f270+269]
 *   batch  b  →  filters [b8 .. b8+7]
 *   PE     p  →  filter  b*8+p
 *   → weight base for (batch b, PE p) = (b*8 + p) * 270
 *
 * On RV32I there is no MUL instruction, so we compute (b*8+p)*270
 * as ((b8+p) << 8) + ((b8+p) << 4) - ((b8+p) << 2) + (b8+p)*2
 *    = (b8+p) * (256 + 16 - 4 + 2) = (b8+p) * 270  ✓
 * GCC -O2 will emit this automatically for a constant multiplier.
 * We keep the code readable with a plain multiply; GCC synth replaces it.
 */
#define WEIGHT_STRIDE  270U   /* elements per filter kernel        */

/* QAT parameters (unchanged) */
#define QM   0x441E703AU
#define QSZ  (((uint32_t)0x26 << 16) | 0x005BU)
#define ZIN  15U

/* ── Weight-load variants ───────────────────────────────────────────────────
 *
 *  variant 0 = FULL  → load w[base .. base+269]
 *  variant 1 = LPAD  → load w[base+90 .. base+269]   (skip first 90)
 *  variant 2 = RPAD  → load w[base .. base+179]       (skip last 90)
 *
 *  batch_idx : 0-3  (selects which block of 8 filters)
 *
 *  Memory saved vs. original:
 *    Original: 12 functions × ~40 instructions each ≈ 480 instructions
 *    Here:     1 function   × ~20 instructions loop  ≈  20 instructions
 * ─────────────────────────────────────────────────────────────────────────── */
static void load_weights(uint32_t batch_idx, uint32_t variant)
{
    /*
     * base_filter = batch_idx * 8   (first filter index in this batch)
     * weight_base = base_filter * WEIGHT_STRIDE
     *             = batch_idx * 8 * 270
     *             = batch_idx * 2160
     *
     * Per-PE offset (PE p inside the batch):
     *   w_start(p) = weight_base + p * WEIGHT_STRIDE
     *
     * We accumulate w_start across the PE loop using an adder
     * (avoids a multiply inside the loop).
     */
    uint32_t w_start = batch_idx * (8U * WEIGHT_STRIDE); /* batch_idx * 2160 */

    for (uint32_t p = 0U; p < NUM_PES; p++) {
        uint32_t s, e;

        switch (variant) {
        case 1U: /* LPAD — skip first CH_STRIDE (90) weights */
            s = w_start + CH_STRIDE;
            e = w_start + KERNEL_END;
            break;
        case 2U: /* RPAD — skip last CH_STRIDE (90) weights */
            s = w_start;
            e = w_start + PAD_END;
            break;
        default: /* FULL */
            s = w_start;
            e = w_start + KERNEL_END;
            break;
        }

        acc_load_weight(p, s, e);
        w_start += WEIGHT_STRIDE; /* advance to next filter */
    }
}

/* ── Single, generalised batch runner ──────────────────────────────────────
 *
 *  batch_idx : 0-3
 *  batch_offset : first bias/output address for this batch (0, 8, 16, 24)
 *
 *  Replaces four separate run_batch() calls, each with 3 function-pointer
 *  arguments.  No heap allocation, no pointer indirection.
 * ─────────────────────────────────────────────────────────────────────────── */
static void run_batch_opt(uint32_t batch_idx, uint32_t batch_offset)
{
    uint32_t p;

    /* ── Bias load (double-load for SRAM latency) ──────────────────────── */
    for (p = 0U; p < NUM_PES; p++) {
        uint32_t ba = batch_offset + p;
        acc_load_bias(p, ba);
        acc_load_bias(p, ba);   /* second load: SRAM read-latency fix */
    }

    /* ── t = 0 : LEFT-PADDED output ────────────────────────────────────────
     *  Effective window: 0w[0..89] + t0w[90..179] + t1*w[180..269]
     *  → load LPAD weights, ifmap flat[0..179], end_val = PAD_END (179)
     * ─────────────────────────────────────────────────────────────────────── */
    load_weights(batch_idx, 1U); /* LPAD */
    for (p = 0U; p < NUM_PES; p++) acc_set_end_val(p, PAD_END);
    for (p = 0U; p < NUM_PES; p++) acc_load_ifmap(p, 0U, PAD_END);
    for (p = 0U; p < NUM_PES; p++) acc_load_iw_counter(p);
    acc_start_conv(1U);
    for (p = 0U; p < NUM_PES; p++) acc_read_result(batch_offset + p);

    /* ── t = 1..13 : NO PADDING ─────────────────────────────────────────────
     *  Window at step k: flat[(k-1)*90 .. (k-1)*90+269]
     *  → load FULL weights (same for all steps), end_val = KERNEL_END (269)
     * ─────────────────────────────────────────────────────────────────────── */
    load_weights(batch_idx, 0U); /* FULL */
    for (p = 0U; p < NUM_PES; p++) acc_set_end_val(p, KERNEL_END);

    uint32_t ws      = 0U;                          /* ifmap window start    */
    uint32_t pp_base = batch_offset + NUM_FILTERS;  /* pp row for t=1        */

    for (uint32_t t = 1U; t <= 13U; t++) {
        for (p = 0U; p < NUM_PES; p++) acc_load_ifmap(p, ws, ws + KERNEL_END);
        for (p = 0U; p < NUM_PES; p++) acc_load_iw_counter(p);
        acc_start_conv(1U);
        for (p = 0U; p < NUM_PES; p++) acc_read_result(pp_base + p);
        ws      += CH_STRIDE;    /* +90 each time-step */
        pp_base += NUM_FILTERS;  /* +32 each time-step */
    }
    /* After loop: ws = 13*90 = 1170 (exactly what t=14 needs) */

    /* ── t = 14 : RIGHT-PADDED output ──────────────────────────────────────
     *  Effective window: t13w[0..89] + t14w[90..179] + 0*w[180..269]
     *  → load RPAD weights, ifmap flat[ws..ws+179], end_val = PAD_END (179)
     * ─────────────────────────────────────────────────────────────────────── */
    load_weights(batch_idx, 2U); /* RPAD */
    for (p = 0U; p < NUM_PES; p++) acc_set_end_val(p, PAD_END);
    for (p = 0U; p < NUM_PES; p++) acc_load_ifmap(p, ws, ws + PAD_END);
    for (p = 0U; p < NUM_PES; p++) acc_load_iw_counter(p);
    acc_start_conv(1U);
    for (p = 0U; p < NUM_PES; p++) acc_read_result(pp_base + p);
}

/* ── Entry point ────────────────────────────────────────────────────────────── */
int main(void)
{
    /* Global accelerator setup (unchanged) */
    acc_set_active_pes(0x00000018U);
    acc_swap_pp(0U);

    /* QAT + Z_in setup for all PEs (unchanged) */
    for (uint32_t p = 0U; p < NUM_PES; p++) {
        acc_load_qat(p, QM, QSZ);
        acc_load_z_in(p, ZIN);
        acc_set_start_val(p, 0U);
    }

    /*
     * Process all 4 batches (32 filters total).
     *
     * Original:  4 × run_batch(offset, b?_lpad, b?_full, b?_rpad)
     *   → 12 static functions in .text, 96 literal address pairs.
     *
     * Optimised: 4 × run_batch_opt(batch_idx, batch_offset)
     *   → 1 load_weights() helper, addresses computed at runtime.
     *
     * Cycle cost of the arithmetic is negligible: the dominant cost
     * is the memory-interface instructions, which are identical.
     */
    run_batch_opt(0U,  0U);
    run_batch_opt(1U,  8U);
    run_batch_opt(2U, 16U);
    run_batch_opt(3U, 24U);

    /* Finalise (unchanged) */
    acc_swap_pp(1U);
    acc_clear();
    while (1) asm volatile ("wfi");
    return 0;
}
