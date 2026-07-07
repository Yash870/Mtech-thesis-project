// FE Release Version: 2.4.24 
//
//       CONFIDENTIAL AND PROPRIETARY SOFTWARE OF ARM PHYSICAL IP, INC.
//      
//       Copyright (c) 1993 - 2026 ARM Physical IP, Inc.  All Rights Reserved.
//      
//       Use of this Software is subject to the terms and conditions of the
//       applicable license agreement with ARM Physical IP, Inc.
//       In addition, this Software is protected by patents, copyright law 
//       and international treaties.
//      
//       The copyright notice(s) in this Software does not indicate actual or
//       intended publication of this Software.
//
//      Verilog model for Synchronous Dual-Port Ram
//
//      Instance Name:              pe_spad_1024x16_dp
//      Words:                      1024
//      Bits:                       16
//      Mux:                        16
//      Drive:                      6
//      Write Mask:                 Off
//      Extra Margin Adjustment:    On
//      Accelerated Retention Test: Off
//      Redundant Rows:             0
//      Redundant Columns:          0
//      Test Muxes                  Off
//
//      Creation Date:  Sat May  9 16:14:28 2026
//      Version: 	r0p1-00eac0
//
//      Modeling Assumptions: This model supports full gate level simulation
//          including proper x-handling and timing check behavior.  Unit
//          delay timing is included in the model. Back-annotation of SDF
//          (v2.1) is supported.  SDF can be created utilyzing the delay
//          calculation views provided with this generator and supported
//          delay calculators.  All buses are modeled [MSB:LSB].  All 
//          ports are padded with Verilog primitives.
//
//      Modeling Limitations: None.
//
//      Known Bugs: None.
//
//      Known Work Arounds: N/A
//
`ifdef ARM_UD_MODEL

`timescale 1 ns/1 ps

`ifdef ARM_UD_DP
`else
`define ARM_UD_DP #0.001
`endif
`ifdef ARM_UD_CP
`else
`define ARM_UD_CP
`endif
`ifdef ARM_UD_SEQ
`else
`define ARM_UD_SEQ #0.01
`endif
`ifdef ARM_UD_CC
`else
`define ARM_UD_CC 0.1
`endif

`celldefine
`ifdef POWER_PINS
module pe_spad_1024x16_dp (QA, QB, CLKA, CENA, WENA, AA, DA, CLKB, CENB, WENB, AB,
    DB, EMAA, EMAB, RETN, VSSE, VDDPE, VDDCE);
`else
module pe_spad_1024x16_dp (QA, QB, CLKA, CENA, WENA, AA, DA, CLKB, CENB, WENB, AB,
    DB, EMAA, EMAB, RETN);
`endif

  parameter BITS = 16;
  parameter WORDS = 1024;
  parameter MUX = 16;
  parameter MEM_WIDTH = 256; // redun block size 4, 128 on left, 128 on right
  parameter MEM_HEIGHT = 64;
  parameter WP_SIZE = 16 ;
  parameter UPM_WIDTH = 3;

  output [15:0] QA;
  output [15:0] QB;
  input  CLKA;
  input  CENA;
  input  WENA;
  input [9:0] AA;
  input [15:0] DA;
  input  CLKB;
  input  CENB;
  input  WENB;
  input [9:0] AB;
  input [15:0] DB;
  input [2:0] EMAA;
  input [2:0] EMAB;
  input  RETN;
`ifdef POWER_PINS
  inout VSSE;
  inout VDDPE;
  inout VDDCE;
`endif

  integer row_address;
  integer mux_address;
  reg [255:0] mem [0:63];
  reg [255:0] row;
  reg LAST_CLKA;
  reg [255:0] data_out;
  reg [255:0] row_mask;
  reg [255:0] new_data;
  reg LAST_CLKB;
  reg [15:0] QA_int;
  reg [15:0] QB_int;
  reg [15:0] writeEnable;
  real previous_CLKA;
  real previous_CLKB;
  initial previous_CLKA = 0;
  initial previous_CLKB = 0;
  reg clk0_int;
  reg clk1_int;
  reg CRENA_legal;
  initial CRENA_legal = 1'b1;
  reg CRENB_legal;
  initial CRENB_legal = 1'b1;

  wire [15:0] QA_;
  wire [15:0] QB_;
 wire  CLKA_;
  wire  CENA_;
  reg  CENA_int;
  wire  WENA_;
  reg  WENA_int;
  wire [9:0] AA_;
  reg [9:0] AA_int;
  wire [15:0] DA_;
  reg [15:0] DA_int;
 wire  CLKB_;
  wire  CENB_;
  reg  CENB_int;
  wire  WENB_;
  reg  WENB_int;
  wire [9:0] AB_;
  reg [9:0] AB_int;
  wire [15:0] DB_;
  reg [15:0] DB_int;
  wire [2:0] EMAA_;
  reg [2:0] EMAA_int;
  wire [2:0] EMAB_;
  reg [2:0] EMAB_int;
  wire  RETN_;
  reg  RETN_int;

  assign QA[0] = QA_[0]; 
  assign QA[1] = QA_[1]; 
  assign QA[2] = QA_[2]; 
  assign QA[3] = QA_[3]; 
  assign QA[4] = QA_[4]; 
  assign QA[5] = QA_[5]; 
  assign QA[6] = QA_[6]; 
  assign QA[7] = QA_[7]; 
  assign QA[8] = QA_[8]; 
  assign QA[9] = QA_[9]; 
  assign QA[10] = QA_[10]; 
  assign QA[11] = QA_[11]; 
  assign QA[12] = QA_[12]; 
  assign QA[13] = QA_[13]; 
  assign QA[14] = QA_[14]; 
  assign QA[15] = QA_[15]; 
  assign QB[0] = QB_[0]; 
  assign QB[1] = QB_[1]; 
  assign QB[2] = QB_[2]; 
  assign QB[3] = QB_[3]; 
  assign QB[4] = QB_[4]; 
  assign QB[5] = QB_[5]; 
  assign QB[6] = QB_[6]; 
  assign QB[7] = QB_[7]; 
  assign QB[8] = QB_[8]; 
  assign QB[9] = QB_[9]; 
  assign QB[10] = QB_[10]; 
  assign QB[11] = QB_[11]; 
  assign QB[12] = QB_[12]; 
  assign QB[13] = QB_[13]; 
  assign QB[14] = QB_[14]; 
  assign QB[15] = QB_[15]; 
  assign CLKA_ = CLKA;
  assign CENA_ = CENA;
  assign WENA_ = WENA;
  assign AA_[0] = AA[0];
  assign AA_[1] = AA[1];
  assign AA_[2] = AA[2];
  assign AA_[3] = AA[3];
  assign AA_[4] = AA[4];
  assign AA_[5] = AA[5];
  assign AA_[6] = AA[6];
  assign AA_[7] = AA[7];
  assign AA_[8] = AA[8];
  assign AA_[9] = AA[9];
  assign DA_[0] = DA[0];
  assign DA_[1] = DA[1];
  assign DA_[2] = DA[2];
  assign DA_[3] = DA[3];
  assign DA_[4] = DA[4];
  assign DA_[5] = DA[5];
  assign DA_[6] = DA[6];
  assign DA_[7] = DA[7];
  assign DA_[8] = DA[8];
  assign DA_[9] = DA[9];
  assign DA_[10] = DA[10];
  assign DA_[11] = DA[11];
  assign DA_[12] = DA[12];
  assign DA_[13] = DA[13];
  assign DA_[14] = DA[14];
  assign DA_[15] = DA[15];
  assign CLKB_ = CLKB;
  assign CENB_ = CENB;
  assign WENB_ = WENB;
  assign AB_[0] = AB[0];
  assign AB_[1] = AB[1];
  assign AB_[2] = AB[2];
  assign AB_[3] = AB[3];
  assign AB_[4] = AB[4];
  assign AB_[5] = AB[5];
  assign AB_[6] = AB[6];
  assign AB_[7] = AB[7];
  assign AB_[8] = AB[8];
  assign AB_[9] = AB[9];
  assign DB_[0] = DB[0];
  assign DB_[1] = DB[1];
  assign DB_[2] = DB[2];
  assign DB_[3] = DB[3];
  assign DB_[4] = DB[4];
  assign DB_[5] = DB[5];
  assign DB_[6] = DB[6];
  assign DB_[7] = DB[7];
  assign DB_[8] = DB[8];
  assign DB_[9] = DB[9];
  assign DB_[10] = DB[10];
  assign DB_[11] = DB[11];
  assign DB_[12] = DB[12];
  assign DB_[13] = DB[13];
  assign DB_[14] = DB[14];
  assign DB_[15] = DB[15];
  assign EMAA_[0] = EMAA[0];
  assign EMAA_[1] = EMAA[1];
  assign EMAA_[2] = EMAA[2];
  assign EMAB_[0] = EMAB[0];
  assign EMAB_[1] = EMAB[1];
  assign EMAB_[2] = EMAB[2];
  assign RETN_ = RETN;

  assign `ARM_UD_SEQ QA_ = RETN_ ? (QA_int) : {16{1'b0}};
  assign `ARM_UD_SEQ QB_ = RETN_ ? (QB_int) : {16{1'b0}};

`ifdef INITIALIZE_MEMORY
  integer i;
  initial
    for (i = 0; i < MEM_HEIGHT; i = i + 1)
      mem[i] = {MEM_WIDTH{1'b0}};
`endif

  task failedWrite;
  input port;
  integer i;
  begin
    for (i = 0; i < MEM_HEIGHT; i = i + 1)
      mem[i] = {MEM_WIDTH{1'bx}};
  end
  endtask

  function isBitX;
    input bitIn;
    begin
      isBitX = ( bitIn===1'bx || bitIn===1'bz ) ? 1'b1 : 1'b0;
    end
  endfunction


  task readWriteA;
  begin
    if (RETN_int === 1'bx) begin
      failedWrite(0);
      QA_int = {16{1'bx}};
    end else if (RETN_int === 1'b0 && CENA_int === 1'b0) begin
      failedWrite(0);
      QA_int = {16{1'bx}};
    end else if (RETN_int === 1'b0) begin
      // no cycle in retention mode
    end else if (^{CENA_int, EMAA_int} === 1'bx) begin
      failedWrite(0);
      QA_int = {16{1'bx}};
    end else if ((AA_int >= WORDS) && (CENA_int === 1'b0)) begin
      writeEnable = ~{16{WENA_int}};
      QA_int = ((writeEnable & DA_int) | (~writeEnable & {16{1'bx}}));
    end else if (CENA_int === 1'b0 && (^AA_int) === 1'bx) begin
      if (WENA_int !== 1'b1) failedWrite(0);
      QA_int = {16{1'bx}};
    end else if (CENA_int === 1'b0) begin
      mux_address = (AA_int & 4'b1111);
      row_address = (AA_int >> 4);
      if (row_address >= 64)
        row = {256{1'bx}};
      else
        row = mem[row_address];
      writeEnable = ~{16{WENA_int}};
      row_mask =  ( {15'b000000000000000, writeEnable[15], 15'b000000000000000, writeEnable[14],
          15'b000000000000000, writeEnable[13], 15'b000000000000000, writeEnable[12],
          15'b000000000000000, writeEnable[11], 15'b000000000000000, writeEnable[10],
          15'b000000000000000, writeEnable[9], 15'b000000000000000, writeEnable[8],
          15'b000000000000000, writeEnable[7], 15'b000000000000000, writeEnable[6],
          15'b000000000000000, writeEnable[5], 15'b000000000000000, writeEnable[4],
          15'b000000000000000, writeEnable[3], 15'b000000000000000, writeEnable[2],
          15'b000000000000000, writeEnable[1], 15'b000000000000000, writeEnable[0]} << mux_address);
      new_data =  ( {15'b000000000000000, DA_int[15], 15'b000000000000000, DA_int[14],
          15'b000000000000000, DA_int[13], 15'b000000000000000, DA_int[12], 15'b000000000000000, DA_int[11],
          15'b000000000000000, DA_int[10], 15'b000000000000000, DA_int[9], 15'b000000000000000, DA_int[8],
          15'b000000000000000, DA_int[7], 15'b000000000000000, DA_int[6], 15'b000000000000000, DA_int[5],
          15'b000000000000000, DA_int[4], 15'b000000000000000, DA_int[3], 15'b000000000000000, DA_int[2],
          15'b000000000000000, DA_int[1], 15'b000000000000000, DA_int[0]} << mux_address);
      row = (row & ~row_mask) | (row_mask & (~row_mask | new_data));
      mem[row_address] = row;
      data_out = (row >> mux_address);
      QA_int = {data_out[240], data_out[224], data_out[208], data_out[192], data_out[176],
        data_out[160], data_out[144], data_out[128], data_out[112], data_out[96], data_out[80],
        data_out[64], data_out[48], data_out[32], data_out[16], data_out[0]};
    end
  end
  endtask

  always @ RETN_ begin
    if (RETN_ == 1'b0) begin
      QA_int = {16{1'b0}};
      CENA_int = 1'b0;
      WENA_int = 1'b0;
      AA_int = {10{1'b0}};
      DA_int = {16{1'b0}};
      EMAA_int = {3{1'b0}};
      RETN_int = 1'b0;
    end else begin
      QA_int = {16{1'bx}};
      CENA_int = 1'bx;
      WENA_int = 1'bx;
      AA_int = {10{1'bx}};
      DA_int = {16{1'bx}};
      EMAA_int = {3{1'bx}};
      RETN_int = 1'bx;
    end
    RETN_int = RETN_;
  end

  always @ CLKA_ begin
`ifdef POWER_PINS
    if (VSSE === 1'bx || VSSE === 1'bz)
      $display("ERROR: Illegal value for VSSE %b", VSSE);
    if (VDDPE === 1'bx || VDDPE === 1'bz)
      $display("ERROR: Illegal value for VDDPE %b", VDDPE);
    if (VDDCE === 1'bx || VDDCE === 1'bz)
      $display("ERROR: Illegal value for VDDCE %b", VDDCE);
`endif
    if (CLKA_ === 1'bx && (CENA_ !== 1'b1)) begin
      failedWrite(0);
      QA_int = {16{1'bx}};
    end else if (CLKA_ === 1'b1 && LAST_CLKA === 1'b0) begin
      CENA_int = CENA_;
      WENA_int = WENA_;
      AA_int = AA_;
      DA_int = DA_;
      EMAA_int = EMAA_;
      RETN_int = RETN_;
      clk0_int = 1'b0;
      previous_CLKA = $realtime;
      readWriteA;
      if (previous_CLKA == previous_CLKB && is_contention(AA_int, AB_int, WENA_int,
        WENB_int) && (CENA_int !== 1'b1 && CENB_int !== 1'b1)) begin
        if (WENA_int !== 1'b1 && WENB_int !== 1'b1) begin
          DA_int = {16{1'bx}};
          readWriteA;
          DB_int = {16{1'bx}};
          readWriteB;
        end else if (WENA_int !== 1'b1) begin
          QB_int = {16{1'bx}};
        end else if (WENB_int !== 1'b1) begin
          QA_int = {16{1'bx}};
        end else begin
        end
      end
    end
    LAST_CLKA = CLKA_;
  end

  task readWriteB;
  begin
    if (RETN_int === 1'bx) begin
      failedWrite(1);
      QB_int = {16{1'bx}};
    end else if (RETN_int === 1'b0 && CENB_int === 1'b0) begin
      failedWrite(1);
      QB_int = {16{1'bx}};
    end else if (RETN_int === 1'b0) begin
      // no cycle in retention mode
    end else if (^{CENB_int, EMAB_int} === 1'bx) begin
      failedWrite(1);
      QB_int = {16{1'bx}};
    end else if ((AB_int >= WORDS) && (CENB_int === 1'b0)) begin
      writeEnable = ~{16{WENB_int}};
      QB_int = ((writeEnable & DB_int) | (~writeEnable & {16{1'bx}}));
    end else if (CENB_int === 1'b0 && (^AB_int) === 1'bx) begin
      if (WENB_int !== 1'b1) failedWrite(1);
      QB_int = {16{1'bx}};
    end else if (CENB_int === 1'b0) begin
      mux_address = (AB_int & 4'b1111);
      row_address = (AB_int >> 4);
      if (row_address >= 64)
        row = {256{1'bx}};
      else
        row = mem[row_address];
      writeEnable = ~{16{WENB_int}};
      row_mask =  ( {15'b000000000000000, writeEnable[15], 15'b000000000000000, writeEnable[14],
          15'b000000000000000, writeEnable[13], 15'b000000000000000, writeEnable[12],
          15'b000000000000000, writeEnable[11], 15'b000000000000000, writeEnable[10],
          15'b000000000000000, writeEnable[9], 15'b000000000000000, writeEnable[8],
          15'b000000000000000, writeEnable[7], 15'b000000000000000, writeEnable[6],
          15'b000000000000000, writeEnable[5], 15'b000000000000000, writeEnable[4],
          15'b000000000000000, writeEnable[3], 15'b000000000000000, writeEnable[2],
          15'b000000000000000, writeEnable[1], 15'b000000000000000, writeEnable[0]} << mux_address);
      new_data =  ( {15'b000000000000000, DB_int[15], 15'b000000000000000, DB_int[14],
          15'b000000000000000, DB_int[13], 15'b000000000000000, DB_int[12], 15'b000000000000000, DB_int[11],
          15'b000000000000000, DB_int[10], 15'b000000000000000, DB_int[9], 15'b000000000000000, DB_int[8],
          15'b000000000000000, DB_int[7], 15'b000000000000000, DB_int[6], 15'b000000000000000, DB_int[5],
          15'b000000000000000, DB_int[4], 15'b000000000000000, DB_int[3], 15'b000000000000000, DB_int[2],
          15'b000000000000000, DB_int[1], 15'b000000000000000, DB_int[0]} << mux_address);
      row = (row & ~row_mask) | (row_mask & (~row_mask | new_data));
      mem[row_address] = row;
      data_out = (row >> mux_address);
      QB_int = {data_out[240], data_out[224], data_out[208], data_out[192], data_out[176],
        data_out[160], data_out[144], data_out[128], data_out[112], data_out[96], data_out[80],
        data_out[64], data_out[48], data_out[32], data_out[16], data_out[0]};
    end
  end
  endtask

  always @ RETN_ begin
    if (RETN_ == 1'b0) begin
      QB_int = {16{1'b0}};
      CENB_int = 1'b0;
      WENB_int = 1'b0;
      AB_int = {10{1'b0}};
      DB_int = {16{1'b0}};
      EMAB_int = {3{1'b0}};
      RETN_int = 1'b0;
    end else begin
      QB_int = {16{1'bx}};
      CENB_int = 1'bx;
      WENB_int = 1'bx;
      AB_int = {10{1'bx}};
      DB_int = {16{1'bx}};
      EMAB_int = {3{1'bx}};
      RETN_int = 1'bx;
    end
    RETN_int = RETN_;
  end

  always @ CLKB_ begin
`ifdef POWER_PINS
    if (VSSE === 1'bx || VSSE === 1'bz)
      $display("ERROR: Illegal value for VSSE %b", VSSE);
    if (VDDPE === 1'bx || VDDPE === 1'bz)
      $display("ERROR: Illegal value for VDDPE %b", VDDPE);
    if (VDDCE === 1'bx || VDDCE === 1'bz)
      $display("ERROR: Illegal value for VDDCE %b", VDDCE);
`endif
    if (CLKB_ === 1'bx && (CENB_ !== 1'b1)) begin
      failedWrite(1);
      QB_int = {16{1'bx}};
    end else if (CLKB_ === 1'b1 && LAST_CLKB === 1'b0) begin
      CENB_int = CENB_;
      WENB_int = WENB_;
      AB_int = AB_;
      DB_int = DB_;
      EMAB_int = EMAB_;
      RETN_int = RETN_;
      clk1_int = 1'b0;
      previous_CLKB = $realtime;
      readWriteB;
      if (previous_CLKA == previous_CLKB && is_contention(AA_int, AB_int, WENA_int,
        WENB_int) && (CENB_int !== 1'b1 && CENA_int !== 1'b1)) begin
        if (WENA_int !== 1'b1 && WENB_int !== 1'b1) begin
          DA_int = {16{1'bx}};
          readWriteA;
          DB_int = {16{1'bx}};
          readWriteB;
        end else if (WENA_int !== 1'b1) begin
          QB_int = {16{1'bx}};
        end else if (WENB_int !== 1'b1) begin
          QA_int = {16{1'bx}};
        end else begin
        end
      end
    end
    LAST_CLKB = CLKB_;
  end


  function is_contention;
    input [9:0] aa;
    input [9:0] ab;
    input  wena;
    input  wenb;
    reg result;
  begin
    if ((& wena) === 1'b1 && (& wenb) === 1'b1) begin
      result = 1'b0;
    end else if (aa == ab) begin
      result = 1'b1;
    end else begin
      result = 1'b0;
    end
    is_contention = result;
  end
  endfunction


endmodule
`endcelldefine
`else
`timescale 1 ns/1 ps
`celldefine
`ifdef POWER_PINS
module pe_spad_1024x16_dp (QA, QB, CLKA, CENA, WENA, AA, DA, CLKB, CENB, WENB, AB,
    DB, EMAA, EMAB, RETN, VSSE, VDDPE, VDDCE);
`else
module pe_spad_1024x16_dp (QA, QB, CLKA, CENA, WENA, AA, DA, CLKB, CENB, WENB, AB,
    DB, EMAA, EMAB, RETN);
`endif

  parameter BITS = 16;
  parameter WORDS = 1024;
  parameter MUX = 16;
  parameter MEM_WIDTH = 256; // redun block size 4, 128 on left, 128 on right
  parameter MEM_HEIGHT = 64;
  parameter WP_SIZE = 16 ;
  parameter UPM_WIDTH = 3;

  output [15:0] QA;
  output [15:0] QB;
  input  CLKA;
  input  CENA;
  input  WENA;
  input [9:0] AA;
  input [15:0] DA;
  input  CLKB;
  input  CENB;
  input  WENB;
  input [9:0] AB;
  input [15:0] DB;
  input [2:0] EMAA;
  input [2:0] EMAB;
  input  RETN;
`ifdef POWER_PINS
  inout VSSE;
  inout VDDPE;
  inout VDDCE;
`endif

  integer row_address;
  integer mux_address;
  reg [255:0] mem [0:63];
  reg [255:0] row;
  reg LAST_CLKA;
  reg [255:0] data_out;
  reg [255:0] row_mask;
  reg [255:0] new_data;
  reg LAST_CLKB;
  reg [15:0] QA_int;
  reg [15:0] QB_int;
  reg [15:0] writeEnable;
  real previous_CLKA;
  real previous_CLKB;
  initial previous_CLKA = 0;
  initial previous_CLKB = 0;
  reg  cont_flag0_int;
  reg  cont_flag1_int;
  initial cont_flag0_int = 1'b0;
  initial cont_flag1_int = 1'b0;

  reg NOT_AA0, NOT_AA1, NOT_AA2, NOT_AA3, NOT_AA4, NOT_AA5, NOT_AA6, NOT_AA7, NOT_AA8;
  reg NOT_AA9, NOT_AB0, NOT_AB1, NOT_AB2, NOT_AB3, NOT_AB4, NOT_AB5, NOT_AB6, NOT_AB7;
  reg NOT_AB8, NOT_AB9, NOT_CENA, NOT_CENB, NOT_CLKA_MINH, NOT_CLKA_MINL, NOT_CLKA_PER;
  reg NOT_CLKB_MINH, NOT_CLKB_MINL, NOT_CLKB_PER, NOT_CONTA, NOT_CONTB, NOT_DA0, NOT_DA1;
  reg NOT_DA10, NOT_DA11, NOT_DA12, NOT_DA13, NOT_DA14, NOT_DA15, NOT_DA2, NOT_DA3;
  reg NOT_DA4, NOT_DA5, NOT_DA6, NOT_DA7, NOT_DA8, NOT_DA9, NOT_DB0, NOT_DB1, NOT_DB10;
  reg NOT_DB11, NOT_DB12, NOT_DB13, NOT_DB14, NOT_DB15, NOT_DB2, NOT_DB3, NOT_DB4;
  reg NOT_DB5, NOT_DB6, NOT_DB7, NOT_DB8, NOT_DB9, NOT_EMAA0, NOT_EMAA1, NOT_EMAA2;
  reg NOT_EMAB0, NOT_EMAB1, NOT_EMAB2, NOT_RETN, NOT_RETNA, NOT_RETNB, NOT_WENA, NOT_WENB;
  reg clk0_int;
  reg clk1_int;
  reg CRENA_legal;
  initial CRENA_legal = 1'b1;
  reg CRENB_legal;
  initial CRENB_legal = 1'b1;

  wire [15:0] QA_;
  wire [15:0] QB_;
 wire  CLKA_;
  wire  CENA_;
  reg  CENA_int;
  wire  WENA_;
  reg  WENA_int;
  wire [9:0] AA_;
  reg [9:0] AA_int;
  wire [15:0] DA_;
  reg [15:0] DA_int;
 wire  CLKB_;
  wire  CENB_;
  reg  CENB_int;
  wire  WENB_;
  reg  WENB_int;
  wire [9:0] AB_;
  reg [9:0] AB_int;
  wire [15:0] DB_;
  reg [15:0] DB_int;
  wire [2:0] EMAA_;
  reg [2:0] EMAA_int;
  wire [2:0] EMAB_;
  reg [2:0] EMAB_int;
  wire  RETN_;
  reg  RETN_int;

  buf B0(QA[0], QA_[0]);
  buf B1(QA[1], QA_[1]);
  buf B2(QA[2], QA_[2]);
  buf B3(QA[3], QA_[3]);
  buf B4(QA[4], QA_[4]);
  buf B5(QA[5], QA_[5]);
  buf B6(QA[6], QA_[6]);
  buf B7(QA[7], QA_[7]);
  buf B8(QA[8], QA_[8]);
  buf B9(QA[9], QA_[9]);
  buf B10(QA[10], QA_[10]);
  buf B11(QA[11], QA_[11]);
  buf B12(QA[12], QA_[12]);
  buf B13(QA[13], QA_[13]);
  buf B14(QA[14], QA_[14]);
  buf B15(QA[15], QA_[15]);
  buf B16(QB[0], QB_[0]);
  buf B17(QB[1], QB_[1]);
  buf B18(QB[2], QB_[2]);
  buf B19(QB[3], QB_[3]);
  buf B20(QB[4], QB_[4]);
  buf B21(QB[5], QB_[5]);
  buf B22(QB[6], QB_[6]);
  buf B23(QB[7], QB_[7]);
  buf B24(QB[8], QB_[8]);
  buf B25(QB[9], QB_[9]);
  buf B26(QB[10], QB_[10]);
  buf B27(QB[11], QB_[11]);
  buf B28(QB[12], QB_[12]);
  buf B29(QB[13], QB_[13]);
  buf B30(QB[14], QB_[14]);
  buf B31(QB[15], QB_[15]);
  buf B32(CLKA_, CLKA);
  buf B33(CENA_, CENA);
  buf B34(WENA_, WENA);
  buf B35(AA_[0], AA[0]);
  buf B36(AA_[1], AA[1]);
  buf B37(AA_[2], AA[2]);
  buf B38(AA_[3], AA[3]);
  buf B39(AA_[4], AA[4]);
  buf B40(AA_[5], AA[5]);
  buf B41(AA_[6], AA[6]);
  buf B42(AA_[7], AA[7]);
  buf B43(AA_[8], AA[8]);
  buf B44(AA_[9], AA[9]);
  buf B45(DA_[0], DA[0]);
  buf B46(DA_[1], DA[1]);
  buf B47(DA_[2], DA[2]);
  buf B48(DA_[3], DA[3]);
  buf B49(DA_[4], DA[4]);
  buf B50(DA_[5], DA[5]);
  buf B51(DA_[6], DA[6]);
  buf B52(DA_[7], DA[7]);
  buf B53(DA_[8], DA[8]);
  buf B54(DA_[9], DA[9]);
  buf B55(DA_[10], DA[10]);
  buf B56(DA_[11], DA[11]);
  buf B57(DA_[12], DA[12]);
  buf B58(DA_[13], DA[13]);
  buf B59(DA_[14], DA[14]);
  buf B60(DA_[15], DA[15]);
  buf B61(CLKB_, CLKB);
  buf B62(CENB_, CENB);
  buf B63(WENB_, WENB);
  buf B64(AB_[0], AB[0]);
  buf B65(AB_[1], AB[1]);
  buf B66(AB_[2], AB[2]);
  buf B67(AB_[3], AB[3]);
  buf B68(AB_[4], AB[4]);
  buf B69(AB_[5], AB[5]);
  buf B70(AB_[6], AB[6]);
  buf B71(AB_[7], AB[7]);
  buf B72(AB_[8], AB[8]);
  buf B73(AB_[9], AB[9]);
  buf B74(DB_[0], DB[0]);
  buf B75(DB_[1], DB[1]);
  buf B76(DB_[2], DB[2]);
  buf B77(DB_[3], DB[3]);
  buf B78(DB_[4], DB[4]);
  buf B79(DB_[5], DB[5]);
  buf B80(DB_[6], DB[6]);
  buf B81(DB_[7], DB[7]);
  buf B82(DB_[8], DB[8]);
  buf B83(DB_[9], DB[9]);
  buf B84(DB_[10], DB[10]);
  buf B85(DB_[11], DB[11]);
  buf B86(DB_[12], DB[12]);
  buf B87(DB_[13], DB[13]);
  buf B88(DB_[14], DB[14]);
  buf B89(DB_[15], DB[15]);
  buf B90(EMAA_[0], EMAA[0]);
  buf B91(EMAA_[1], EMAA[1]);
  buf B92(EMAA_[2], EMAA[2]);
  buf B93(EMAB_[0], EMAB[0]);
  buf B94(EMAB_[1], EMAB[1]);
  buf B95(EMAB_[2], EMAB[2]);
  buf B96(RETN_, RETN);

  assign QA_ = RETN_ ? (QA_int) : {16{1'b0}};
  assign QB_ = RETN_ ? (QB_int) : {16{1'b0}};

`ifdef INITIALIZE_MEMORY
  integer i;
  initial
    for (i = 0; i < MEM_HEIGHT; i = i + 1)
      mem[i] = {MEM_WIDTH{1'b0}};
`endif

  task failedWrite;
  input port;
  integer i;
  begin
    for (i = 0; i < MEM_HEIGHT; i = i + 1)
      mem[i] = {MEM_WIDTH{1'bx}};
  end
  endtask

  function isBitX;
    input bitIn;
    begin
      isBitX = ( bitIn===1'bx || bitIn===1'bz ) ? 1'b1 : 1'b0;
    end
  endfunction


  task readWriteA;
  begin
    if (RETN_int === 1'bx) begin
      failedWrite(0);
      QA_int = {16{1'bx}};
    end else if (RETN_int === 1'b0 && CENA_int === 1'b0) begin
      failedWrite(0);
      QA_int = {16{1'bx}};
    end else if (RETN_int === 1'b0) begin
      // no cycle in retention mode
    end else if (^{CENA_int, EMAA_int} === 1'bx) begin
      failedWrite(0);
      QA_int = {16{1'bx}};
    end else if ((AA_int >= WORDS) && (CENA_int === 1'b0)) begin
      writeEnable = ~{16{WENA_int}};
      QA_int = ((writeEnable & DA_int) | (~writeEnable & {16{1'bx}}));
    end else if (CENA_int === 1'b0 && (^AA_int) === 1'bx) begin
      if (WENA_int !== 1'b1) failedWrite(0);
      QA_int = {16{1'bx}};
    end else if (CENA_int === 1'b0) begin
      mux_address = (AA_int & 4'b1111);
      row_address = (AA_int >> 4);
      if (row_address >= 64)
        row = {256{1'bx}};
      else
        row = mem[row_address];
      writeEnable = ~{16{WENA_int}};
      row_mask =  ( {15'b000000000000000, writeEnable[15], 15'b000000000000000, writeEnable[14],
          15'b000000000000000, writeEnable[13], 15'b000000000000000, writeEnable[12],
          15'b000000000000000, writeEnable[11], 15'b000000000000000, writeEnable[10],
          15'b000000000000000, writeEnable[9], 15'b000000000000000, writeEnable[8],
          15'b000000000000000, writeEnable[7], 15'b000000000000000, writeEnable[6],
          15'b000000000000000, writeEnable[5], 15'b000000000000000, writeEnable[4],
          15'b000000000000000, writeEnable[3], 15'b000000000000000, writeEnable[2],
          15'b000000000000000, writeEnable[1], 15'b000000000000000, writeEnable[0]} << mux_address);
      new_data =  ( {15'b000000000000000, DA_int[15], 15'b000000000000000, DA_int[14],
          15'b000000000000000, DA_int[13], 15'b000000000000000, DA_int[12], 15'b000000000000000, DA_int[11],
          15'b000000000000000, DA_int[10], 15'b000000000000000, DA_int[9], 15'b000000000000000, DA_int[8],
          15'b000000000000000, DA_int[7], 15'b000000000000000, DA_int[6], 15'b000000000000000, DA_int[5],
          15'b000000000000000, DA_int[4], 15'b000000000000000, DA_int[3], 15'b000000000000000, DA_int[2],
          15'b000000000000000, DA_int[1], 15'b000000000000000, DA_int[0]} << mux_address);
      row = (row & ~row_mask) | (row_mask & (~row_mask | new_data));
      mem[row_address] = row;
      data_out = (row >> mux_address);
      QA_int = {data_out[240], data_out[224], data_out[208], data_out[192], data_out[176],
        data_out[160], data_out[144], data_out[128], data_out[112], data_out[96], data_out[80],
        data_out[64], data_out[48], data_out[32], data_out[16], data_out[0]};
    end
  end
  endtask

  always @ RETN_ begin
    if (RETN_ == 1'b0) begin
      QA_int = {16{1'b0}};
      CENA_int = 1'b0;
      WENA_int = 1'b0;
      AA_int = {10{1'b0}};
      DA_int = {16{1'b0}};
      EMAA_int = {3{1'b0}};
      RETN_int = 1'b0;
    end else begin
      QA_int = {16{1'bx}};
      CENA_int = 1'bx;
      WENA_int = 1'bx;
      AA_int = {10{1'bx}};
      DA_int = {16{1'bx}};
      EMAA_int = {3{1'bx}};
      RETN_int = 1'bx;
    end
    RETN_int = RETN_;
  end

  always @ CLKA_ begin
`ifdef POWER_PINS
    if (VSSE === 1'bx || VSSE === 1'bz)
      $display("ERROR: Illegal value for VSSE %b", VSSE);
    if (VDDPE === 1'bx || VDDPE === 1'bz)
      $display("ERROR: Illegal value for VDDPE %b", VDDPE);
    if (VDDCE === 1'bx || VDDCE === 1'bz)
      $display("ERROR: Illegal value for VDDCE %b", VDDCE);
`endif
    if (CLKA_ === 1'bx && (CENA_ !== 1'b1)) begin
      failedWrite(0);
      QA_int = {16{1'bx}};
    end else if (CLKA_ === 1'b1 && LAST_CLKA === 1'b0) begin
      CENA_int = CENA_;
      WENA_int = WENA_;
      AA_int = AA_;
      DA_int = DA_;
      EMAA_int = EMAA_;
      RETN_int = RETN_;
      clk0_int = 1'b0;
      previous_CLKA = $realtime;
      readWriteA;
      if (previous_CLKA == previous_CLKB && is_contention(AA_int, AB_int, WENA_int,
        WENB_int) && (CENA_int !== 1'b1 && CENB_int !== 1'b1)) begin
        if (WENA_int !== 1'b1 && WENB_int !== 1'b1) begin
          DA_int = {16{1'bx}};
          readWriteA;
          DB_int = {16{1'bx}};
          readWriteB;
        end else if (WENA_int !== 1'b1) begin
          QB_int = {16{1'bx}};
        end else if (WENB_int !== 1'b1) begin
          QA_int = {16{1'bx}};
        end else begin
        end
      end
    end
    LAST_CLKA = CLKA_;
  end

  reg globalNotifier0;
  initial globalNotifier0 = 1'b0;

  always @ globalNotifier0 begin
    if ($realtime == 0) begin
    end else if (CENA_int === 1'bx || EMAA_int[0] === 1'bx || EMAA_int[1] === 1'bx || 
      EMAA_int[2] === 1'bx || RETN_int === 1'bx || clk0_int === 1'bx) begin
      QA_int = {16{1'bx}};
      failedWrite(0);
    end else if (cont_flag0_int === 1'bx) begin
      cont_flag0_int = 1'b0;
        if (WENA_ !== 1'b1 && WENB_int !== 1'b1) begin
          DA_int = {16{1'bx}};
          readWriteA;
          DB_int = {16{1'bx}};
          readWriteB;
        end else if (WENA_ !== 1'b1) begin
          QB_int = {16{1'bx}};
        end else if (WENB_int !== 1'b1) begin
          QA_int = {16{1'bx}};
        end else begin
        end
    end else begin
      readWriteA;
   end
    globalNotifier0 = 1'b0;
  end

  task readWriteB;
  begin
    if (RETN_int === 1'bx) begin
      failedWrite(1);
      QB_int = {16{1'bx}};
    end else if (RETN_int === 1'b0 && CENB_int === 1'b0) begin
      failedWrite(1);
      QB_int = {16{1'bx}};
    end else if (RETN_int === 1'b0) begin
      // no cycle in retention mode
    end else if (^{CENB_int, EMAB_int} === 1'bx) begin
      failedWrite(1);
      QB_int = {16{1'bx}};
    end else if ((AB_int >= WORDS) && (CENB_int === 1'b0)) begin
      writeEnable = ~{16{WENB_int}};
      QB_int = ((writeEnable & DB_int) | (~writeEnable & {16{1'bx}}));
    end else if (CENB_int === 1'b0 && (^AB_int) === 1'bx) begin
      if (WENB_int !== 1'b1) failedWrite(1);
      QB_int = {16{1'bx}};
    end else if (CENB_int === 1'b0) begin
      mux_address = (AB_int & 4'b1111);
      row_address = (AB_int >> 4);
      if (row_address >= 64)
        row = {256{1'bx}};
      else
        row = mem[row_address];
      writeEnable = ~{16{WENB_int}};
      row_mask =  ( {15'b000000000000000, writeEnable[15], 15'b000000000000000, writeEnable[14],
          15'b000000000000000, writeEnable[13], 15'b000000000000000, writeEnable[12],
          15'b000000000000000, writeEnable[11], 15'b000000000000000, writeEnable[10],
          15'b000000000000000, writeEnable[9], 15'b000000000000000, writeEnable[8],
          15'b000000000000000, writeEnable[7], 15'b000000000000000, writeEnable[6],
          15'b000000000000000, writeEnable[5], 15'b000000000000000, writeEnable[4],
          15'b000000000000000, writeEnable[3], 15'b000000000000000, writeEnable[2],
          15'b000000000000000, writeEnable[1], 15'b000000000000000, writeEnable[0]} << mux_address);
      new_data =  ( {15'b000000000000000, DB_int[15], 15'b000000000000000, DB_int[14],
          15'b000000000000000, DB_int[13], 15'b000000000000000, DB_int[12], 15'b000000000000000, DB_int[11],
          15'b000000000000000, DB_int[10], 15'b000000000000000, DB_int[9], 15'b000000000000000, DB_int[8],
          15'b000000000000000, DB_int[7], 15'b000000000000000, DB_int[6], 15'b000000000000000, DB_int[5],
          15'b000000000000000, DB_int[4], 15'b000000000000000, DB_int[3], 15'b000000000000000, DB_int[2],
          15'b000000000000000, DB_int[1], 15'b000000000000000, DB_int[0]} << mux_address);
      row = (row & ~row_mask) | (row_mask & (~row_mask | new_data));
      mem[row_address] = row;
      data_out = (row >> mux_address);
      QB_int = {data_out[240], data_out[224], data_out[208], data_out[192], data_out[176],
        data_out[160], data_out[144], data_out[128], data_out[112], data_out[96], data_out[80],
        data_out[64], data_out[48], data_out[32], data_out[16], data_out[0]};
    end
  end
  endtask

  always @ RETN_ begin
    if (RETN_ == 1'b0) begin
      QB_int = {16{1'b0}};
      CENB_int = 1'b0;
      WENB_int = 1'b0;
      AB_int = {10{1'b0}};
      DB_int = {16{1'b0}};
      EMAB_int = {3{1'b0}};
      RETN_int = 1'b0;
    end else begin
      QB_int = {16{1'bx}};
      CENB_int = 1'bx;
      WENB_int = 1'bx;
      AB_int = {10{1'bx}};
      DB_int = {16{1'bx}};
      EMAB_int = {3{1'bx}};
      RETN_int = 1'bx;
    end
    RETN_int = RETN_;
  end

  always @ CLKB_ begin
`ifdef POWER_PINS
    if (VSSE === 1'bx || VSSE === 1'bz)
      $display("ERROR: Illegal value for VSSE %b", VSSE);
    if (VDDPE === 1'bx || VDDPE === 1'bz)
      $display("ERROR: Illegal value for VDDPE %b", VDDPE);
    if (VDDCE === 1'bx || VDDCE === 1'bz)
      $display("ERROR: Illegal value for VDDCE %b", VDDCE);
`endif
    if (CLKB_ === 1'bx && (CENB_ !== 1'b1)) begin
      failedWrite(1);
      QB_int = {16{1'bx}};
    end else if (CLKB_ === 1'b1 && LAST_CLKB === 1'b0) begin
      CENB_int = CENB_;
      WENB_int = WENB_;
      AB_int = AB_;
      DB_int = DB_;
      EMAB_int = EMAB_;
      RETN_int = RETN_;
      clk1_int = 1'b0;
      previous_CLKB = $realtime;
      readWriteB;
      if (previous_CLKA == previous_CLKB && is_contention(AA_int, AB_int, WENA_int,
        WENB_int) && (CENB_int !== 1'b1 && CENA_int !== 1'b1)) begin
        if (WENA_int !== 1'b1 && WENB_int !== 1'b1) begin
          DA_int = {16{1'bx}};
          readWriteA;
          DB_int = {16{1'bx}};
          readWriteB;
        end else if (WENA_int !== 1'b1) begin
          QB_int = {16{1'bx}};
        end else if (WENB_int !== 1'b1) begin
          QA_int = {16{1'bx}};
        end else begin
        end
      end
    end
    LAST_CLKB = CLKB_;
  end

  reg globalNotifier1;
  initial globalNotifier1 = 1'b0;

  always @ globalNotifier1 begin
    if ($realtime == 0) begin
    end else if (CENB_int === 1'bx || EMAB_int[0] === 1'bx || EMAB_int[1] === 1'bx || 
      EMAB_int[2] === 1'bx || RETN_int === 1'bx || clk1_int === 1'bx) begin
      QB_int = {16{1'bx}};
      failedWrite(1);
    end else if (cont_flag1_int === 1'bx) begin
      cont_flag1_int = 1'b0;
        if (WENA_int !== 1'b1 && WENB_ !== 1'b1) begin
          DA_int = {16{1'bx}};
          readWriteA;
          DB_int = {16{1'bx}};
          readWriteB;
        end else if (WENA_int !== 1'b1) begin
          QB_int = {16{1'bx}};
        end else if (WENB_ !== 1'b1) begin
          QA_int = {16{1'bx}};
        end else begin
        end
    end else begin
      readWriteB;
   end
    globalNotifier1 = 1'b0;
  end

  always @ NOT_AA0 begin
    AA_int[0] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_AA1 begin
    AA_int[1] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_AA2 begin
    AA_int[2] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_AA3 begin
    AA_int[3] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_AA4 begin
    AA_int[4] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_AA5 begin
    AA_int[5] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_AA6 begin
    AA_int[6] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_AA7 begin
    AA_int[7] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_AA8 begin
    AA_int[8] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_AA9 begin
    AA_int[9] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_AB0 begin
    AB_int[0] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_AB1 begin
    AB_int[1] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_AB2 begin
    AB_int[2] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_AB3 begin
    AB_int[3] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_AB4 begin
    AB_int[4] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_AB5 begin
    AB_int[5] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_AB6 begin
    AB_int[6] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_AB7 begin
    AB_int[7] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_AB8 begin
    AB_int[8] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_AB9 begin
    AB_int[9] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_CENA begin
    CENA_int = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_CENB begin
    CENB_int = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_DA0 begin
    DA_int[0] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_DA10 begin
    DA_int[10] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_DA11 begin
    DA_int[11] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_DA12 begin
    DA_int[12] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_DA13 begin
    DA_int[13] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_DA14 begin
    DA_int[14] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_DA15 begin
    DA_int[15] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_DA1 begin
    DA_int[1] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_DA2 begin
    DA_int[2] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_DA3 begin
    DA_int[3] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_DA4 begin
    DA_int[4] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_DA5 begin
    DA_int[5] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_DA6 begin
    DA_int[6] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_DA7 begin
    DA_int[7] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_DA8 begin
    DA_int[8] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_DA9 begin
    DA_int[9] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_DB0 begin
    DB_int[0] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_DB10 begin
    DB_int[10] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_DB11 begin
    DB_int[11] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_DB12 begin
    DB_int[12] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_DB13 begin
    DB_int[13] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_DB14 begin
    DB_int[14] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_DB15 begin
    DB_int[15] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_DB1 begin
    DB_int[1] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_DB2 begin
    DB_int[2] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_DB3 begin
    DB_int[3] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_DB4 begin
    DB_int[4] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_DB5 begin
    DB_int[5] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_DB6 begin
    DB_int[6] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_DB7 begin
    DB_int[7] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_DB8 begin
    DB_int[8] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_DB9 begin
    DB_int[9] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_EMAA0 begin
    EMAA_int[0] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_EMAA1 begin
    EMAA_int[1] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_EMAA2 begin
    EMAA_int[2] = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_EMAB0 begin
    EMAB_int[0] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_EMAB1 begin
    EMAB_int[1] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_EMAB2 begin
    EMAB_int[2] = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_RETN begin
    RETN_int = 1'bx;
    if( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
    if( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_RETNA begin
    RETN_int = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_RETNB begin
    RETN_int = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_WENA begin
    WENA_int = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_WENB begin
    WENB_int = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_CLKA_MINH begin
    clk0_int = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_CLKA_MINL begin
    clk0_int = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_CLKA_PER begin
    clk0_int = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_CLKB_MINH begin
    clk1_int = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_CLKB_MINL begin
    clk1_int = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_CLKB_PER begin
    clk1_int = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end
  always @ NOT_CONTA begin
    cont_flag0_int = 1'bx;
    if ( globalNotifier0 === 1'b0 ) globalNotifier0 = 1'bx;
  end
  always @ NOT_CONTB begin
    cont_flag1_int = 1'bx;
    if ( globalNotifier1 === 1'b0 ) globalNotifier1 = 1'bx;
  end

  function is_contention;
    input [9:0] aa;
    input [9:0] ab;
    input  wena;
    input  wenb;
    reg result;
  begin
    if ((& wena) === 1'b1 && (& wenb) === 1'b1) begin
      result = 1'b0;
    end else if (aa == ab) begin
      result = 1'b1;
    end else begin
      result = 1'b0;
    end
    is_contention = result;
  end
  endfunction

   wire contA_flag = is_contention(AB_, AA_int, WENB_, WENA_int) & (CENB_ !== 1'b1 && CENA_int !== 1'b1);
   wire contB_flag = is_contention(AA_, AB_int, WENA_, WENB_int) & (CENA_ !== 1'b1 && CENB_int !== 1'b1);

  wire CENA_flag;
  wire flagA;
  wire DA_flag;
  wire cyc_flagA;
  wire CENB_flag;
  wire flagB;
  wire DB_flag;
  wire cyc_flagB;
  wire contA_EMAA2eq0andEMAA1eq0andEMAA0eq0;
  wire contA_EMAA2eq0andEMAA1eq0andEMAA0eq1;
  wire contA_EMAA2eq0andEMAA1eq1andEMAA0eq0;
  wire contA_EMAA2eq0andEMAA1eq1andEMAA0eq1;
  wire contA_EMAA2eq1andEMAA1eq0andEMAA0eq0;
  wire contA_EMAA2eq1andEMAA1eq0andEMAA0eq1;
  wire contA_EMAA2eq1andEMAA1eq1andEMAA0eq0;
  wire contA_EMAA2eq1andEMAA1eq1andEMAA0eq1;
  wire contB_EMAB2eq0andEMAB1eq0andEMAB0eq0;
  wire contB_EMAB2eq0andEMAB1eq0andEMAB0eq1;
  wire contB_EMAB2eq0andEMAB1eq1andEMAB0eq0;
  wire contB_EMAB2eq0andEMAB1eq1andEMAB0eq1;
  wire contB_EMAB2eq1andEMAB1eq0andEMAB0eq0;
  wire contB_EMAB2eq1andEMAB1eq0andEMAB0eq1;
  wire contB_EMAB2eq1andEMAB1eq1andEMAB0eq0;
  wire contB_EMAB2eq1andEMAB1eq1andEMAB0eq1;
  wire EMAA2eq0andEMAA1eq0andEMAA0eq0;
  wire EMAA2eq0andEMAA1eq0andEMAA0eq1;
  wire EMAA2eq0andEMAA1eq1andEMAA0eq0;
  wire EMAA2eq0andEMAA1eq1andEMAA0eq1;
  wire EMAA2eq1andEMAA1eq0andEMAA0eq0;
  wire EMAA2eq1andEMAA1eq0andEMAA0eq1;
  wire EMAA2eq1andEMAA1eq1andEMAA0eq0;
  wire EMAA2eq1andEMAA1eq1andEMAA0eq1;
  wire EMAB2eq0andEMAB1eq0andEMAB0eq0;
  wire EMAB2eq0andEMAB1eq0andEMAB0eq1;
  wire EMAB2eq0andEMAB1eq1andEMAB0eq0;
  wire EMAB2eq0andEMAB1eq1andEMAB0eq1;
  wire EMAB2eq1andEMAB1eq0andEMAB0eq0;
  wire EMAB2eq1andEMAB1eq0andEMAB0eq1;
  wire EMAB2eq1andEMAB1eq1andEMAB0eq0;
  wire EMAB2eq1andEMAB1eq1andEMAB0eq1;
  assign CENA_flag = 1'b1;
  assign flagA = !CENA_;
  assign DA_flag = !(CENA_ || WENA_);
  assign cyc_flagA = !CENA_;
  assign CENB_flag = 1'b1;
  assign flagB = !CENB_;
  assign DB_flag = !(CENB_ || WENB_);
  assign cyc_flagB = !CENB_;
  assign contA_EMAA2eq0andEMAA1eq0andEMAA0eq0 = EMAA2eq0andEMAA1eq0andEMAA0eq0 && contA_flag;
  assign contA_EMAA2eq0andEMAA1eq0andEMAA0eq1 = EMAA2eq0andEMAA1eq0andEMAA0eq1 && contA_flag;
  assign contA_EMAA2eq0andEMAA1eq1andEMAA0eq0 = EMAA2eq0andEMAA1eq1andEMAA0eq0 && contA_flag;
  assign contA_EMAA2eq0andEMAA1eq1andEMAA0eq1 = EMAA2eq0andEMAA1eq1andEMAA0eq1 && contA_flag;
  assign contA_EMAA2eq1andEMAA1eq0andEMAA0eq0 = EMAA2eq1andEMAA1eq0andEMAA0eq0 && contA_flag;
  assign contA_EMAA2eq1andEMAA1eq0andEMAA0eq1 = EMAA2eq1andEMAA1eq0andEMAA0eq1 && contA_flag;
  assign contA_EMAA2eq1andEMAA1eq1andEMAA0eq0 = EMAA2eq1andEMAA1eq1andEMAA0eq0 && contA_flag;
  assign contA_EMAA2eq1andEMAA1eq1andEMAA0eq1 = EMAA2eq1andEMAA1eq1andEMAA0eq1 && contA_flag;
  assign contB_EMAB2eq0andEMAB1eq0andEMAB0eq0 = EMAB2eq0andEMAB1eq0andEMAB0eq0 && contB_flag;
  assign contB_EMAB2eq0andEMAB1eq0andEMAB0eq1 = EMAB2eq0andEMAB1eq0andEMAB0eq1 && contB_flag;
  assign contB_EMAB2eq0andEMAB1eq1andEMAB0eq0 = EMAB2eq0andEMAB1eq1andEMAB0eq0 && contB_flag;
  assign contB_EMAB2eq0andEMAB1eq1andEMAB0eq1 = EMAB2eq0andEMAB1eq1andEMAB0eq1 && contB_flag;
  assign contB_EMAB2eq1andEMAB1eq0andEMAB0eq0 = EMAB2eq1andEMAB1eq0andEMAB0eq0 && contB_flag;
  assign contB_EMAB2eq1andEMAB1eq0andEMAB0eq1 = EMAB2eq1andEMAB1eq0andEMAB0eq1 && contB_flag;
  assign contB_EMAB2eq1andEMAB1eq1andEMAB0eq0 = EMAB2eq1andEMAB1eq1andEMAB0eq0 && contB_flag;
  assign contB_EMAB2eq1andEMAB1eq1andEMAB0eq1 = EMAB2eq1andEMAB1eq1andEMAB0eq1 && contB_flag;
  assign EMAA2eq0andEMAA1eq0andEMAA0eq0 = !EMAA_[2] && !EMAA_[1] && !EMAA_[0] && cyc_flagA;
  assign EMAA2eq0andEMAA1eq0andEMAA0eq1 = !EMAA_[2] && !EMAA_[1] && EMAA_[0] && cyc_flagA;
  assign EMAA2eq0andEMAA1eq1andEMAA0eq0 = !EMAA_[2] && EMAA_[1] && !EMAA_[0] && cyc_flagA;
  assign EMAA2eq0andEMAA1eq1andEMAA0eq1 = !EMAA_[2] && EMAA_[1] && EMAA_[0] && cyc_flagA;
  assign EMAA2eq1andEMAA1eq0andEMAA0eq0 = EMAA_[2] && !EMAA_[1] && !EMAA_[0] && cyc_flagA;
  assign EMAA2eq1andEMAA1eq0andEMAA0eq1 = EMAA_[2] && !EMAA_[1] && EMAA_[0] && cyc_flagA;
  assign EMAA2eq1andEMAA1eq1andEMAA0eq0 = EMAA_[2] && EMAA_[1] && !EMAA_[0] && cyc_flagA;
  assign EMAA2eq1andEMAA1eq1andEMAA0eq1 = EMAA_[2] && EMAA_[1] && EMAA_[0] && cyc_flagA;
  assign EMAB2eq0andEMAB1eq0andEMAB0eq0 = !EMAB_[2] && !EMAB_[1] && !EMAB_[0] && cyc_flagB;
  assign EMAB2eq0andEMAB1eq0andEMAB0eq1 = !EMAB_[2] && !EMAB_[1] && EMAB_[0] && cyc_flagB;
  assign EMAB2eq0andEMAB1eq1andEMAB0eq0 = !EMAB_[2] && EMAB_[1] && !EMAB_[0] && cyc_flagB;
  assign EMAB2eq0andEMAB1eq1andEMAB0eq1 = !EMAB_[2] && EMAB_[1] && EMAB_[0] && cyc_flagB;
  assign EMAB2eq1andEMAB1eq0andEMAB0eq0 = EMAB_[2] && !EMAB_[1] && !EMAB_[0] && cyc_flagB;
  assign EMAB2eq1andEMAB1eq0andEMAB0eq1 = EMAB_[2] && !EMAB_[1] && EMAB_[0] && cyc_flagB;
  assign EMAB2eq1andEMAB1eq1andEMAB0eq0 = EMAB_[2] && EMAB_[1] && !EMAB_[0] && cyc_flagB;
  assign EMAB2eq1andEMAB1eq1andEMAB0eq1 = EMAB_[2] && EMAB_[1] && EMAB_[0] && cyc_flagB;

  specify
      $hold(posedge CENA, negedge RETN, 1.000, NOT_RETN);
      $setuphold(posedge CLKA &&& CENA_flag, posedge CENA, 1.000, 0.500, NOT_CENA);
      $setuphold(posedge CLKA &&& CENA_flag, negedge CENA, 1.000, 0.500, NOT_CENA);
      $setuphold(posedge CLKA &&& flagA, posedge WENA, 1.000, 0.500, NOT_WENA);
      $setuphold(posedge CLKA &&& flagA, negedge WENA, 1.000, 0.500, NOT_WENA);
      $setuphold(posedge CLKA &&& flagA, posedge AA[9], 1.000, 0.500, NOT_AA9);
      $setuphold(posedge CLKA &&& flagA, negedge AA[9], 1.000, 0.500, NOT_AA9);
      $setuphold(posedge CLKA &&& flagA, posedge AA[8], 1.000, 0.500, NOT_AA8);
      $setuphold(posedge CLKA &&& flagA, negedge AA[8], 1.000, 0.500, NOT_AA8);
      $setuphold(posedge CLKA &&& flagA, posedge AA[7], 1.000, 0.500, NOT_AA7);
      $setuphold(posedge CLKA &&& flagA, negedge AA[7], 1.000, 0.500, NOT_AA7);
      $setuphold(posedge CLKA &&& flagA, posedge AA[6], 1.000, 0.500, NOT_AA6);
      $setuphold(posedge CLKA &&& flagA, negedge AA[6], 1.000, 0.500, NOT_AA6);
      $setuphold(posedge CLKA &&& flagA, posedge AA[5], 1.000, 0.500, NOT_AA5);
      $setuphold(posedge CLKA &&& flagA, negedge AA[5], 1.000, 0.500, NOT_AA5);
      $setuphold(posedge CLKA &&& flagA, posedge AA[4], 1.000, 0.500, NOT_AA4);
      $setuphold(posedge CLKA &&& flagA, negedge AA[4], 1.000, 0.500, NOT_AA4);
      $setuphold(posedge CLKA &&& flagA, posedge AA[3], 1.000, 0.500, NOT_AA3);
      $setuphold(posedge CLKA &&& flagA, negedge AA[3], 1.000, 0.500, NOT_AA3);
      $setuphold(posedge CLKA &&& flagA, posedge AA[2], 1.000, 0.500, NOT_AA2);
      $setuphold(posedge CLKA &&& flagA, negedge AA[2], 1.000, 0.500, NOT_AA2);
      $setuphold(posedge CLKA &&& flagA, posedge AA[1], 1.000, 0.500, NOT_AA1);
      $setuphold(posedge CLKA &&& flagA, negedge AA[1], 1.000, 0.500, NOT_AA1);
      $setuphold(posedge CLKA &&& flagA, posedge AA[0], 1.000, 0.500, NOT_AA0);
      $setuphold(posedge CLKA &&& flagA, negedge AA[0], 1.000, 0.500, NOT_AA0);
      $setuphold(posedge CLKA &&& DA_flag, posedge DA[15], 1.000, 0.500, NOT_DA15);
      $setuphold(posedge CLKA &&& DA_flag, negedge DA[15], 1.000, 0.500, NOT_DA15);
      $setuphold(posedge CLKA &&& DA_flag, posedge DA[14], 1.000, 0.500, NOT_DA14);
      $setuphold(posedge CLKA &&& DA_flag, negedge DA[14], 1.000, 0.500, NOT_DA14);
      $setuphold(posedge CLKA &&& DA_flag, posedge DA[13], 1.000, 0.500, NOT_DA13);
      $setuphold(posedge CLKA &&& DA_flag, negedge DA[13], 1.000, 0.500, NOT_DA13);
      $setuphold(posedge CLKA &&& DA_flag, posedge DA[12], 1.000, 0.500, NOT_DA12);
      $setuphold(posedge CLKA &&& DA_flag, negedge DA[12], 1.000, 0.500, NOT_DA12);
      $setuphold(posedge CLKA &&& DA_flag, posedge DA[11], 1.000, 0.500, NOT_DA11);
      $setuphold(posedge CLKA &&& DA_flag, negedge DA[11], 1.000, 0.500, NOT_DA11);
      $setuphold(posedge CLKA &&& DA_flag, posedge DA[10], 1.000, 0.500, NOT_DA10);
      $setuphold(posedge CLKA &&& DA_flag, negedge DA[10], 1.000, 0.500, NOT_DA10);
      $setuphold(posedge CLKA &&& DA_flag, posedge DA[9], 1.000, 0.500, NOT_DA9);
      $setuphold(posedge CLKA &&& DA_flag, negedge DA[9], 1.000, 0.500, NOT_DA9);
      $setuphold(posedge CLKA &&& DA_flag, posedge DA[8], 1.000, 0.500, NOT_DA8);
      $setuphold(posedge CLKA &&& DA_flag, negedge DA[8], 1.000, 0.500, NOT_DA8);
      $setuphold(posedge CLKA &&& DA_flag, posedge DA[7], 1.000, 0.500, NOT_DA7);
      $setuphold(posedge CLKA &&& DA_flag, negedge DA[7], 1.000, 0.500, NOT_DA7);
      $setuphold(posedge CLKA &&& DA_flag, posedge DA[6], 1.000, 0.500, NOT_DA6);
      $setuphold(posedge CLKA &&& DA_flag, negedge DA[6], 1.000, 0.500, NOT_DA6);
      $setuphold(posedge CLKA &&& DA_flag, posedge DA[5], 1.000, 0.500, NOT_DA5);
      $setuphold(posedge CLKA &&& DA_flag, negedge DA[5], 1.000, 0.500, NOT_DA5);
      $setuphold(posedge CLKA &&& DA_flag, posedge DA[4], 1.000, 0.500, NOT_DA4);
      $setuphold(posedge CLKA &&& DA_flag, negedge DA[4], 1.000, 0.500, NOT_DA4);
      $setuphold(posedge CLKA &&& DA_flag, posedge DA[3], 1.000, 0.500, NOT_DA3);
      $setuphold(posedge CLKA &&& DA_flag, negedge DA[3], 1.000, 0.500, NOT_DA3);
      $setuphold(posedge CLKA &&& DA_flag, posedge DA[2], 1.000, 0.500, NOT_DA2);
      $setuphold(posedge CLKA &&& DA_flag, negedge DA[2], 1.000, 0.500, NOT_DA2);
      $setuphold(posedge CLKA &&& DA_flag, posedge DA[1], 1.000, 0.500, NOT_DA1);
      $setuphold(posedge CLKA &&& DA_flag, negedge DA[1], 1.000, 0.500, NOT_DA1);
      $setuphold(posedge CLKA &&& DA_flag, posedge DA[0], 1.000, 0.500, NOT_DA0);
      $setuphold(posedge CLKA &&& DA_flag, negedge DA[0], 1.000, 0.500, NOT_DA0);
      $setuphold(posedge CLKA &&& cyc_flagA, posedge EMAA[2], 1.000, 0.500, NOT_EMAA2);
      $setuphold(posedge CLKA &&& cyc_flagA, negedge EMAA[2], 1.000, 0.500, NOT_EMAA2);
      $setuphold(posedge CLKA &&& cyc_flagA, posedge EMAA[1], 1.000, 0.500, NOT_EMAA1);
      $setuphold(posedge CLKA &&& cyc_flagA, negedge EMAA[1], 1.000, 0.500, NOT_EMAA1);
      $setuphold(posedge CLKA &&& cyc_flagA, posedge EMAA[0], 1.000, 0.500, NOT_EMAA0);
      $setuphold(posedge CLKA &&& cyc_flagA, negedge EMAA[0], 1.000, 0.500, NOT_EMAA0);
      $setuphold(posedge CLKA, posedge RETN, 1.000, 0.500, NOT_RETNA);
      $setuphold(posedge CLKA, negedge RETN, 1.000, 0.500, NOT_RETNA);
      $hold(posedge RETN, negedge CENA, 1.000, NOT_RETN);
      $hold(posedge CENB, negedge RETN, 1.000, NOT_RETN);
      $setuphold(posedge CLKB &&& CENB_flag, posedge CENB, 1.000, 0.500, NOT_CENB);
      $setuphold(posedge CLKB &&& CENB_flag, negedge CENB, 1.000, 0.500, NOT_CENB);
      $setuphold(posedge CLKB &&& flagB, posedge WENB, 1.000, 0.500, NOT_WENB);
      $setuphold(posedge CLKB &&& flagB, negedge WENB, 1.000, 0.500, NOT_WENB);
      $setuphold(posedge CLKB &&& flagB, posedge AB[9], 1.000, 0.500, NOT_AB9);
      $setuphold(posedge CLKB &&& flagB, negedge AB[9], 1.000, 0.500, NOT_AB9);
      $setuphold(posedge CLKB &&& flagB, posedge AB[8], 1.000, 0.500, NOT_AB8);
      $setuphold(posedge CLKB &&& flagB, negedge AB[8], 1.000, 0.500, NOT_AB8);
      $setuphold(posedge CLKB &&& flagB, posedge AB[7], 1.000, 0.500, NOT_AB7);
      $setuphold(posedge CLKB &&& flagB, negedge AB[7], 1.000, 0.500, NOT_AB7);
      $setuphold(posedge CLKB &&& flagB, posedge AB[6], 1.000, 0.500, NOT_AB6);
      $setuphold(posedge CLKB &&& flagB, negedge AB[6], 1.000, 0.500, NOT_AB6);
      $setuphold(posedge CLKB &&& flagB, posedge AB[5], 1.000, 0.500, NOT_AB5);
      $setuphold(posedge CLKB &&& flagB, negedge AB[5], 1.000, 0.500, NOT_AB5);
      $setuphold(posedge CLKB &&& flagB, posedge AB[4], 1.000, 0.500, NOT_AB4);
      $setuphold(posedge CLKB &&& flagB, negedge AB[4], 1.000, 0.500, NOT_AB4);
      $setuphold(posedge CLKB &&& flagB, posedge AB[3], 1.000, 0.500, NOT_AB3);
      $setuphold(posedge CLKB &&& flagB, negedge AB[3], 1.000, 0.500, NOT_AB3);
      $setuphold(posedge CLKB &&& flagB, posedge AB[2], 1.000, 0.500, NOT_AB2);
      $setuphold(posedge CLKB &&& flagB, negedge AB[2], 1.000, 0.500, NOT_AB2);
      $setuphold(posedge CLKB &&& flagB, posedge AB[1], 1.000, 0.500, NOT_AB1);
      $setuphold(posedge CLKB &&& flagB, negedge AB[1], 1.000, 0.500, NOT_AB1);
      $setuphold(posedge CLKB &&& flagB, posedge AB[0], 1.000, 0.500, NOT_AB0);
      $setuphold(posedge CLKB &&& flagB, negedge AB[0], 1.000, 0.500, NOT_AB0);
      $setuphold(posedge CLKB &&& DB_flag, posedge DB[15], 1.000, 0.500, NOT_DB15);
      $setuphold(posedge CLKB &&& DB_flag, negedge DB[15], 1.000, 0.500, NOT_DB15);
      $setuphold(posedge CLKB &&& DB_flag, posedge DB[14], 1.000, 0.500, NOT_DB14);
      $setuphold(posedge CLKB &&& DB_flag, negedge DB[14], 1.000, 0.500, NOT_DB14);
      $setuphold(posedge CLKB &&& DB_flag, posedge DB[13], 1.000, 0.500, NOT_DB13);
      $setuphold(posedge CLKB &&& DB_flag, negedge DB[13], 1.000, 0.500, NOT_DB13);
      $setuphold(posedge CLKB &&& DB_flag, posedge DB[12], 1.000, 0.500, NOT_DB12);
      $setuphold(posedge CLKB &&& DB_flag, negedge DB[12], 1.000, 0.500, NOT_DB12);
      $setuphold(posedge CLKB &&& DB_flag, posedge DB[11], 1.000, 0.500, NOT_DB11);
      $setuphold(posedge CLKB &&& DB_flag, negedge DB[11], 1.000, 0.500, NOT_DB11);
      $setuphold(posedge CLKB &&& DB_flag, posedge DB[10], 1.000, 0.500, NOT_DB10);
      $setuphold(posedge CLKB &&& DB_flag, negedge DB[10], 1.000, 0.500, NOT_DB10);
      $setuphold(posedge CLKB &&& DB_flag, posedge DB[9], 1.000, 0.500, NOT_DB9);
      $setuphold(posedge CLKB &&& DB_flag, negedge DB[9], 1.000, 0.500, NOT_DB9);
      $setuphold(posedge CLKB &&& DB_flag, posedge DB[8], 1.000, 0.500, NOT_DB8);
      $setuphold(posedge CLKB &&& DB_flag, negedge DB[8], 1.000, 0.500, NOT_DB8);
      $setuphold(posedge CLKB &&& DB_flag, posedge DB[7], 1.000, 0.500, NOT_DB7);
      $setuphold(posedge CLKB &&& DB_flag, negedge DB[7], 1.000, 0.500, NOT_DB7);
      $setuphold(posedge CLKB &&& DB_flag, posedge DB[6], 1.000, 0.500, NOT_DB6);
      $setuphold(posedge CLKB &&& DB_flag, negedge DB[6], 1.000, 0.500, NOT_DB6);
      $setuphold(posedge CLKB &&& DB_flag, posedge DB[5], 1.000, 0.500, NOT_DB5);
      $setuphold(posedge CLKB &&& DB_flag, negedge DB[5], 1.000, 0.500, NOT_DB5);
      $setuphold(posedge CLKB &&& DB_flag, posedge DB[4], 1.000, 0.500, NOT_DB4);
      $setuphold(posedge CLKB &&& DB_flag, negedge DB[4], 1.000, 0.500, NOT_DB4);
      $setuphold(posedge CLKB &&& DB_flag, posedge DB[3], 1.000, 0.500, NOT_DB3);
      $setuphold(posedge CLKB &&& DB_flag, negedge DB[3], 1.000, 0.500, NOT_DB3);
      $setuphold(posedge CLKB &&& DB_flag, posedge DB[2], 1.000, 0.500, NOT_DB2);
      $setuphold(posedge CLKB &&& DB_flag, negedge DB[2], 1.000, 0.500, NOT_DB2);
      $setuphold(posedge CLKB &&& DB_flag, posedge DB[1], 1.000, 0.500, NOT_DB1);
      $setuphold(posedge CLKB &&& DB_flag, negedge DB[1], 1.000, 0.500, NOT_DB1);
      $setuphold(posedge CLKB &&& DB_flag, posedge DB[0], 1.000, 0.500, NOT_DB0);
      $setuphold(posedge CLKB &&& DB_flag, negedge DB[0], 1.000, 0.500, NOT_DB0);
      $setuphold(posedge CLKB &&& cyc_flagB, posedge EMAB[2], 1.000, 0.500, NOT_EMAB2);
      $setuphold(posedge CLKB &&& cyc_flagB, negedge EMAB[2], 1.000, 0.500, NOT_EMAB2);
      $setuphold(posedge CLKB &&& cyc_flagB, posedge EMAB[1], 1.000, 0.500, NOT_EMAB1);
      $setuphold(posedge CLKB &&& cyc_flagB, negedge EMAB[1], 1.000, 0.500, NOT_EMAB1);
      $setuphold(posedge CLKB &&& cyc_flagB, posedge EMAB[0], 1.000, 0.500, NOT_EMAB0);
      $setuphold(posedge CLKB &&& cyc_flagB, negedge EMAB[0], 1.000, 0.500, NOT_EMAB0);
      $setuphold(posedge CLKB, posedge RETN, 1.000, 0.500, NOT_RETNB);
      $setuphold(posedge CLKB, negedge RETN, 1.000, 0.500, NOT_RETNB);
      $hold(posedge RETN, negedge CENB, 1.000, NOT_RETN);
      $setup(posedge CLKA, posedge CLKB &&& contA_EMAA2eq0andEMAA1eq0andEMAA0eq0, 3.000, NOT_CONTB);
      $setup(posedge CLKA, posedge CLKB &&& contA_EMAA2eq0andEMAA1eq0andEMAA0eq1, 3.000, NOT_CONTB);
      $setup(posedge CLKA, posedge CLKB &&& contA_EMAA2eq0andEMAA1eq1andEMAA0eq0, 3.000, NOT_CONTB);
      $setup(posedge CLKA, posedge CLKB &&& contA_EMAA2eq0andEMAA1eq1andEMAA0eq1, 3.000, NOT_CONTB);
      $setup(posedge CLKA, posedge CLKB &&& contA_EMAA2eq1andEMAA1eq0andEMAA0eq0, 3.000, NOT_CONTB);
      $setup(posedge CLKA, posedge CLKB &&& contA_EMAA2eq1andEMAA1eq0andEMAA0eq1, 3.000, NOT_CONTB);
      $setup(posedge CLKA, posedge CLKB &&& contA_EMAA2eq1andEMAA1eq1andEMAA0eq0, 3.000, NOT_CONTB);
      $setup(posedge CLKA, posedge CLKB &&& contA_EMAA2eq1andEMAA1eq1andEMAA0eq1, 3.000, NOT_CONTB);
      $setup(posedge CLKB, posedge CLKA &&& contB_EMAB2eq0andEMAB1eq0andEMAB0eq0, 3.000, NOT_CONTA);
      $setup(posedge CLKB, posedge CLKA &&& contB_EMAB2eq0andEMAB1eq0andEMAB0eq1, 3.000, NOT_CONTA);
      $setup(posedge CLKB, posedge CLKA &&& contB_EMAB2eq0andEMAB1eq1andEMAB0eq0, 3.000, NOT_CONTA);
      $setup(posedge CLKB, posedge CLKA &&& contB_EMAB2eq0andEMAB1eq1andEMAB0eq1, 3.000, NOT_CONTA);
      $setup(posedge CLKB, posedge CLKA &&& contB_EMAB2eq1andEMAB1eq0andEMAB0eq0, 3.000, NOT_CONTA);
      $setup(posedge CLKB, posedge CLKA &&& contB_EMAB2eq1andEMAB1eq0andEMAB0eq1, 3.000, NOT_CONTA);
      $setup(posedge CLKB, posedge CLKA &&& contB_EMAB2eq1andEMAB1eq1andEMAB0eq0, 3.000, NOT_CONTA);
      $setup(posedge CLKB, posedge CLKA &&& contB_EMAB2eq1andEMAB1eq1andEMAB0eq1, 3.000, NOT_CONTA);

      $width(posedge CLKA &&& cyc_flagA, 1.000, 0, NOT_CLKA_MINH);
      $width(negedge CLKA &&& cyc_flagA, 1.000, 0, NOT_CLKA_MINL);
`ifdef NO_SDTC
      $period(posedge CLKA  &&& cyc_flagA, 3.000, NOT_CLKA_PER);
`else
      $period(posedge CLKA &&& EMAA2eq0andEMAA1eq0andEMAA0eq0, 3.000, NOT_CLKA_PER);
      $period(posedge CLKA &&& EMAA2eq0andEMAA1eq0andEMAA0eq1, 3.000, NOT_CLKA_PER);
      $period(posedge CLKA &&& EMAA2eq0andEMAA1eq1andEMAA0eq0, 3.000, NOT_CLKA_PER);
      $period(posedge CLKA &&& EMAA2eq0andEMAA1eq1andEMAA0eq1, 3.000, NOT_CLKA_PER);
      $period(posedge CLKA &&& EMAA2eq1andEMAA1eq0andEMAA0eq0, 3.000, NOT_CLKA_PER);
      $period(posedge CLKA &&& EMAA2eq1andEMAA1eq0andEMAA0eq1, 3.000, NOT_CLKA_PER);
      $period(posedge CLKA &&& EMAA2eq1andEMAA1eq1andEMAA0eq0, 3.000, NOT_CLKA_PER);
      $period(posedge CLKA &&& EMAA2eq1andEMAA1eq1andEMAA0eq1, 3.000, NOT_CLKA_PER);
`endif

      $width(posedge CLKB &&& cyc_flagB, 1.000, 0, NOT_CLKB_MINH);
      $width(negedge CLKB &&& cyc_flagB, 1.000, 0, NOT_CLKB_MINL);
`ifdef NO_SDTC
      $period(posedge CLKB  &&& cyc_flagB, 3.000, NOT_CLKB_PER);
`else
      $period(posedge CLKB &&& EMAB2eq0andEMAB1eq0andEMAB0eq0, 3.000, NOT_CLKB_PER);
      $period(posedge CLKB &&& EMAB2eq0andEMAB1eq0andEMAB0eq1, 3.000, NOT_CLKB_PER);
      $period(posedge CLKB &&& EMAB2eq0andEMAB1eq1andEMAB0eq0, 3.000, NOT_CLKB_PER);
      $period(posedge CLKB &&& EMAB2eq0andEMAB1eq1andEMAB0eq1, 3.000, NOT_CLKB_PER);
      $period(posedge CLKB &&& EMAB2eq1andEMAB1eq0andEMAB0eq0, 3.000, NOT_CLKB_PER);
      $period(posedge CLKB &&& EMAB2eq1andEMAB1eq0andEMAB0eq1, 3.000, NOT_CLKB_PER);
      $period(posedge CLKB &&& EMAB2eq1andEMAB1eq1andEMAB0eq0, 3.000, NOT_CLKB_PER);
      $period(posedge CLKB &&& EMAB2eq1andEMAB1eq1andEMAB0eq1, 3.000, NOT_CLKB_PER);
`endif

      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[15]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[15]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[15]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[15]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[15]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[15]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[15]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[15]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[14]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[14]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[14]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[14]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[14]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[14]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[14]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[14]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[13]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[13]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[13]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[13]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[13]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[13]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[13]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[13]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[12]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[12]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[12]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[12]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[12]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[12]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[12]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[12]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[11]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[11]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[11]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[11]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[11]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[11]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[11]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[11]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[10]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[10]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[10]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[10]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[10]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[10]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[10]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[10]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[9]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[9]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[9]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[9]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[9]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[9]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[9]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[9]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[8]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[8]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[8]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[8]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[8]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[8]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[8]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[8]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[7]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[7]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[7]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[7]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[7]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[7]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[7]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[7]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[6]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[6]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[6]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[6]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[6]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[6]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[6]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[6]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[5]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[5]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[5]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[5]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[5]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[5]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[5]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[5]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[4]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[4]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[4]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[4]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[4]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[4]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[4]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[4]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[3]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[3]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[3]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[3]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[3]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[3]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[3]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[3]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[2]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[2]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[2]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[2]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[2]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[2]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[2]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[2]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[1]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[1]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[1]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[1]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[1]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[1]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[1]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[1]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[0]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[0]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[0]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b0) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[0]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[0]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b0) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[0]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b0))
        (posedge CLKA => (QA[0]:1'b0))=(1.000, 1.000);
      if ((EMAA[2] == 1'b1) && (EMAA[1] == 1'b1) && (EMAA[0] == 1'b1))
        (posedge CLKA => (QA[0]:1'b0))=(1.000, 1.000);

      (RETN => (QA[15] +: 1'b0)) = (1.000);
      (RETN => (QA[14] +: 1'b0)) = (1.000);
      (RETN => (QA[13] +: 1'b0)) = (1.000);
      (RETN => (QA[12] +: 1'b0)) = (1.000);
      (RETN => (QA[11] +: 1'b0)) = (1.000);
      (RETN => (QA[10] +: 1'b0)) = (1.000);
      (RETN => (QA[9] +: 1'b0)) = (1.000);
      (RETN => (QA[8] +: 1'b0)) = (1.000);
      (RETN => (QA[7] +: 1'b0)) = (1.000);
      (RETN => (QA[6] +: 1'b0)) = (1.000);
      (RETN => (QA[5] +: 1'b0)) = (1.000);
      (RETN => (QA[4] +: 1'b0)) = (1.000);
      (RETN => (QA[3] +: 1'b0)) = (1.000);
      (RETN => (QA[2] +: 1'b0)) = (1.000);
      (RETN => (QA[1] +: 1'b0)) = (1.000);
      (RETN => (QA[0] +: 1'b0)) = (1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[15]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[15]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[15]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[15]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[15]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[15]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[15]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[15]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[14]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[14]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[14]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[14]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[14]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[14]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[14]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[14]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[13]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[13]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[13]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[13]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[13]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[13]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[13]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[13]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[12]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[12]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[12]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[12]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[12]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[12]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[12]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[12]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[11]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[11]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[11]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[11]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[11]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[11]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[11]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[11]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[10]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[10]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[10]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[10]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[10]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[10]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[10]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[10]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[9]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[9]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[9]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[9]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[9]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[9]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[9]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[9]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[8]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[8]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[8]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[8]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[8]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[8]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[8]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[8]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[7]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[7]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[7]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[7]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[7]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[7]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[7]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[7]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[6]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[6]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[6]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[6]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[6]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[6]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[6]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[6]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[5]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[5]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[5]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[5]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[5]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[5]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[5]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[5]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[4]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[4]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[4]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[4]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[4]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[4]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[4]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[4]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[3]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[3]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[3]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[3]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[3]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[3]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[3]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[3]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[2]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[2]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[2]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[2]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[2]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[2]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[2]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[2]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[1]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[1]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[1]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[1]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[1]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[1]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[1]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[1]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[0]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[0]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[0]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b0) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[0]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[0]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b0) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[0]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b0))
        (posedge CLKB => (QB[0]:1'b0))=(1.000, 1.000);
      if ((EMAB[2] == 1'b1) && (EMAB[1] == 1'b1) && (EMAB[0] == 1'b1))
        (posedge CLKB => (QB[0]:1'b0))=(1.000, 1.000);

      (RETN => (QB[15] +: 1'b0)) = (1.000);
      (RETN => (QB[14] +: 1'b0)) = (1.000);
      (RETN => (QB[13] +: 1'b0)) = (1.000);
      (RETN => (QB[12] +: 1'b0)) = (1.000);
      (RETN => (QB[11] +: 1'b0)) = (1.000);
      (RETN => (QB[10] +: 1'b0)) = (1.000);
      (RETN => (QB[9] +: 1'b0)) = (1.000);
      (RETN => (QB[8] +: 1'b0)) = (1.000);
      (RETN => (QB[7] +: 1'b0)) = (1.000);
      (RETN => (QB[6] +: 1'b0)) = (1.000);
      (RETN => (QB[5] +: 1'b0)) = (1.000);
      (RETN => (QB[4] +: 1'b0)) = (1.000);
      (RETN => (QB[3] +: 1'b0)) = (1.000);
      (RETN => (QB[2] +: 1'b0)) = (1.000);
      (RETN => (QB[1] +: 1'b0)) = (1.000);
      (RETN => (QB[0] +: 1'b0)) = (1.000);
  endspecify

endmodule
`endcelldefine
`endif
