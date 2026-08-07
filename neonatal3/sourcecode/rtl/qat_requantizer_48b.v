/*
 * Module: qat_requantizer
 * Description: Performs QAT scaling with Output Zero Point support.
 * UPGRADED: Now natively accepts 48-bit inputs for RMS Gamma precision.
 * Output = Clamp( ( (Accumulator * Mult) >>> Shift ) + Zero_Point )
 */

`timescale 1ns / 1ps

module qat_requantizer_48b(
    // Data Inputs
    input wire signed [47:0]  accum_in ,  // UPGRADED: 48-bit input from PE MUX
    
    // QAT Control Parameters
    input wire signed [31:0]  qat_mult,   // Fixed-point Multiplier
    input wire        [5:0]   qat_shift,  // Shift amount for scaling (0-63)
    input wire signed [15:0]  zero_point, // Output Zero Point (Z_out)

    // Output
    output wire signed [15:0] data_out
);

//--------------------------------------------------
// 1. Fixed-Point Multiplication (Scaling)
//    Result width = 48 (acc) + 32 (mult) = 80 bits
//--------------------------------------------------
wire signed [79:0] product;
assign product = accum_in * qat_mult; 

//--------------------------------------------------
// 2. Rounding Logic (Round to nearest)
//--------------------------------------------------
wire signed [79:0] rounding_val;

// Cast to 80-bit signed literal
assign rounding_val = (qat_shift > 0) ? (80'sd1 << (qat_shift - 1)) : 80'sd0; 

wire signed [79:0] round_product;
assign round_product = product + rounding_val; 

//-------------------------------------------------
// 3. Arithmetic Right Shift (Scaling)
//-------------------------------------------------
wire signed [79:0] shifted_val;
assign shifted_val = round_product >>> qat_shift; 

//---------------------------------------------------------
// 4. Add Output Zero Point (Z_out)
//    Width match: 80 bit total - 16 bits ZP = 64 bits padding 
//---------------------------------------------------------
wire signed [79:0] val_with_zp;

// UPGRADED: Sign extend Z_out by 64 bits to match the 80-bit wire
assign val_with_zp = shifted_val + {{64{zero_point[15]}}, zero_point}; 

//--------------------------------------------------
// 5. Clamping to Keras uint8 range (0 to 255)
//--------------------------------------------------
reg signed [15:0] clamped_result;

always @(*) begin
    if (val_with_zp > 80'sd255) begin
        clamped_result = 16'sd255; 
    end else if (val_with_zp < 80'sd0) begin        
        clamped_result = 16'sd0; 
    end else begin
        clamped_result = val_with_zp[15:0]; 
    end
end



assign data_out = clamped_result; 

endmodule
