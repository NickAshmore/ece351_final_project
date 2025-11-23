`timescale 1ns / 1ps


/*
// step_detector.v
// Uses |dynamic Z| + sample strobe to detect steps.
//
// Pipeline should be:
//   adxl362_simple -> accel_preprocess -> step_detector
//
// Tune parameters based on your sample rate and testing.

module step_detector #(
    // Magnitude thresholds (in raw accel LSBs after preprocessing)
    parameter [15:0] TH_HIGH = 16'd250,  // must exceed this to start a peak
    parameter [15:0] TH_LOW  = 16'd150,  // must fall below this to end a peak

    // Peak duration limits (in samples with dyn_valid = 1)
    // For ~1 kHz accel sampling:
    //   MIN_PEAK_SAMPLES ~ 5–10 (5–10 ms)
    //   MAX_PEAK_SAMPLES ~ 200   (200 ms)
    parameter integer MIN_PEAK_SAMPLES = 8,
    parameter integer MAX_PEAK_SAMPLES = 200,

    // Minimum gap between steps (in samples)
    // For ~1 kHz, 200 samples = 200 ms (max ~5 steps/s)
    parameter integer MIN_STEP_GAP_SAMPLES = 1000
)(
    input  wire        clk,
    input  wire        reset,

    // From accel_preprocess:
    input  wire        dyn_valid,        // strobe for new |dynamic| sample
    input  wire [15:0] z_dynamic_abs,    // |sample - baseline|

    // Outputs:
    output reg         step_pulse,       // 1 clk when a step is detected
    output reg [15:0]  step_count,       // running count

    // Optional debug:
    output reg         in_peak,          // currently inside a candidate peak
    output reg [15:0]  peak_len_samples, // samples in current peak
    output reg [15:0]  gap_samples       // samples since last accepted step
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            step_pulse        <= 1'b0;
            step_count        <= 16'd0;
            in_peak           <= 1'b0;
            peak_len_samples  <= 16'd0;
            gap_samples       <= 16'd0;
        end else begin
            // default: no pulse this cycle
            step_pulse <= 1'b0;

            // increment gap timer on each new sample
            if (dyn_valid) begin
                if (gap_samples != 16'hFFFF)
                    gap_samples <= gap_samples + 16'd1;
            end

            if (dyn_valid) begin
                // ----------------------------
                // PEAK ENTRY (start candidate)
                // ----------------------------
                if (!in_peak) begin
                    // only start a peak if:
                    //  - magnitude is above TH_HIGH, and
                    //  - enough time has passed since last accepted step
                    if (z_dynamic_abs >= TH_HIGH &&
                        gap_samples >= MIN_STEP_GAP_SAMPLES[15:0]) begin
                        in_peak          <= 1'b1;
                        peak_len_samples <= 16'd1;  // count this sample
                    end
                end else begin
                    // ----------------------------
                    // INSIDE A PEAK
                    // ----------------------------

                    // still above the lower threshold? keep counting length
                    if (z_dynamic_abs >= TH_LOW) begin
                        if (peak_len_samples != 16'hFFFF)
                            peak_len_samples <= peak_len_samples + 16'd1;

                        // If it runs too long, abandon this peak
                        if (peak_len_samples >= MAX_PEAK_SAMPLES[15:0]) begin
                            in_peak          <= 1'b0;
                            peak_len_samples <= 16'd0;
                        end
                    end
                    // dropped below TH_LOW ? peak ended, decide if it's a step
                    else begin
                        // Accept as a step if peak duration is in valid window
                        if (peak_len_samples >= MIN_PEAK_SAMPLES[15:0] &&
                            peak_len_samples <= MAX_PEAK_SAMPLES[15:0] &&
                            gap_samples      >= MIN_STEP_GAP_SAMPLES[15:0]) begin
                            step_pulse  <= 1'b1;
                            step_count  <= step_count + 16'd1;
                            gap_samples <= 16'd0;
                        end

                        // In any case, leave peak state
                        in_peak          <= 1'b0;
                        peak_len_samples <= 16'd0;
                    end
                end
            end
        end
    end

endmodule */
/*
module step_detector #(
    // Magnitude thresholds (in raw accel LSBs after preprocessing)
    parameter [15:0] TH_HIGH = 16'd250,  // must exceed this to start a peak
    parameter [15:0] TH_LOW  = 16'd150,  // must fall below this to end a peak

    // Peak duration limits (in samples with dyn_valid = 1)
    parameter integer MIN_PEAK_SAMPLES = 8,
    parameter integer MAX_PEAK_SAMPLES = 200,

    // Minimum gap between steps, measured in *samples* (dyn_valid strobes)
    // For ~1 kHz sampling, 200 samples ~ 200 ms
    parameter integer MIN_STEP_GAP_SAMPLES = 200,

    // Minimum gap between steps, measured in *clock cycles*
    // e.g. at 100 MHz: 50_000_000 cycles ? 0.5 s
    parameter integer MIN_STEP_GAP_CYCLES  = 50_000_000
)(
    input  wire        clk,
    input  wire        reset,

    // From accel_preprocess:
    input  wire        dyn_valid,        // strobe for new |dynamic| sample
    input  wire [15:0] z_dynamic_abs,    // |sample - baseline|

    // Outputs:
    output reg         step_pulse,       // 1 clk when a step is detected
    output reg [15:0]  step_count,       // running count

    // Optional debug:
    output reg         in_peak,          // currently inside a candidate peak
    output reg [15:0]  peak_len_samples, // samples in current peak
    output reg [15:0]  gap_samples       // samples since last accepted step
);

    // New: gap in raw clock cycles since last accepted step
    reg [31:0] gap_cycles;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            step_pulse        <= 1'b0;
            step_count        <= 16'd0;
            in_peak           <= 1'b0;
            peak_len_samples  <= 16'd0;
            gap_samples       <= 16'd0;
            gap_cycles        <= 32'd0;
        end else begin
            // default: no pulse this cycle
            step_pulse <= 1'b0;

            // Clock-based gap counter: counts every clk
            if (gap_cycles != 32'hFFFF_FFFF)
                gap_cycles <= gap_cycles + 32'd1;

            // Sample-based gap counter: counts dyn_valid strobes
            if (dyn_valid) begin
                if (gap_samples != 16'hFFFF)
                    gap_samples <= gap_samples + 16'd1;
            end

            if (dyn_valid) begin
                // ----------------------------
                // PEAK ENTRY (start candidate)
                // ----------------------------
                if (!in_peak) begin
                    // only start a peak if:
                    //  - magnitude is above TH_HIGH, and
                    //  - enough time has passed since last accepted step
                    //    in BOTH samples and clock cycles
                    if (z_dynamic_abs >= TH_HIGH &&
                        gap_samples >= MIN_STEP_GAP_SAMPLES[15:0] &&
                        gap_cycles  >= MIN_STEP_GAP_CYCLES[31:0]) begin
                        in_peak          <= 1'b1;
                        peak_len_samples <= 16'd1;  // count this sample
                    end
                end else begin
                    // ----------------------------
                    // INSIDE A PEAK
                    // ----------------------------

                    // still above the lower threshold? keep counting length
                    if (z_dynamic_abs >= TH_LOW) begin
                        if (peak_len_samples != 16'hFFFF)
                            peak_len_samples <= peak_len_samples + 16'd1;

                        // If it runs too long, abandon this peak
                        if (peak_len_samples >= MAX_PEAK_SAMPLES[15:0]) begin
                            in_peak          <= 1'b0;
                            peak_len_samples <= 16'd0;
                        end
                    end
                    // dropped below TH_LOW ? peak ended, decide if it's a step
                    else begin
                        // Accept as a step if peak duration is in valid window
                        // AND the cooldown has elapsed (samples + cycles)
                        if (peak_len_samples >= MIN_PEAK_SAMPLES[15:0] &&
                            peak_len_samples <= MAX_PEAK_SAMPLES[15:0] &&
                            gap_samples      >= MIN_STEP_GAP_SAMPLES[15:0] &&
                            gap_cycles       >= MIN_STEP_GAP_CYCLES[31:0]) begin
                            step_pulse  <= 1'b1;
                            step_count  <= step_count + 16'd1;
                            gap_samples <= 16'd0;
                            gap_cycles  <= 32'd0;
                        end

                        // In any case, leave peak state
                        in_peak          <= 1'b0;
                        peak_len_samples <= 16'd0;
                    end
                end
            end
        end
    end

endmodule
*/
module step_detector #(
    // Magnitude thresholds (in raw accel LSBs after preprocessing)
    parameter [15:0] TH_HIGH = 16'd250,  // must exceed this to start a peak
    parameter [15:0] TH_LOW  = 16'd150,  // must fall below this to end a peak

    // Peak duration limits (in samples with dyn_valid = 1)
    parameter integer MIN_PEAK_SAMPLES = 8,
    parameter integer MAX_PEAK_SAMPLES = 200,

    // Minimum gap between steps, measured in *samples* (dyn_valid strobes)
    parameter integer MIN_STEP_GAP_SAMPLES = 200,

    // Minimum gap between steps, measured in *clock cycles*
    // e.g. at 100 MHz: 50_000_000 cycles ? 0.5 s
    parameter integer MIN_STEP_GAP_CYCLES  = 50_000_000
)(
    input  wire        clk,
    input  wire        reset,

    // From accel_preprocess:
    input  wire        dyn_valid,        // strobe for new |dynamic| sample
    input  wire [15:0] z_dynamic_abs,    // |sample - baseline|

    // Outputs:
    output reg         step_pulse,       // 1 clk when a step is detected
    output reg [15:0]  step_count,       // running count

    // Optional debug:
    output reg         in_peak,          // high when in a peak-related state
    output reg [15:0]  peak_len_samples, // samples in current peak
    output reg [15:0]  gap_samples       // samples since last accepted step
);

    // Gap in raw clock cycles since last accepted step
    reg [31:0] gap_cycles;

    // ------------------------------------------------------------
    // FSM state encoding
    // ------------------------------------------------------------
    localparam [1:0]
        S_IDLE       = 2'd0,
        S_PEAK_RISE  = 2'd1,
        S_PEAK_FALL  = 2'd2,
        S_COOLDOWN   = 2'd3;

    reg [1:0] state, next_state;

    // handy wires for checks
    wire peak_len_too_short = (peak_len_samples <  MIN_PEAK_SAMPLES[15:0]);
    wire peak_len_too_long  = (peak_len_samples >  MAX_PEAK_SAMPLES[15:0]);
    wire peak_len_valid     = (peak_len_samples >= MIN_PEAK_SAMPLES[15:0] &&
                               peak_len_samples <= MAX_PEAK_SAMPLES[15:0]);

    wire cooldown_done_samples = (gap_samples >= MIN_STEP_GAP_SAMPLES[15:0]);
    wire cooldown_done_cycles  = (gap_cycles  >= MIN_STEP_GAP_CYCLES[31:0]);
    wire cooldown_done         = cooldown_done_samples && cooldown_done_cycles;

    // ------------------------------------------------------------
    // Sequential block: state register & datapath updates
    // ------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state            <= S_IDLE;
            step_pulse       <= 1'b0;
            step_count       <= 16'd0;
            in_peak          <= 1'b0;
            peak_len_samples <= 16'd0;
            gap_samples      <= 16'd0;
            gap_cycles       <= 32'd0;
        end else begin
            state      <= next_state;
            step_pulse <= 1'b0;  // default, overridden on valid step

            // Gap timers: count since last accepted step
            // gap_cycles: every clock, saturate at max
            if (gap_cycles != 32'hFFFF_FFFF)
                gap_cycles <= gap_cycles + 32'd1;

            // gap_samples: count dyn_valid strobes, saturate at max
            if (dyn_valid) begin
                if (gap_samples != 16'hFFFF)
                    gap_samples <= gap_samples + 16'd1;
            end

            // Default in_peak based on state
            in_peak <= (state == S_PEAK_RISE) || (state == S_PEAK_FALL);

            // Peak length counting & step detection
            case (state)
                // ------------------------------------------------
                // IDLE: waiting for a new peak
                // ------------------------------------------------
                S_IDLE: begin
                    // no active peak
                    peak_len_samples <= 16'd0;

                    if (dyn_valid && z_dynamic_abs >= TH_HIGH) begin
                        // starting a new peak: count this first sample
                        peak_len_samples <= 16'd1;
                    end
                end

                // ------------------------------------------------
                // PEAK_RISE: inside a peak while magnitude is high
                // ------------------------------------------------
                S_PEAK_RISE: begin
                    if (dyn_valid) begin
                        if (z_dynamic_abs >= TH_LOW) begin
                            // still inside peak, keep counting length
                            if (peak_len_samples != 16'hFFFF)
                                peak_len_samples <= peak_len_samples + 16'd1;
                        end
                        // else: fell below TH_LOW, peak_len_samples frozen
                        // and we'll evaluate it in S_PEAK_FALL
                    end
                end

                // ------------------------------------------------
                // PEAK_FALL: peak just ended, decide if it was a step
                // ------------------------------------------------
                S_PEAK_FALL: begin
                    // Decide only once, on entering this state.
                    // If peak duration is valid, register a step.
                    if (peak_len_valid) begin
                        step_pulse       <= 1'b1;
                        step_count       <= step_count + 16'd1;
                        gap_samples      <= 16'd0;
                        gap_cycles       <= 32'd0;
                    end

                    // After decision, peak_len_samples no longer needed
                    peak_len_samples <= 16'd0;
                end

                // ------------------------------------------------
                // COOLDOWN: enforce minimum time between steps
                // ------------------------------------------------
                S_COOLDOWN: begin
                    // Nothing special here; cooldown_done is checked
                    // in next_state logic. We just wait.
                    peak_len_samples <= 16'd0;
                end

                default: begin
                    // safety
                    peak_len_samples <= 16'd0;
                end
            endcase
        end
    end

    // ------------------------------------------------------------
    // Combinational block: next-state logic
    // ------------------------------------------------------------
    always @* begin
        next_state = state;

        case (state)
            // ----------------------------------------------------
            // IDLE: can start a peak if TH_HIGH is crossed
            // ----------------------------------------------------
            S_IDLE: begin
                if (dyn_valid && z_dynamic_abs >= TH_HIGH) begin
                    next_state = S_PEAK_RISE;
                end
            end

            // ----------------------------------------------------
            // PEAK_RISE: stay while above TH_LOW, else go to PEAK_FALL
            // If peak gets too long, abandon and go to IDLE.
            // ----------------------------------------------------
            S_PEAK_RISE: begin
                if (dyn_valid) begin
                    if (z_dynamic_abs >= TH_LOW) begin
                        // still in peak; if it's already too long, abandon
                        if (peak_len_samples >= MAX_PEAK_SAMPLES[15:0])
                            next_state = S_IDLE;  // invalid long peak
                        else
                            next_state = S_PEAK_RISE;
                    end else begin
                        // fell below TH_LOW: peak ended, evaluate
                        next_state = S_PEAK_FALL;
                    end
                end
            end

            // ----------------------------------------------------
            // PEAK_FALL: duration is already frozen in peak_len_samples.
            // If valid duration ? COOLDOWN, else ? IDLE.
            // ----------------------------------------------------
            S_PEAK_FALL: begin
                if (peak_len_valid)
                    next_state = S_COOLDOWN;  // accepted step
                else
                    next_state = S_IDLE;      // rejected (too short/long)
            end

            // ----------------------------------------------------
            // COOLDOWN: wait until both time-based and sample-based
            // gaps have elapsed, then go back to IDLE.
            // ----------------------------------------------------
            S_COOLDOWN: begin
                if (cooldown_done)
                    next_state = S_IDLE;
            end

            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

endmodule

