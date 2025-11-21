`timescale 1ns / 1ps

module gprmc_parser (
    input clk,
    input rst,

    // UART input
    input [7:0] rx_data,
    input       rx_valid,

    // Fix status output
    output reg fix_valid,    // 1 = Active (A), 0 = Void (V)

    // Latitude ASCII digits
    output [7:0] lat0, lat1, lat2, lat3, lat4, lat5, lat6, lat7,

    // Longitude ASCII digits
    output [7:0] lon0, lon1, lon2, lon3, lon4, lon5, lon6, lon7,

    // Speed ASCII digits (knots)
    output [7:0] spd0, spd1, spd2, spd3, spd4, spd5,
    output reg   speed_ready
);


// ---------------------------
// Internal Registers
// ---------------------------

// State tracking
reg seen_g;
reg seen_p;
reg seen_r;

// Comma counting
reg [3:0] comma_count;

// Status (A/V)
reg [7:0] status_char;

// Latitude registers
reg [7:0] lat0_reg, lat1_reg, lat2_reg, lat3_reg;
reg [7:0] lat4_reg, lat5_reg, lat6_reg, lat7_reg;
reg [3:0] lat_len;

// Longitude registers
reg [7:0] lon0_reg, lon1_reg, lon2_reg, lon3_reg;
reg [7:0] lon4_reg, lon5_reg, lon6_reg, lon7_reg;
reg [3:0] lon_len;

// Speed registers
reg [7:0] spd0_reg, spd1_reg, spd2_reg, spd3_reg, spd4_reg, spd5_reg;
reg [2:0] speed_len;


// ---------------------------
// Sequential Logic
// ---------------------------
always @(posedge clk) begin
    if (rst) begin
        seen_g <= 0;
        seen_p <= 0;
        seen_r <= 0;

        comma_count  <= 0;

        lat_len <= 0;
        lon_len <= 0;
        speed_len <= 0;

        fix_valid   <= 0;
        speed_ready <= 0;
    end
    else if (rx_valid) begin
       
        // -------------------------------
        // Detect "$GPRMC"
        // -------------------------------
        
        if (rx_data == "$") begin
            lat0_reg <= "0";
            lat1_reg <= "0";
            lat2_reg <= "0";
            lat3_reg <= "0";
            lat4_reg <= "0";
            lat5_reg <= "0";
            lat6_reg <= "0";
            lat7_reg <= "0";

            lon0_reg <= "0";
            lon1_reg <= "0";
            lon2_reg <= "0";
            lon3_reg <= "0";
            lon4_reg <= "0";
            lon5_reg <= "0";
            lon6_reg <= "0";
            lon7_reg <= "0";

            spd0_reg <= "0";
            spd1_reg <= "0";
            spd2_reg <= "0";
            spd3_reg <= "0";
            spd4_reg <= "0";
            spd5_reg <= "0";

            comma_count <= 0;
            lat_len   <= 0;
            lon_len   <= 0;
            speed_len   <= 0;

            // IMPORTANT: do NOT "skip" the rest of the parser
            // Just continue to next byte
        end
        
        if (!seen_g && rx_data == "$")
            seen_g <= 1;
        else if (seen_g && !seen_p && rx_data == "G")
            seen_p <= 1;
        else if (seen_g && seen_p && !seen_r && rx_data == "P")
            seen_r <= 1;
       
        // Fully detected "$GPR"
        if (seen_g && seen_p && seen_r && rx_data == "M") begin
            comma_count <= 0;
        end

        // Count commas AFTER "$GPRMC"
        if (rx_data == "," && seen_r)
            comma_count <= comma_count + 1;


        // ---------------------------------
        // FIELD 2 ? Fix Status (A or V)
        // comma_count = 1
        // ---------------------------------
        if (comma_count == 1 && rx_data != ",") begin
            status_char <= rx_data;
            fix_valid <= (rx_data == "A") ? 1'b1 : 1'b0;
        end


        // ---------------------------------
        // FIELD 3 ? Latitude (DDMMmmmm)
        // comma_count = 2
        // ---------------------------------
        if (comma_count == 2) begin
            if (rx_data != ",") begin
                case(lat_len)
                    0: lat0_reg <= rx_data;
                    1: lat1_reg <= rx_data;
                    2: lat2_reg <= rx_data;
                    3: lat3_reg <= rx_data;
                    4: lat4_reg <= rx_data;
                    5: lat5_reg <= rx_data;
                    6: lat6_reg <= rx_data;
                    7: lat7_reg <= rx_data;
                endcase
                if (lat_len < 7) lat_len <= lat_len + 1;
            end
            else begin
                lat_len <= 0;
            end
        end


        // ---------------------------------
        // FIELD 5 ? Longitude
        // comma_count = 4
        // ---------------------------------
        if (comma_count == 4) begin
            if (rx_data != ",") begin
                case(lon_len)
                    0: lon0_reg <= rx_data;
                    1: lon1_reg <= rx_data;
                    2: lon2_reg <= rx_data;
                    3: lon3_reg <= rx_data;
                    4: lon4_reg <= rx_data;
                    5: lon5_reg <= rx_data;
                    6: lon6_reg <= rx_data;
                    7: lon7_reg <= rx_data;
                endcase
                if (lon_len < 7) lon_len <= lon_len + 1;
            end
            else begin
                lon_len <= 0;
            end
        end


        // ---------------------------------
        // FIELD 7 ? Speed in knots (ASCII)
        // comma_count = 6
        // ---------------------------------
        if (comma_count == 6) begin

            if (rx_data != ",") begin
                case(speed_len)
                    0: spd0_reg <= rx_data;
                    1: spd1_reg <= rx_data;
                    2: spd2_reg <= rx_data;
                    3: spd3_reg <= rx_data;
                    4: spd4_reg <= rx_data;
                    5: spd5_reg <= rx_data;
                endcase

                if (speed_len < 6)
                    speed_len <= speed_len + 1;
                    
                speed_ready <=1'b0;
            end

            else begin
                speed_ready <= 1'b1;
                speed_len   <= 0;
            end
        end
        else begin
            speed_ready <= 0; // pulse only for one comma
        end

    end
end


// ---------------------------------
// Output assignments
// ---------------------------------

assign lat0 = lat0_reg;
assign lat1 = lat1_reg;
assign lat2 = lat2_reg;
assign lat3 = lat3_reg;
assign lat4 = lat4_reg;
assign lat5 = lat5_reg;
assign lat6 = lat6_reg;
assign lat7 = lat7_reg;

assign lon0 = lon0_reg;
assign lon1 = lon1_reg;
assign lon2 = lon2_reg;
assign lon3 = lon3_reg;
assign lon4 = lon4_reg;
assign lon5 = lon5_reg;
assign lon6 = lon6_reg;
assign lon7 = lon7_reg;

assign spd0 = spd0_reg;
assign spd1 = spd1_reg;
assign spd2 = spd2_reg;
assign spd3 = spd3_reg;
assign spd4 = spd4_reg;
assign spd5 = spd5_reg;

endmodule