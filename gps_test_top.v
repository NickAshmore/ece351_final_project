`timescale 1ns / 1ps

module gps_display_top (
    input  wire        clk,       // 100 MHz clock
    input  wire        rst,
    input  wire        gps_rx,    // GPS TX → FPGA RX (JA1)
    output wire [1:0]  led,       // Fix LEDs
    input  wire [3:0]  sw,        // Mode switches
    output wire [3:0]  an,
    output wire [6:0]  seg
);

// ===================================================
//  UART RECEIVER
// ===================================================
wire [7:0] gps_data_out;
wire       gps_data_valid;

uart_rx #(
    .CLK_FREQ_HZ(100000000),
    .BAUD_RATE(9600)
)
UART_RX (
    .clk(clk),
    .rst(rst),
    .gps_rx(gps_rx),
    .data_out(gps_data_out),
    .data_valid(gps_data_valid)
);

wire [7:0] lat0, lat1, lat2, lat3, lat4, lat5, lat6, lat7;
wire [7:0] lon0, lon1, lon2, lon3, lon4, lon5, lon6, lon7;

wire [7:0] spd0, spd1, spd2, spd3, spd4, spd5;
wire       speed_ready;

gprmc_parser PARSER (
    .clk(clk),
    .rst(rst),
    .rx_data(gps_data_out),
    .rx_valid(gps_data_valid),

    .fix_valid(),       // already handled
    .lat0(lat0), .lat1(lat1), .lat2(lat2), .lat3(lat3),
    .lat4(lat4), .lat5(lat5), .lat6(lat6), .lat7(lat7),

    .lon0(lon0), .lon1(lon1), .lon2(lon2), .lon3(lon3),
    .lon4(lon4), .lon5(lon5), .lon6(lon6), .lon7(lon7),

    .spd0(spd0), .spd1(spd1), .spd2(spd2),
    .spd3(spd3), .spd4(spd4), .spd5(spd5),

    .speed_ready(speed_ready)
);

wire [3:0] mph0, mph1, mph2, mph3;
wire [15:0] mph_x100;

knots_to_mph MPH (
    .clk(clk),
    .rst(rst),
    .speed_ready(speed_ready),

    .spd0(spd0), .spd1(spd1), .spd2(spd2),
    .spd3(spd3), .spd4(spd4), .spd5(spd5),

    .mph0(mph0), .mph1(mph1), .mph2(mph2), .mph3(mph3),
    .mph_x100_out(mph_x100)
);

// ===================================================
//  MODE MULTIPLEXER
// ===================================================
// sw[0]=MPH
// sw[1]=DIST
// sw[2]=LON
// sw[3]=LAT
reg [3:0] d0, d1, d2, d3;

always @(*) begin

    if (sw[0]) begin
        d0 = mph0; d1 = mph1; d2 = mph2; d3 = mph3;     // MPH mode
    end
    else if (sw[2]) begin
        d0 = lon0; d1 = lon1; d2 = lon2; d3 = lon3; // Longitude
    end
    else begin
        d0 = lat0; d1 = lat1; d2 = lat2; d3 = lat3; // Latitude (default)
    end

end

// ===================================================
//  7-SEG DISPLAY DRIVER
// ===================================================
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

endmodule


