/*
* Author - Ankur Gupta
* Version -1.0
* PE for Neonatal work
* Date-24-01-2026
*/

`timescale 1ns/1ps
module PE#(
  parameter [3:0] PE_id=3'd1,
  parameter PE_on_off= 0
)(
  input  wire        clk,
  input  wire        rst,
  input  wire [15:0] ifmap,
  input  wire [15:0] weight,
  input  wire [41:0] bias,
  input  wire [31:0] qat_mult,
  input  wire [5:0]  qat_shift,
  input  wire [15:0] zero_point,
  input  wire [15:0] z_in,
  input  wire [31:0] control,
  input  wire [9:0]  addr,
  input  wire        ready,
  input  wire [9:0]  se_counter_val,
  output wire [15:0] Psum_out,
  output wire        done,
  output reg         valid
);

wire signed [15:0] Min0,Min1;
wire signed [15:0] Min0_dequant;
wire signed [31:0] Mout;
wire PE_en ;
wire load_PE_en;
/* verilator lint_off UNUSEDSIGNAL */
wire PE_on ;
/* verilator lint_on UNUSEDSIGNAL */
wire  [9:0]  addr_count;
wire         ifmap_wen;
wire         weight_wen;
wire         spad_ren;
wire         load_iw;
reg signed  [41:0] bias_reg;
reg   [9:0]  start_val;
reg   [9:0]  end_val;
wire  [9:0]  se_val;
wire         load_bias;
wire         load_qat;
/* verilator lint_off UNUSEDSIGNAL */
wire [8:0] reserved_sig = control[26:18];
/* verilator lint_on UNUSEDSIGNAL */
wire load_ev;
wire load_sv;
wire clear;
reg signed [42:0]  Psum_buf;
reg done_d1;
reg valid_temp;
reg valid_temp2;

wire relu_en;
reg  relu_en_reg;
reg  [31:0] qat_mult_reg;
reg  [5:0]  qat_shift_reg;
reg  [15:0] zero_point_reg;

wire signed [15:0] Psum_buf_quant;
reg signed [15:0] Psum_buf_quant_reg;
wire signed [15:0] relu_in;
wire signed [15:0] relu_out;
reg signed [15:0] relu_out_reg;
reg done_d1_prev;
reg spad_ren_reg;
reg signed [42:0] Psum_buf_unqant;

assign PE_en        = (PE_id == control[3:0]);
// Load targeting has two backward-compatible modes:
//   control[5] = 0: control[3:0] is one PE ID (legacy instructions)
//   control[5] = 1: control[8:6] is N-1 and PE0..PE(N-1) are selected
wire [3:0] load_pe_count = {1'b0, control[8:6]} + 4'd1;
assign load_PE_en   = control[5] ? (PE_id < load_pe_count) : PE_en;
/* verilator lint_off UNUSEDSIGNAL */
assign PE_on        = control[4+PE_on_off] ;
/* verilator lint_on UNUSEDSIGNAL */
assign ifmap_wen    = control[14];
assign weight_wen   = control[15];
assign spad_ren     = control[16];
assign load_iw      = control[12];
assign load_sv      = control[28] & PE_en;
assign load_ev      = control[27] & PE_en;
assign relu_en      = control[17];
assign load_bias    = control[29];
assign load_qat     = control[30];
assign clear        = control[31];
assign se_val       = se_counter_val;

// ---------------------------------------------------------
// FOOLPROOF UNPACKING LOGIC (UNSIGNED)
// ---------------------------------------------------------
wire [15:0] z_out_unpacked = {8'd0, zero_point_reg[7:0]};
wire [15:0] z_in_unpacked  = {8'd0, zero_point_reg[15:8]};

relu #(.WIDTH(16)) relu0(
    .relu_in(relu_in),
    .zero_point($signed(z_out_unpacked)),
    .relu_out(relu_out)
);

scratchpad_dual_port  ifmap0(
    .clk(clk),
    .ren(spad_ren),
    .raddr(addr_count),
    .rdata(Min0),
    .wen(ifmap_wen & load_PE_en),
    .waddr(addr),
    .wdata(ifmap)
);

scratchpad_dual_port  weight0(
    .clk(clk),
    .ren(spad_ren),
    .raddr(addr_count),
    .rdata(Min1),
    .wen(weight_wen & load_PE_en),
    .waddr(addr),
    .wdata(weight)
);

qat_requantizer #() requantizer0(
    .accum_in(Psum_buf_unqant),
    .qat_mult(qat_mult_reg),
    .qat_shift(qat_shift_reg),
    .zero_point(z_out_unpacked), // Uses Unpacked Z_out
    .data_out(Psum_buf_quant)
);

counter #(.restart_behav(0) , .width(10)) ifmap_weight_addr( 
    .clk(clk),
    .rst(rst | clear),
    .load(load_iw & PE_en),
    .start_val(start_val),
    .end_val(end_val),
    .enable(spad_ren),
    .count(addr_count),
    .done(done)
);

always @(posedge clk) begin
  if (rst || clear) begin
    relu_en_reg <= 0;
  end else if (load_iw & PE_en) begin  
    relu_en_reg <= 0;
  end else if (relu_en) begin
    relu_en_reg <= 1;
  end else begin
    relu_en_reg <= relu_en_reg;
  end
end

always @(posedge clk) begin
  if (rst || clear) begin
    bias_reg <=0;
  end else if (load_PE_en & load_bias) begin
    bias_reg <= bias;
  end else begin
    bias_reg <= bias_reg;
  end
end

always @(posedge clk) begin
  if (rst || clear) begin
    qat_mult_reg <= 0;
    qat_shift_reg <= 0;
    zero_point_reg <= 0;  
  end else if (load_qat & PE_en) begin
    qat_mult_reg <= qat_mult;
    qat_shift_reg <= qat_shift;
    zero_point_reg <= zero_point; // Contains both unpacked Z
  end else begin
    qat_mult_reg <= qat_mult_reg;
    qat_shift_reg <= qat_shift_reg;
    zero_point_reg <= zero_point_reg;
  end
end

always @(posedge clk) begin
 if (rst || clear) begin
   start_val <=0;
   end_val <= 0;
 end else begin
   if(load_sv) begin
     start_val <= se_val;
   end else if (load_ev) begin
     end_val <= se_val;
   end else begin
     start_val <= start_val;
     end_val  <= end_val;
   end
 end
end

// FIX: Cast to $signed here during the math operation
assign Min0_dequant = $signed(Min0) - $signed(z_in_unpacked); 
assign Mout         = Min0_dequant * Min1; 

always @(posedge clk) begin
  if (rst || clear) begin
    done_d1<=0;
  end else begin
    done_d1<=done & ~done_d1_prev;
  end
end

always @(posedge clk) begin
  if (rst || clear) begin
    spad_ren_reg<=0;
  end else begin
    spad_ren_reg<=spad_ren;
  end
end

always @(posedge clk) begin
  if (rst || clear) begin
    done_d1_prev <= 0;
  end else begin
    done_d1_prev <= done;
  end
end

always @(posedge clk) begin
  if(rst || clear) begin
    Psum_buf <= 0;
  end else if (load_iw & PE_en) begin
    Psum_buf <= 0;
  end else if (spad_ren_reg & ~done_d1_prev) begin
    Psum_buf <= Psum_buf + {{11{Mout[31]}}, Mout};
  end else if (done_d1) begin
    Psum_buf <= Psum_buf + bias_reg;
  end
end

always @(posedge clk) begin
  if (rst) begin
    valid_temp <= 0;
  end else if (done_d1) begin
    valid_temp <= 1;
  end else begin
    valid_temp <= 0;
  end
end

always @(posedge clk) begin
  if (rst) begin
    valid_temp2 <= 0;
  end else begin
    valid_temp2 <= valid_temp;
  end
end

always @(posedge clk) begin
  if (rst) begin
    valid <= 0;
  end else if (valid & ready) begin
    valid <= 0;
  end else if (valid_temp2) begin
    valid <= 1;
  end
end

always @(posedge clk) begin
  if(rst) begin
    Psum_buf_unqant <= 0;
  end else begin
    Psum_buf_unqant <= Psum_buf;
  end
end

always @(posedge clk) begin
  if (rst) begin
    relu_out_reg <= 0;
    Psum_buf_quant_reg <= 0;
  end else begin
    relu_out_reg <= relu_out;
    Psum_buf_quant_reg <= Psum_buf_quant;
  end
end

assign relu_in  = Psum_buf_quant; 
assign Psum_out = relu_en_reg ? relu_out_reg : Psum_buf_quant_reg; 

endmodule
