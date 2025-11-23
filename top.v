// top.v
`timescale 1ns / 1ps

module top (
    input  wire clk,          // 100 MHz
    input  wire btnC,         // reset button

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

    // -----------------------------------
    // 7-seg display: show step_count
    // -----------------------------------
    sevenseg_hex u_disp (
        .clk   (clk),
        .reset (reset),
        .value (step_count),   // was z_abs before; now step counter
        .seg   (seg),
        .an    (an),
        .dp    (dp)
    );

endmodule


