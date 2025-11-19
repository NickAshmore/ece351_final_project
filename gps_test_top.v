`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/06/2025 10:12:59 AM
// Design Name: 
// Module Name: gps_test_top
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

module gps_display_top (
    input  clk,    // 100 MHz System Clock (W5)
    input  rst,    // Reset Button (btnC)
    input  gps_rx,  // GPS Serial Data Input (JA1 - J1)
    output tx,      // PC Serial Data Output (USB-UART - A18)
    output [1:0] led,
    output [3:0] an,
    output [6:0] seg
);

// --- Internal Wires ---
wire [7:0] gps_data_out;   // Data received from the GPS
wire       gps_data_valid; // Pulse when a byte is fully received
wire [7:0] gps_data_filtered;

wire [7:0] filtered_byte;
wire filtered_valid;

wire gps_rx_fixed = gps_rx;

// --- Instance 1: UART Receiver (Reads GPS Data) ---
// Uses default 100MHz clock and 9600 baud rate (8N1)
uart_rx #(
    .CLK_FREQ_HZ(100000000),
    .BAUD_RATE(9600)
)
i_uart_rx (
    .clk(clk),
    .rst(rst),
    .gps_rx(gps_rx_fixed),
    .data_out(gps_data_out),
    .data_valid(gps_data_valid)
);

wire fix_ok;
wire fix_bad;

gprmc_fix_detector detector (
    .clk(clk),
    .rst(rst),
    .rx_data(gps_data_out),
    .rx_valid(gps_data_valid),
    .fix_valid(fix_ok),
    .fix_invalid(fix_bad)
);

assign led[0] = fix_ok;
assign led[1] = fix_bad;

wire [9:0] lat0, lat1, lat2, lat3, lat4, lat5, lat6, lat7, lat8, lat9;
wire [10:0] lon0, lon1, lon2, lon3, lon4, lon5, lon6, lon7, lon8, lon9, lon10;
wire [3:0] lat_len;
wire [3:0] lon_len;
wire       lat_dir;
wire       lon_dir;
wire       new_fix;

gprmc_parser PARSER (
    .clk(clk),
    .rst(rst),
    .rx_data(gps_data_out),
    .rx_valid(gps_data_valid),

    .lat0(lat0),
    .lat1(lat1),
    .lat2(lat2),
    .lat3(lat3),
    .lat4(lat4),
    .lat5(lat5),
    .lat6(lat6),
    .lat7(lat7),
    .lat8(lat8),
    .lat9(lat9),
    .lat_len(lat_len),
    .lat_dir(lat_dir),

    .lon0(lon0),
    .lon1(lon1),
    .lon2(lon2),
    .lon3(lon3),
    .lon4(lon4),
    .lon5(lon5),
    .lon6(lon6),
    .lon7(lon7),
    .lon8(lon8),
    .lon9(lon9),
    .lon10(lon10),
    .lon_len(lon_len),
    .lon_dir(lon_dir),

    .new_fix(new_fix)
);

wire [3:0] d0;
wire [3:0] d1;
wire [3:0] d2;
wire [3:0] d3;

wire [7:0] lat0 = lat_digits[0];
wire [7:0] lat1 = lat_digits[1];
wire [7:0] lat2 = lat_digits[2];
wire [7:0] lat3 = lat_digits[3];
wire [7:0] lat4 = lat_digits[4];
wire [7:0] lat5 = lat_digits[5];
wire [7:0] lat6 = lat_digits[6];
wire [7:0] lat7 = lat_digits[7];
wire [7:0] lat8 = lat_digits[8];
wire [7:0] lat9 = lat_digits[9];

ddmm_extract DDMM (
    .clk(clk),
    .rst(rst),
    .new_fix(new_fix),

    .lat0(lat0),
    .lat1(lat1),
    .lat2(lat2),
    .lat3(lat3),
    .lat4(lat4),
    .lat5(lat5),
    .lat6(lat6),
    .lat7(lat7),
    .lat8(lat8),
    .lat9(lat9),
    .lat_len(lat_len),

    .d0(d0),
    .d1(d1),
    .d2(d2),
    .d3(d3)
);

seven_seg_driver DISP (
    .clk(clk),
    .rst(rst),

    .d0(d0),
    .d1(d1),
    .d2(d2),
    .d3(d3),

    .an(an),
    .seg(seg)
);
/*
assign gps_data_filtered = 
    (gps_data_out >= 8'h20 && gps_data_out <=8'h7E)
        ? gps_data_out
        : 8'h20; //'?'
*/
/*
nmea_filter FILTER(
    .clk(clk),
    .rst(rst),
    .rx_data(gps_data_out),
    .rx_valid(gps_data_valid),
    .data_out(filtered_byte),
    .data_valid(filtered_valid)

);
*/
// --- Instance 2: UART Transmitter (Sends data to PC) ---
// Transmits the received GPS byte to the PC as soon as it is valid.

/*
uart_tx_echo #(
    .CLK_FREQ_HZ(100000000),
    .BAUD_RATE(9600)
)
i_uart_tx (
    .clk(clk),
    .rst(rst),
    // Trigger transmission immediately when the receiver confirms a valid byte
    .tx_start(filtered_valid), 
    // Data input is the data just received from the GPS
    .data_in(filtered_byte),     
    .tx(tx) // Connected to the top-level 'tx' port
);
*/
endmodule
