/*
* Author - Ankur Gupta
* Version -1.0
* Decoder for Neonatal work
* Date-24-01-2026
*/

//Fixed Pattern handshake
`timescale 1ns/1ps
module handshake_muxF (
  input wire        clk,
  input wire        rst,
  input wire [3:0]  num_active_pes,
  input wire [9:0]  out_per_pe,
  //sources
  input  wire        src0_valid,
  output wire        src0_ready,
  input  wire [15:0] src0_data,
 
  input  wire        src1_valid,
  output wire        src1_ready,
  input  wire [15:0] src1_data,

  input  wire        src2_valid,
  output wire        src2_ready,
  input  wire [15:0] src2_data,
 
  input  wire        src3_valid,
  output wire        src3_ready,
  input  wire [15:0] src3_data,
  input  wire        src4_valid,
  output wire        src4_ready,
  input  wire [15:0] src4_data,

  input  wire        src5_valid,
  output wire        src5_ready,
  input  wire [15:0] src5_data,
  input  wire        src6_valid,
  output wire        src6_ready,
  input  wire [15:0] src6_data,
 
  input  wire        src7_valid,
  output wire        src7_ready,
  input  wire [15:0] src7_data,
  //master
  output reg         mst_valid,
  input  wire        mst_ready,
  output reg  [15:0] mst_data
);
reg [2:0] current_turn;
reg [9:0] output_count;

always @(posedge clk) begin
  if(rst) begin
    current_turn <= 0;
    output_count <= 0;
  end
  else begin
    if (mst_valid && mst_ready) begin
      if (output_count == out_per_pe-1) begin 
        output_count <= 0;
      
        if (current_turn == num_active_pes-1) begin
          current_turn <= 0;
        end
        else begin
          current_turn <= current_turn + 1;
        end
      end
      else begin
        output_count <= output_count + 1;
      end
    end
  end
end

always @(*) begin
  case (current_turn)
     3'd0: begin
       mst_valid = src0_valid;
       mst_data = src0_data;
     end
     3'd1:begin
       mst_valid = src1_valid;
       mst_data = src1_data;
     end
     3'd2: begin
       mst_valid = src2_valid;
       mst_data = src2_data;
     end
     3'd3:begin
       mst_valid = src3_valid;
       mst_data = src3_data;
     end
     3'd4: begin
       mst_valid = src4_valid;
       mst_data = src4_data;
     end
     3'd5:begin
       mst_valid = src5_valid;
       mst_data = src5_data;
     end
     3'd6: begin
       mst_valid = src6_valid;
       mst_data = src6_data;
     end
     3'd7:begin
       mst_valid = src7_valid;
       mst_data = src7_data;
     end
     default: begin
       mst_valid = 0;
       mst_data = 0;
    
     end
  endcase
end
assign src0_ready = (current_turn == 3'd0) && mst_ready;
assign src1_ready = (current_turn == 3'd1) && mst_ready;
assign src2_ready = (current_turn == 3'd2) && mst_ready;
assign src3_ready = (current_turn == 3'd3) && mst_ready;
assign src4_ready = (current_turn == 3'd4) && mst_ready;
assign src5_ready = (current_turn == 3'd5) && mst_ready;
assign src6_ready = (current_turn == 3'd6) && mst_ready;
assign src7_ready = (current_turn == 3'd7) && mst_ready;
endmodule

