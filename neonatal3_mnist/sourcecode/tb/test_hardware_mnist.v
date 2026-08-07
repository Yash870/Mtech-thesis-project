`timescale 1ns/1ps

module test_hardware_mnist();
    reg clk_16mhz;
    wire pin_1;
    reg  pin_2;
    wire [3:0] user_leds;

    wire       qspi_sck;
    wire       qspi_cs_n;
    wire [3:0] qspi_io_out;
    wire [3:0] qspi_io_in;
    wire       qspi_io_oe;

    integer sample_start;
    integer sample_count;
    integer sample_idx;
    integer sample_errors;
    integer total_hw_pass;
    integer total_class_pass;
    integer total_hw_errors;
    integer summary_fd;
    string case_root;
    string summary_path;
    string input_path;
    string scores_path;
    string class_path;
    string argmax_path;

    reg [15:0] expected_scores [0:9];
    reg [31:0] expected_class  [0:0];
    reg [31:0] expected_argmax [0:0];
    reg [15:0] ping_shadow [0:4095];
    reg [15:0] pong_shadow [0:4095];

    integer i;
    integer ping_errors;
    integer pong_errors;
    integer use_ping;
    integer predicted_class;
    reg [15:0] best_score;
    integer done_seen;

    integer _sig_r, _sig_c, _sig_b;
    reg [15:0]  _sig_rom [0:1023];
    reg [255:0] _sig_row;

    integer _rec_r, _rec_c, _rec_b;
    reg [15:0]  _rec_rom [0:1023];
    reg [255:0] _rec_row;

    integer _cpu_r, _cpu_c, _cpu_b;
    reg [31:0]  _cpu_rom [0:2047];
    reg [511:0] _cpu_row;
    reg [31:0]  _cpu_verify;

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

    qspi_flash_model_mnist flash_model (
        .clk         (clk_16mhz),
        .qspi_sck    (qspi_sck),
        .qspi_cs_n   (qspi_cs_n),
        .qspi_io_out (qspi_io_out),
        .qspi_io_in  (qspi_io_in),
        .qspi_io_oe  (qspi_io_oe)
    );

    initial begin
        clk_16mhz = 1'b0;
        forever #31.25 clk_16mhz = ~clk_16mhz;
    end

    task automatic clear_shadows;
        begin
            for (i = 0; i < 4096; i = i + 1) begin
                ping_shadow[i] = 16'hxxxx;
                pong_shadow[i] = 16'hxxxx;
            end
        end
    endtask

    task automatic pack_cpu_sram;
        begin
            for (_cpu_r = 0; _cpu_r < 128; _cpu_r = _cpu_r + 1) begin
                _cpu_row = 512'd0;
                for (_cpu_c = 0; _cpu_c < 16; _cpu_c = _cpu_c + 1)
                    for (_cpu_b = 0; _cpu_b < 32; _cpu_b = _cpu_b + 1)
                        _cpu_row[_cpu_c + _cpu_b*16] = _cpu_rom[_cpu_r*16 + _cpu_c][_cpu_b];
                dut.soc.memory.u_sram.mem[_cpu_r] = _cpu_row;
            end
            _cpu_verify = 32'd0;
            for (_cpu_b = 0; _cpu_b < 32; _cpu_b = _cpu_b + 1)
                _cpu_verify[_cpu_b] = dut.soc.memory.u_sram.mem[0][_cpu_b * 16];
        end
    endtask

    task automatic pack_recip_lut;
        begin
            $readmemh("../sourcecode/tb/veeresh_compiler/build_output/hex/reciprocal_lut.hex", _rec_rom);
            for (_rec_r = 0; _rec_r < 64; _rec_r = _rec_r + 1) begin
                _rec_row = 256'd0;
                for (_rec_c = 0; _rec_c < 16; _rec_c = _rec_c + 1)
                    for (_rec_b = 0; _rec_b < 16; _rec_b = _rec_b + 1)
                        _rec_row[_rec_c + _rec_b*16] = _rec_rom[_rec_r*16 + _rec_c][_rec_b];
                dut.decoder_acc_inst.rms_norm.lut_inst.u_recip_lut.mem[_rec_r] = _rec_row;
            end
            $display("[MNIST_REC_INIT] reciprocal LUT packed.");
        end
    endtask

    task automatic pack_sigmoid_lut;
        begin
            $readmemh("../sourcecode/tb/veeresh_compiler/build_output/hex/sigmoid_lut.hex", _sig_rom);
            for (_sig_r = 0; _sig_r < 64; _sig_r = _sig_r + 1) begin
                _sig_row = 256'd0;
                for (_sig_c = 0; _sig_c < 16; _sig_c = _sig_c + 1)
                    for (_sig_b = 0; _sig_b < 16; _sig_b = _sig_b + 1)
                        _sig_row[_sig_c + _sig_b*16] = _sig_rom[_sig_r*16 + _sig_c][_sig_b];
                dut.decoder_acc_inst.u_sigmoid.u_sigmoid_lut.mem[_sig_r] = _sig_row;
            end
            $display("[MNIST_SIG_INIT] sigmoid LUT packed.");
        end
    endtask

    always @(posedge clk_16mhz) begin
        if (dut.psum_mem.ping_sram.en && dut.psum_mem.ping_sram.wen)
            ping_shadow[dut.psum_mem.ping_sram.addr] <= dut.psum_mem.ping_sram.din;
        if (dut.psum_mem.pong_sram.en && dut.psum_mem.pong_sram.wen)
            pong_shadow[dut.psum_mem.pong_sram.addr] <= dut.psum_mem.pong_sram.din;
    end

    always @(posedge clk_16mhz) begin
        if (dut.soc.cpu.trap)
            $display("[MNIST_CPU_TRAP] CPU trapped at time=%0t ns", $realtime);
    end

    task automatic wait_for_done_or_timeout;
        begin
            done_seen = 0;
            fork
                begin
                    wait(user_leds[0] == 1'b1);
                    done_seen = 1;
                end
                begin
                    repeat(30_000_000) @(posedge clk_16mhz);
                end
            join_any
            disable fork;
        end
    endtask

    task automatic run_one_sample(input integer idx);
        begin
            $sformat(input_path,  "%s/%0d/hex/mnist_input.hex", case_root, idx);
            $sformat(scores_path, "%s/%0d/golden/expected_scores.hex", case_root, idx);
            $sformat(class_path,  "%s/%0d/golden/expected_class.hex", case_root, idx);
            $sformat(argmax_path, "%s/%0d/golden/expected_argmax.hex", case_root, idx);

            $display("[MNIST_SIM] sample %0d", idx);
            $readmemh(input_path, flash_model.flash_input);
            $readmemh(scores_path, expected_scores);
            $readmemh(class_path, expected_class);
            $readmemh(argmax_path, expected_argmax);

            sample_errors = 0;
            clear_shadows();
            pin_2 = 1'b0;
            repeat(20) @(posedge clk_16mhz);
            pack_cpu_sram();
            repeat(5) @(posedge clk_16mhz);
            pin_2 = 1'b1;

            wait_for_done_or_timeout();
            if (!done_seen) begin
                $display("[MNIST_FAIL] sample=%0d timeout", idx);
                sample_errors = sample_errors + 1;
            end else begin
                repeat(20) @(posedge clk_16mhz);

                ping_errors = 0;
                pong_errors = 0;
                for (i = 0; i < 10; i = i + 1) begin
                    if (ping_shadow[i] !== expected_scores[i]) ping_errors = ping_errors + 1;
                    if (pong_shadow[i] !== expected_scores[i]) pong_errors = pong_errors + 1;
                end
                use_ping = (ping_errors <= pong_errors);

                best_score = 16'd0;
                predicted_class = 0;
                for (i = 0; i < 10; i = i + 1) begin
                    if (use_ping) begin
                        if (ping_shadow[i] !== expected_scores[i]) sample_errors = sample_errors + 1;
                        if (i == 0 || ping_shadow[i] > best_score) begin
                            best_score = ping_shadow[i];
                            predicted_class = i;
                        end
                    end else begin
                        if (pong_shadow[i] !== expected_scores[i]) sample_errors = sample_errors + 1;
                        if (i == 0 || pong_shadow[i] > best_score) begin
                            best_score = pong_shadow[i];
                            predicted_class = i;
                        end
                    end
                end

                if (predicted_class !== expected_argmax[0]) begin
                    sample_errors = sample_errors + 1;
                    $display("[MNIST_FAIL] sample=%0d predicted=%0d expected_argmax=%0d", idx, predicted_class, expected_argmax[0]);
                end
            end

            if (sample_errors == 0) begin
                total_hw_pass = total_hw_pass + 1;
                $display("[MNIST_PASS] sample=%0d hardware matched golden", idx);
            end else begin
                total_hw_errors = total_hw_errors + 1;
                $display("[MNIST_FAIL] sample=%0d hardware_errors=%0d", idx, sample_errors);
            end

            if (predicted_class == expected_class[0])
                total_class_pass = total_class_pass + 1;

            $fdisplay(summary_fd, "%0d,%0d,%0d,%0d,%0d", idx, (sample_errors == 0), predicted_class, expected_class[0], (predicted_class == expected_class[0]));
            $fflush(summary_fd);

            pin_2 = 1'b0;
            repeat(10) @(posedge clk_16mhz);
        end
    endtask

    initial begin
        pin_2 = 1'b0;
        sample_start = 0;
        sample_count = 1;
        case_root = "../sourcecode/tb/veeresh_compiler/build_output/mnist_cases";
        summary_path = "mnist_logs/summary.csv";
        if (!$value$plusargs("MNIST_START=%d", sample_start)) sample_start = 0;
        if (!$value$plusargs("MNIST_COUNT=%d", sample_count)) sample_count = 1;
        if (!$value$plusargs("MNIST_CASE_ROOT=%s", case_root))
            case_root = "../sourcecode/tb/veeresh_compiler/build_output/mnist_cases";
        if (!$value$plusargs("MNIST_SUMMARY=%s", summary_path))
            summary_path = "mnist_logs/summary.csv";

        $readmemh("../sourcecode/tb/veeresh_compiler/veeresh_compiler.hex", _cpu_rom);
        pack_cpu_sram();
        $display("[MNIST_CPU_INIT] readback[0]=0x%08h expected=0x%08h %s",
                 _cpu_verify, _cpu_rom[0], (_cpu_verify === _cpu_rom[0]) ? "OK" : "MISMATCH");
        pack_recip_lut();
        pack_sigmoid_lut();

        summary_fd = $fopen(summary_path, "w");
        if (summary_fd == 0) begin
            $display("[MNIST_FAIL] could not open summary file %s", summary_path);
            $finish;
        end
        $fdisplay(summary_fd, "index,hardware_ok,predicted,true_class,class_correct");
        $fflush(summary_fd);

        total_hw_pass = 0;
        total_class_pass = 0;
        total_hw_errors = 0;

        $display("[MNIST] multi-sample simulation start=%0d count=%0d case_root=%s", sample_start, sample_count, case_root);
        for (sample_idx = sample_start; sample_idx < sample_start + sample_count; sample_idx = sample_idx + 1)
            run_one_sample(sample_idx);

        $fclose(summary_fd);
        $display("[MNIST] hardware_pass=%0d/%0d class_correct=%0d/%0d", total_hw_pass, sample_count, total_class_pass, sample_count);
        $display("[MNIST] summary: %s", summary_path);
        if (total_hw_errors == 0) $display("MNIST HARDWARE SUCCESSFUL!");
        else                      $display("MNIST HARDWARE FAILED with %0d failed samples.", total_hw_errors);
        $finish;
    end
endmodule

module qspi_flash_model_mnist (
    input  wire       clk,
    input  wire       qspi_sck,
    input  wire       qspi_cs_n,
    input  wire [3:0] qspi_io_out,
    output reg  [3:0] qspi_io_in,
    input  wire       qspi_io_oe
);

reg [15:0] flash_input  [0:4095];
reg [15:0] flash_weight [0:65535];
reg [31:0] flash_bias   [0:1023];
integer init_i;

localparam [23:0] BASE_INPUT  = 24'h000000;
localparam [23:0] BASE_WEIGHT = 24'h002000;
localparam [23:0] BASE_BIAS   = 24'h022000;

initial begin
    for (init_i = 0; init_i < 4096; init_i = init_i + 1) flash_input[init_i] = 16'd0;
    $readmemh("../sourcecode/tb/veeresh_compiler/build_output/hex/global_weights.hex", flash_weight);
    $readmemh("../sourcecode/tb/veeresh_compiler/build_output/hex/global_bias.hex",    flash_bias);
    qspi_io_in = 4'b0;
end

localparam RX_CMD   = 2'd0;
localparam RX_ADDR  = 2'd1;
localparam RX_DUMMY = 2'd2;
localparam RX_DATA  = 2'd3;

reg [1:0]  rx_state;
reg [3:0]  rx_cnt;
reg [7:0]  rx_cmd;
reg [23:0] rx_addr;
reg [31:0] tx_data;
reg [3:0]  tx_nibbles;
reg        tx_start;
reg [31:0] tx_shift;
reg [3:0]  tx_rem;
reg        tx_active;

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
