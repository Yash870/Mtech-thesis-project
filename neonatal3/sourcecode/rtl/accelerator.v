/*
* Author - Ankur Gupta
* Version -1.0
* Decoder for Neonatal work
* Date-24-01-2026
*/

`timescale 1ns/1ps
module accelerator ( 
input   wire          clk,
input   wire          rst,
input   wire [3:0]    num_active_pes,
input   wire [9:0]    out_per_pe,
input   wire [31:0]   control_signal,
input   wire [9:0]    addr,
input   wire [15:0]   ifmap,
input   wire [15:0]   weight,
input   wire [41:0]   bias,
input   wire [31:0]   qat_mult,
input   wire [5:0]    qat_shift,
input   wire [15:0]   zero_point,
input   wire [15:0]   z_in,
input   wire          M_ready,
input   wire [9:0]    se_counter_val,
output  wire [15:0]  M_Psum_out,
output  wire         done1, done2, done3, done4, done5, done6, done7, done8,
output  wire         M_valid
);


wire ready0,ready1,ready2,ready3,ready4,ready5,ready6,ready7;
wire [15:0] Psum_out0,Psum_out1,Psum_out2,Psum_out3,Psum_out4,Psum_out5,Psum_out6,Psum_out7;
wire valid0,valid1,valid2,valid3,valid4,valid5,valid6,valid7;

PE #(.PE_id(0),.PE_on_off(0)) PE0 ( .clk(clk),.rst(rst),.ifmap(ifmap),.weight(weight),.bias(bias),.control(control_signal),.addr(addr),.ready(ready0),.Psum_out(Psum_out0),.done(done1),.valid(valid0),.qat_mult(qat_mult),.qat_shift(qat_shift),.zero_point(zero_point),.z_in(z_in),.se_counter_val(se_counter_val) );
PE #(.PE_id(1),.PE_on_off(0)) PE1 ( .clk(clk),.rst(rst),.ifmap(ifmap),.weight(weight),.bias(bias),.control(control_signal),.addr(addr),.ready(ready1),.Psum_out(Psum_out1),.done(done2),.valid(valid1),.qat_mult(qat_mult),.qat_shift(qat_shift),.zero_point(zero_point),.z_in(z_in),.se_counter_val(se_counter_val) );
PE #(.PE_id(2),.PE_on_off(0)) PE2 ( .clk(clk),.rst(rst),.ifmap(ifmap),.weight(weight),.bias(bias),.control(control_signal),.addr(addr),.ready(ready2),.Psum_out(Psum_out2),.done(done3),.valid(valid2),.qat_mult(qat_mult),.qat_shift(qat_shift),.zero_point(zero_point),.z_in(z_in),.se_counter_val(se_counter_val) );
PE #(.PE_id(3),.PE_on_off(0)) PE3 ( .clk(clk),.rst(rst),.ifmap(ifmap),.weight(weight),.bias(bias),.control(control_signal),.addr(addr),.ready(ready3),.Psum_out(Psum_out3),.done(done4),.valid(valid3),.qat_mult(qat_mult),.qat_shift(qat_shift),.zero_point(zero_point),.z_in(z_in),.se_counter_val(se_counter_val) );
PE #(.PE_id(4),.PE_on_off(0)) PE4 ( .clk(clk),.rst(rst),.ifmap(ifmap),.weight(weight),.bias(bias),.control(control_signal),.addr(addr),.ready(ready4),.Psum_out(Psum_out4),.done(done5),.valid(valid4),.qat_mult(qat_mult),.qat_shift(qat_shift),.zero_point(zero_point),.z_in(z_in),.se_counter_val(se_counter_val) );
PE #(.PE_id(5),.PE_on_off(0)) PE5 ( .clk(clk),.rst(rst),.ifmap(ifmap),.weight(weight),.bias(bias),.control(control_signal),.addr(addr),.ready(ready5),.Psum_out(Psum_out5),.done(done6),.valid(valid5),.qat_mult(qat_mult),.qat_shift(qat_shift),.zero_point(zero_point),.z_in(z_in),.se_counter_val(se_counter_val) );
PE #(.PE_id(6),.PE_on_off(0)) PE6 ( .clk(clk),.rst(rst),.ifmap(ifmap),.weight(weight),.bias(bias),.control(control_signal),.addr(addr),.ready(ready6),.Psum_out(Psum_out6),.done(done7),.valid(valid6),.qat_mult(qat_mult),.qat_shift(qat_shift),.zero_point(zero_point),.z_in(z_in),.se_counter_val(se_counter_val) );
PE #(.PE_id(7),.PE_on_off(0)) PE7 ( .clk(clk),.rst(rst),.ifmap(ifmap),.weight(weight),.bias(bias),.control(control_signal),.addr(addr),.ready(ready7),.Psum_out(Psum_out7),.done(done8),.valid(valid7),.qat_mult(qat_mult),.qat_shift(qat_shift),.zero_point(zero_point),.z_in(z_in),.se_counter_val(se_counter_val) );


handshake_muxF handshake_muxF0( 
    .clk(clk),.rst(rst),.num_active_pes(num_active_pes),.out_per_pe(out_per_pe),
    .src0_valid(valid0),.src0_ready(ready0),.src0_data(Psum_out0),
    .src1_valid(valid1),.src1_ready(ready1),.src1_data(Psum_out1),
    .src2_valid(valid2),.src2_ready(ready2),.src2_data(Psum_out2),
    .src3_valid(valid3),.src3_ready(ready3),.src3_data(Psum_out3),
    .src4_valid(valid4),.src4_ready(ready4),.src4_data(Psum_out4),
    .src5_valid(valid5),.src5_ready(ready5),.src5_data(Psum_out5),
    .src6_valid(valid6),.src6_ready(ready6),.src6_data(Psum_out6),
    .src7_valid(valid7),.src7_ready(ready7),.src7_data(Psum_out7),
    .mst_valid(M_valid),.mst_ready(M_ready),.mst_data(M_Psum_out)
);
    
endmodule
