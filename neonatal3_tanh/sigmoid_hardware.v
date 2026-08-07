`timescale 1ns/1ps

// Sigmoid hardware using lut_sram_1024x16 macro for RTL + ASIC simulation.
// Pipeline latency: 4 clock cycles (valid_in to valid_out).
//   Stage 1 : DSP  q_in*M_int16 + B_int32           (1 cy)
//   Stage 2 : arith-right-shift + clamp -> addr      (1 cy)
//   Stage 3 : SRAM read (CEN asserted, Q updates)    (1 cy)
//   Stage 4 : register SRAM Q -> sig_out             (1 cy)
//
// CRITICAL: all valid_* regs are initialised to 0 at declaration time so that
// lut_cen = ~valid_d2 = 1 (SRAM disabled) from t=0.  Without this, valid_d2
// starts as X, CEN = X, and the ARM model's readWrite task calls failedWrite()
// at the first posedge CLK — destroying the MUX-16 mem[] we loaded.
//
// SRAM init: $readmemh fills a local shadow ROM; then we build each 256-bit
// MUX-16 row in a local reg (_row_buf) and write it whole via hierarchical
// reference.  Per-bit hierarchical bit-select silently fails in Xcelium.
// Simulator needs -NOTIMINGCHECKS -nospecify to suppress specify-block
// violations in RTL mode.

module sigmoid_hardware (
    input  wire               clk,
    input  wire               rst,

    // Data stream
    input  wire               valid_in,
    input  wire signed [15:0] q_in,

    // Configuration
    input  wire signed [15:0] M_int16,
    input  wire signed [31:0] B_int32,
    input  wire [3:0]         scale_bits,
    input  wire               tanh_mode,

    // Output stream
    output reg                valid_out,
    output reg  [15:0]        sig_out
);

// =============================================================================
// STAGE 1 — DSP Multiply-Accumulate
// =============================================================================
reg signed [31:0] p_stage1  = 32'd0;
reg               valid_d1  = 1'b0;
reg               tanh_d1   = 1'b0;

always @(posedge clk) begin
    if (rst) begin
        valid_d1 <= 1'b0;
        tanh_d1  <= 1'b0;
        p_stage1 <= 32'd0;
    end else begin
        valid_d1 <= valid_in;
        tanh_d1  <= valid_in ? tanh_mode : 1'b0;
        if (valid_in)
            p_stage1 <= (q_in * M_int16) + B_int32;
    end
end

// =============================================================================
// STAGE 2 — Arithmetic right-shift + clamp to [0, 1023]
// =============================================================================
reg [9:0]  addr_stage2 = 10'd0;
reg        valid_d2    = 1'b0;   // MUST init to 0: lut_cen=~valid_d2; X here
                                  // causes failedWrite in ARM model at clk 0.
reg        tanh_d2     = 1'b0;

wire signed [32:0] p_stage1_ext = {p_stage1[31], p_stage1};
wire signed [32:0] shifted_val_ext = tanh_d1
                                     ? ((p_stage1_ext <<< 1) >>> scale_bits)
                                     : (p_stage1_ext >>> scale_bits);

always @(posedge clk) begin
    if (rst) begin
        valid_d2    <= 1'b0;
        tanh_d2     <= 1'b0;
        addr_stage2 <= 10'd0;
    end else begin
        valid_d2 <= valid_d1;
        tanh_d2  <= valid_d1 ? tanh_d1 : 1'b0;
        if (valid_d1) begin
            if (shifted_val_ext < 33'sd0)
                addr_stage2 <= 10'd0;
            else if (shifted_val_ext > 33'sd1023)
                addr_stage2 <= 10'd1023;
            else
                addr_stage2 <= shifted_val_ext[9:0];
        end
    end
end

// =============================================================================
// STAGE 3 — lut_sram_1024x16 macro read
// CEN is active-low: CEN=0 when valid_d2=1 (address ready on bus).
// ARM model updates Q_int via blocking assignment inside always @ CLK_
// (which fires through a buf gate, δ-cycle after posedge clk).
// Do NOT sample Q at the same posedge — capture it one cycle later (Stage 4).
// =============================================================================
wire [15:0] lut_q;
wire        lut_cen = ~valid_d2;   // active-low; 1 = disabled (safe default)

lut_sram_1024x16 u_sigmoid_lut (
    .Q   (lut_q),
    .CLK (clk),
    .CEN (lut_cen),
    .WEN (1'b1),       // 1 = read-only
    .A   (addr_stage2),
    .D   (16'd0),
    .EMA (3'b000),
    .RETN(1'b1)
);

// =============================================================================
// STAGE 4 — Register SRAM output
// lut_q at this posedge reflects the SRAM read from the previous cycle
// (no race: SRAM Q_int was updated at δ=1 of the prior posedge via buf/CLK_).
// =============================================================================
reg valid_d3 = 1'b0;
reg tanh_d3  = 1'b0;

always @(posedge clk) begin
    if (rst) begin
        valid_d3 <= 1'b0;
        tanh_d3  <= 1'b0;
    end else begin
        valid_d3 <= valid_d2;
        tanh_d3  <= valid_d2 ? tanh_d2 : 1'b0;
    end
end

always @(posedge clk) begin
    if (rst) begin
        valid_out <= 1'b0;
        sig_out   <= 16'd0;
    end else begin
        valid_out <= valid_d3;
        if (valid_d3)
            sig_out <= tanh_d3 ? (lut_q - 16'h8000) : lut_q;
    end
end

// SRAM initialisation is done by the testbench via hierarchical reference:
//   test_hardware.dut.decoder_acc_inst.u_sigmoid.u_sigmoid_lut.mem[r]
// This keeps sigmoid_hardware.v fully synthesisable with no simulation-only regs.

endmodule
