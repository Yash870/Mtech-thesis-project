`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Create Date: 30.03.2026 11:15:06
// Module Name: test_hardware
// Project Name: neonatal hardware
//
// Author : Veeresh S 
//////////////////////////////////////////////////////////////////////////////////


module test_hardware();
    reg           clk_16mhz;

    // hardware UART
    wire          pin_1;
    reg           pin_2;

    // onboard LEDs - 4 LEDs for debugging
    wire [3:0]    user_leds;
    
    // QSPI flash interface wires
    wire         qspi_sck;
    wire         qspi_cs_n;
    wire [3:0]   qspi_io_out;
    wire [3:0]   qspi_io_in;
    wire         qspi_io_oe;
    
    
    reg [15:0] golden_sigmoid [0:0]; // Only 1 value expected
    reg [15:0] captured_sigmoid;     // To store the sniffed value
    reg        sigmoid_captured = 0; // Flag to know when we caught it

    reg [15:0] golden_layer [0:479];
    reg [15:0] golden_layer2 [0:479];
    integer i=0;
    integer errors=0;
    integer diff=0,max_err=-10000,min_err = 10000;

    // Shadow copies of ping/pong SRAMs for TB readback.
    // scratchpad_sram now uses ARM SRAM macro (no .ram[] array).
    // These mirrors capture every write so the comparison loop can still use [i] indexing.
    reg [15:0] ping_shadow [0:4095];
    reg [15:0] pong_shadow [0:4095];
    integer    ping_write_cnt = 0;
    integer    pong_write_cnt = 0;
    reg        pe0_ifmap_first_write_done = 0;
    reg        pe0_weight_first_write_done = 0;

    // Sigmoid LUT SRAM initialisation
    // Loads sigmoid_lut.hex and packs it into lut_sram_1024x16's MUX-16
    // interleaved mem[] via hierarchical reference.
    // Must run before first clock edge reaches the SRAM.
    integer      _sig_r, _sig_c, _sig_b;
    reg [15:0]   _sig_rom [0:1023];
    reg [255:0]  _sig_row;

    // Reciprocal LUT SRAM initialisation
    integer      _rec_r, _rec_c, _rec_b;
    reg [15:0]   _rec_rom [0:1023];
    reg [255:0]  _rec_row;

    // CPU firmware SRAM initialisation (picosoc_sram_2048x32, MUX-16)
    // picosoc_mem no longer has $readmemh — loaded here via hierarchical write.
    // 2048 words x 32 bits -> 128 rows x 512 bits; pack: mem[r][col + bit*16] = rom[r*16+col][bit]
    integer      _cpu_r, _cpu_c, _cpu_b;
    reg [31:0]   _cpu_rom [0:2047];
    reg [511:0]  _cpu_row;
    reg [31:0]   _cpu_verify;    // readback spot-check word

    initial begin
        $readmemh("/home/users/2035ayush/Ayush/neonatal/sourcecode/tb/veeresh_compiler/build_output/hex/reciprocal_lut.hex",
                  _rec_rom);
        $display("[REC_INIT] hex loaded.  _rec_rom[0]=0x%04h  _rec_rom[512]=0x%04h",
                 _rec_rom[0], _rec_rom[512]);
        for (_rec_r = 0; _rec_r < 64; _rec_r = _rec_r + 1) begin
            _rec_row = 256'd0;
            for (_rec_c = 0; _rec_c < 16; _rec_c = _rec_c + 1)
                for (_rec_b = 0; _rec_b < 16; _rec_b = _rec_b + 1)
                    _rec_row[_rec_c + _rec_b*16] = _rec_rom[_rec_r*16 + _rec_c][_rec_b];
            dut.decoder_acc_inst.rms_norm.lut_inst.u_recip_lut.mem[_rec_r] = _rec_row;
        end
        $display("[REC_INIT] mem packed.  row[0]=0x%064h",
                 dut.decoder_acc_inst.rms_norm.lut_inst.u_recip_lut.mem[0]);
    end

    initial begin
        $readmemh("/home/users/2035ayush/Ayush/neonatal/sourcecode/tb/veeresh_compiler/veeresh_compiler.hex",
                  _cpu_rom);
        $display("[CPU_INIT] hex loaded.  rom[0]=0x%08h  rom[1]=0x%08h  rom[2]=0x%08h",
                 _cpu_rom[0], _cpu_rom[1], _cpu_rom[2]);
        for (_cpu_r = 0; _cpu_r < 128; _cpu_r = _cpu_r + 1) begin
            _cpu_row = 512'd0;
            for (_cpu_c = 0; _cpu_c < 16; _cpu_c = _cpu_c + 1)
                for (_cpu_b = 0; _cpu_b < 32; _cpu_b = _cpu_b + 1)
                    _cpu_row[_cpu_c + _cpu_b*16] = _cpu_rom[_cpu_r*16 + _cpu_c][_cpu_b];
            dut.soc.memory.u_sram.mem[_cpu_r] = _cpu_row;
        end
        // Readback spot-check: addr=0 -> row=0, col=0, Q[k]=mem[0][k*16]
        _cpu_verify = 32'd0;
        for (_cpu_b = 0; _cpu_b < 32; _cpu_b = _cpu_b + 1)
            _cpu_verify[_cpu_b] = dut.soc.memory.u_sram.mem[0][_cpu_b * 16];
        $display("[CPU_INIT] mem packed. readback[addr=0]=0x%08h expected=0x%08h %s",
                 _cpu_verify, _cpu_rom[0],
                 (_cpu_verify === _cpu_rom[0]) ? "OK" : "MISMATCH");
    end

    initial begin
        $readmemh("/home/users/2035ayush/Ayush/neonatal/sourcecode/tb/veeresh_compiler/build_output/hex/sigmoid_lut.hex",
                  _sig_rom);
        $display("[SIG_INIT] hex loaded.  _sig_rom[0]=0x%04h  _sig_rom[512]=0x%04h (expect ~0000 and ~8000)",
                 _sig_rom[0], _sig_rom[512]);
        for (_sig_r = 0; _sig_r < 64; _sig_r = _sig_r + 1) begin
            _sig_row = 256'd0;
            for (_sig_c = 0; _sig_c < 16; _sig_c = _sig_c + 1)
                for (_sig_b = 0; _sig_b < 16; _sig_b = _sig_b + 1)
                    _sig_row[_sig_c + _sig_b*16] = _sig_rom[_sig_r*16 + _sig_c][_sig_b];
            dut.decoder_acc_inst.u_sigmoid.u_sigmoid_lut.mem[_sig_r] = _sig_row;
        end
        $display("[SIG_INIT] mem packed.  row[32]=0x%064h",
                 dut.decoder_acc_inst.u_sigmoid.u_sigmoid_lut.mem[32]);
    end

    // ── Ping-pong SRAM shadow mirrors ───────────────────────────────────────
    // Mirror every write to scratchpad_sram into shadow arrays for TB comparison.
    always @(posedge clk_16mhz) begin
        if (dut.psum_mem.ping_sram.en && dut.psum_mem.ping_sram.wen) begin
            ping_shadow[dut.psum_mem.ping_sram.addr] <= dut.psum_mem.ping_sram.din;
            if (ping_write_cnt < 10) begin
                $display("[PING_SRAM] Write #%0d: addr=%0d data=0x%04h t=%0t",
                         ping_write_cnt, dut.psum_mem.ping_sram.addr,
                         dut.psum_mem.ping_sram.din, $time);
                ping_write_cnt <= ping_write_cnt + 1;
            end
        end
        if (dut.psum_mem.pong_sram.en && dut.psum_mem.pong_sram.wen) begin
            pong_shadow[dut.psum_mem.pong_sram.addr] <= dut.psum_mem.pong_sram.din;
            if (pong_write_cnt < 10) begin
                $display("[PONG_SRAM] Write #%0d: addr=%0d data=0x%04h t=%0t",
                         pong_write_cnt, dut.psum_mem.pong_sram.addr,
                         dut.psum_mem.pong_sram.din, $time);
                pong_write_cnt <= pong_write_cnt + 1;
            end
        end
    end

    // ── PE0 scratchpad_dual_port first-write debug ───────────────────────────
    always @(posedge clk_16mhz) begin
        if (dut.decoder_acc_inst.pe_array.PE0.ifmap0.wen && !pe0_ifmap_first_write_done) begin
            $display("[PE0_IFMAP] First write: addr=%0d data=0x%04h",
                     dut.decoder_acc_inst.pe_array.PE0.ifmap0.waddr,
                     dut.decoder_acc_inst.pe_array.PE0.ifmap0.wdata);
            pe0_ifmap_first_write_done <= 1;
        end
        if (dut.decoder_acc_inst.pe_array.PE0.weight0.wen && !pe0_weight_first_write_done) begin
            $display("[PE0_WEIGHT] First write: addr=%0d data=0x%04h",
                     dut.decoder_acc_inst.pe_array.PE0.weight0.waddr,
                     dut.decoder_acc_inst.pe_array.PE0.weight0.wdata);
            pe0_weight_first_write_done <= 1;
        end
    end

    // ── CPU debug: TRAP detection ────────────────────────────────────────────
    always @(posedge clk_16mhz) begin
        if (dut.soc.cpu.trap)
            $display("[CPU_TRAP] CPU trapped at time=%0t ns — check illegal instruction or misaligned access.", $realtime);
    end

    // ── CPU debug: first 10 instruction fetches ──────────────────────────────
    integer _dbg_ifetch_cnt = 0;
    always @(posedge clk_16mhz) begin
        if (_dbg_ifetch_cnt < 10 && dut.soc.mem_valid && dut.soc.mem_instr && dut.soc.mem_ready) begin
            $display("[CPU_IFETCH %0d] PC=0x%08h insn=0x%08h  t=%0t",
                     _dbg_ifetch_cnt, dut.soc.mem_addr, dut.soc.mem_rdata, $realtime);
            _dbg_ifetch_cnt <= _dbg_ifetch_cnt + 1;
        end
    end

    // ── CPU debug: first 10 data memory operations ───────────────────────────
    integer _dbg_dmem_cnt = 0;
    always @(posedge clk_16mhz) begin
        if (_dbg_dmem_cnt < 10 && dut.soc.mem_valid && !dut.soc.mem_instr && dut.soc.mem_ready) begin
            $display("[CPU_DMEM %0d] addr=0x%08h wstrb=%0b rdata=0x%08h wdata=0x%08h  t=%0t",
                     _dbg_dmem_cnt, dut.soc.mem_addr, dut.soc.mem_wstrb,
                     dut.soc.mem_rdata, dut.soc.mem_wdata, $realtime);
            _dbg_dmem_cnt <= _dbg_dmem_cnt + 1;
        end
    end

    // ── Watchdog: kill simulation if stuck ───────────────────────────────────
    initial begin
        repeat(20_000_000) @(posedge clk_16mhz);
        $display("[WATCHDOG] Timeout after 20M cycles — simulation did not complete.");
        $finish;
    end

    hardware dut(
        .clk_16mhz   (clk_16mhz),
        .pin_1       (pin_1),
        .pin_2       (pin_2),
        .user_leds   (user_leds),
        .qspi_sck    (qspi_sck),
        .qspi_cs_n   (qspi_cs_n),
        .qspi_io_out (qspi_io_out),
        .qspi_io_in  (qspi_io_in),
        .qspi_io_oe  (qspi_io_oe)
    );

    // QSPI flash behavioral model — responds to 0xEB quad reads from qspi_master
    qspi_flash_model flash_model (
        .clk         (clk_16mhz),
        .qspi_sck    (qspi_sck),
        .qspi_cs_n   (qspi_cs_n),
        .qspi_io_out (qspi_io_out),
        .qspi_io_in  (qspi_io_in),
        .qspi_io_oe  (qspi_io_oe)
    );
    
    
    initial begin
        clk_16mhz = 1'b0;
        forever begin
            #31.25 clk_16mhz = ~clk_16mhz;  // 16MHz clock
        end
    end

    always @(posedge clk_16mhz) begin
        // If CPU reads data from Sigmoid instruction (funct7 == 0x0F)
        if (dut.pcpi_valid && dut.pcpi_ready && (dut.pcpi_insn[31:25] == 7'b0001111)) begin
            captured_sigmoid <= dut.pcpi_rd[15:0];
            sigmoid_captured <= 1'b1;
        end
    end

    // ── Log file handles ────────────────────────────────────────────────────
    integer qspi_log_fd;
    integer pe_log_fd;

    initial begin
        qspi_log_fd = $fopen("/tmp/qspi_log.txt", "w");
        pe_log_fd   = $fopen("/tmp/pe_log.txt",   "w");
        $fdisplay(qspi_log_fd, "TYPE     BYTE_ADDR  WORD_IDX  FETCHED   EXPECTED  STATUS");
        $fdisplay(pe_log_fd,   "WADDR  PSUM");
    end

    // Log every QSPI transaction at S_CS_HOLD: data_shift holds raw received word
    always @(posedge clk_16mhz) begin
        if (dut.qspi_master_inst.state == 3'd6) begin  // S_CS_HOLD
            case (dut.qspi_master_inst.req_sel)
                2'd0: $fdisplay(qspi_log_fd, "INPUT    %06h     %0d\t%04h      %04h      %s",
                        dut.qspi_master_inst.flash_addr,
                        dut.qspi_master_inst.flash_addr >> 1,
                        dut.qspi_master_inst.data_shift[15:0],
                        flash_model.flash_input[dut.qspi_master_inst.flash_addr >> 1],
                        (dut.qspi_master_inst.data_shift[15:0] !== flash_model.flash_input[dut.qspi_master_inst.flash_addr >> 1]) ? "MISMATCH" : "ok");
                2'd1: $fdisplay(qspi_log_fd, "WEIGHT   %06h     %0d\t%04h      %04h      %s",
                        dut.qspi_master_inst.flash_addr,
                        (dut.qspi_master_inst.flash_addr - 24'h002000) >> 1,
                        dut.qspi_master_inst.data_shift[15:0],
                        flash_model.flash_weight[(dut.qspi_master_inst.flash_addr - 24'h002000) >> 1],
                        (dut.qspi_master_inst.data_shift[15:0] !== flash_model.flash_weight[(dut.qspi_master_inst.flash_addr - 24'h002000) >> 1]) ? "MISMATCH" : "ok");
                2'd2: $fdisplay(qspi_log_fd, "BIAS     %06h     %0d\t%08h  %08h  %s",
                        dut.qspi_master_inst.flash_addr,
                        (dut.qspi_master_inst.flash_addr - 24'h022000) >> 2,
                        dut.qspi_master_inst.data_shift[31:0],
                        flash_model.flash_bias[(dut.qspi_master_inst.flash_addr - 24'h022000) >> 2],
                        (dut.qspi_master_inst.data_shift[31:0] !== flash_model.flash_bias[(dut.qspi_master_inst.flash_addr - 24'h022000) >> 2]) ? "MISMATCH" : "ok");
            endcase
        end
    end

    // Log PE array output every time it writes a psum to ping-pong buffer
    always @(posedge clk_16mhz) begin
        if (dut.decoder_acc_inst.PEarray_M_valid && dut.decoder_acc_inst.PEarray_M_ready) begin
            $fdisplay(pe_log_fd, "%0d\t%04h",
                      dut.decoder_acc_inst.decoder_pp_waddr,
                      dut.decoder_acc_inst.PEarray_Psum_out);
        end
    end

    initial begin
        pin_2 = 1'b0;
        repeat(20) @(posedge clk_16mhz);
        pin_2 = 1'b1;
        
        
        //1,conv
        //2,rms
        //3,pool
        //4,conv
        //5,rms
        //6,pool
        //7,conv
        //8,rms
        //9,10, dense
        
        //have odd number layer on top and even number on bottom, starts form layer 1, not 0
        $readmemh("/home/users/2035ayush/Ayush/neonatal/sourcecode/tb/veeresh_compiler/build_output/golden/layer_9_dense_golden.hex", golden_layer2);
        $readmemh("/home/users/2035ayush/Ayush/neonatal/sourcecode/tb/veeresh_compiler/build_output/golden/layer_10_dense_golden.hex", golden_layer);
        $readmemh("/home/users/2035ayush/Ayush/neonatal/sourcecode/tb/veeresh_compiler/build_output/golden/layer_11_sigmoid_golden.hex", golden_sigmoid);
        
        $display("Hardware Simulation Started...");
        
        wait(user_leds[0] == 1'b1);
        
        $display("Starting Comparison...");
        //odd
        for (i = 0; i < 480; i = i + 1) begin
            if(golden_layer2[i] !== 16'hxxxx) begin
                diff = pong_shadow[i] - golden_layer2[i];
                if(diff > max_err) max_err = diff;
                if(diff < min_err) min_err = diff;
                if (diff !== 0) begin
                    $display("odd [FAIL] Index %0d: Expected %04h, Got %04h (Diff: %0d)",
                             i, golden_layer2[i], pong_shadow[i], diff);
                    errors = errors + 1;
                end else begin
                    $display("odd [PASS] Index %0d: Expected %04h, Got %04h",
                             i, golden_layer2[i], pong_shadow[i]);
                end
            end
        end
        //even
        for (i = 0; i < 480; i = i + 1) begin
            if(golden_layer[i] !== 16'hxxxx) begin
                diff = ping_shadow[i] - golden_layer[i];
                if(diff > max_err) max_err = diff;
                if(diff < min_err) min_err = diff;
                if (diff !== 0) begin
                    $display("even [FAIL] Index %0d: Expected %04h, Got %04h (Diff: %0d)",
                             i, golden_layer[i], ping_shadow[i], diff);
                    errors = errors + 1;
                end else begin
                    $display("even [PASS] Index %0d: Expected %04h, Got %04h",
                             i, golden_layer[i], ping_shadow[i]);
                end
            end
        end
        
        $display("Waiting for Final Sigmoid Output...");
        wait(sigmoid_captured == 1'b1);
        
        diff = captured_sigmoid - golden_sigmoid[0];
        if (diff !== 0) begin
            $display("[FAIL] FINAL SIGMOID: Expected %04h, Got %04h (Diff: %0d)",
                     golden_sigmoid[0], captured_sigmoid, diff);
            errors = errors + 1;
        end else begin
            $display("[SUCCESS] FINAL SIGMOID: Expected %04h, Got %04h", 
                     golden_sigmoid[0], captured_sigmoid);
        end
        
        if(captured_sigmoid>16'h8000) $display("----Seizure----");
        else $display("----NO Seizure----");

        if (errors == 0)
            $display("SUCCESSFUL!");
        else begin
            $display("FAILED with %0d errors.", errors);
            $display("Max error : %0d", max_err);
            $display("Min error : %0d", min_err);
        end

        $finish;
    end
endmodule

/////////////////////////////////////////////////////////////////////////////////////////
/*Author: Ayush Aman 

 * QSPI Flash Behavioral Model — testbench only
 *
 * Responds to Quad I/O Fast Read (0xEB) from qspi_master.
 * Loads same three hex files used previously by scratchpad_dual_port instances.
 *
 * Flash memory map (byte-addressed, matches qspi_master.v):
 *   input  : 0x000000  (16-bit x 4096  entries)
 *   weight : 0x002000  (16-bit x 65536 entries)
 *   bias   : 0x022000  (32-bit x 1024  entries)
 *
 * Timing strategy:
 *   posedge clk + #1 : sample CMD/ADDR (after master's non-blocking assignments
 *                       settle — avoids the SCK combinational glitch on CS assert)
 *   negedge clk      : drive DATA nibbles (half-period setup before master samples)
 *
 * NOTE: qspi_sck is accepted as input (physical pin) but not used for triggering.
 *       The combinational assign qspi_sck = clk & ~cs_n in qspi_master produces a
 *       spurious posedge during the NBA region when CS asserts, so we use posedge
 *       clk directly instead.
 */

`timescale 1ns/1ps
module qspi_flash_model (
    input  wire       clk,          // system clock (same as qspi_master)
    input  wire       qspi_sck,     // physical pin — accepted but not used for triggering
    input  wire       qspi_cs_n,
    input  wire [3:0] qspi_io_out,  // master -> flash
    output reg  [3:0] qspi_io_in,   // flash  -> master
    input  wire       qspi_io_oe    // 1 = master owns IO bus
);

// ── Memory arrays (word-addressed) ─────────────────────────────────────────
reg [15:0] flash_input  [0:4095];
reg [15:0] flash_weight [0:65535];
reg [31:0] flash_bias   [0:1023];

localparam [23:0] BASE_INPUT  = 24'h000000;
localparam [23:0] BASE_WEIGHT = 24'h002000;
localparam [23:0] BASE_BIAS   = 24'h022000;

initial begin
    $readmemh("/home/users/2035ayush/Ayush/neonatal/sourcecode/tb/veeresh_compiler/build_output/hex/seizure_1.hex",      flash_input);
    $readmemh("/home/users/2035ayush/Ayush/neonatal/sourcecode/tb/veeresh_compiler/build_output/hex/global_weights.hex", flash_weight);
    $readmemh("/home/users/2035ayush/Ayush/neonatal/sourcecode/tb/veeresh_compiler/build_output/hex/global_bias.hex",    flash_bias);
    qspi_io_in = 4'b0;
end

// ── RX state machine ────────────────────────────────────────────────────────
localparam RX_CMD   = 2'd0;
localparam RX_ADDR  = 2'd1;
localparam RX_DUMMY = 2'd2;
localparam RX_DATA  = 2'd3;

reg [1:0]  rx_state;
reg [3:0]  rx_cnt;
reg [7:0]  rx_cmd;
reg [23:0] rx_addr;

// TX handoff (written only by posedge block, read by negedge block)
reg [31:0] tx_data;     // MSB-aligned: 16-bit in [31:16], 32-bit in [31:0]
reg [3:0]  tx_nibbles;  // 4 for 16-bit, 8 for 32-bit
reg        tx_start;    // single-cycle pulse when data is ready

// TX shift state (written only by negedge block)
reg [31:0] tx_shift;
reg [3:0]  tx_rem;
reg        tx_active;

// ── posedge clk: receive CMD / ADDR / DUMMY ─────────────────────────────────
// Fires on every posedge clk; gated by qspi_cs_n.
// #1 delay ensures master's non-blocking assignments on qspi_io_out have settled.
always @(posedge clk) begin
    if (qspi_cs_n) begin
        // CS not asserted — hold reset state (runs every cycle until CS goes low)
        rx_state   <= RX_CMD;
        rx_cnt     <= 4'd7;
        rx_cmd     <= 8'b0;
        rx_addr    <= 24'b0;
        tx_start   <= 1'b0;
        tx_data    <= 32'b0;
        tx_nibbles <= 4'b0;
    end else begin
        // CS active: sample after master's NBAs settle
        #1;
        tx_start <= 1'b0;  // default: no start pulse this cycle

        case (rx_state)

        RX_CMD: begin
            // CMD phase: single-bit on IO0, MSB first, 8 cycles
            rx_cmd <= {rx_cmd[6:0], qspi_io_out[0]};
            if (rx_cnt == 4'd0) begin
                rx_cnt   <= 4'd5;   // 6 quad-cycles for ADDR
                rx_state <= RX_ADDR;
            end else rx_cnt <= rx_cnt - 1;
        end

        RX_ADDR: begin
            // ADDR phase: quad (4 bits/cycle), MSB first, 6 cycles = 24 bits
            rx_addr <= {rx_addr[19:0], qspi_io_out};
            if (rx_cnt == 4'd0) begin
                rx_cnt   <= 4'd3;   // 4 dummy cycles
                rx_state <= RX_DUMMY;
            end else rx_cnt <= rx_cnt - 1;
        end

        RX_DUMMY: begin
            // Dummy phase: 4 cycles, no data, just wait
            if (rx_cnt == 4'd0) begin
                // Decode byte address → word index → load MSB-aligned tx_data
                if (rx_addr < BASE_WEIGHT) begin
                    tx_data    <= {flash_input[(rx_addr - BASE_INPUT) >> 1], 16'b0};
                    tx_nibbles <= 4'd4;
                end else if (rx_addr < BASE_BIAS) begin
                    tx_data    <= {flash_weight[(rx_addr - BASE_WEIGHT) >> 1], 16'b0};
                    tx_nibbles <= 4'd4;
                end else begin
                    tx_data    <= flash_bias[(rx_addr - BASE_BIAS) >> 2];
                    tx_nibbles <= 4'd8;
                end
                tx_start <= 1'b1;   // pulse: negedge block will latch tx_data
                rx_state <= RX_DATA;
            end else rx_cnt <= rx_cnt - 1;
        end

        RX_DATA: ;  // DATA driven by negedge block; nothing to do here

        endcase
    end
end

// ── negedge clk: drive DATA nibbles to master ───────────────────────────────
// Fires half a clock period before posedge clk where master samples qspi_io_in.
// tx_start set by posedge block (NBAs settled before negedge fires).
always @(negedge clk) begin
    if (qspi_cs_n) begin
        qspi_io_in <= 4'b0;
        tx_active  <= 1'b0;
        tx_rem     <= 4'b0;
        tx_shift   <= 32'b0;
    end else if (tx_start) begin
        // First nibble: latch tx_data and start streaming
        qspi_io_in <= tx_data[31:28];
        tx_shift   <= {tx_data[27:0], 4'b0};   // pre-shift: remaining nibbles
        tx_rem     <= tx_nibbles - 1;
        tx_active  <= 1'b1;
    end else if (tx_active) begin
        // Subsequent nibbles
        qspi_io_in <= tx_shift[31:28];
        tx_shift   <= {tx_shift[27:0], 4'b0};
        if (tx_rem == 4'd0) begin
            tx_active  <= 1'b0;
            qspi_io_in <= 4'b0;
        end else tx_rem <= tx_rem - 1;
    end else begin
        qspi_io_in <= 4'b0;
    end
end

endmodule
