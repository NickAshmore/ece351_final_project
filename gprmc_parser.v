`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/19/2025 03:31:41 PM
// Design Name: 
// Module Name: gprmc_parser
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

module gprmc_parser (
    input  wire       clk,
    input  wire       rst,

    input  wire [7:0] rx_data,
    input  wire       rx_valid,

    // Flattened latitude output (max 10 digits)
    output reg [7:0] lat0,
    output reg [7:0] lat1,
    output reg [7:0] lat2,
    output reg [7:0] lat3,
    output reg [7:0] lat4,
    output reg [7:0] lat5,
    output reg [7:0] lat6,
    output reg [7:0] lat7,
    output reg [7:0] lat8,
    output reg [7:0] lat9,
    output reg [3:0] lat_len,
    output reg       lat_dir,      // 1=N, 0=S

    // Flattened longitude output (max 11 digits)
    output reg [7:0] lon0,
    output reg [7:0] lon1,
    output reg [7:0] lon2,
    output reg [7:0] lon3,
    output reg [7:0] lon4,
    output reg [7:0] lon5,
    output reg [7:0] lon6,
    output reg [7:0] lon7,
    output reg [7:0] lon8,
    output reg [7:0] lon9,
    output reg [7:0] lon10,
    output reg [3:0] lon_len,
    output reg       lon_dir,      // 1=E, 0=W

    output reg       new_fix
);

    // FSM
    localparam WAIT_DOLLAR = 0;
    localparam MATCH_G     = 1;
    localparam MATCH_P     = 2;
    localparam MATCH_R     = 3;
    localparam MATCH_M     = 4;
    localparam MATCH_C     = 5;
    localparam READ_FIELDS = 6;

    reg [3:0] state = WAIT_DOLLAR;
    reg [3:0] comma_count = 0;
    
      reg [3:0] lat_idx = 0;
    reg [3:0] lon_idx = 0;

    always @(posedge clk) begin
        if (rst) begin
            state       <= WAIT_DOLLAR;
            comma_count <= 0;
            lat_idx     <= 0;
            lon_idx     <= 0;
            new_fix     <= 0;
        end else if (rx_valid) begin
            new_fix <= 0;

            case (state)

            WAIT_DOLLAR:
                if (rx_data == "$")
                    state <= MATCH_G;

            MATCH_G:
                state <= (rx_data == "G") ? MATCH_P : WAIT_DOLLAR;

            MATCH_P:
                state <= (rx_data == "P") ? MATCH_R : WAIT_DOLLAR;

            MATCH_R:
                state <= (rx_data == "R") ? MATCH_M : WAIT_DOLLAR;

            MATCH_M:
                state <= (rx_data == "M") ? MATCH_C : WAIT_DOLLAR;

            MATCH_C:
                if (rx_data == "C") begin
                    state        <= READ_FIELDS;
                    comma_count  <= 0;
                    lat_idx      <= 0;
                    lon_idx      <= 0;
                end else begin
                    state        <= WAIT_DOLLAR;
                end

            READ_FIELDS: begin
                if (rx_data == ",")
                    comma_count <= comma_count + 1;

                else begin
                    // FIELD 3 - Latitude digits
                    if (comma_count == 2) begin
                        case (lat_idx)
                            0: lat0  <= rx_data;
                            1: lat1  <= rx_data;
                            2: lat2  <= rx_data;
                            3: lat3  <= rx_data;
                            4: lat4  <= rx_data;
                            5: lat5  <= rx_data;
                            6: lat6  <= rx_data;
                            7: lat7  <= rx_data;
                            8: lat8  <= rx_data;
                            9: lat9  <= rx_data;
                        endcase
                        lat_idx <= lat_idx + 1;
                    end

                    // FIELD 4 - N/S
                    if (comma_count == 3) begin
                        lat_dir <= (rx_data == "N") ? 1 : 0;
                    end

                    // FIELD 5 - Longitude digits
                    if (comma_count == 4) begin
                        case (lon_idx)
                            0: lon0  <= rx_data;
                            1: lon1  <= rx_data;
                            2: lon2  <= rx_data;
                            3: lon3  <= rx_data;
                            4: lon4  <= rx_data;
                            5: lon5  <= rx_data;
                            6: lon6  <= rx_data;
                            7: lon7  <= rx_data;
                            8: lon8  <= rx_data;
                            9: lon9  <= rx_data;
                            10: lon10 <= rx_data;
                        endcase
                        lon_idx <= lon_idx + 1;
                    end

                    // FIELD 6 - E/W ? done
                    if (comma_count == 5) begin
                        lon_dir <= (rx_data == "E") ? 1 : 0;

                        lat_len <= lat_idx;
                        lon_len <= lon_idx;

                        new_fix <= 1;
                        state   <= WAIT_DOLLAR;
                    end
                end
            end

            endcase
        end
    end
endmodule