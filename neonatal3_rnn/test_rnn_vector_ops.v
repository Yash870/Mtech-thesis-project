`timescale 1ns/1ps

module test_rnn_vector_ops;
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

    reg [15:0] pp_mem [0:4095];
    reg [15:0] decoder_pp_rdata_r;
    wire [15:0] decoder_pp_rdata = decoder_pp_rdata_r;

    integer errors;
    integer i;

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
        .input_data         (16'h0000),
        .weight_data        (16'h0000),
        .bias_data          (32'h0000_0000),
        .decoder_pp_wdata   (decoder_pp_wdata),
        .decoder_pp_rdata   (decoder_pp_rdata),
        .illegal_instr      (illegal_instr),
        .mem_stall          (1'b0)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        if (decoder_pp_ren) begin
            decoder_pp_rdata_r <= pp_mem[decoder_pp_raddr];
        end
        if (decoder_pp_wen) begin
            pp_mem[decoder_pp_waddr] <= decoder_pp_wdata;
        end
    end

    function [31:0] acc_insn;
        input [6:0] funct7;
        begin
            acc_insn = {funct7, 5'd0, 5'd0, 3'd0, 5'd0, 7'h2b};
        end
    endfunction

    function [31:0] pack_addr_len;
        input [11:0] addr;
        input integer len;
        begin
            pack_addr_len = {8'd0, (len - 1), addr};
        end
    endfunction

    function [31:0] pack_addr_addr;
        input [11:0] addr0;
        input [11:0] addr1;
        begin
            pack_addr_addr = {8'd0, addr1, addr0};
        end
    endfunction

    task issue_acc;
        input [6:0] funct7;
        input [31:0] rs1;
        input [31:0] rs2;
        output [31:0] rd;
        integer timeout;
        begin
            @(negedge clk);
            pcpi_insn  = acc_insn(funct7);
            pcpi_rs1   = rs1;
            pcpi_rs2   = rs2;
            pcpi_valid = 1'b1;
            timeout = 0;
            while (pcpi_ready !== 1'b1 && timeout < 300) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (timeout >= 300) begin
                $display("[RNN FAIL] funct7=0x%02h timed out", funct7);
                errors = errors + 1;
            end
            rd = pcpi_rd;
            @(negedge clk);
            pcpi_valid = 1'b0;
            pcpi_insn  = 32'd0;
            pcpi_rs1   = 32'd0;
            pcpi_rs2   = 32'd0;
            repeat (3) @(posedge clk);
        end
    endtask

    task check_pp;
        input [11:0] addr;
        input [15:0] expected;
        begin
            if (pp_mem[addr] !== expected) begin
                $display("[RNN FAIL] pp[%0d] expected 0x%04h got 0x%04h", addr, expected, pp_mem[addr]);
                errors = errors + 1;
            end else begin
                $display("[RNN PASS] pp[%0d] = 0x%04h", addr, expected);
            end
        end
    endtask

    task check_state;
        input [11:0] addr;
        input [31:0] expected;
        reg [31:0] rd;
        begin
            issue_acc(7'h1d, addr, 32'd0, rd);
            if (rd !== expected) begin
                $display("[RNN FAIL] state[%0d] expected 0x%08h got 0x%08h", addr, expected, rd);
                errors = errors + 1;
            end else begin
                $display("[RNN PASS] state[%0d] = 0x%08h", addr, expected);
            end
        end
    endtask

    reg [31:0] rd_unused;

    initial begin
        errors = 0;
        pcpi_valid = 1'b0;
        pcpi_insn  = 32'd0;
        pcpi_rs1   = 32'd0;
        pcpi_rs2   = 32'd0;
        resetn     = 1'b0;
        decoder_pp_rdata_r = 16'd0;
        for (i = 0; i < 4096; i = i + 1) begin
            pp_mem[i] = 16'd0;
        end
        repeat (5) @(posedge clk);
        resetn = 1'b1;
        repeat (5) @(posedge clk);

        pp_mem[0] = 16'h1000;
        pp_mem[1] = 16'h2000;
        pp_mem[2] = 16'h4000;
        pp_mem[3] = 16'h8000;

        issue_acc(7'h17, pack_addr_len(12'd0, 4), 32'd16, rd_unused);
        check_state(12'd16, 32'h0000_1000);
        check_state(12'd17, 32'h0000_2000);
        check_state(12'd18, 32'h0000_4000);
        check_state(12'd19, 32'hffff_8000);

        issue_acc(7'h18, pack_addr_len(12'd16, 4), 32'd100, rd_unused);
        check_pp(12'd100, 16'h1000);
        check_pp(12'd101, 16'h2000);
        check_pp(12'd102, 16'h4000);
        check_pp(12'd103, 16'h8000);

        issue_acc(7'h1c, 32'd32, 32'h0000_1000, rd_unused);
        issue_acc(7'h1c, 32'd33, 32'h0000_1000, rd_unused);
        issue_acc(7'h1c, 32'd34, 32'h0000_4000, rd_unused);
        issue_acc(7'h1c, 32'd35, 32'h0000_4000, rd_unused);
        pp_mem[200] = 16'h1000;
        pp_mem[201] = 16'h7000;
        pp_mem[202] = 16'h4000;
        pp_mem[203] = 16'h4000;

        issue_acc(7'h19, pack_addr_addr(12'd200, 12'd32), pack_addr_len(12'd300, 4), rd_unused);
        check_pp(12'd300, 16'h2000);
        check_pp(12'd301, 16'h7fff);
        check_pp(12'd302, 16'h7fff);
        check_pp(12'd303, 16'h7fff);

        issue_acc(7'h1a, pack_addr_addr(12'd200, 12'd32), pack_addr_len(12'd400, 4), rd_unused);
        check_pp(12'd400, 16'h0200);
        check_pp(12'd401, 16'h0e00);
        check_pp(12'd402, 16'h2000);
        check_pp(12'd403, 16'h2000);

        issue_acc(7'h1b, pack_addr_len(12'd200, 4), 32'd500, rd_unused);
        check_pp(12'd500, 16'h6fff);
        check_pp(12'd501, 16'h0fff);
        check_pp(12'd502, 16'h3fff);
        check_pp(12'd503, 16'h3fff);

        issue_acc(7'h1e, pack_addr_len(12'd32, 4), 32'd0, rd_unused);
        check_state(12'd32, 32'h0000_0000);
        check_state(12'd33, 32'h0000_0000);
        check_state(12'd34, 32'h0000_0000);
        check_state(12'd35, 32'h0000_0000);

        if (errors == 0) begin
            $display("[RNN TEST] PASS");
        end else begin
            $display("[RNN TEST] FAIL errors=%0d", errors);
        end
        $finish;
    end
endmodule
