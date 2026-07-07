/*
* Author - Ankur Gupta
* Version -1.0
* Decoder for Neonatal work
* Date-24-01-2026
*/

`timescale 1ns/1ps 

module ping_pong_controller#(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 10
)(
    input wire clk,
    input wire rst,
    // control signals
    input wire swap,
    
    // Write Interface (Producer)
    input wire                  wr_en,
    input wire [ADDR_WIDTH-1:0] wr_addr,
    input wire [DATA_WIDTH-1:0] wr_data,


    // Read Interface (Consumer)
    input   wire                  rd_en,

    input   wire [ADDR_WIDTH-1:0] rd_addr,
    output  wire [DATA_WIDTH-1:0] rd_data

);

    // Toggle State: 
    // 1 = Write to Ping, Read from Pong
    // 0 = Write to Pong, Read from Ping
    reg write_to_ping;

    always @(posedge clk) begin
        if (rst) begin
            write_to_ping <= 1'b1;
        end else if (swap) begin
            write_to_ping <= ~write_to_ping;
        end
    end


    // ==========================================
    // Internal Signals for SRAM Instances
    // ==========================================
    wire ping_en, pong_en;
    wire ping_wen, pong_wen;
    wire [ADDR_WIDTH-1:0] ping_addr, pong_addr;
    wire [DATA_WIDTH-1:0] ping_dout, pong_dout;

    assign ping_en = write_to_ping ? wr_en : rd_en;
    assign ping_addr = write_to_ping ? wr_addr :rd_addr;
    assign ping_wen  = write_to_ping ? wr_en : 1'b0;

    assign pong_en = write_to_ping ? rd_en : wr_en;
    assign pong_addr = write_to_ping ? rd_addr: wr_addr;
    assign pong_wen  = write_to_ping ? 1'b0:wr_en;
    
    assign rd_data = write_to_ping ? pong_dout :ping_dout;



    // ==========================================
    // Instantiating the SRAMs
    // ==========================================

    scratchpad_sram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) ping_sram(
        .clk(clk),
        .en(ping_en),
        .wen(ping_wen),
        .addr(ping_addr),
        .din(wr_data),
        .dout(ping_dout)
    );

    scratchpad_sram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) pong_sram(
        .clk(clk),
        .en(pong_en),
        .wen(pong_wen),
        .addr(pong_addr),
        .din(wr_data),
        .dout(pong_dout)
    );
    

    
endmodule
