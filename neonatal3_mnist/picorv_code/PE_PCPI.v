`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.11.2025 13:54:43
// Design Name: 
// Module Name: PE_PCPI
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module PE_PCPI(
input clk,
input resetn,
input pcpi_valid,
input [31:0] pcpi_insn,
input [31:0] pcpi_rs1,
input [31:0] pcpi_rs2,
output reg pcpi_wr,
output reg [31:0] pcpi_rd,
output  pcpi_wait,
output reg pcpi_ready,
output reg debug_valid_seen,  // Debug output
output reg debug_custom_seen  // Debug: custom instruction recognized
);

// instruction decoding
wire [6:0] opcode = pcpi_insn[6:0];
wire [2:0] funct3 = pcpi_insn[14:12];
wire [6:0] funct7 = pcpi_insn[31:25]; // Fixed: should be 6 bits, not 2


// custom opcodes - using custom-1 opcode space (0x2B) since 0x0B is used by PicoRV32 for IRQ
localparam CUSTOM1_OPCODE = 7'b0101011;

//custom function codes for different add operations
localparam CUSTOM_ADD = 3'b000;
localparam CUSTOM_ADD_IMM = 3'b001;
localparam CUSTOM_ADD_SAT = 3'b010; //Saturated addition

// NOTE: The instruction 0x0062B2AB has funct3=3, so let's add that too
localparam CUSTOM_ADD_SAT_ALT = 3'b011; // Alternative encoding

//instruction recognition

wire is_custom_add = (opcode == CUSTOM1_OPCODE) && (funct3 == CUSTOM_ADD); 
wire is_custom_add_imm = (opcode == CUSTOM1_OPCODE) && (funct3 == CUSTOM_ADD_IMM) ;
wire is_custom_add_sat = (opcode == CUSTOM1_OPCODE) && ((funct3 == CUSTOM_ADD_SAT) || (funct3 == CUSTOM_ADD_SAT_ALT));
wire is_valid_custom = is_custom_add || is_custom_add_imm || is_custom_add_sat;


//addition logic
reg [31:0] add_result;
reg [32:0] add_result_ext; // Extended for overflow detection
wire [31:0] immediate = {{20{pcpi_insn[31]}},pcpi_insn[31:20]}; // Sign-extended immediate

always @(*) begin
    case (1'b1)
        is_custom_add: begin
            add_result_ext = {1'b0 , pcpi_rs1} + {1'b0 , pcpi_rs2};
            add_result = add_result_ext[31:0];
        end
        
        is_custom_add_imm: begin
            add_result_ext = {1'b0 , pcpi_rs1} + {1'b0 , immediate};
            add_result = add_result_ext[31:0];
        end
        
        is_custom_add_sat: begin
            add_result_ext = {1'b0 , pcpi_rs1} + {1'b0, pcpi_rs2};
            // saturated addition - clamp to max value on overflow
            add_result = add_result_ext[32] ? 32'hFFFFFFFF:add_result_ext[31:0];
        end 
        
        default: begin
            add_result_ext = 33'b0;
            add_result = 32'b0;
        end

    endcase
    
end
        
     //PCPI protocol implementation
always @(posedge clk) begin
    if(!resetn) begin
        pcpi_wr <= 1'b0;
        pcpi_rd <= 32'b0;
        pcpi_ready <= 1'b0;
        debug_valid_seen <= 1'b0;
        debug_custom_seen <= 1'b0;
    end
    else begin
        pcpi_wr <= 1'b0;
        pcpi_ready <= 1'b0;
        
        // Debug: Set flag if we ever see pcpi_valid
        if (pcpi_valid) begin
            debug_valid_seen <= 1'b1;
        end
        
        // Debug: Set flag if we see a custom instruction (any opcode 0x2B)
        if (pcpi_valid && (opcode == CUSTOM1_OPCODE)) begin
            debug_custom_seen <= 1'b1;
        end
        
        if (pcpi_valid && is_valid_custom) begin
            pcpi_rd <= add_result;
            pcpi_wr <= 1'b1;
            pcpi_ready <= 1'b1;
        end
    end
 end
 
     // No wait states needed for single-cycle operation
    assign pcpi_wait = 1'b0;
 
endmodule
