`timescale 1ns/1ps

module test_first_n_loads;
    reg clk;
    reg resetn;

    reg         pcpi_valid;
    reg [31:0] pcpi_insn;
    reg [31:0] pcpi_rs1;
    reg [31:0] pcpi_rs2;
    wire        pcpi_wr;
    wire [31:0] pcpi_rd;
    wire        pcpi_wait;
    wire        pcpi_ready;

    wire        decoder_ren_input;
    wire [11:0] decoder_addr_input;
    wire        decoder_ren_weight;
    wire [15:0] decoder_addr_weight;
    wire        decoder_ren_bias;
    wire [9:0]  decoder_addr_bias;
    wire        decoder_pp_ren;
    wire [11:0] decoder_pp_raddr;
    wire        decoder_pp_wen;
    wire [11:0] decoder_pp_waddr;
    wire        decoder_pp_swap;
    wire [15:0] decoder_pp_wdata;
    wire        illegal_instr;

    reg [15:0] input_data;
    reg [15:0] weight_data;
    reg [31:0] bias_data;

    integer errors;
    integer i;
    integer ifmap_writes [0:7];
    integer weight_writes [0:7];

    decoder_acc dut (
        .clk                (clk),
        .resetn             (resetn),
        .pcpi_valid         (pcpi_valid),
        .pcpi_insn          (pcpi_insn),
        .pcpi_rs1           (pcpi_rs1),
        .pcpi_rs2           (pcpi_rs2),
        .pcpi_wr            (pcpi_wr),
        .pcpi_rd            (pcpi_rd),
        .pcpi_wait          (pcpi_wait),
        .pcpi_ready         (pcpi_ready),
        .decoder_ren_input  (decoder_ren_input),
        .decoder_addr_input (decoder_addr_input),
        .decoder_ren_weight (decoder_ren_weight),
        .decoder_addr_weight(decoder_addr_weight),
        .decoder_ren_bias   (decoder_ren_bias),
        .decoder_addr_bias  (decoder_addr_bias),
        .decoder_pp_ren     (decoder_pp_ren),
        .decoder_pp_raddr   (decoder_pp_raddr),
        .decoder_pp_wen     (decoder_pp_wen),
        .decoder_pp_waddr   (decoder_pp_waddr),
        .decoder_pp_swap    (decoder_pp_swap),
        .input_data         (input_data),
        .weight_data        (weight_data),
        .bias_data          (bias_data),
        .decoder_pp_wdata   (decoder_pp_wdata),
        .decoder_pp_rdata   (16'h0000),
        .illegal_instr      (illegal_instr),
        .mem_stall          (1'b0)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    function [31:0] acc_insn;
        input [6:0] funct7;
        input [2:0] funct3;
        begin
            acc_insn = {funct7, 5'd0, 5'd0, funct3, 5'd0, 7'h2b};
        end
    endfunction

    task reset_write_counts;
        begin
            for (i = 0; i < 8; i = i + 1) begin
                ifmap_writes[i] = 0;
                weight_writes[i] = 0;
            end
        end
    endtask

    task issue_acc;
        input [6:0] funct7;
        input [2:0] funct3;
        input [31:0] rs1;
        input [31:0] rs2;
        integer timeout;
        begin
            @(negedge clk);
            pcpi_insn  = acc_insn(funct7, funct3);
            pcpi_rs1   = rs1;
            pcpi_rs2   = rs2;
            pcpi_valid = 1'b1;

            timeout = 0;
            while (pcpi_ready !== 1'b1 && timeout < 200) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (timeout >= 200) begin
                $display("[FIRST_N FAIL] funct7=0x%02h timed out waiting for pcpi_ready", funct7);
                errors = errors + 1;
            end

            @(negedge clk);
            pcpi_valid = 1'b0;
            pcpi_insn  = 32'd0;
            pcpi_rs1   = 32'd0;
            pcpi_rs2   = 32'd0;
            repeat (4) @(posedge clk);
        end
    endtask

    task check_ifmap_first_n;
        input integer n;
        begin
            for (i = 0; i < 8; i = i + 1) begin
                if (i < n) begin
                    if (ifmap_writes[i] == 0) begin
                        $display("[FIRST_N FAIL] ifmap PE%0d expected writes, got 0", i);
                        errors = errors + 1;
                    end else begin
                        $display("[FIRST_N PASS] ifmap PE%0d writes=%0d", i, ifmap_writes[i]);
                    end
                end else if (ifmap_writes[i] != 0) begin
                    $display("[FIRST_N FAIL] ifmap PE%0d should not be written, writes=%0d", i, ifmap_writes[i]);
                    errors = errors + 1;
                end else begin
                    $display("[FIRST_N PASS] ifmap PE%0d not selected", i);
                end
            end
        end
    endtask

    task check_weight_first_n;
        input integer n;
        begin
            for (i = 0; i < 8; i = i + 1) begin
                if (i < n) begin
                    if (weight_writes[i] == 0) begin
                        $display("[FIRST_N FAIL] weight PE%0d expected writes, got 0", i);
                        errors = errors + 1;
                    end else begin
                        $display("[FIRST_N PASS] weight PE%0d writes=%0d", i, weight_writes[i]);
                    end
                end else if (weight_writes[i] != 0) begin
                    $display("[FIRST_N FAIL] weight PE%0d should not be written, writes=%0d", i, weight_writes[i]);
                    errors = errors + 1;
                end else begin
                    $display("[FIRST_N PASS] weight PE%0d not selected", i);
                end
            end
        end
    endtask

    task check_bias_first_n;
        input integer n;
        begin
            if (n > 0 && dut.pe_array.PE0.bias_reg[31:0] !== bias_data) begin $display("[FIRST_N FAIL] bias PE0 got 0x%08h", dut.pe_array.PE0.bias_reg[31:0]); errors = errors + 1; end
            if (n > 1 && dut.pe_array.PE1.bias_reg[31:0] !== bias_data) begin $display("[FIRST_N FAIL] bias PE1 got 0x%08h", dut.pe_array.PE1.bias_reg[31:0]); errors = errors + 1; end
            if (n > 2 && dut.pe_array.PE2.bias_reg[31:0] !== bias_data) begin $display("[FIRST_N FAIL] bias PE2 got 0x%08h", dut.pe_array.PE2.bias_reg[31:0]); errors = errors + 1; end
            if (n > 3 && dut.pe_array.PE3.bias_reg[31:0] !== bias_data) begin $display("[FIRST_N FAIL] bias PE3 got 0x%08h", dut.pe_array.PE3.bias_reg[31:0]); errors = errors + 1; end
            if (n > 4 && dut.pe_array.PE4.bias_reg[31:0] !== bias_data) begin $display("[FIRST_N FAIL] bias PE4 got 0x%08h", dut.pe_array.PE4.bias_reg[31:0]); errors = errors + 1; end
            if (n > 5 && dut.pe_array.PE5.bias_reg[31:0] !== bias_data) begin $display("[FIRST_N FAIL] bias PE5 got 0x%08h", dut.pe_array.PE5.bias_reg[31:0]); errors = errors + 1; end
            if (n > 6 && dut.pe_array.PE6.bias_reg[31:0] !== bias_data) begin $display("[FIRST_N FAIL] bias PE6 got 0x%08h", dut.pe_array.PE6.bias_reg[31:0]); errors = errors + 1; end
            if (n > 7 && dut.pe_array.PE7.bias_reg[31:0] !== bias_data) begin $display("[FIRST_N FAIL] bias PE7 got 0x%08h", dut.pe_array.PE7.bias_reg[31:0]); errors = errors + 1; end

            if (n <= 0 && dut.pe_array.PE0.bias_reg !== 42'd0) begin $display("[FIRST_N FAIL] bias PE0 should remain zero"); errors = errors + 1; end
            if (n <= 1 && dut.pe_array.PE1.bias_reg !== 42'd0) begin $display("[FIRST_N FAIL] bias PE1 should remain zero"); errors = errors + 1; end
            if (n <= 2 && dut.pe_array.PE2.bias_reg !== 42'd0) begin $display("[FIRST_N FAIL] bias PE2 should remain zero"); errors = errors + 1; end
            if (n <= 3 && dut.pe_array.PE3.bias_reg !== 42'd0) begin $display("[FIRST_N FAIL] bias PE3 should remain zero"); errors = errors + 1; end
            if (n <= 4 && dut.pe_array.PE4.bias_reg !== 42'd0) begin $display("[FIRST_N FAIL] bias PE4 should remain zero"); errors = errors + 1; end
            if (n <= 5 && dut.pe_array.PE5.bias_reg !== 42'd0) begin $display("[FIRST_N FAIL] bias PE5 should remain zero"); errors = errors + 1; end
            if (n <= 6 && dut.pe_array.PE6.bias_reg !== 42'd0) begin $display("[FIRST_N FAIL] bias PE6 should remain zero"); errors = errors + 1; end
            if (n <= 7 && dut.pe_array.PE7.bias_reg !== 42'd0) begin $display("[FIRST_N FAIL] bias PE7 should remain zero"); errors = errors + 1; end

            for (i = 0; i < 8; i = i + 1) begin
                if (i < n) $display("[FIRST_N PASS] bias PE%0d selected", i);
                else       $display("[FIRST_N PASS] bias PE%0d not selected", i);
            end
        end
    endtask

    always @(posedge clk) begin
        if (resetn) begin
            if (dut.pe_array.PE0.ifmap0.wen) ifmap_writes[0] = ifmap_writes[0] + 1;
            if (dut.pe_array.PE1.ifmap0.wen) ifmap_writes[1] = ifmap_writes[1] + 1;
            if (dut.pe_array.PE2.ifmap0.wen) ifmap_writes[2] = ifmap_writes[2] + 1;
            if (dut.pe_array.PE3.ifmap0.wen) ifmap_writes[3] = ifmap_writes[3] + 1;
            if (dut.pe_array.PE4.ifmap0.wen) ifmap_writes[4] = ifmap_writes[4] + 1;
            if (dut.pe_array.PE5.ifmap0.wen) ifmap_writes[5] = ifmap_writes[5] + 1;
            if (dut.pe_array.PE6.ifmap0.wen) ifmap_writes[6] = ifmap_writes[6] + 1;
            if (dut.pe_array.PE7.ifmap0.wen) ifmap_writes[7] = ifmap_writes[7] + 1;

            if (dut.pe_array.PE0.weight0.wen) weight_writes[0] = weight_writes[0] + 1;
            if (dut.pe_array.PE1.weight0.wen) weight_writes[1] = weight_writes[1] + 1;
            if (dut.pe_array.PE2.weight0.wen) weight_writes[2] = weight_writes[2] + 1;
            if (dut.pe_array.PE3.weight0.wen) weight_writes[3] = weight_writes[3] + 1;
            if (dut.pe_array.PE4.weight0.wen) weight_writes[4] = weight_writes[4] + 1;
            if (dut.pe_array.PE5.weight0.wen) weight_writes[5] = weight_writes[5] + 1;
            if (dut.pe_array.PE6.weight0.wen) weight_writes[6] = weight_writes[6] + 1;
            if (dut.pe_array.PE7.weight0.wen) weight_writes[7] = weight_writes[7] + 1;
        end
    end

    initial begin
        errors = 0;
        reset_write_counts();
        input_data  = 16'h1111;
        weight_data = 16'h2222;
        bias_data   = 32'h0000_0333;
        pcpi_valid  = 1'b0;
        pcpi_insn   = 32'd0;
        pcpi_rs1    = 32'd0;
        pcpi_rs2    = 32'd0;

        resetn = 1'b0;
        repeat (5) @(posedge clk);
        resetn = 1'b1;
        repeat (2) @(posedge clk);

        $display("[FIRST_N] Testing ifmap FIRST_N opcode funct7=0x13 for PE0..PE3");
        reset_write_counts();
        issue_acc(7'h13, 3'd3, 32'd0, 32'd2);
        check_ifmap_first_n(4);

        $display("[FIRST_N] Testing weight FIRST_N opcode funct7=0x14 for PE0..PE4");
        reset_write_counts();
        issue_acc(7'h14, 3'd4, 32'd0, 32'd2);
        check_weight_first_n(5);

        $display("[FIRST_N] Testing bias FIRST_N opcode funct7=0x15 for PE0..PE2");
        issue_acc(7'h15, 3'd2, 32'd0, 32'd0);
        check_bias_first_n(3);

        if (errors == 0) begin
            $display("[FIRST_N SUCCESS] ifmap, weight, and bias FIRST_N load instructions passed.");
        end else begin
            $display("[FIRST_N FAILED] %0d errors.", errors);
        end
        $finish;
    end
endmodule
