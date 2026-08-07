`timescale 1ns/1ps

module test_tanh_activation;
    reg clk;
    reg rst;
    reg valid_in;
    reg signed [15:0] q_in;
    reg signed [15:0] m_int16;
    reg signed [31:0] b_int32;
    reg [3:0] scale_bits;
    reg tanh_mode;
    wire valid_out;
    wire [15:0] sig_out;

    integer errors;
    integer row;
    integer col;
    integer bit_idx;
    reg [255:0] packed_row;
    reg [15:0] lut_word;

    sigmoid_hardware dut (
        .clk        (clk),
        .rst        (rst),
        .valid_in   (valid_in),
        .q_in       (q_in),
        .M_int16    (m_int16),
        .B_int32    (b_int32),
        .scale_bits (scale_bits),
        .tanh_mode  (tanh_mode),
        .valid_out  (valid_out),
        .sig_out    (sig_out)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    function [15:0] lut_value;
        input integer addr;
        begin
            lut_value = addr[9:0] << 6;
        end
    endfunction

    task init_lut;
        begin
            for (row = 0; row < 64; row = row + 1) begin
                packed_row = 256'd0;
                for (col = 0; col < 16; col = col + 1) begin
                    lut_word = lut_value(row * 16 + col);
                    for (bit_idx = 0; bit_idx < 16; bit_idx = bit_idx + 1)
                        packed_row[col + bit_idx * 16] = lut_word[bit_idx];
                end
                dut.u_sigmoid_lut.mem[row] = packed_row;
            end
            dut.u_sigmoid_lut.Q_int = 16'h0000;
        end
    endtask

    task run_case;
        input do_tanh;
        input signed [15:0] q;
        input signed [15:0] m;
        input signed [31:0] b;
        input [3:0] shift;
        input [15:0] expected;
        begin
            @(negedge clk);
            tanh_mode  = do_tanh;
            q_in       = q;
            m_int16    = m;
            b_int32    = b;
            scale_bits = shift;
            valid_in   = 1'b1;

            @(negedge clk);
            valid_in = 1'b0;

            while (valid_out !== 1'b1) @(posedge clk);
            #1;
            if (sig_out !== expected) begin
                $display("[TANH_ACT FAIL] mode=%0d q=%0d expected=0x%04h got=0x%04h", do_tanh, q, expected, sig_out);
                errors = errors + 1;
            end else begin
                $display("[TANH_ACT PASS] mode=%0d q=%0d got=0x%04h", do_tanh, q, sig_out);
            end
            repeat (2) @(posedge clk);
        end
    endtask

    initial begin
        errors = 0;
        valid_in = 1'b0;
        tanh_mode = 1'b0;
        q_in = 16'sd0;
        m_int16 = 16'sd1;
        b_int32 = 32'sd0;
        scale_bits = 4'd0;

        init_lut();
        rst = 1'b1;
        repeat (4) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);

        // Sigmoid mode: address = 256, LUT returns 256 << 6 = 0x4000.
        run_case(1'b0, 16'sd256, 16'sd1, 32'sd0, 4'd0, 16'h4000);

        // Tanh mode doubles the address input before the same sigmoid LUT.
        // q=256 -> addr=512 -> LUT=0x8000 -> tanh output=0x0000.
        run_case(1'b1, 16'sd256, 16'sd1, 32'sd0, 4'd0, 16'h0000);

        // Positive saturation-adjacent case: q=511 -> doubled addr=1022.
        run_case(1'b1, 16'sd511, 16'sd1, 32'sd0, 4'd0, 16'h7f80);

        // Negative values clamp to sigmoid addr 0, then subtract 0x8000.
        run_case(1'b1, -16'sd1, 16'sd1, 32'sd0, 4'd0, 16'h8000);

        if (errors == 0) begin
            $display("[TANH_ACT SUCCESS] sigmoid compatibility and tanh mode passed.");
        end else begin
            $display("[TANH_ACT FAILED] %0d errors.", errors);
        end
        $finish;
    end
endmodule
