/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
`timescale 1ns/1ps

module RMS_PE (
    input  wire        clk,
    input  wire        rst,
    input  wire [15:0] ifmap,
    input  wire [15:0] weight,
    input  wire [9:0]  addr,
    input  wire [9:0]  se_counter_val,
    input  wire [31:0] control,
    input  wire [31:0] qat_mult,
    input  wire [5:0]  qat_shift,
    input  wire [15:0] zero_point,
    input  wire [15:0] z_in,             

    output wire [15:0] Psum_out,       
    output reg         rms_first_done, 
    output reg         rms_valid,      
    output reg         rms_last_done   
);

wire rms_enable  = control[18]; 
wire load_iw     = control[12] & rms_enable;
wire ifmap_wen   = control[14]; 
wire weight_wen  = control[15]; 
wire load_sv     = control[28]; 
wire load_ev     = control[27]; 
wire load_qat    = control[30]; 

reg [9:0]  start_val, end_val;
reg [1:0]  mean_elements; 
reg [31:0] qat_mult_reg;
reg [5:0]  qat_shift_reg;
reg [15:0] zero_point_reg;

// FOOLPROOF UNPACKING LOGIC (UNSIGNED)
wire [15:0] z_out_unpacked = {8'd0, zero_point_reg[7:0]};
wire [15:0] z_in_unpacked  = {8'd0, zero_point_reg[15:8]};

always @(posedge clk) begin
    if (rst) begin
        start_val <= 0; end_val <= 0;
        qat_mult_reg <= 0; qat_shift_reg <= 0; zero_point_reg <= 0;
        mean_elements <= 0;
    end else begin
        if (load_sv)  start_val <= se_counter_val;
        if (load_ev)  end_val <= se_counter_val;
        if (load_qat) begin
            qat_mult_reg <= qat_mult;
            qat_shift_reg <= qat_shift;
            zero_point_reg <= zero_point;
        end
        if (rms_enable) mean_elements <= control[20:19];
    end
end

reg [15:0] ifmap_scratch [0:127];
reg [15:0] weight_scratch [0:127];
reg [15:0] ifmap_rdata, weight_rdata;
reg [9:0]  addr_count;
wire [6:0] internal_raddr = addr_count[6:0];

reg        writeback_en;
reg [6:0]  writeback_addr;
reg [15:0] writeback_data;
reg [6:0]  weight_waddr;

always @(posedge clk) begin
    if (rst) begin
        weight_waddr <= 0;
        ifmap_rdata  <= 0;
        weight_rdata <= 0;
    end else begin
        if (ifmap_wen) begin
            ifmap_scratch[addr[6:0]] <= ifmap;
        end else if (writeback_en) begin
            ifmap_scratch[writeback_addr] <= writeback_data;
        end
        ifmap_rdata <= ifmap_scratch[internal_raddr];

        if (weight_wen) begin
            weight_scratch[addr[6:0]] <= weight;
        end

        weight_rdata <= weight_scratch[addr_count - start_val];
    end
end

localparam IDLE = 3'd0, ACCUM_WAIT = 3'd1, ACCUM = 3'd2, LUT = 3'd3, LUT_WAIT = 3'd4, NORMALIZE = 3'd5;
reg [2:0] state;
reg [2:0] step; 

reg [9:0] process_cnt; 

reg signed [42:0] Psum_buf;
reg signed [31:0] sq_stage1_reg;

// NORMALIZE Math Registers
reg signed [31:0] sq_reg;
reg signed [47:0] mant_prod_reg;
reg signed [31:0] x_norm_reg;
reg signed [47:0] gamma_prod_reg;

reg  [39:0] lut_mean_in;
wire [15:0] lut_mantissa_out;
wire [5:0]  lut_k_out;
wire        lut_valid_out;
reg         lut_valid_in  = 1'b0;
reg  [15:0] mantissa_reg;
reg  [5:0]  k_reg;

reg [9:0] addr_delay1;
reg [9:0] addr_delay2;

// FIX: Added val_d0 to perfect the 3-stage shift register
reg val_d0, val_d1, val_d2; 
reg [9:0] output_count;

// 32-BIT OVERFLOW PROTECTION
wire signed [31:0] ifmap_ext = $signed(ifmap_rdata);
wire signed [31:0] zin_ext   = $signed(z_in_unpacked);
wire signed [31:0] centered_accum = ifmap_ext - zin_ext;

always @(posedge clk) begin
    if (rst) begin
        state <= IDLE;
        addr_count <= 0;
        process_cnt <= 0;
        Psum_buf <= 0;
        writeback_en <= 0;
        writeback_addr <= 0;
        writeback_data <= 0;
        rms_valid <= 0; rms_first_done <= 0; rms_last_done <= 0;
        val_d0 <= 0; val_d1 <= 0; val_d2 <= 0;
        lut_valid_in <= 0;
        sq_stage1_reg <= 0;
        addr_delay1 <= 0;
        addr_delay2 <= 0;
        output_count <= 0;
        step <= 0;
        lut_mean_in <= 0;
        mantissa_reg <= 0;
        k_reg <= 0;
        sq_reg <= 0;
        mant_prod_reg <= 0;
        x_norm_reg <= 0;
        gamma_prod_reg <= 0;
    end else begin
        case (state)
            
            IDLE: begin
                rms_valid <= 0; 
                rms_first_done <= 0; 
                rms_last_done <= 0; // <--- RESTORE THIS: Clear it immediately!
                
                writeback_en <= 0; 
                Psum_buf <= 0; 
                val_d0 <= 0; val_d1 <= 0; val_d2 <= 0;
                
                if (load_iw) begin
                    addr_count <= start_val;
                    process_cnt <= start_val;
                    state <= ACCUM_WAIT; 
                end
            end

            ACCUM_WAIT: begin
                state <= ACCUM; 
            end

            ACCUM: begin 
                // Stage 0: Safe Address Generation
                if (process_cnt <= end_val) begin
                    addr_count <= process_cnt;
                    process_cnt <= process_cnt + 1;
                    val_d0 <= 1; // Mark the data generation as valid
                end else begin
                    val_d0 <= 0;
                end
                
                // Shift the valid signals perfectly with the data
                val_d1 <= val_d0;
                val_d2 <= val_d1;
                
                addr_delay1 <= addr_count;
                addr_delay2 <= addr_delay1;
                
                // Stage 1: Math and Writeback
                if (val_d1) begin
                    writeback_en <= 1;
                    writeback_addr <= addr_delay1[6:0];
                    writeback_data <= centered_accum[15:0]; 
                    sq_stage1_reg <= centered_accum * centered_accum;
                end else begin
                    writeback_en <= 0;
                end

                // Stage 2: Accumulate and Transition
                if (val_d2) begin
                    Psum_buf <= Psum_buf + sq_stage1_reg;
                    if (addr_delay2 == end_val) begin
                        state <= LUT;
                    end
                end
            end

            LUT: begin
                writeback_en <= 0;
                if      (mean_elements == 2'b00) lut_mean_in <= {2'b0, Psum_buf[42:5]};
                else if (mean_elements == 2'b01) lut_mean_in <= {3'b0, Psum_buf[42:6]};
                else                             lut_mean_in <= {4'b0, Psum_buf[42:7]};

                lut_valid_in <= 1'b1;   // pulse valid: data stable next cycle
                addr_count   <= start_val;
                output_count <= start_val;
                step  <= 0;
                state <= LUT_WAIT;
            end

            LUT_WAIT: begin
                lut_valid_in <= 1'b0;   // one-cycle pulse only
                // reciprocal_lut is 3-stage pipeline; wait for valid_out
                if (lut_valid_out) begin
                    mantissa_reg <= lut_mantissa_out;
                    k_reg        <= lut_k_out;
                    state        <= NORMALIZE;
                end
            end

            NORMALIZE: begin 
                case (step)
                    3'd0: begin
                        rms_valid <= 0; 
                        rms_first_done <= 0; 
                        sq_reg <= ifmap_ext * ifmap_ext;
                        step <= 1;
                    end
                    
                    3'd1: begin
                        mant_prod_reg <= $unsigned(sq_reg) * $unsigned(mantissa_reg);
                        step <= 2;
                    end

                    3'd2: begin
                        x_norm_reg <= mant_prod_reg >>> k_reg;
                        step <= 3;
                    end

                    3'd3: begin
                        gamma_prod_reg <= x_norm_reg * $signed(weight_rdata);
                        if (addr_count < end_val) addr_count <= addr_count + 1; 
                        step <= 4;
                    end

                    3'd4: begin
                        rms_valid <= 1;
                        if (output_count == start_val) rms_first_done <= 1;
                        
                        if (output_count == end_val) begin
                            rms_last_done <= 1;
                            state <= IDLE;
                        end else begin
                            output_count <= output_count + 1;
                            step <= 0;
                        end
                    end
                    
                    default: step <= 0;
                endcase
            end

            default: begin
                state <= IDLE;
            end
        endcase
    end
end

reciprocal_lut lut_inst (
    .clk      (clk),
    .rst      (rst),
    .valid_in (lut_valid_in),
    .mean_in  (lut_mean_in),
    .valid_out(lut_valid_out),
    .mantissa (lut_mantissa_out),
    .k_out    (lut_k_out)
);

qat_requantizer_48b req_inst (
    .accum_in(gamma_prod_reg),
    .qat_mult(qat_mult_reg),
    .qat_shift(qat_shift_reg),
    .zero_point(z_out_unpacked), 
    .data_out(Psum_out) 
);

endmodule