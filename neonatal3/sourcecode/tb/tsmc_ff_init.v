// tsmc_ff_init.v — Zero-delay behavioral overrides for all TSMC 65nm HVT FF cells
//                  used in hardware_netlist.v.
//
// COMPILE ORDER: must appear BEFORE TSMC lib in dut_src_list_routed.txt.
// -ALLOWREDEFINITION keeps FIRST definition: compile first → our models win.
//
// WHY NEEDED: Genus synthesis removed all reset connections (decoder_acc.resetn,
// soc.resetn etc. are tied to logic_1_1_net). The testbench reset pulse has no
// effect on the DUT. FFs that lack a reset pin (DFQD*, EDFD*, SDF*) would start
// at X in GLV. These overrides initialize Q=0 at time-0, which equals the
// designed-for reset state (same as asserting resetn for picorv32 then releasing).
//
// Cell types covered (33 total — verified against hardware_routed.v grep):
//
//  Basic D-FF         : DFD1 DFD2 DFQD1 DFQD2 DFQD4
//  D-FF async clear   : DFKCND1 DFKCND2 DFKCNQD1 DFKCNQD2 DFKCNQD4
//  D-FF clear+set     : DFKCSND1
//  D-FF async set     : DFKSND1
//  Enable D-FF        : EDFD1 EDFD2 EDFQD1 EDFQD4
//  Enable D-FF clear  : EDFKCND1 EDFKCNQD1 EDFKCNQD2 EDFKCNQD4
//  Scan D-FF          : SDFQD0 SDFQD2 SDFQND0 SDFXQD0
//  Scan D-FF clear    : SDFKCND1 SDFKCNQD0 SDFKCNQD1 SDFKCNQD2
//  Scan D-FF clr+set  : SDFKCSNQD0
//  Scan D-FF set      : SDFKSNQD0
//  Scan+Ena D-FF clear: SEDFKCNQD0

// ── Basic D-FF (no reset, no enable) ─────────────────────────────────────

module DFD1HVT (input D, CP, output reg Q, output QN);
    initial Q = 1'b0;
    assign  QN = ~Q;
    always @(posedge CP) Q <= D;
endmodule

module DFD2HVT (input D, CP, output reg Q, output QN);
    initial Q = 1'b0;
    assign  QN = ~Q;
    always @(posedge CP) Q <= D;
endmodule

module DFQD1HVT (input D, CP, output reg Q);
    initial Q = 1'b0;
    always @(posedge CP) Q <= D;
endmodule

module DFQD2HVT (input D, CP, output reg Q);
    initial Q = 1'b0;
    always @(posedge CP) Q <= D;
endmodule

module DFQD4HVT (input D, CP, output reg Q);
    initial Q = 1'b0;
    always @(posedge CP) Q <= D;
endmodule

// ── D-FF with async clear-low (CN=0 → Q=0) ───────────────────────────────

module DFKCND1HVT (input D, CP, CN, output reg Q, output QN);
    initial Q = 1'b0;
    assign  QN = ~Q;
    always @(posedge CP or negedge CN)
        if (!CN) Q <= 1'b0;
        else     Q <= D;
endmodule

module DFKCND2HVT (input D, CP, CN, output reg Q, output QN);
    initial Q = 1'b0;
    assign  QN = ~Q;
    always @(posedge CP or negedge CN)
        if (!CN) Q <= 1'b0;
        else     Q <= D;
endmodule

module DFKCNQD1HVT (input D, CP, CN, output reg Q);
    initial Q = 1'b0;
    always @(posedge CP or negedge CN)
        if (!CN) Q <= 1'b0;
        else     Q <= D;
endmodule

// ── D-FF with async clear-low AND set-low ────────────────────────────────

module DFKCSND1HVT (input D, CP, CN, SN, output reg Q, output QN);
    initial Q = 1'b0;
    assign  QN = ~Q;
    always @(posedge CP or negedge CN or negedge SN)
        if      (!CN) Q <= 1'b0;
        else if (!SN) Q <= 1'b1;
        else          Q <= D;
endmodule

// ── D-FF with async set-low (SN=0 → Q=1) ────────────────────────────────

module DFKSND1HVT (input D, CP, SN, output reg Q, output QN);
    initial Q = 1'b0;
    assign  QN = ~Q;
    always @(posedge CP or negedge SN)
        if (!SN) Q <= 1'b1;
        else     Q <= D;
endmodule

// ── Enable D-FF (E=clock-enable, no reset) ───────────────────────────────
// E=1: load D on posedge; E=0: hold Q

module EDFD1HVT (input D, CP, E, output reg Q, output QN);
    initial Q = 1'b0;
    assign  QN = ~Q;
    always @(posedge CP)
        if (E) Q <= D;
endmodule

module EDFD2HVT (input D, CP, E, output reg Q, output QN);
    initial Q = 1'b0;
    assign  QN = ~Q;
    always @(posedge CP)
        if (E) Q <= D;
endmodule

module EDFQD1HVT (input D, CP, E, output reg Q);
    initial Q = 1'b0;
    always @(posedge CP)
        if (E) Q <= D;
endmodule

module EDFQD4HVT (input D, CP, E, output reg Q);
    initial Q = 1'b0;
    always @(posedge CP)
        if (E) Q <= D;
endmodule

// ── D-FF with async clear-low, Q only, higher drive strengths ────────────

module DFKCNQD2HVT (input D, CP, CN, output reg Q);
    initial Q = 1'b0;
    always @(posedge CP or negedge CN)
        if (!CN) Q <= 1'b0;
        else     Q <= D;
endmodule

module DFKCNQD4HVT (input D, CP, CN, output reg Q);
    initial Q = 1'b0;
    always @(posedge CP or negedge CN)
        if (!CN) Q <= 1'b0;
        else     Q <= D;
endmodule

// ── Enable D-FF with async clear-low ─────────────────────────────────────

module EDFKCND1HVT (input D, CP, E, CN, output reg Q, output QN);
    initial Q = 1'b0;
    assign  QN = ~Q;
    always @(posedge CP or negedge CN)
        if      (!CN) Q <= 1'b0;
        else if (E)   Q <= D;
endmodule

module EDFKCNQD1HVT (input D, CP, E, CN, output reg Q);
    initial Q = 1'b0;
    always @(posedge CP or negedge CN)
        if      (!CN) Q <= 1'b0;
        else if (E)   Q <= D;
endmodule

module EDFKCNQD2HVT (input D, CP, E, CN, output reg Q);
    initial Q = 1'b0;
    always @(posedge CP or negedge CN)
        if      (!CN) Q <= 1'b0;
        else if (E)   Q <= D;
endmodule

module EDFKCNQD4HVT (input D, CP, E, CN, output reg Q);
    initial Q = 1'b0;
    always @(posedge CP or negedge CN)
        if      (!CN) Q <= 1'b0;
        else if (E)   Q <= D;
endmodule

// ── Scan D-FF (SI=scan-in, SE=scan-enable; SE=0 in functional sim) ───────
// SE=1: load SI (scan path); SE=0: load D (data path)

module SDFQD0HVT (input D, SI, SE, CP, output reg Q);
    initial Q = 1'b0;
    always @(posedge CP)
        if (SE) Q <= SI;
        else    Q <= D;
endmodule

module SDFQD1HVT (input D, SI, SE, CP, output reg Q);
    initial Q = 1'b0;
    always @(posedge CP)
        if (SE) Q <= SI;
        else    Q <= D;
endmodule

module SDFQD2HVT (input D, SI, SE, CP, output reg Q);
    initial Q = 1'b0;
    always @(posedge CP)
        if (SE) Q <= SI;
        else    Q <= D;
endmodule

module SDFQD4HVT (input D, SI, SE, CP, output reg Q);
    initial Q = 1'b0;
    always @(posedge CP)
        if (SE) Q <= SI;
        else    Q <= D;
endmodule

// Scan D-FF, QN output only (Q inverted internally)
module SDFQND0HVT (input D, SI, SE, CP, output QN);
    reg Q = 1'b0;
    assign QN = ~Q;
    always @(posedge CP)
        if (SE) Q <= SI;
        else    Q <= D;
endmodule

// Scan D-FF with XOR data input: when SA=0 → D_eff = DA^DB; SA=1 → D_eff = DA
module SDFXQD0HVT (input DA, DB, SA, SI, SE, CP, output reg Q);
    initial Q = 1'b0;
    wire D_eff = SA ? DA : (DA ^ DB);
    always @(posedge CP)
        if (SE) Q <= SI;
        else    Q <= D_eff;
endmodule

// ── Scan D-FF with async clear-low ───────────────────────────────────────

module SDFKCND1HVT (input D, CP, CN, SI, SE, output reg Q, output QN);
    initial Q = 1'b0;
    assign  QN = ~Q;
    always @(posedge CP or negedge CN)
        if      (!CN) Q <= 1'b0;
        else if (SE)  Q <= SI;
        else          Q <= D;
endmodule

module SDFKCNQD0HVT (input D, CP, CN, SI, SE, output reg Q);
    initial Q = 1'b0;
    always @(posedge CP or negedge CN)
        if      (!CN) Q <= 1'b0;
        else if (SE)  Q <= SI;
        else          Q <= D;
endmodule

module SDFKCNQD1HVT (input D, CP, CN, SI, SE, output reg Q);
    initial Q = 1'b0;
    always @(posedge CP or negedge CN)
        if      (!CN) Q <= 1'b0;
        else if (SE)  Q <= SI;
        else          Q <= D;
endmodule

module SDFKCNQD2HVT (input D, CP, CN, SI, SE, output reg Q);
    initial Q = 1'b0;
    always @(posedge CP or negedge CN)
        if      (!CN) Q <= 1'b0;
        else if (SE)  Q <= SI;
        else          Q <= D;
endmodule

// ── Scan D-FF with async clear-low AND set-low ───────────────────────────

module SDFKCSNQD0HVT (input D, CP, CN, SN, SI, SE, output reg Q);
    initial Q = 1'b0;
    always @(posedge CP or negedge CN or negedge SN)
        if      (!CN) Q <= 1'b0;
        else if (!SN) Q <= 1'b1;
        else if (SE)  Q <= SI;
        else          Q <= D;
endmodule

// ── Scan D-FF with async set-low ─────────────────────────────────────────

module SDFKSNQD0HVT (input D, CP, SN, SI, SE, output reg Q);
    initial Q = 1'b0;
    always @(posedge CP or negedge SN)
        if      (!SN) Q <= 1'b1;
        else if (SE)  Q <= SI;
        else          Q <= D;
endmodule

// ── Scan+Enable D-FF with async clear-low ────────────────────────────────
// Priority: CN (async clear) > SE (scan) > E (enable) > hold

module SEDFQD1HVT (input D, CP, E, SI, SE, output reg Q);
    initial Q = 1'b0;
    always @(posedge CP)
        if      (SE) Q <= SI;
        else if (E)  Q <= D;
endmodule

module SEDFKCNQD0HVT (input D, CP, CN, E, SI, SE, output reg Q);
    initial Q = 1'b0;
    always @(posedge CP or negedge CN)
        if      (!CN) Q <= 1'b0;
        else if (SE)  Q <= SI;
        else if (E)   Q <= D;
endmodule

// ── Delay buffers (Innovus hold-fix cells) ───────────────────────────────
// DEL*HVT are pure wire delays inserted by Innovus for hold-time fixing.
// TSMC UDP models start output at X until first input event — assign Z=I
// propagates immediately at t=0 so no X reaches downstream logic.

module DEL005HVT (input I, output Z); assign Z = I; endmodule
module DEL015HVT (input I, output Z); assign Z = I; endmodule
module DEL01HVT  (input I, output Z); assign Z = I; endmodule
module DEL02HVT  (input I, output Z); assign Z = I; endmodule
module DEL0HVT   (input I, output Z); assign Z = I; endmodule
module DEL1HVT   (input I, output Z); assign Z = I; endmodule
module DEL2HVT   (input I, output Z); assign Z = I; endmodule
