`timescale 1ns/1ps
module scratchpad_sram #(
  parameter DATA_WIDTH = 16,
  parameter ADDR_WIDTH = 10,
  parameter DEPTH      = 1 << ADDR_WIDTH
)(
  input  wire                  clk,
  input  wire                  en,
  input  wire                  wen,
  input  wire [ADDR_WIDTH-1:0] addr,
  input  wire [DATA_WIDTH-1:0] din,
  output wire [DATA_WIDTH-1:0] dout
);

generate
  if (DEPTH == 4096) begin : gen_4096
    pingpong_sram_4096x16 u_sram (
      .Q   (dout),
      .CLK (clk),
      .CEN (~en),
      .WEN (~wen),
      .A   (addr[11:0]),
      .D   (din),
      .EMA (3'b000),
      .RETN(1'b1)
    );
  end else begin : gen_1024
    lut_sram_1024x16 u_sram (
      .Q   (dout),
      .CLK (clk),
      .CEN (~en),
      .WEN (~wen),
      .A   (addr[9:0]),
      .D   (din),
      .EMA (3'b000),
      .RETN(1'b1)
    );
  end
endgenerate

endmodule
