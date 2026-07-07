/*
 *  PicoSoC - A simple example SoC using PicoRV32
 *
 *  Copyright (C) 2017  Clifford Wolf <clifford@clifford.at>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

module hardware (
    input           clk_16mhz,

    // hardware UART
    output          pin_1,
    input           pin_2,

    // onboard LEDs - 4 LEDs for debugging
    output [3:0]    user_leds,

    // QSPI flash interface (memory lives off-chip)
    output          qspi_sck,
    output          qspi_cs_n,
    output [3:0]    qspi_io_out,
    input  [3:0]    qspi_io_in,
    output          qspi_io_oe
);

	wire            pcpi_valid;
	wire    [31:0]  pcpi_insn;
	wire    [31:0]  pcpi_rs1;
	wire    [31:0]  pcpi_rs2;
	wire            pcpi_wr;
	wire    [31:0]  pcpi_rd;
	wire            pcpi_wait;
	wire            pcpi_ready;
    wire clk = clk_16mhz;
    


    // memory read signals — decoder_acc drives, consumed by qspi_master
    wire        decoder_ren_input;
    wire [11:0] decoder_addr_input;
    wire        decoder_ren_weight;
    wire [15:0] decoder_addr_weight;
    wire        decoder_ren_bias;
    wire [9:0]  decoder_addr_bias;

    // read data returned from qspi_master to decoder_acc
    wire [15:0] rdata_input;
    wire [15:0] rdata_weight;
    wire [31:0] rdata_bias;
    wire        mem_stall;


    // ping-pong buffer signal
    wire decoder_pp_ren;
    wire [11:0] decoder_pp_raddr;
    wire [15:0] decoder_pp_rdata;
    wire decoder_pp_wen;
    wire [11:0] decoder_pp_waddr;
    wire [15:0] decoder_pp_wdata;
    wire decoder_pp_swap;

    ///////////////////////////////////
    // Power-on Reset
    ///////////////////////////////////
    // pin_2 is the active-low external reset.
    // Testbench drives pin_2=0 for 20 cycles then releases to 1.
    // ser_rx tied to 1 (UART idle) so Genus does NOT merge resetn and ser_rx nets.
    wire resetn = pin_2;
    wire ser_rx_in = 1'b1;

  
    ///////////////////////////////////
    // Peripheral Bus
    ///////////////////////////////////
    wire        iomem_valid;
    reg         iomem_ready;
    wire [3:0]  iomem_wstrb;
    wire [31:0] iomem_addr;
    wire [31:0] iomem_wdata;
    reg  [31:0] iomem_rdata;

    reg [31:0] gpio;
//    wire debug_valid_seen;
//    wire debug_custom_seen;
//    assign user_leds = {debug_custom_seen, debug_valid_seen, gpio[1:0]};  // LED3=custom_seen, LED2=valid_seen, LED1-0=GPIO
    assign user_leds = gpio[3:0];
    always @(posedge clk) begin
        if (!resetn) begin
            gpio        <= 0;
            iomem_ready <= 0;
            iomem_rdata <= 32'h0;
        end else begin
            iomem_ready <= 0;

            ///////////////////////////
            // GPIO Peripheral
            ///////////////////////////
            if (iomem_valid && !iomem_ready && iomem_addr[31:24] == 8'h03) begin
                iomem_ready <= 1;
                iomem_rdata <= gpio;
                if (iomem_wstrb[0]) gpio[ 7: 0] <= iomem_wdata[ 7: 0];
                if (iomem_wstrb[1]) gpio[15: 8] <= iomem_wdata[15: 8];
                if (iomem_wstrb[2]) gpio[23:16] <= iomem_wdata[23:16];
                if (iomem_wstrb[3]) gpio[31:24] <= iomem_wdata[31:24];
            end

            
            ///////////////////////////
            // Template Peripheral
            ///////////////////////////
            if (iomem_valid && !iomem_ready && iomem_addr[31:24] == 8'h04) begin
                iomem_ready <= 1;
                iomem_rdata <= 32'h0;
            end
        end
    end

    picosoc #(
        .PROGADDR_RESET(32'h0000_0000), // beginning of user space in SPI flash
        .PROGADDR_IRQ(32'h0000_0010),
        .MEM_WORDS(2048)                // use 2KBytes of block RAM by default
    ) soc (
        .clk          (clk         ),
        .resetn       (resetn      ),

        .ser_tx       (pin_1       ),
        .ser_rx       (ser_rx_in  ),

        .irq_5        (1'b0        ),
        .irq_6        (1'b0        ),
        .irq_7        (1'b0        ),

        .iomem_valid  (iomem_valid ),
        .iomem_ready  (iomem_ready ),
        .iomem_wstrb  (iomem_wstrb ),
        .iomem_addr   (iomem_addr  ),
        .iomem_wdata  (iomem_wdata ),
        .iomem_rdata  (iomem_rdata ),
        
        .pcpi_valid  (pcpi_valid ),
		.pcpi_insn   (pcpi_insn  ),
		.pcpi_rs1    (pcpi_rs1   ),
		.pcpi_rs2    (pcpi_rs2   ),
		.pcpi_wr     (pcpi_wr    ),
		.pcpi_rd     (pcpi_rd    ),
		.pcpi_wait   (pcpi_wait  ),
		.pcpi_ready  (pcpi_ready )
    );
    
    decoder_acc decoder_acc_inst (
        .clk(clk),
        .resetn(resetn),
        .pcpi_valid(pcpi_valid),
        .pcpi_insn(pcpi_insn),
        .pcpi_rs1(pcpi_rs1),
        .pcpi_rs2(pcpi_rs2),
        .pcpi_wr(pcpi_wr),
        .pcpi_rd(pcpi_rd),
        .pcpi_wait(pcpi_wait),
        .pcpi_ready(pcpi_ready),
        .decoder_ren_input(decoder_ren_input),
        .decoder_addr_input(decoder_addr_input),
        .decoder_ren_weight(decoder_ren_weight),
        .decoder_addr_weight(decoder_addr_weight),
        .decoder_ren_bias(decoder_ren_bias),
        .decoder_addr_bias(decoder_addr_bias),
        .input_data(rdata_input),
        .weight_data(rdata_weight),
        .bias_data(rdata_bias),
        .mem_stall(mem_stall),
        .decoder_pp_ren(decoder_pp_ren),
        .decoder_pp_raddr(decoder_pp_raddr),
        .decoder_pp_wen(decoder_pp_wen),
        .decoder_pp_waddr(decoder_pp_waddr),
        .decoder_pp_swap(decoder_pp_swap),
        .decoder_pp_wdata(decoder_pp_wdata),
        .decoder_pp_rdata(decoder_pp_rdata)
    );


    qspi_master qspi_master_inst (
        .clk          (clk),
        .rst          (~resetn),
        .ren_input    (decoder_ren_input),
        .addr_input   (decoder_addr_input),
        .rdata_input  (rdata_input),
        .ren_weight   (decoder_ren_weight),
        .addr_weight  (decoder_addr_weight),
        .rdata_weight (rdata_weight),
        .ren_bias     (decoder_ren_bias),
        .addr_bias    (decoder_addr_bias),
        .rdata_bias   (rdata_bias),
        .mem_stall    (mem_stall),
        .qspi_sck     (qspi_sck),
        .qspi_cs_n    (qspi_cs_n),
        .qspi_io_out  (qspi_io_out),
        .qspi_io_in   (qspi_io_in),
        .qspi_io_oe   (qspi_io_oe)
    );


// psum memory (ping-pong buffer for storing partial sums, can be added similarly to input and weight memory if needed)
ping_pong_controller #(
    .DATA_WIDTH(16),
    .ADDR_WIDTH(12)
) psum_mem (
    .clk(clk),
    .rst(~resetn),
    .swap(decoder_pp_swap), // Control signal from decoder to swap ping-pong buffers
    .rd_en(decoder_pp_ren),
    .rd_addr(decoder_pp_raddr),
    .rd_data(decoder_pp_rdata),
    .wr_en(decoder_pp_wen),
    .wr_addr(decoder_pp_waddr),
    .wr_data(decoder_pp_wdata)
);


endmodule
