`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/19/2025 03:54:31 PM
// Design Name: 
// Module Name: ddmm_extract
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

module ddmm_extract (
    input  wire        clk,
    input  wire        rst,
    input  wire        new_fix,      // pulse from parser

    // latitude digits from the parser
    input  wire [7:0]  lat0,
    input  wire [7:0]  lat1,
    input  wire [7:0]  lat2,
    input  wire [7:0]  lat3,
//    input  wire [7:0]  lat4,
//    input  wire [7:0]  lat5,
//    input  wire [7:0]  lat6,
//    input  wire [7:0]  lat7,


    output reg [3:0] d0,   // most significant digit
    output reg [3:0] d1,
    output reg [3:0] d2,
    output reg [3:0] d3    // least significant digit
);

    always @(posedge clk) begin
        if (rst) begin
            // DEFAULT = ALL ONES (1111)
            d0 <= 4'd1;
            d1 <= 4'd1;
            d2 <= 4'd1;
            d3 <= 4'd1;

        end
        else if (new_fix)begin
        
            d0 <= lat0- 8'd48;
            d1 <= lat1- 8'd48;
            d2 <= lat2- 8'd48;
            d3 <= lat3- 8'd48;
        
        end
    end

endmodule