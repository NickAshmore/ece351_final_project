`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/23/2025 12:15:06 PM
// Design Name: 
// Module Name: Top
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

module top (
    input        clk,
    input        rst,
    input        gps_rx,
    input  [15:0] sw,
    output       tx,
    output [3:0] an,
    output [6:0] seg
);


    // STEP SIDE


    reg [15:0] step_count = 16'd0;
    reg [25:0] step_div   = 26'd0;

    always @(posedge clk) begin
        if (rst) begin
            step_div   <= 26'd0;
            step_count <= 16'd0;
        end else begin
            step_div <= step_div + 1'b1;
            // increment roughly every 0.5 second
            if (step_div == 26'd49_999_999) begin
                step_div   <= 26'd0;
                step_count <= step_count + 1'b1;
            end
        end
    end

    // Steps per minute
    wire [15:0] spm;

    steps_per_min SPM_INST (
        .clk(clk),
        .rst(rst),
        .step_count(step_count),
        .spm(spm)
    );


    // sw[14] = 0 total steps
    // sw[14] = 1 steps per minute
    wire [15:0] step_display_value;
    assign step_display_value = (sw[14] == 1'b0) ? step_count : spm;

    wire [3:0] step_d0;
    wire [3:0] step_d1;
    wire [3:0] step_d2;
    wire [3:0] step_d3;

    bin_to_bcd_4digits STEP_BCD (
        .value(step_display_value),
        .d0(step_d0),
        .d1(step_d1),
        .d2(step_d2),
        .d3(step_d3)
    );

    //7 segment
    wire [3:0] an_step;
    wire [6:0] seg_step;

    seven_seg_driver STEP_DISP (
        .clk(clk),
        .rst(rst),
        .d0(step_d0),
        .d1(step_d1),
        .d2(step_d2),
        .d3(step_d3),
        .an(an_step),
        .seg(seg_step)
    );

    // GPS
    wire [3:0] an_gps;
    wire [6:0] seg_gps;
    wire [1:0] gps_led;

    gps_display_top GPS_TOP (
        .clk   (clk),
        .rst   (rst),
        .gps_rx(gps_rx),
        .tx    (tx),
        .led   (gps_led),
        .an    (an_gps),
        .seg   (seg_gps)
    );

//Mode
    // sw[15] = 0 steps
    // sw[15] = 1 GPS
    assign an  = (sw[15] == 1'b0) ? an_step : an_gps;
    assign seg = (sw[15] == 1'b0) ? seg_step : seg_gps;

endmodule
