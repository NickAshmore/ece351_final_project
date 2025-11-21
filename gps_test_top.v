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

wire [9:0] lat0, lat1, lat2, lat3, lat4, lat5, lat6, lat7;
wire [10:0] lon0, lon1, lon2, lon3, lon4, lon5, lon6, lon7;

wire [7:0] spd0, spd1, spd2, spd3, spd4, spd5;
wire [3:0] speed_len;
wire speed_ready;
wire new_fix = speed_ready;

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

    .lon0(lon0),
    .lon1(lon1),
    .lon2(lon2),
    .lon3(lon3),
    .lon4(lon4),
    .lon5(lon5),
    .lon6(lon6),
    .lon7(lon7),
    
    .spd0(spd0),
    .spd1(spd1),
    .spd2(spd2),
    .spd3(spd3),
    .spd4(spd4),
    .spd5(spd5),
    
    .speed_ready(speed_ready)
);

speed_extract SPEEDX (
    .clk(clk),
    .rst(rst),
    .new_fix(new_fix),     // you already have: new_fix = speed_ready

    .spd0(spd0),
    .spd1(spd1),
    .spd2(spd2),
    .spd3(spd3),
    .spd4(spd4),
    .spd5(spd5),
    .speed_len(speed_len),

    .speed_scaled(speed_scaled),   // knots × 10
    .speed_valid(speed_valid)
);


wire [3:0] d0;
wire [3:0] d1;
wire [3:0] d2;
wire [3:0] d3;


/*
ddmm_extract DDMM (
    .clk(clk),
    .rst(rst),
    .new_fix(new_fix),

    .lat0(lat0),
    .lat1(lat1),
    .lat2(lat2),
    .lat3(lat3),
//    .lat4(lat4),
//    .lat5(lat5),
//    .lat6(lat6),
//    .lat7(lat7),

    .d0(d0),
    .d1(d1),
    .d2(d2),
    .d3(d3)
);
*/

wire [3:0] d0_pace, d1_pace, d2_pace, d3_pace;
wire [15:0] pace_seconds;
wire pace_valid;

pace_converter PACER (
    .clk(clk),
    .rst(rst),
    .speed_valid(speed_valid),
    .speed_scaled(speed_scaled),

    .pace_seconds(pace_seconds),
    .pace_valid(pace_valid),

    .d0_pace(d0_pace),
    .d1_pace(d1_pace),
    .d2_pace(d2_pace),
    .d3_pace(d3_pace)
);


seven_seg_driver DISP (
    .clk(clk),
    .rst(rst),

    .d0(d0_pace),
    .d1(d1_pace),
    .d2(d2_pace),
    .d3(d3_pace),

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
