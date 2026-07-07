/*
* Author - Ankur Gupta
* Version -1.0
* Decoder for Neonatal work
* Date-24-01-2026
*/

/*
 * Module: qat_requantizer
 * Description: Performs QAT scaling with Output Zero Point support:
 * Output = Clamp( ( (Accumulator * Mult) >>> Shift ) + Zero_Point )
 */

`timescale 1ns / 1ps

module qat_requantizer(
    //Data Inputs
    input wire signed [42:0]  accum_in ,  //Output from MAC
    //QAT Control Parameters (Load these from registers)
    input wire signed [31:0]  qat_mult,   //Fixed-point Multiplier
    input wire        [5:0]   qat_shift,  //Shift amount for scaling(0-63)
    input wire signed [15:0]  zero_point, // **NEW: Output Zero Point (Z_out)**

    //Output
    output wire signed [15:0]  data_out
);

//--------------------------------------------------
// 1. Fixed-Point Multiplication (Scaling)
//    Result width = 43 (acc) * 32(mult) = 75 bits)
//--------------------------------------------------
wire signed [74:0] product;
assign product = accum_in * qat_mult; // 75-bit result;

//--------------------------------------------------
// 2. Rounding Logic (Round to nearest)
//--------------------------------------------------
wire signed [74:0] rounding_val ;

assign rounding_val = (qat_shift > 0) ? (75'sd1 << (qat_shift - 1)) : 75'sd0; // Add 0.5 for rounding

wire signed [74:0] round_product ;
assign round_product = product + rounding_val; // Rounded product before shifting
//-------------------------------------------------
// 3. Arithmetic Right Shift (Scaling)
//-------------------------------------------------
wire signed [74:0] shifted_val ;
assign shifted_val = round_product >>> qat_shift; // Shifted result after scaling

//---------------------------------------------------------
// 4. Add Output Zero Point (Z_out)
// width match: 75 bit total -16 bits ZP = 59 bits padding 
//---------------------------------------------------------
wire signed [74:0] val_with_zp ;
//**Sign extend by 59 bits
assign val_with_zp = shifted_val + {{59{zero_point[15]}}, zero_point}; // Add Z_out to the scaled value

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

 assign   data_out = clamped_result; // Output the final clamped result
endmodule

