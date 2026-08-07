`timescale 1ns/1ps

module testbench;

    reg        clk_16mhz = 0;
    wire       pin_1;
    reg        pin_2    = 0;
    wire [3:0] user_leds;
    wire       qspi_sck;
    wire       qspi_cs_n;
    wire [3:0] qspi_io_out;
    wire [3:0] qspi_io_in;          // driven by qspi_flash_model
    wire       qspi_io_oe;

    always #31.25 clk_16mhz = ~clk_16mhz;

    hardware dut (
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

    // ── QSPI flash behavioral model ──────────────────────────────────────────
    // Loads seizure_1.hex (input), global_weights.hex (weights), global_bias.hex (bias)
    // Responds to 0xEB Quad I/O Fast Read from qspi_master in hardware DUT.
    qspi_flash_model flash_model (
        .clk         (clk_16mhz),
        .qspi_sck    (qspi_sck),
        .qspi_cs_n   (qspi_cs_n),
        .qspi_io_out (qspi_io_out),
        .qspi_io_in  (qspi_io_in),
        .qspi_io_oe  (qspi_io_oe)
    );

    // ─────────────────────────────────────────────────────────────────────────
    // SRAM 1: picosoc_sram_2048x32  (CPU firmware)
    //   ARM MUX-16 | 128 rows x 512 bits
    //   Pack: mem[row][col + bit*16] = word[row*16+col][bit]  (32-bit word)
    // ─────────────────────────────────────────────────────────────────────────
    integer    _r, _c, _b;
    reg [31:0]  cpu_rom [0:2047];
    reg [511:0] cpu_row;
    reg [31:0]  cpu_rb;
    integer     cpu_err = 0;

    // ─────────────────────────────────────────────────────────────────────────
    // SRAM 2 & 3: lut_sram_1024x16  (reciprocal LUT + sigmoid LUT)
    //   ARM MUX-16 | 64 rows x 256 bits
    //   Pack: mem[row][col + bit*16] = word[row*16+col][bit]  (16-bit word)
    // ─────────────────────────────────────────────────────────────────────────
    reg [15:0]  rec_rom [0:1023];
    reg [255:0] rec_row;
    reg [15:0]  rec_rb;
    integer     rec_err = 0;

    reg [15:0]  sig_rom [0:1023];
    reg [255:0] sig_row;
    reg [15:0]  sig_rb;
    integer     sig_err = 0;

    integer total_err = 0;

    // ─────────────────────────────────────────────────────────────────────────
    // Golden reference arrays
    // ─────────────────────────────────────────────────────────────────────────
    reg [15:0] golden_layer9  [0:479];   // layer_9_dense_golden
    reg [15:0] golden_layer10 [0:479];   // layer_10_dense_golden
    reg [15:0] golden_sigmoid [0:0];     // layer_11_sigmoid_golden

    // ── Ping/pong SRAM shadow mirrors ────────────────────────────────────────
    reg [15:0] ping_shadow [0:4095];
    reg [15:0] pong_shadow [0:4095];
    integer    ping_write_cnt = 0;
    integer    pong_write_cnt = 0;

    // ── Sigmoid capture ───────────────────────────────────────────────────────
    reg [15:0] captured_sigmoid = 0;
    reg        sigmoid_captured = 0;

    // ── Comparison variables ──────────────────────────────────────────────────
    integer    errors   = 0;
    integer    diff     = 0;
    integer    max_err  = -10000;
    integer    min_err  = 10000;
    integer    i        = 0;

    // Log file handles
    integer qspi_log_fd;
    integer pe_log_fd;

    initial begin
        #1;

        // =====================================================================
        // SRAM 1 — CPU firmware (picosoc_sram_2048x32)
        // =====================================================================
        $display("------------------------------------------------------------");
        $display("[SRAM1] Loading CPU firmware...");
        $readmemh("/home/users/2035ayush/Ayush/neonatal/sourcecode/tb/veeresh_compiler/veeresh_compiler.hex",
                  cpu_rom);
        $display("[SRAM1] hex read.  word[0]=0x%08h  word[1]=0x%08h",
                 cpu_rom[0], cpu_rom[1]);

        for (_r = 0; _r < 128; _r = _r + 1) begin
            cpu_row = 512'd0;
            for (_c = 0; _c < 16; _c = _c + 1)
                for (_b = 0; _b < 32; _b = _b + 1)
                    cpu_row[_c + _b*16] = cpu_rom[_r*16 + _c][_b];
            dut.soc_memory_u_sram.mem[_r] = cpu_row;
        end

        cpu_err = 0;
        for (_r = 0; _r < 2048; _r = _r + 1) begin
            cpu_rb = 32'd0;
            for (_b = 0; _b < 32; _b = _b + 1)
                cpu_rb[_b] = dut.soc_memory_u_sram.mem[_r/16][(_r%16) + _b*16];
            if (cpu_rb !== cpu_rom[_r]) begin
                $display("[SRAM1 MISMATCH] addr=%0d  wrote=0x%08h  read=0x%08h",
                         _r, cpu_rom[_r], cpu_rb);
                cpu_err = cpu_err + 1;
                if (cpu_err >= 10) begin $display("[SRAM1 ABORT]"); $finish; end
            end
        end
        if (cpu_err == 0) $display("[SRAM1 PASS] All 2048 words OK.");
        else              $display("[SRAM1 FAIL] %0d errors.", cpu_err);

        // =====================================================================
        // SRAM 2 — Reciprocal LUT (lut_sram_1024x16)
        // =====================================================================
        $display("------------------------------------------------------------");
        $display("[SRAM2] Loading reciprocal LUT...");
        $readmemh("/home/users/2035ayush/Ayush/neonatal/sourcecode/tb/veeresh_compiler/build_output/hex/reciprocal_lut.hex",
                  rec_rom);
        $display("[SRAM2] hex read.  word[0]=0x%04h  word[512]=0x%04h",
                 rec_rom[0], rec_rom[512]);

        for (_r = 0; _r < 64; _r = _r + 1) begin
            rec_row = 256'd0;
            for (_c = 0; _c < 16; _c = _c + 1)
                for (_b = 0; _b < 16; _b = _b + 1)
                    rec_row[_c + _b*16] = rec_rom[_r*16 + _c][_b];
            dut.decoder_acc_inst_rms_norm_lut_inst_u_recip_lut.mem[_r] = rec_row;
        end

        rec_err = 0;
        for (_r = 0; _r < 1024; _r = _r + 1) begin
            rec_rb = 16'd0;
            for (_b = 0; _b < 16; _b = _b + 1)
                rec_rb[_b] = dut.decoder_acc_inst_rms_norm_lut_inst_u_recip_lut.mem[_r/16][(_r%16) + _b*16];
            if (rec_rb !== rec_rom[_r]) begin
                $display("[SRAM2 MISMATCH] addr=%0d  wrote=0x%04h  read=0x%04h",
                         _r, rec_rom[_r], rec_rb);
                rec_err = rec_err + 1;
                if (rec_err >= 10) begin $display("[SRAM2 ABORT]"); $finish; end
            end
        end
        if (rec_err == 0) $display("[SRAM2 PASS] All 1024 words OK.");
        else              $display("[SRAM2 FAIL] %0d errors.", rec_err);

        // Pre-init Q_int=0 so ARM model does not start with X; first real read overwrites it.
        dut.decoder_acc_inst_rms_norm_lut_inst_u_recip_lut.Q_int = 16'h0000;
        $display("[SRAM2] Q_int pre-initialized to 0x0000 (will be overwritten on first read).");

        // =====================================================================
        // SRAM 3 — Sigmoid LUT (lut_sram_1024x16)
        // =====================================================================
        $display("------------------------------------------------------------");
        $display("[SRAM3] Loading sigmoid LUT...");
        $readmemh("/home/users/2035ayush/Ayush/neonatal/sourcecode/tb/veeresh_compiler/build_output/hex/sigmoid_lut.hex",
                  sig_rom);
        $display("[SRAM3] hex read.  word[0]=0x%04h  word[512]=0x%04h",
                 sig_rom[0], sig_rom[512]);

        for (_r = 0; _r < 64; _r = _r + 1) begin
            sig_row = 256'd0;
            for (_c = 0; _c < 16; _c = _c + 1)
                for (_b = 0; _b < 16; _b = _b + 1)
                    sig_row[_c + _b*16] = sig_rom[_r*16 + _c][_b];
            dut.decoder_acc_inst_u_sigmoid_u_sigmoid_lut.mem[_r] = sig_row;
        end

        sig_err = 0;
        for (_r = 0; _r < 1024; _r = _r + 1) begin
            sig_rb = 16'd0;
            for (_b = 0; _b < 16; _b = _b + 1)
                sig_rb[_b] = dut.decoder_acc_inst_u_sigmoid_u_sigmoid_lut.mem[_r/16][(_r%16) + _b*16];
            if (sig_rb !== sig_rom[_r]) begin
                $display("[SRAM3 MISMATCH] addr=%0d  wrote=0x%04h  read=0x%04h",
                         _r, sig_rom[_r], sig_rb);
                sig_err = sig_err + 1;
                if (sig_err >= 10) begin $display("[SRAM3 ABORT]"); $finish; end
            end
        end
        if (sig_err == 0) $display("[SRAM3 PASS] All 1024 words OK.");
        else              $display("[SRAM3 FAIL] %0d errors.", sig_err);

        // =====================================================================
        $display("------------------------------------------------------------");
        total_err = cpu_err + rec_err + sig_err;
        if (total_err == 0)
            $display("[ALL PASS] All 3 SRAMs verified. Backdoor load working.");
        else
            $display("[TOTAL FAIL] %0d errors across all SRAMs.", total_err);

        // =====================================================================
        // Block 4 — Open log files
        // =====================================================================
        $display("------------------------------------------------------------");
        $display("[LOGS] Opening log files...");
        qspi_log_fd = $fopen("/tmp/qspi_log.txt", "w");
        pe_log_fd   = $fopen("/tmp/pe_log.txt",   "w");
        if (qspi_log_fd == 0) $display("[LOGS WARN] Failed to open qspi_log.txt");
        else                  $display("[LOGS OK] qspi_log.txt opened fd=%0d", qspi_log_fd);
        if (pe_log_fd == 0)   $display("[LOGS WARN] Failed to open pe_log.txt");
        else                  $display("[LOGS OK] pe_log.txt opened fd=%0d", pe_log_fd);
        $fdisplay(qspi_log_fd, "TYPE     BYTE_ADDR  WORD_IDX  FETCHED   EXPECTED  STATUS");
        $fdisplay(pe_log_fd,   "WADDR  PSUM");

        // =====================================================================
        // Golden 1 — layer_9_dense (480 x 16-bit, odd/pong buffer)
        // =====================================================================
        $display("------------------------------------------------------------");
        $display("[GOLDEN9] Loading layer_9_dense_golden...");
        $readmemh("/home/users/2035ayush/Ayush/neonatal/sourcecode/tb/veeresh_compiler/build_output/golden/layer_9_dense_golden.hex",
                  golden_layer9);
        $display("[GOLDEN9] word[0]=0x%04h  word[1]=0x%04h  word[479]=0x%04h",
                 golden_layer9[0], golden_layer9[1], golden_layer9[479]);

        // =====================================================================
        // Golden 2 — layer_10_dense (480 x 16-bit, even/ping buffer)
        // =====================================================================
        $display("------------------------------------------------------------");
        $display("[GOLDEN10] Loading layer_10_dense_golden...");
        $readmemh("/home/users/2035ayush/Ayush/neonatal/sourcecode/tb/veeresh_compiler/build_output/golden/layer_10_dense_golden.hex",
                  golden_layer10);
        $display("[GOLDEN10] word[0]=0x%04h  word[1]=0x%04h  word[479]=0x%04h",
                 golden_layer10[0], golden_layer10[1], golden_layer10[479]);

        // =====================================================================
        // Golden 3 — layer_11_sigmoid (1 x 16-bit, final output)
        // =====================================================================
        $display("------------------------------------------------------------");
        $display("[GOLDEN11] Loading layer_11_sigmoid_golden...");
        $readmemh("/home/users/2035ayush/Ayush/neonatal/sourcecode/tb/veeresh_compiler/build_output/golden/layer_11_sigmoid_golden.hex",
                  golden_sigmoid);
        $display("[GOLDEN11] golden_sigmoid[0]=0x%04h", golden_sigmoid[0]);

        $display("------------------------------------------------------------");
        $display("[INIT COMPLETE] All SRAMs loaded. All golden files loaded. Log files open.");

        // =====================================================================
        // Reset sequence — hold 100 cycles then release
        // =====================================================================
        $display("[RESET] pin_2=0, holding reset for 100 cycles...");
        repeat(100) @(posedge clk_16mhz);
        pin_2 = 1'b1;
        $display("[RESET] pin_2=1 at t=%0t — reset released. Hardware running.", $time);

        // Re-init recip_lut mem[] after reset: startup CEN=X glitch may have
        // triggered failedWrite and corrupted all mem[] to X before this point.
        for (_r = 0; _r < 64; _r = _r + 1) begin
            rec_row = 256'd0;
            for (_c = 0; _c < 16; _c = _c + 1)
                for (_b = 0; _b < 16; _b = _b + 1)
                    rec_row[_c + _b*16] = rec_rom[_r*16 + _c][_b];
            dut.decoder_acc_inst_rms_norm_lut_inst_u_recip_lut.mem[_r] = rec_row;
        end
        dut.decoder_acc_inst_rms_norm_lut_inst_u_recip_lut.Q_int = 16'h0000;
        $display("[SRAM2 REINIT] recip_lut mem[] restored after reset. Q_int=0.");

        // Same fix for sigmoid LUT — same ARM model, same startup CEN=X corruption.
        for (_r = 0; _r < 64; _r = _r + 1) begin
            sig_row = 256'd0;
            for (_c = 0; _c < 16; _c = _c + 1)
                for (_b = 0; _b < 16; _b = _b + 1)
                    sig_row[_c + _b*16] = sig_rom[_r*16 + _c][_b];
            dut.decoder_acc_inst_u_sigmoid_u_sigmoid_lut.mem[_r] = sig_row;
        end
        dut.decoder_acc_inst_u_sigmoid_u_sigmoid_lut.Q_int = 16'h0000;
        $display("[SRAM3 REINIT] sigmoid_lut mem[] restored after reset. Q_int=0.");

        $display("Hardware Simulation Started...");

        // =====================================================================
        // Wait for hardware to signal completion via user_leds[0]
        // =====================================================================
        wait(user_leds[0] == 1'b1);
        $display("[DONE] user_leds[0] asserted at t=%0t — hardware signaled done.", $time);

        // =====================================================================
        // Comparison — odd layers → pong_shadow vs golden_layer9
        // =====================================================================
        $display("Starting Comparison...");
        for (i = 0; i < 480; i = i + 1) begin
            if (golden_layer9[i] !== 16'hxxxx) begin
                diff = pong_shadow[i] - golden_layer9[i];
                if (diff > max_err) max_err = diff;
                if (diff < min_err) min_err = diff;
                if (diff !== 0) begin
                    $display("odd [FAIL] Index %0d: Expected %04h, Got %04h (Diff: %0d)",
                             i, golden_layer9[i], pong_shadow[i], diff);
                    errors = errors + 1;
                end else begin
                    $display("odd [PASS] Index %0d: Expected %04h, Got %04h",
                             i, golden_layer9[i], pong_shadow[i]);
                end
            end
        end

        // =====================================================================
        // Comparison — even layers → ping_shadow vs golden_layer10
        // =====================================================================
        for (i = 0; i < 480; i = i + 1) begin
            if (golden_layer10[i] !== 16'hxxxx) begin
                diff = ping_shadow[i] - golden_layer10[i];
                if (diff > max_err) max_err = diff;
                if (diff < min_err) min_err = diff;
                if (diff !== 0) begin
                    $display("even [FAIL] Index %0d: Expected %04h, Got %04h (Diff: %0d)",
                             i, golden_layer10[i], ping_shadow[i], diff);
                    errors = errors + 1;
                end else begin
                    $display("even [PASS] Index %0d: Expected %04h, Got %04h",
                             i, golden_layer10[i], ping_shadow[i]);
                end
            end
        end

        // =====================================================================
        // Final sigmoid comparison
        // =====================================================================
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

        if (captured_sigmoid > 16'h8000) $display("----Seizure----");
        else                             $display("----NO Seizure----");

        if (errors == 0)
            $display("SUCCESSFUL!");
        else begin
            $display("FAILED with %0d errors.", errors);
            $display("Max error: %0d  Min error: %0d", max_err, min_err);
        end

        $finish;
    end

    // ── Ping/pong SRAM shadow mirrors ────────────────────────────────────────
    // CEN active-low: ~psum_mem_ping_sram_n_6 = chip enabled
    // WEN active-low: ~psum_mem_ping_sram_n_7 = write enabled
    // Shared data bus: decoder_pp_wdata
    always @(posedge clk_16mhz) begin
        if (!dut.psum_mem_ping_sram_n_6 && !dut.psum_mem_ping_sram_n_7) begin
            ping_shadow[dut.psum_mem_ping_addr] <= dut.decoder_pp_wdata;
            if (ping_write_cnt < 10) begin
                $display("[PING] Write #%0d: addr=%0d data=0x%04h recip_q=0x%04h t=%0t",
                         ping_write_cnt, dut.psum_mem_ping_addr, dut.decoder_pp_wdata,
                         dut.decoder_acc_inst_rms_norm_lut_inst_lut_q, $time);
                ping_write_cnt <= ping_write_cnt + 1;
            end
        end
        if (!dut.psum_mem_pong_sram_n_6 && !dut.psum_mem_pong_sram_n_7) begin
            pong_shadow[dut.psum_mem_pong_addr] <= dut.decoder_pp_wdata;
            if (pong_write_cnt < 10) begin
                $display("[PONG] Write #%0d: addr=%0d data=0x%04h t=%0t",
                         pong_write_cnt, dut.psum_mem_pong_addr, dut.decoder_pp_wdata, $time);
                pong_write_cnt <= pong_write_cnt + 1;
            end
        end
    end

    // ── Recip LUT access monitor — disabled for GLS (n_2360 net renamed in new netlist) ──
    // integer _rlut_cnt = 0;
    // always @(negedge dut.decoder_acc_inst_rms_norm_lut_inst_n_2360) begin
    //     if (_rlut_cnt < 5) begin
    //         $display("[RLUT] CEN low #%0d: addr_d1=%03h recip_q=%04h t=%0t",
    //                  _rlut_cnt,
    //                  dut.decoder_acc_inst_rms_norm_lut_inst_addr_d1,
    //                  dut.decoder_acc_inst_rms_norm_lut_inst_lut_q,
    //                  $time);
    //         _rlut_cnt = _rlut_cnt + 1;
    //     end
    // end

    // ── Sigmoid capture: pcpi_insn[31:25]==0001111 (funct7=0x0F) ─────────────
    always @(posedge clk_16mhz) begin
        if (dut.pcpi_valid && dut.pcpi_ready && (dut.pcpi_insn[31:25] == 7'b0001111)) begin
            captured_sigmoid <= dut.pcpi_rd[15:0];
            sigmoid_captured <= 1'b1;
        end
    end

    // ── CPU TRAP monitor ─────────────────────────────────────────────────────
    // trap is UNCONNECTED in synthesis netlist — monitor disabled for GLS
    // always @(posedge clk_16mhz) begin
    //     if (dut.soc_cpu.trap)
    //         $display("[CPU_TRAP] CPU trapped at t=%0t", $time);
    // end

    // ── user_leds change monitor ─────────────────────────────────────────────
    always @(user_leds)
        $display("[LEDS] user_leds changed to %04b at t=%0t", user_leds, $time);

    // ── Heartbeat every 500K cycles ──────────────────────────────────────────
    integer _hb = 0;
    always @(posedge clk_16mhz) begin
        _hb = _hb + 1;
        if (_hb % 500_000 == 0)
            $display("[HB] %0dK cycles elapsed. user_leds=%04b  pc=0x%08h  pcpi=%b  t=%0t",
                     _hb/1000, user_leds,
                     dut.soc_mem_addr, dut.pcpi_valid, $time);
    end

    // ── QSPI activity monitor (first 10 transactions) ────────────────────────
    integer _qspi_cnt = 0;
    always @(negedge qspi_cs_n) begin
        if (_qspi_cnt < 10) begin
            $display("[QSPI] CS asserted (transaction %0d) at t=%0t", _qspi_cnt+1, $time);
            _qspi_cnt = _qspi_cnt + 1;
        end
    end

    // ── Watchdog: kill simulation if hardware never completes ─────────────────
    initial begin
        repeat(20_000_000) @(posedge clk_16mhz);
        $display("[WATCHDOG] Timeout after 20M cycles — hardware did not complete.");
        $display("[WATCHDOG] user_leds=%04b  qspi_cs_n=%b", user_leds, qspi_cs_n);
        $finish;
    end

endmodule

// ============================================================================
// QSPI Flash Behavioral Model
// Author: Ayush Aman
//
// Responds to Quad I/O Fast Read (0xEB) from qspi_master.
// Flash memory map (byte-addressed):
//   input  : 0x000000  (16-bit x 4096  entries) — seizure_1.hex
//   weight : 0x002000  (16-bit x 65536 entries) — global_weights.hex
//   bias   : 0x022000  (32-bit x 1024  entries) — global_bias.hex
// ============================================================================
`timescale 1ns/1ps
module qspi_flash_model (
    input  wire       clk,
    input  wire       qspi_sck,
    input  wire       qspi_cs_n,
    input  wire [3:0] qspi_io_out,  // master → flash
    output reg  [3:0] qspi_io_in,   // flash  → master
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
    $readmemh("/home/users/2035ayush/Ayush/neonatal/sourcecode/tb/veeresh_compiler/build_output/hex/seizure_1.hex",
              flash_input);
    $readmemh("/home/users/2035ayush/Ayush/neonatal/sourcecode/tb/veeresh_compiler/build_output/hex/global_weights.hex",
              flash_weight);
    $readmemh("/home/users/2035ayush/Ayush/neonatal/sourcecode/tb/veeresh_compiler/build_output/hex/global_bias.hex",
              flash_bias);
    qspi_io_in = 4'b0;
    $display("[FLASH] Loaded: input[0]=0x%04h  weight[0]=0x%04h  bias[0]=0x%08h",
             flash_input[0], flash_weight[0], flash_bias[0]);
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

// TX handoff
reg [31:0] tx_data;
reg [3:0]  tx_nibbles;
reg        tx_start;

// TX shift state
reg [31:0] tx_shift;
reg [3:0]  tx_rem;
reg        tx_active;

// ── posedge clk: receive CMD / ADDR / DUMMY ─────────────────────────────────
always @(posedge clk) begin
    if (qspi_cs_n) begin
        rx_state   <= RX_CMD;
        rx_cnt     <= 4'd7;
        rx_cmd     <= 8'b0;
        rx_addr    <= 24'b0;
        tx_start   <= 1'b0;
        tx_data    <= 32'b0;
        tx_nibbles <= 4'b0;
    end else begin
        #1;
        tx_start <= 1'b0;

        case (rx_state)
        RX_CMD: begin
            rx_cmd <= {rx_cmd[6:0], qspi_io_out[0]};
            if (rx_cnt == 4'd0) begin
                rx_cnt   <= 4'd5;
                rx_state <= RX_ADDR;
            end else rx_cnt <= rx_cnt - 1;
        end
        RX_ADDR: begin
            rx_addr <= {rx_addr[19:0], qspi_io_out};
            if (rx_cnt == 4'd0) begin
                rx_cnt   <= 4'd3;
                rx_state <= RX_DUMMY;
            end else rx_cnt <= rx_cnt - 1;
        end
        RX_DUMMY: begin
            if (rx_cnt == 4'd0) begin
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
                tx_start <= 1'b1;
                rx_state <= RX_DATA;
            end else rx_cnt <= rx_cnt - 1;
        end
        RX_DATA: ;
        endcase
    end
end

// ── negedge clk: drive DATA nibbles to master ───────────────────────────────
always @(negedge clk) begin
    if (qspi_cs_n) begin
        qspi_io_in <= 4'b0;
        tx_active  <= 1'b0;
        tx_rem     <= 4'b0;
        tx_shift   <= 32'b0;
    end else if (tx_start) begin
        qspi_io_in <= tx_data[31:28];
        tx_shift   <= {tx_data[27:0], 4'b0};
        tx_rem     <= tx_nibbles - 1;
        tx_active  <= 1'b1;
    end else if (tx_active) begin
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
