/*
 * Module: reciprocal_lut
 * Description: Pipelined reciprocal LUT using lut_sram_1024x16 macro.
 * 3-stage pipeline (valid_in to valid_out):
 *   Stage 1 : Leading zero detect + address registration   (1 cy)
 *   Stage 2 : SRAM read (CEN asserted, Q updates at CLK_)  (1 cy)
 *   Stage 3 : Register SRAM Q -> mantissa, k_out           (1 cy)
 *
 * No ifdef ASIC_SYNTHESIS — single code path for RTL sim + synthesis.
 * SRAM initialisation done by testbench via hierarchical reference:
 *   test_hardware.dut.decoder_acc_inst.rms_norm.lut_inst.u_recip_lut.mem[r]
 *
 * IMPORTANT: valid_d1 initialised to 0 so lut_cen=1 (SRAM disabled) at t=0.
 * Without this, CEN=X at first posedge CLK triggers ARM model failedWrite()
 * which wipes all mem[] to X.
 */

/* verilator lint_off UNUSEDSIGNAL */
`timescale 1ns / 1ps

module reciprocal_lut (
    input  wire        clk,
    input  wire        rst,
    input  wire        valid_in,
    input  wire [39:0] mean_in,    // 40-bit Sum of Squares Mean

    output reg         valid_out,
    output reg  [15:0] mantissa,   // 16-bit ROM output
    output reg  [5:0]  k_out       // 6-bit exponent (MSB position)
);

// =============================================================================
// COMBINATIONAL — Leading Zero Detect + Address Extraction
// =============================================================================
reg [5:0] msb_pos;
integer   lz_i;

always @(*) begin
    msb_pos = 6'd0;
    for (lz_i = 0; lz_i < 40; lz_i = lz_i + 1)
        if (mean_in[lz_i]) msb_pos = lz_i[5:0];
end

wire [39:0] shifted_mean = mean_in << (6'd39 - msb_pos);
wire [9:0]  rom_addr     = shifted_mean[38:29];
wire        zero_in      = (mean_in == 40'd0);

// =============================================================================
// STAGE 1 — Register address and k (after combo settle)
// =============================================================================
reg [9:0]  addr_d1  = 10'd0;
reg [5:0]  k_d1     = 6'd0;
reg        zero_d1  = 1'b0;
reg        valid_d1 = 1'b0;   // MUST init 0: lut_cen=~valid_d1; X→failedWrite

always @(posedge clk) begin
    if (rst) begin
        valid_d1 <= 1'b0;
        addr_d1  <= 10'd0;
        k_d1     <= 6'd0;
        zero_d1  <= 1'b0;
    end else begin
        valid_d1 <= valid_in;
        if (valid_in) begin
            addr_d1 <= zero_in ? 10'd0 : rom_addr;
            k_d1    <= zero_in ? 6'd0  : msb_pos;
            zero_d1 <= zero_in;
        end
    end
end

// =============================================================================
// STAGE 2 — lut_sram_1024x16 macro read
// CEN active-low: CEN=0 when valid_d1=1 (address stable on bus).
// ARM model updates Q_int via blocking assign inside always @ CLK_ (buf-delayed).
// Do NOT sample Q at this posedge — register it one cycle later (Stage 3).
// =============================================================================
wire [15:0] lut_q;
wire        lut_cen = ~valid_d1;   // active-low; 1 = disabled (safe default)

lut_sram_1024x16 u_recip_lut (
    .Q   (lut_q),
    .CLK (clk),
    .CEN (lut_cen),
    .WEN (1'b1),        // 1 = read-only
    .A   (addr_d1),
    .D   (16'd0),
    .EMA (3'b000),
    .RETN(1'b1)
);

reg [5:0]  k_d2    = 6'd0;
reg        zero_d2 = 1'b0;
reg        valid_d2 = 1'b0;

always @(posedge clk) begin
    if (rst) begin
        valid_d2 <= 1'b0;
        k_d2     <= 6'd0;
        zero_d2  <= 1'b0;
    end else begin
        valid_d2 <= valid_d1;
        if (valid_d1) begin
            k_d2    <= k_d1;
            zero_d2 <= zero_d1;
        end
    end
end

// =============================================================================
// STAGE 3 — Register SRAM output
// lut_q at this posedge reflects SRAM read from previous cycle (no race).
// =============================================================================
always @(posedge clk) begin
    if (rst) begin
        valid_out <= 1'b0;
        mantissa  <= 16'd0;
        k_out     <= 6'd0;
    end else begin
        valid_out <= valid_d2;
        if (valid_d2) begin
            mantissa <= zero_d2 ? 16'd0 : lut_q;
            k_out    <= zero_d2 ? 6'd0  : k_d2;
        end
    end
end

endmodule
