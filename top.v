// top.v
`timescale 1ns / 1ps

module top (
    input  wire clk,          // 100 MHz
    input  wire btnC,         // reset button
    input wire gps_rx,
    input wire [15:0] sw,
    
    // SPI pins to Pmod ACL2 (map these to JA in XDC)
    output wire acl_sclk,
    output wire acl_mosi,
    input  wire acl_miso,
    output wire acl_cs_n,

    // 7-seg
    output wire [6:0] seg,
    output wire [3:0] an,
    output wire       dp
);

//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
// GPS MODE INSTANTIATIONS

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
    .rst(reset),
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
    .rst(reset),
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
    .rst(reset),
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

    if (sw[2]) begin
        d0 = mph0; d1 = mph1; d2 = mph2; d3 = mph3;     // MPH mode
    end
    else if (sw[3]) begin
        d0 = lon0; d1 = lon1; d2 = lon2; d3 = lon3; // Longitude
    end
    else if (~sw[3]) begin
        d0 = lat0; d1 = lat1; d2 = lat2; d3 = lat3; // Latitude (default)
    end

end

wire [15:0] gps_output = {d3, d2, d1, d0};
//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////

    // Simple reset (active-high)
    wire reset = btnC;

    // -------------------------------
    // ADXL362: raw Z + valid strobe
    // -------------------------------
    wire signed [15:0] z_data;
    wire               z_valid;

    adxl362_simple u_acl (
        .clk      (clk),
        .reset    (reset),
        .spi_cs_n (acl_cs_n),
        .spi_sclk (acl_sclk),
        .spi_mosi (acl_mosi),
        .spi_miso (acl_miso),
        .z_data   (z_data),
        .z_valid  (z_valid)
    );

    // -----------------------------------
    // Preprocess: baseline + dynamic + |·|
    // -----------------------------------
    wire signed [15:0] z_baseline;
    wire signed [15:0] z_dynamic;
    wire        [15:0] z_dynamic_abs;
    wire               dyn_valid;

    accel_preprocess #(
        .BASELINE_SHIFT(6)        // tune this later if needed
    ) u_pre (
        .clk           (clk),
        .reset         (reset),
        .z_data        (z_data),
        .z_valid       (z_valid),
        .z_baseline    (z_baseline),
        .z_dynamic     (z_dynamic),
        .z_dynamic_abs (z_dynamic_abs),
        .dyn_valid     (dyn_valid)
    );

    // -------------------------
    // Step detector
    // -------------------------
    wire        step_pulse;
    wire [15:0] step_count;
    wire        in_peak_dbg;
    wire [15:0] peak_len_dbg;
    wire [15:0] gap_dbg;

    step_detector #(
        // You can tweak these later after you see behavior
        .TH_HIGH              (16'd250),
        .TH_LOW               (16'd150),
        .MIN_PEAK_SAMPLES     (8),
        .MAX_PEAK_SAMPLES     (200),
        .MIN_STEP_GAP_SAMPLES (200)
    ) u_step (
        .clk              (clk),
        .reset            (reset),
        .dyn_valid        (dyn_valid),
        .z_dynamic_abs    (z_dynamic_abs),
        .step_pulse       (step_pulse),
        .step_count       (step_count),
        .in_peak          (in_peak_dbg),
        .peak_len_samples (peak_len_dbg),
        .gap_samples      (gap_dbg)
    );
    
    wire [15:0] spm;
    steps_per_min(.clk(clk), .rst(reset), .spm(spm));

    // -----------------------------------
    // 7-seg display multiplexing 
    // -----------------------------------
    wire [15:0] output_to_display;
    wire output_select;
    
    /*
    If switch 15 is HIGH, mode is step_count
        If switch 1 is HIGH, mode is total step_count
        If switch 1 is LOW, mode is steps_per_minute
    If switch 15 is LOW, mode is GPS
        If switch 2 is HIGH, mode is long/lat 
        If Switch 2 is LOW, mode is speed
        If Switch 3 is HIGH, display long
        If Switch 4 is LOW, display lat
    */
    
    reg [15:0] output_to_display_r;
assign output_to_display = output_to_display_r;

always @* begin
    // default
    output_to_display_r = 16'd0;

    if (sw[15]) begin
        // STEP MODE
        if (sw[1]) begin
            output_to_display_r = step_count;   // total steps
        end else begin
            output_to_display_r = spm;          // steps per minute
        end
    end else begin
        // GPS MODE
        output_to_display_r = gps_output;       // already muxed long/lat/speed externally
    end
end

    
    sevenseg_hex display_output (
        .clk   (clk),
        .reset (reset),
        .value (output_to_display),  
        .seg   (seg),
        .an    (an),
        .dp    (dp)
    );


///////////////////////////

endmodule


