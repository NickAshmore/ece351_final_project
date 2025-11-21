`timescale 1ns / 1ps

module pace_converter (
    input  wire        clk,
    input  wire        rst,
    input  wire        speed_valid,     // pulse from speed_extract
    input  wire [15:0] speed_scaled,    // knots × 10

    output reg [15:0] pace_seconds,     // total seconds per mile
    output reg        pace_valid,       // 1-cycle pulse

    // Pace digits MMSS for the 7-seg
    output reg [3:0] d0_pace,   // tens of minutes
    output reg [3:0] d1_pace,   // ones of minutes
    output reg [3:0] d2_pace,   // tens of seconds
    output reg [3:0] d3_pace    // ones of seconds
);

    reg [15:0] pace_val;
    reg [15:0] minutes;
    reg [15:0] seconds;

    always @(posedge clk) begin
        if (rst) begin
            pace_seconds <= 0;
            pace_valid   <= 0;

            d0_pace <= 4'd1;  // default = 1111 (FPGA reset marker)
            d1_pace <= 4'd1;
            d2_pace <= 4'd1;
            d3_pace <= 4'd1;

        end else begin

            pace_valid <= 0; // default LOW each cycle

            if (speed_valid) begin
                //-----------------------------------------
                // 1. Compute pace = seconds per mile
                // pace ? 36000 / (knots × 10)
                //-----------------------------------------
                if (speed_scaled > 0)
                    pace_val = 36000 / speed_scaled;
                else
                    pace_val = 9999;   // standing still

                pace_seconds <= pace_val;
                pace_valid   <= 1'b1;

                //-----------------------------------------
                // 2. Convert total seconds ? MM:SS
                //-----------------------------------------

                minutes = pace_val / 60;
                seconds = pace_val % 60;

                d0_pace <= (minutes / 10) % 10;
                d1_pace <= (minutes     ) % 10;
                d2_pace <= (seconds / 10) % 10;
                d3_pace <= (seconds     ) % 10;
            end
        end
    end

endmodule
