/*
 * QSPI Master — Quad I/O Fast Read (opcode 0xEB)
 *
 * Serves three read-only memory channels (input/weight/bias) for decoder_acc.
 * Presents same addr/ren/rdata interface as scratchpad_dual_port.
 * Asserts mem_stall=1 while QSPI transaction in progress; decoder_acc freezes.
 *
 * Flash memory map (byte-addressed):
 *   input  : BASE 0x000000  (16-bit x 4096  =   8 KB)
 *   weight : BASE 0x002000  (16-bit x 65536 = 128 KB)
 *   bias   : BASE 0x022000  (32-bit x 1024  =   4 KB)
 *
 * QSPI protocol per transaction:
 *   CS_SETUP (1 cy) -> CMD 0xEB (8 cy, single-bit IO0) ->
 *   ADDR (6 cy, quad 4b/cy = 24b) -> DUMMY (4 cy) ->
 *   DATA (4 cy = 16b  OR  8 cy = 32b, quad) -> CS_HOLD -> DONE
 *
 * SCK = clk gated by ~qspi_cs_n  (assigned as wire outside state machine).
 * Data driven by master on IO[3:0]; released (io_oe=0) during DUMMY+DATA
 * so flash can drive IO[3:0] back.
 */

`timescale 1ns/1ps
module qspi_master (
    input  wire        clk,
    input  wire        rst,

    // --- decoder_acc memory read interface ---
    input  wire        ren_input,
    input  wire [11:0] addr_input,
    output reg  [15:0] rdata_input,

    input  wire        ren_weight,
    input  wire [15:0] addr_weight,
    output reg  [15:0] rdata_weight,

    input  wire        ren_bias,
    input  wire [9:0]  addr_bias,
    output reg  [31:0] rdata_bias,

    output wire        mem_stall,   // 1 while transaction in progress (combinational)

    // --- QSPI pins ---
    output wire        qspi_sck,    // SCK = clk when CS asserted
    output reg         qspi_cs_n,
    output reg  [3:0]  qspi_io_out, // master -> flash (cmd/addr phases)
    input  wire [3:0]  qspi_io_in,  // flash  -> master (data phase)
    output reg         qspi_io_oe   // 1 = master driving IO[3:0]
);

// SCK gated with chip-select (idles low when deselected)
assign qspi_sck = clk & ~qspi_cs_n;

// Combinational stall: assert immediately when any ren fires or transaction active


// Flash base addresses (byte-addressed)
localparam [23:0] BASE_INPUT  = 24'h000000;
localparam [23:0] BASE_WEIGHT = 24'h002000;
localparam [23:0] BASE_BIAS   = 24'h022000;

localparam [7:0] CMD_QUAD_READ = 8'hEB;

// State encoding
localparam [2:0]
    S_IDLE     = 3'd0,
    S_CS_SETUP = 3'd1,
    S_CMD      = 3'd2,
    S_ADDR     = 3'd3,
    S_DUMMY    = 3'd4,
    S_DATA     = 3'd5,
    S_CS_HOLD  = 3'd6,
    S_DONE     = 3'd7;

reg [2:0]  state;
reg [3:0]  bit_cnt;     // cycles remaining in current phase
reg [23:0] flash_addr;  // byte address latched at request time
reg [7:0]  cmd_shift;   // shift register for CMD byte
reg [23:0] addr_shift;  // shift register for ADDR
reg [31:0] data_shift;  // accumulates received data
reg        is_32bit;    // 1 for bias (32-bit word), 0 for 16-bit
reg [1:0]  req_sel;     // 0=input, 1=weight, 2=bias

assign mem_stall = (state != S_IDLE) || ren_input || ren_weight || ren_bias;

always @(posedge clk) begin
    if (rst) begin
        state        <= S_IDLE;
        qspi_cs_n    <= 1'b1;
        qspi_io_oe   <= 1'b0;
        qspi_io_out  <= 4'b0;
        bit_cnt      <= 4'd0;
        flash_addr   <= 24'b0;
        cmd_shift    <= 8'b0;
        addr_shift   <= 24'b0;
        data_shift   <= 32'b0;
        is_32bit     <= 1'b0;
        req_sel      <= 2'b0;
        rdata_input  <= 16'b0;
        rdata_weight <= 16'b0;
        rdata_bias   <= 32'b0;
    end else begin
        case (state)

        // ── Wait for a read request ───────────────────────────────────────
        S_IDLE: begin
            qspi_cs_n  <= 1'b1;
            qspi_io_oe <= 1'b0;
            // Priority: input > weight > bias
            if (ren_input) begin
                flash_addr <= BASE_INPUT  + ({{12{1'b0}}, addr_input}  << 1);
                is_32bit   <= 1'b0;
                req_sel    <= 2'd0;
                state      <= S_CS_SETUP;
            end else if (ren_weight) begin
                flash_addr <= BASE_WEIGHT + ({{8{1'b0}},  addr_weight} << 1);
                is_32bit   <= 1'b0;
                req_sel    <= 2'd1;
                state      <= S_CS_SETUP;
            end else if (ren_bias) begin
                flash_addr <= BASE_BIAS   + ({{14{1'b0}}, addr_bias}   << 2);
                is_32bit   <= 1'b1;
                req_sel    <= 2'd2;
                state      <= S_CS_SETUP;
            end
        end

        // ── Assert CS, load shift registers ──────────────────────────────
        S_CS_SETUP: begin
            qspi_cs_n   <= 1'b0;
            qspi_io_oe  <= 1'b1;
            qspi_io_out <= 4'b0;
            cmd_shift   <= CMD_QUAD_READ;
            addr_shift  <= flash_addr;
            data_shift  <= 32'b0;
            bit_cnt     <= 4'd7;          // 8 CMD bits, count 7..0
            state       <= S_CMD;
        end

        // ── Send CMD byte: 1 bit/cycle on IO0, MSB first ─────────────────
        S_CMD: begin
            qspi_io_out <= {3'b0, cmd_shift[7]};
            cmd_shift   <= {cmd_shift[6:0], 1'b0};
            if (bit_cnt == 4'd0) begin
                bit_cnt <= 4'd5;          // 6 quad cycles = 24-bit addr
                state   <= S_ADDR;
            end else begin
                bit_cnt <= bit_cnt - 1;
            end
        end

        // ── Send ADDR: 4 bits/cycle (quad), MSB first ────────────────────
        S_ADDR: begin
            qspi_io_out <= addr_shift[23:20];
            addr_shift  <= {addr_shift[19:0], 4'b0};
            if (bit_cnt == 4'd0) begin
                qspi_io_oe <= 1'b0;       // release bus — flash drives from here
                bit_cnt    <= 4'd3;       // 4 dummy cycles
                state      <= S_DUMMY;
            end else begin
                bit_cnt <= bit_cnt - 1;
            end
        end

        // ── Dummy cycles (flash prepares data) ───────────────────────────
        S_DUMMY: begin
            qspi_io_oe  <= 1'b0;
            qspi_io_out <= 4'b0;
            if (bit_cnt == 4'd0) begin
                // 16-bit: 4 nibbles, 32-bit: 8 nibbles
                bit_cnt <= is_32bit ? 4'd7 : 4'd3;
                state   <= S_DATA;
            end else begin
                bit_cnt <= bit_cnt - 1;
            end
        end

        // ── Receive DATA: 4 bits/cycle from flash, MSB first ─────────────
        S_DATA: begin
            data_shift <= {data_shift[27:0], qspi_io_in};
            if (bit_cnt == 4'd0) begin
                state <= S_CS_HOLD;
            end else begin
                bit_cnt <= bit_cnt - 1;
            end
        end

        // ── Deassert CS, latch received data to correct output register ──
        S_CS_HOLD: begin
            qspi_cs_n <= 1'b1;
            case (req_sel)
                2'd0: rdata_input  <= data_shift[15:0];
                2'd1: rdata_weight <= data_shift[15:0];
                2'd2: rdata_bias   <= data_shift[31:0];
                default: ;
            endcase
            state <= S_DONE;
        end

        // ── Release stall — decoder_acc resumes next cycle ────────────────
        S_DONE: begin
            state <= S_IDLE;
        end

        default: state <= S_IDLE;
        endcase
    end
end

endmodule
