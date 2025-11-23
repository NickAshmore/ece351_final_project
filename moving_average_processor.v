`timescale 1ns / 1ps

// Goal of this module is to take the raw, signed z-axis acceleration value, convert it to unsigned 16 bit magnitude.
// Then, rather than tracking the magnitude, we need to track change in magnitude. If we take a moving average over the past 5 samples, 
// and subtract this moving average from the most recent reading, we will see the relative acceleration. 
// 

module accel_preprocess #(
    // Bigger SHIFT = slower baseline (follows only very slow changes)
    parameter integer BASELINE_SHIFT = 6  // ~1/64 step toward new sample
)(
    input  wire              clk,
    input  wire              reset,
    input  wire signed [15:0] z_data,   // raw signed Z from accelerometer
    input  wire              z_valid,   // 1-cycle strobe per new sample

    output reg  signed [15:0] z_baseline,     // slow baseline (gravity)
    output reg  signed [15:0] z_dynamic,      // signed: sample - baseline
    output reg         [15:0] z_dynamic_abs,  // |z_dynamic|
    output reg                dyn_valid       // 1-cycle strobe when updated
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            z_baseline    <= 16'sd0;
            z_dynamic     <= 16'sd0;
            z_dynamic_abs <= 16'd0;
            dyn_valid     <= 1'b0;
        end else begin
            dyn_valid <= 1'b0;  // default

            if (z_valid) begin
                // --- compute dynamic = current sample - current baseline ---
                // (1-sample delay vs updated baseline is fine; baseline is slow)
                z_dynamic <= z_data - z_baseline;

                // --- absolute value of dynamic (two's complement) ---
                if (z_dynamic[15])
                    z_dynamic_abs <= (~z_dynamic + 16'd1);
                else
                    z_dynamic_abs <= z_dynamic[15:0];

                // --- update slow baseline (IIR low-pass) ---
                // baseline += (z_data - baseline) / 2^BASELINE_SHIFT
                z_baseline <= z_baseline +
                              ((z_data - z_baseline) >>> BASELINE_SHIFT);

                // mark outputs valid this cycle
                dyn_valid <= 1'b1;
            end
        end
    end

endmodule

