/*
* Author - Ankur Gupta
* Version -1.0
* Decoder for Neonatal work
* Date-24-01-2026
*/

//==========================================
//    This will take signals from processes 
// and generate control signals for PE array. 
// It will also generate address for PE array.
//===========================================

`timescale 1ns/1ps
module decoder_acc (
    input clk, resetn,
    // RISC-V Custom Instruction Interface (PCPI)
    input             pcpi_valid,
    input      [31:0] pcpi_insn,
    input      [31:0] pcpi_rs1,
    input      [31:0] pcpi_rs2,
    output reg        pcpi_wr,
    output reg [31:0] pcpi_rd,
    output reg        pcpi_wait,
    output reg        pcpi_ready,

    output reg        decoder_ren_input, // Read enable for input memory
    output wire [11:0]  decoder_addr_input, // Address for input memory access
    output reg        decoder_ren_weight, // Read enable for weight memory
    output wire [15:0]  decoder_addr_weight, // Address for weight memory access
    output reg        decoder_ren_bias, // Read enable for bias memory
    output reg [9:0]  decoder_addr_bias, // Address for bias memory access

    output wire       decoder_pp_ren, // Read enable for psum memory
    output wire [11:0] decoder_pp_raddr, // Address for psum memory
    output reg        decoder_pp_wen, // Write enable for psum memory
    output reg [11:0]  decoder_pp_waddr, // Address for psum memory
    output wire       decoder_pp_swap, // Swap signal for psum memory

    input wire [15:0] input_data, // Data from input memory (if needed for combinational logic in decoder)
    input wire [15:0] weight_data, // Data from weight memory (if needed for combinational logic in decoder)
    input wire [31:0] bias_data, // Data from bias memory (if needed for combinational logic in decoder)
    output reg [15:0] decoder_pp_wdata, // Data to be written to psum memory
    input wire [15:0] decoder_pp_rdata, // Data to be read from psum memory

    output reg        illegal_instr, // Signal to indicate illegal instruction

    input  wire       mem_stall      // 1 while QSPI transaction in progress
);

wire        rst = ~resetn; // Active high reset signal
wire        done_input; 
reg         enable_input; 
reg         load_input; 
wire        done_weight; 
reg         enable_weight; 
reg         load_weight; 

// Control signals to PE array
reg [31:0] control_signal; 
reg [9:0]  addr_d1,addr; 

reg [3:0]  num_active_pes; // Number of active PEs in the array
reg [9:0]  out_per_pe; // Number of outputs per PE

reg  [31:0]  decoder_qat_mult;
reg  [5:0]   decoder_qat_shift;
reg  [15:0]  decoder_qat_zp;
reg  [15:0]  decoder_z_in;
wire [6:0]   opcode = pcpi_insn[6:0];
wire [6:0]   funct7 = pcpi_insn[31:25];
wire [2:0]   funct3 = pcpi_insn[14:12];
wire         rms_en = pcpi_insn[31];
/* verilator lint_off UNUSED */ 
wire [9:0]  reserved_pcpi_insn = pcpi_insn[24:15];
wire [4:0]  reserved_pcpi_insn2 = pcpi_insn[11:7];
wire [21:0] reserved_pcpi_rs1 = pcpi_rs1[31:10];
wire [21:0] reserved_pcpi_rs2 = pcpi_rs2[31:10];
/* verilator lint_on UNUSED */

wire        acc_op = (opcode ==7'b0101011); 

// Legacy loads use funct3 as one PE ID.  The FIRST_N variants use funct3 as
// count_minus_one, so 3'b000 targets PE0 and 3'b111 targets PE0..PE7.
wire        instr_load_ifmap_single = acc_op && (funct7 == 7'b0000001 || funct7 == 7'b1000001);
wire        instr_load_weight_single= acc_op && (funct7 == 7'b0000010 || funct7 == 7'b1000010);
wire        instr_load_bias_single  = acc_op && (funct7 == 7'b0000011);
wire        instr_load_ifmap_first_n= acc_op && (funct7 == 7'b0010011); // 0x13
wire        instr_load_weight_first_n=acc_op && (funct7 == 7'b0010100); // 0x14
wire        instr_load_bias_first_n = acc_op && (funct7 == 7'b0010101); // 0x15
wire        instr_load_ifmap        = instr_load_ifmap_single || instr_load_ifmap_first_n;
wire        instr_load_weight       = instr_load_weight_single || instr_load_weight_first_n;
wire        instr_load_bias         = instr_load_bias_single || instr_load_bias_first_n;
wire        instr_load_qat_val      = acc_op && (funct7 == 7'b0000100 || funct7 == 7'b1000100); 
wire        instr_maxpooling        = acc_op && (funct7 == 7'b0000110); 
wire        instr_swap_pp           = acc_op && (funct7 == 7'b0001110); 
wire        instr_start_conv        = acc_op && (funct7 == 7'b0000111); 
wire        instr_clear             = acc_op && (funct7 == 7'b0001000); 
wire        instr_num_active_pes    = acc_op && (funct7 == 7'b0001001); 
wire        instr_set_start_val     = acc_op && (funct7 == 7'b0001010 || funct7 == 7'b1001010); 
wire        instr_set_end_val       = acc_op && (funct7 == 7'b0000101 || funct7 == 7'b1000101); 
wire        instr_set_pe_on_off     = acc_op && (funct7 == 7'b0001011); 
wire        instr_read_status       = acc_op && (funct7 == 7'b0001100); 
wire        instr_read_result       = acc_op && (funct7 == 7'b0001101); 
wire        instr_sigmoid           = acc_op && (funct7 == 7'b0001111); 
wire        instr_start_rms         = acc_op && (funct7 == 7'b0010000 || funct7 == 7'b1010000); 
wire        instr_load_iw_counter   = acc_op && (funct7 == 7'b0010001 || funct7 == 7'b1010001); 
wire        instr_load_z_in         = acc_op && (funct7 == 7'b0010010); 

// PE.v interprets control[5] as FIRST_N mode and control[8:6] as N-1.
// In legacy mode, control[3:0] remains the selected PE ID.
wire        instr_load_first_n      = instr_load_ifmap_first_n ||
                                      instr_load_weight_first_n ||
                                      instr_load_bias_first_n;

wire [31:0] load_target_control     = instr_load_first_n
                                      ? {23'd0, funct3, 1'b1, 5'd0}
                                      : {29'd0, funct3};

wire [7:0]  done;
reg  [9:0]  se_counter_val;
wire [15:0] ifmap_data;
reg         swap_in_pp;
reg         bias_pending;
reg         done_ifmap_pending;
reg         done_weight_pending;
wire        PEarray_M_valid;
reg         PEarray_M_ready;
wire [15:0] PEarray_Psum_out;

// ----maxpool fsm signals and states---//
localparam MP_IDLE       = 3'd0; 
localparam MP_READ_A     = 3'd1; 
localparam MP_WAIT_A     = 3'd2; 
localparam MP_WAIT_B     = 3'd3; 
localparam MP_WRITE      = 3'd4; 
localparam MP_DONE       = 3'd5; 
localparam MP_DONE_WRITE = 3'd6; 

reg [2:0]  mp_state;         
reg [11:0] mp_rd_base;       
reg [11:0] mp_wr_base;       
reg [11:0] mp_pairs;         
reg [11:0] mp_stride;

// Nested Loop Counters for True Keras 2D Pooling
reg [11:0] mp_ch_idx;   
reg [11:0] mp_pair_idx; 

reg [15:0] mp_val_a;        
wire[15:0] mp_max_out;       
reg [11:0] mp_pp_raddr;      
reg        mp_pp_ren_r;     

maxpool mp_unit (
    .in1(mp_val_a),
    .in2(decoder_pp_rdata),
    .max(mp_max_out)
);
//---------------------------------------//

//------------sigmoid fsm signals and states---//
localparam SIG_IDLE = 3'd0; 
localparam SIG_READ = 3'd1; 
localparam SIG_WAIT = 3'd2; 
localparam SIG_PIPE = 3'd3; 
localparam SIG_DONE = 3'd4; 

reg [2:0] sig_state;
reg [11:0] sig_pp_raddr_r; 
reg        sig_pp_ren_r;   
reg        sig_valid_in_r; 
reg  signed [15:0] sig_M_int16;
reg  signed [31:0] sig_B_int32;
reg  [3:0]         sig_scale_bits;
wire               sig_valid_out;
wire [15:0]        sig_out;

sigmoid_hardware u_sigmoid (
    .clk        (clk),
    .rst        (rst),
    .valid_in   (sig_valid_in_r),
    .q_in       (decoder_pp_rdata),
    .M_int16    (sig_M_int16),
    .B_int32    (sig_B_int32),
    .scale_bits (sig_scale_bits),
    .valid_out  (sig_valid_out),
    .sig_out    (sig_out)
);
//-------------------------------------------------------------//

//---------------rms_norm----------------------------------------//
wire [15:0] rms_psum_out;
wire        rms_first_done;
wire        rms_valid;
wire        rms_last_done;

localparam RMS_IDLE   = 2'd0;
localparam RMS_WAIT   = 2'd1;
localparam RMS_FINISH = 2'd2;

reg [1:0] rms_state;
reg [11:0] rms_wr_base; 
reg [11:0] rms_wr_offset; 

RMS_PE rms_norm (
    .clk(clk),
    .rst(rst),
    .ifmap(ifmap_data),  
    .weight(weight_data), 
    .addr(addr),
    .se_counter_val(se_counter_val),
    .control(control_signal),
    .qat_mult(decoder_qat_mult),
    .qat_shift(decoder_qat_shift),
    .zero_point(decoder_qat_zp),
    .z_in(decoder_z_in),          // <-- ADDED THIS WIRE
    .Psum_out(rms_psum_out),
    .rms_first_done(rms_first_done),
    .rms_valid(rms_valid),
    .rms_last_done(rms_last_done)
);
//--------------------------------------------------------------//

  counter #(
      .width(12),
      .restart_behav(1)  
  ) addr_ifmap_counter (
      .clk(clk),
      .rst(rst),
      .load(load_input),  
      .start_val(pcpi_rs1[11:0]),  
      .end_val(pcpi_rs2[11:0]),  
      .enable(enable_input),  
      .count(decoder_addr_input),  
      .done(done_input)  
  );

  counter #(
      .width(16),
      .restart_behav(1)  
  ) addr_weight_counter (
      .clk(clk),
      .rst(rst),
      .load(load_weight),  
      .start_val(pcpi_rs1[15:0]),  
      .end_val(pcpi_rs2[15:0]),  
      .enable(enable_weight),  
      .count(decoder_addr_weight),  
      .done(done_weight)  
  );

  accelerator pe_array (
      .clk(clk),
      .rst(rst),
      .num_active_pes(num_active_pes),  
      .out_per_pe(out_per_pe),  
      .control_signal(control_signal),  
      .addr(addr),  
      .qat_mult(decoder_qat_mult),  
      .qat_shift(decoder_qat_shift),  
      .zero_point(decoder_qat_zp),  
      .z_in(decoder_z_in),  
      .ifmap(ifmap_data),  
      .weight(weight_data),  
      .bias({{10{bias_data[31]}}, bias_data}),  
      .M_ready(PEarray_M_ready),
      .M_valid(PEarray_M_valid),
      .M_Psum_out(PEarray_Psum_out),
      .done1(done[0]),
      .done2(done[1]),
      .done3(done[2]),
      .done4(done[3]),
      .done5(done[4]),
      .done6(done[5]),
      .done7(done[6]),
      .done8(done[7]),
      .se_counter_val(se_counter_val)
  );

wire mp_active = (mp_state != MP_IDLE);
wire sig_active = (sig_state != SIG_IDLE);

// TRUE 2D STRIDE MATH
wire [11:0] mp_addr_a_full = mp_rd_base + mp_ch_idx + (mp_pair_idx * 2 * mp_stride);
wire [11:0] mp_addr_b_full = mp_rd_base + mp_ch_idx + (mp_pair_idx * 2 * mp_stride) + mp_stride;
wire [11:0] mp_waddr_full  = mp_wr_base + mp_ch_idx + (mp_pair_idx * mp_stride);

assign ifmap_data = swap_in_pp ? decoder_pp_rdata : input_data;
assign decoder_pp_raddr = mp_active? mp_pp_raddr:sig_active ? sig_pp_raddr_r:decoder_addr_input;
assign decoder_pp_ren = mp_active? mp_pp_ren_r:sig_active ? sig_pp_ren_r:decoder_ren_input;
assign decoder_pp_swap = (pcpi_valid && instr_swap_pp && !pcpi_ready); 

always @(posedge clk) begin
    if (!resetn)
        addr <= 1023;
    else
        addr <= addr_d1;
end

always @(posedge clk) begin
    if (!resetn) begin
        pcpi_ready          <= 0;
        pcpi_wr             <= 0;
        pcpi_rd             <= 0;
        pcpi_wait           <= 0;
        addr_d1             <= 1023;
        control_signal      <= 0;
        decoder_qat_mult    <= 0;
        decoder_qat_shift   <= 0;
        decoder_qat_zp      <= 0;
        decoder_z_in        <= 0;
        num_active_pes      <= 0;
        out_per_pe          <= 1;
        decoder_ren_input   <= 0;
        decoder_ren_weight  <= 0;
        decoder_ren_bias    <= 0;
        decoder_addr_bias   <= 0;
        enable_input        <= 0;
        load_input          <= 0;
        enable_weight       <= 0;
        load_weight         <= 0;
        decoder_pp_wen      <= 0;
        decoder_pp_waddr    <= 0;
        decoder_pp_wdata    <= 0;
        mp_state            <= MP_IDLE;
        mp_ch_idx           <= 0;
        mp_pair_idx         <= 0;
        mp_pp_ren_r         <= 0;
        mp_rd_base          <= 0;
        mp_wr_base          <= 0;
        mp_pairs            <= 0;
        mp_stride           <= 0;
        mp_val_a            <= 0;
        mp_pp_raddr         <= 0;
        sig_state           <= SIG_IDLE;
        sig_pp_ren_r        <= 0;
        sig_valid_in_r      <= 0;
        sig_pp_raddr_r      <= 0;
        sig_M_int16         <= 0;
        sig_B_int32         <= 0;
        sig_scale_bits      <= 0;
        rms_wr_base         <= 0;
        rms_wr_offset       <= 0;
        rms_state           <= RMS_IDLE;
        swap_in_pp          <= 0;
        bias_pending        <= 0;
        done_ifmap_pending  <= 0;
        done_weight_pending <= 0;
        PEarray_M_ready     <= 0;
        se_counter_val      <= 0;
        illegal_instr       <= 1;
    end
    else begin

       if (pcpi_valid && instr_load_ifmap) begin
            illegal_instr           <= 0;
            if(done_input || done_ifmap_pending) begin
                // Wait for last QSPI fetch to complete before releasing CPU
                control_signal      <= 32'h0000_4000 | load_target_control | (rms_en ? 32'h0004_0000 : 32'h0);
                enable_input        <= 0;
                decoder_ren_input   <= 0;
                if (!mem_stall) begin
                    pcpi_ready          <= 1;
                    pcpi_rd             <= 0;
                    pcpi_wait           <= 0;
                    pcpi_wr             <= 0;
                    addr_d1             <= 1023;
                    done_ifmap_pending  <= 0;
                end else begin
                    pcpi_ready          <= 0;
                    pcpi_wait           <= 1;
                    done_ifmap_pending  <= 1;
                    // addr_d1 unchanged — keeps last address for correct final write
                end
            end
            else if (load_input==0 && pcpi_wait==0) begin
                load_input          <= 1; 
                pcpi_wait           <= 1; 
                control_signal      <= 0;
                addr_d1             <= 1023;
            end
            else begin
                control_signal      <= 32'h0000_4000 | load_target_control | (rms_en ? 32'h0004_0000 : 32'h0);
                pcpi_ready          <= 0;
                pcpi_wr             <= 0;
                pcpi_rd             <= 0;
                pcpi_wait           <= 1;
                load_input          <= 0;
                if (!mem_stall) begin
                    addr_d1           <= addr_d1 + 1;
                    enable_input      <= 1;
                    decoder_ren_input <= 1;
                end else begin
                    enable_input      <= 0;
                    decoder_ren_input <= 0;
                end
            end
        end
        else if (pcpi_valid && instr_load_weight) begin
            illegal_instr           <= 0;
            if(done_weight || done_weight_pending) begin
                // Wait for last QSPI fetch to complete before releasing CPU
                control_signal      <= 32'h0000_8000 | load_target_control | (rms_en ? 32'h0004_0000 : 32'h0);
                enable_weight       <= 0;
                decoder_ren_weight  <= 0;
                if (!mem_stall) begin
                    pcpi_ready           <= 1;
                    pcpi_rd              <= 0;
                    pcpi_wait            <= 0;
                    pcpi_wr              <= 0;
                    addr_d1              <= 1023;
                    done_weight_pending  <= 0;
                end else begin
                    pcpi_ready           <= 0;
                    pcpi_wait            <= 1;
                    done_weight_pending  <= 1;
                    // addr_d1 unchanged
                end
            end
            else if (load_weight==0 && pcpi_wait==0) begin
                load_weight         <= 1; 
                pcpi_wait           <= 1; 
                control_signal      <= 0;
                addr_d1             <= 1023;
            end
            else begin
                control_signal      <= 32'h0000_8000 | load_target_control | (rms_en ? 32'h0004_0000 : 32'h0);
                pcpi_ready          <= 0;
                pcpi_wr             <= 0;
                pcpi_rd             <= 0;
                pcpi_wait           <= 1;
                load_weight         <= 0;
                if (!mem_stall) begin
                    addr_d1            <= addr_d1 + 1;
                    enable_weight      <= 1;
                    decoder_ren_weight <= 1;
                end else begin
                    enable_weight      <= 0;
                    decoder_ren_weight <= 0;
                end
            end
        end
        else if (pcpi_valid && instr_load_bias) begin
            illegal_instr     <= 0;
            decoder_addr_bias <= pcpi_rs1[9:0];
            control_signal    <= 32'h2000_0000 | load_target_control;
            pcpi_wr           <= 0;
            pcpi_rd           <= 0;
            if (!bias_pending) begin
                // First cycle: trigger QSPI read
                decoder_ren_bias <= 1;
                bias_pending     <= 1;
                pcpi_ready       <= 0;
                pcpi_wait        <= 1;
            end else if (mem_stall) begin
                // Waiting for QSPI to complete
                decoder_ren_bias <= 0;
                pcpi_ready       <= 0;
                pcpi_wait        <= 1;
            end else begin
                // QSPI done, bias_data now valid
                decoder_ren_bias <= 0;
                bias_pending     <= 0;
                pcpi_ready       <= 1;
                pcpi_wait        <= 0;
            end
        end
        else if (pcpi_valid && instr_load_qat_val) begin
            illegal_instr           <= 0; 
            decoder_qat_mult        <= pcpi_rs1[31:0];
            decoder_qat_shift       <= pcpi_rs2[21:16];
            decoder_qat_zp          <= pcpi_rs2[15:0];
            pcpi_ready              <= 1;
            pcpi_rd                 <= 0;
            pcpi_wr                 <= 0;
            pcpi_wait               <= 0;
            control_signal          <= {16'h4000,4'h0,8'h00,{1'b0,funct3}}| (rms_en ? 32'h0004_0000 : 32'h0); 
        end
        else if (pcpi_valid && instr_load_z_in) begin
            illegal_instr           <= 0; 
            decoder_z_in            <= pcpi_rs1[15:0];
            pcpi_ready              <= 1;
            pcpi_rd                 <= 0;
            pcpi_wr                 <= 0;
            pcpi_wait               <= 0;
            control_signal          <= {16'h4000,4'h0,8'h00,{1'b0,funct3}}; 
        end
        else if (pcpi_valid && instr_start_conv) begin
            illegal_instr       <= 0; 
            if(done == 8'hFF || (done & ((8'b1 << num_active_pes) - 8'b1)) == ((8'b1 << num_active_pes) - 8'b1)) begin
                pcpi_ready          <= 1;
                pcpi_wait           <= 0;
                pcpi_wr             <= 0;
                pcpi_rd             <= 0;
                control_signal      <= 0;
            end
            else begin
                control_signal      <= {3'b0, 2'b00, 9'd0,pcpi_rs1[0], 1'b1, 16'h0000};
                pcpi_ready          <= 0;
                pcpi_wait           <= 1;
                pcpi_rd             <= 0;
                pcpi_wr             <= 0;
            end
        end
        else if (pcpi_valid && instr_clear) begin
            illegal_instr       <= 0; 
            control_signal      <= {16'h8000,8'h00,4'h0,{1'b0,funct3}}; 
            pcpi_ready          <= 1; 
            pcpi_rd             <= 0; 
            pcpi_wait           <= 0; 
            pcpi_wr             <= 0; 
        end
        else if (pcpi_valid && instr_num_active_pes) begin
            illegal_instr       <= 0; 
            num_active_pes      <= pcpi_rs1[3:0];
            out_per_pe          <= pcpi_rs1[13:4];
            pcpi_ready          <= 1;
            pcpi_rd             <= 0;
            pcpi_wr             <= 0;
            pcpi_wait           <= 0;
            control_signal      <= 0;
        end
        else if (pcpi_valid && instr_set_start_val) begin
            illegal_instr       <= 0; 
            control_signal      <= {16'h1000,8'h00,4'h0,{1'b0,funct3}}| (rms_en ? 32'h0004_0000 : 32'h0); 
            pcpi_ready          <= 1; 
            pcpi_rd             <= 0; 
            pcpi_wait           <= 0; 
            pcpi_wr             <= 0; 
            se_counter_val        <= pcpi_rs1[9:0]; 
        end
        else if (pcpi_valid && instr_set_end_val) begin
            illegal_instr       <= 0; 
            control_signal      <= {16'h0800,8'h00,4'h0,{1'b0,funct3}}| (rms_en ? 32'h0004_0000 : 32'h0); 
            pcpi_ready          <= 1; 
            pcpi_rd             <= 0; 
            pcpi_wait           <= 0; 
            pcpi_wr             <= 0; 
            se_counter_val        <= pcpi_rs1[9:0]; 
        end
        else if (pcpi_valid && instr_load_iw_counter) begin
            illegal_instr       <= 0;
            control_signal      <= {16'h0000, 4'h1, 8'h00, {1'b0,funct3}}| (rms_en ? 32'h0004_0000 : 32'h0);
            pcpi_ready          <= 1; 
            pcpi_rd             <= 0; 
            pcpi_wait           <= 0; 
            pcpi_wr             <= 0;
        end
        else if (pcpi_valid && instr_set_pe_on_off) begin
            illegal_instr       <= 1; 
        end
        else if (pcpi_valid && instr_read_status) begin
            illegal_instr       <= 1; 
        end
        else if (pcpi_valid && instr_read_result) begin
            illegal_instr       <= 0; 
            if (!PEarray_M_valid) begin
                PEarray_M_ready <= 0;
                decoder_pp_wen <=  0;
                pcpi_wait      <=  1;
                pcpi_ready     <=  0;
                pcpi_rd        <=  0;
                pcpi_wr         <= 0; 
            end
            else begin
                PEarray_M_ready <= !pcpi_ready;
                decoder_pp_wen <=  1;
                pcpi_wait      <=  0;
                pcpi_ready     <=  1;
                decoder_pp_waddr <= pcpi_rs1[11:0];
                pcpi_rd        <=  {16'h0000,PEarray_Psum_out};
                pcpi_wr        <=   1;
                decoder_pp_wdata <= PEarray_Psum_out;
            end
        end 
        else if (pcpi_valid && instr_swap_pp) begin
            illegal_instr       <= 0;
            swap_in_pp          <= pcpi_rs1[0];
            pcpi_ready          <= 1;
            pcpi_wait           <= 0;
            pcpi_rd             <= 0;
            pcpi_wr             <= 0;
            control_signal      <= 0;
        end
        else if (pcpi_valid && instr_maxpooling) begin
            illegal_instr <= 0;
            case (mp_state)
            MP_IDLE : begin
                mp_rd_base  <= pcpi_rs1[11:0];
                mp_stride   <= pcpi_rs1[23:12]; // Read from upper 12 bits
                mp_wr_base  <= pcpi_rs2[11:0];
                mp_pairs    <= pcpi_rs2[23:12];
                mp_ch_idx   <= 0;
                mp_pair_idx <= 0;
                mp_pp_ren_r <= 0;
                pcpi_ready  <= 0;
                pcpi_rd     <= 0;
                pcpi_wr     <= 0;
                pcpi_wait   <= 1;
                mp_state    <= MP_READ_A;
            end
            MP_READ_A : begin
               mp_pp_raddr <= mp_addr_a_full; 
               mp_pp_ren_r <= 1;
               mp_state    <= MP_WAIT_A;
            end
            MP_WAIT_A : begin
               mp_pp_raddr <= mp_addr_b_full; 
               mp_pp_ren_r <= 1;
               mp_state    <= MP_WAIT_B;
            end
            MP_WAIT_B : begin
                mp_val_a            <= decoder_pp_rdata; 
                mp_pp_ren_r         <= 0;
                mp_state            <= MP_WRITE;
            end
            MP_WRITE : begin
                decoder_pp_wen      <= 1;
                decoder_pp_waddr    <= mp_waddr_full; 
                decoder_pp_wdata    <= mp_max_out; 
                mp_state            <= MP_DONE_WRITE; 
            end
            MP_DONE_WRITE : begin
                decoder_pp_wen <= 0;
                if (mp_ch_idx + 1 >= mp_stride) begin
                    mp_ch_idx <= 0;
                    if (mp_pair_idx + 1 >= mp_pairs) begin
                        mp_state <= MP_DONE;
                    end else begin
                        mp_pair_idx <= mp_pair_idx + 1;
                        mp_state    <= MP_READ_A;
                    end
                end else begin
                    mp_ch_idx <= mp_ch_idx + 1;
                    mp_state  <= MP_READ_A;
                end
            end
            MP_DONE : begin
                pcpi_ready  <= 1;
                pcpi_wait   <= 0;
                pcpi_rd     <= 0;
                pcpi_wr     <= 0;
                mp_state    <= MP_DONE; // Hold until global else catches it
            end
            default : begin
                mp_state    <= MP_IDLE;
            end
            endcase
        end
        else if(pcpi_valid && instr_sigmoid) begin
            illegal_instr <= 0;
            case(sig_state)
            SIG_IDLE : begin
                sig_M_int16     <= pcpi_rs1[15:0];
                sig_scale_bits  <= pcpi_rs1[19:16];
                sig_B_int32     <= pcpi_rs2[31:0];
                sig_pp_raddr_r  <= pcpi_rs1[31:20];
                sig_pp_ren_r    <= 1;
                sig_valid_in_r  <= 0;
                pcpi_ready      <= 0;
                pcpi_rd         <= 0;
                pcpi_wr         <= 0;
                pcpi_wait       <= 1;
                sig_state       <= SIG_READ;
            end
            SIG_READ : begin
                sig_pp_ren_r   <= 1;
                sig_valid_in_r <= 0;
                sig_state      <= SIG_WAIT;
            end
            SIG_WAIT : begin
                sig_pp_ren_r    <= 0;
                sig_valid_in_r  <= 1;
                sig_state       <= SIG_PIPE;
            end
            SIG_PIPE : begin
                sig_valid_in_r <= 0;
                if(sig_valid_out) begin
                    sig_state <= SIG_DONE;
                end
            end
            SIG_DONE : begin
                pcpi_ready  <= 1;
                pcpi_wait   <= 0;
                pcpi_rd     <= {16'h0000,sig_out};
                pcpi_wr     <= 1;
                sig_state   <= SIG_DONE; // Hold until global else catches it
            end
            default : begin
                sig_state   <= SIG_IDLE;
            end
            endcase
        end
        else if(pcpi_valid && instr_start_rms) begin
            illegal_instr <= 0;
            case(rms_state)
                RMS_IDLE : begin
                    control_signal <= (1<<18)| (1<<12)|({30'd0,pcpi_rs2[1:0]}<<19);
                    rms_wr_base    <= pcpi_rs1[11:0]; 
                    rms_wr_offset  <= 0;
                    rms_state      <= RMS_WAIT;
                    pcpi_ready     <= 0;
                    pcpi_wait      <= 1;
                    pcpi_rd        <= 0;
                    pcpi_wr        <= 0;
                end
                RMS_WAIT : begin
                    control_signal <= (1<<18) | ({30'd0,pcpi_rs2[1:0]}<<19);
                    if (rms_valid) begin
                        decoder_pp_wen   <= 1;
                        decoder_pp_waddr <= rms_wr_base + rms_wr_offset;
                        decoder_pp_wdata <= rms_psum_out;
                        rms_wr_offset    <= rms_wr_offset + 1;
                    end 
                    else begin
                        decoder_pp_wen <= 0;
                    end
                    if(rms_last_done) begin
                        rms_state <= RMS_FINISH;
                    end
                end
                RMS_FINISH: begin
                    decoder_pp_wen <= 0;
                    pcpi_ready     <= 1;
                    pcpi_wait      <= 0;
                    pcpi_rd        <= 0;
                    pcpi_wr        <= 0;
                    rms_state      <= RMS_FINISH; // Hold until global else catches it
                end
                default : begin
                    rms_state      <= RMS_IDLE;
                end
            endcase
        end
        else begin
            // GLOBAL ELSE: Safely handles unknown instructions AND valid drops!
            illegal_instr       <= 1; 
            pcpi_ready          <= 0;
            pcpi_wr             <= 0;
            pcpi_rd             <= 0;
            pcpi_wait           <= 0;
            control_signal      <= 0;
            addr_d1             <= 1023;
            decoder_ren_input   <= 0;
            decoder_ren_weight  <= 0;
            decoder_ren_bias    <= 0;
            decoder_pp_wen      <= 0;
            decoder_pp_waddr    <= 0;
            decoder_pp_wdata    <= 0;
            enable_input        <= 0;
            load_input          <= 0;
            enable_weight       <= 0;
            load_weight         <= 0;
            PEarray_M_ready     <= 0;
            
            // FSM RESETS: These cleanly release the blocks when pcpi_valid goes to 0
            mp_state            <= MP_IDLE;
            sig_state           <= SIG_IDLE;
            rms_state           <= RMS_IDLE;
            bias_pending        <= 0;
            done_ifmap_pending  <= 0;
            done_weight_pending <= 0;
        end
    end
end

endmodule
