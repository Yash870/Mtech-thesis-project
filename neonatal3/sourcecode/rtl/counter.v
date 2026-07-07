/*
* Author - Ankur Gupta
* Version -1.0
* Decoder for Neonatal work
* Date-24-01-2026
*/

`timescale 1ns/1ps
module counter#(
  parameter  width = 8,
  parameter [1:0] restart_behav=0 // 0="HOLD" ,1="RESTART" ,2="WRAP_ZERO"
)(
  input wire clk,
  input wire rst,
  input wire load,
  input wire [width-1:0] start_val,
  input wire [width-1:0] end_val,
  input wire enable,
  output reg [width-1:0] count,
  output reg done
);

reg [width-1:0] end_limit;
reg [width-1:0] start_point;

always @(posedge clk) begin
  if(rst) begin
    count       <= 0;
    end_limit   <= 0;
    done        <= 0;
    start_point <= 0;
  end
  else if (load) begin
    start_point <= start_val;
    count     <= start_val;
    end_limit <= end_val;
    done      <= 0;
  end
  else if (enable) begin
    if (count == end_limit) begin
      done <= 1;
      case(restart_behav)
        1 : count <= start_point;  // RESTART
        2 : count <= 0;            // WRAP_ZERO
        default : count <= count;  // HOLD
      endcase
    end
    else begin
      count <= count +1;
      done  <= 0;
    end
  end
  else begin
    done  <= 0;
  end
end
  
endmodule
