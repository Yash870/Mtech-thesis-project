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
