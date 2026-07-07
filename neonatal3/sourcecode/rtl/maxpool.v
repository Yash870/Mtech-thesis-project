`timescale 1ns/1ps
/*
* Author - Ankur Gupta
* Version -1.0
* Maxpool for Neonatal work
* Date-25-03-2026
*/

module maxpool(
    input wire  [15:0] in1,
    input wire  [15:0] in2,
    output wire [15:0] max
);
    assign max =(in1 > in2) ? in1: in2;
endmodule
