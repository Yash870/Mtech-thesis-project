`timescale 1ns/1ps
module relu#(
  parameter WIDTH = 32
)(
  input  wire signed [WIDTH-1:0]  relu_in,
  input  wire signed [WIDTH-1:0]  zero_point, // QAT Zero Point
  output wire signed [WIDTH-1:0]  relu_out
);

// Clamp to zero_point, NOT 0
assign relu_out = (relu_in < zero_point) ? zero_point : relu_in;

endmodule