// picosoc_sram_init.v — Behavioral override for picosoc_sram_2048x32 ARM macro.
//
// In GLV, the synthesised netlist instantiates picosoc_sram_2048x32 (ARM macro)
// instead of picosoc_mem, so the RTL $readmemh path is not compiled.
// This override provides a simple synchronous SRAM with the same ARM port
// interface but initialises the memory array from the firmware hex at sim start.
//
// Compile order: must appear as a DIRECT FILE before the ARM macro (-v) in
// dut_src_list_glv.txt so that -v skips this module.
//
// Port semantics (ARM SP SRAM, active-low enables):
//   CEN  = chip enable (0 = active)
//   GWEN = global write enable (0 = any byte may be written)
//   WEN  = byte write enable [3:0] (0 = write that byte)
//   A    = word address [10:0] (2048 locations)
//   RETN = retention mode (1 = normal; tied to 1 in netlist)

module picosoc_sram_2048x32 (Q, CLK, CEN, WEN, A, D, EMA, GWEN, RETN);
    output reg [31:0] Q;
    input             CLK, CEN, GWEN, RETN;
    input      [3:0]  WEN;
    input      [10:0] A;
    input      [31:0] D;
    input      [2:0]  EMA;

    reg [31:0] mem [0:2047];

    initial begin
        $readmemh("/home/users/2035ayush/Ayush/neonatal/sourcecode/tb/veeresh_compiler/veeresh_compiler.hex", mem);
        $display("[GLV] picosoc_sram_init: firmware loaded. mem[0]=%08h mem[1]=%08h (expect 1840006f)", mem[0], mem[1]);
    end

    always @(posedge CLK) begin
        if (!CEN) begin
            if (!GWEN) begin
                if (!WEN[0]) mem[A][ 7: 0] <= D[ 7: 0];
                if (!WEN[1]) mem[A][15: 8] <= D[15: 8];
                if (!WEN[2]) mem[A][23:16] <= D[23:16];
                if (!WEN[3]) mem[A][31:24] <= D[31:24];
            end
            Q <= mem[A];
        end
    end
endmodule
