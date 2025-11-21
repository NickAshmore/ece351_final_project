`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/21/2025 01:08:27 PM
// Design Name: 
// Module Name: spped_extract
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module speed_extract (
    input  wire        clk,
    input  wire        rst,
    input  wire        new_fix,     // pulse per GPS sentence

    input  wire [7:0]  spd0,
    input  wire [7:0]  spd1,
    input  wire [7:0]  spd2,
    input  wire [7:0]  spd3,
    input  wire [7:0]  spd4,
    input  wire [7:0]  spd5,
    input  wire [3:0]  speed_len,

    output reg [15:0] speed_scaled,   // knots * 10
    output reg        speed_valid
);

    reg [15:0] value;
    // Convert ASCII character to 0-9 digit or ignore
    function [3:0] to_digit;
        input [7:0] ch;
        begin
            if (ch >= "0" && ch <= "9")
                to_digit = ch - 8'd48;
            else
                to_digit = 4'd0;
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            speed_scaled <= 0;
            speed_valid  <= 0;

        end else begin
            speed_valid <= 0;

            if (new_fix) begin
                // Build a fixed-scale speed value (knots × 10)
                // Examples:
                // "0.00" ? 0
                // "1.25" ? 12
                // "12.5" ? 125
                // "8.43" ? 84

                value = 0;

                // Process digits left to right, skip decimal
                if (spd0 != ".") value = value*10 + to_digit(spd0);
                if (spd1 != ".") value = value*10 + to_digit(spd1);
                if (spd2 != ".") value = value*10 + to_digit(spd2);
                if (spd3 != ".") value = value*10 + to_digit(spd3);
                if (spd4 != ".") value = value*10 + to_digit(spd4);
                if (spd5 != ".") value = value*10 + to_digit(spd5);

                // Now value is "knots × 100"
                // Convert to knots × 10 by dividing by 10
                speed_scaled <= value / 10;

                speed_valid <= 1'b1;
            end
        end
    end

endmodule
