`timescale 1ns/1ps
module scratchpad_dual_port #(
  parameter DATA_WIDTH = 16,
  parameter ADDR_WIDTH = 10
)(
  input  wire                  clk,

  input  wire                  ren,
  input  wire [ADDR_WIDTH-1:0] raddr,
  output wire [DATA_WIDTH-1:0] rdata,

  input  wire                  wen,
  input  wire [ADDR_WIDTH-1:0] waddr,
  input  wire [DATA_WIDTH-1:0] wdata
);

pe_spad_1024x16_dp u_spad_dp (
  .QA  (rdata),
  .QB  (),
  .CLKA(clk),
  .CENA(~ren),
  .WENA(1'b1),
  .AA  (raddr[9:0]),
  .DA  (16'd0),
  .CLKB(clk),
  .CENB(~wen),
  .WENB(~wen),
  .AB  (waddr[9:0]),
  .DB  (wdata),
  .EMAA(3'b000),
  .EMAB(3'b000),
  .RETN(1'b1)
);

endmodule
