`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/19/2025 03:00:09 PM
// Design Name: 
// Module Name: gprmc_detector
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

module gprmc_fix_detector (
    input clk,
    input rst,

    input [7:0] rx_data,
    input       rx_valid,

    output reg  fix_valid,   // 1 = A (valid fix)
    output reg  fix_invalid  // 1 = V (invalid fix)
);

    // States for detecting "$GPRMC,"
    localparam WAIT_DOLLAR = 0;
    localparam MATCH_G     = 1;
    localparam MATCH_P     = 2;
    localparam MATCH_R     = 3;
    localparam MATCH_M     = 4;
    localparam MATCH_C     = 5;
    localparam SKIP_TIME   = 6;
    localparam FIND_STATUS = 7;

    reg [2:0] state = WAIT_DOLLAR;
    reg [2:0] comma_count = 0;

    always @(posedge clk) begin
        if (rst) begin
            state        <= WAIT_DOLLAR;
            comma_count  <= 0;
            fix_valid    <= 0;
            fix_invalid  <= 0;
        end else if (rx_valid) begin

            case (state)

                WAIT_DOLLAR:
                    if (rx_data == "$") state <= MATCH_G;

                MATCH_G:
                    state <= (rx_data == "G") ? MATCH_P : WAIT_DOLLAR;

                MATCH_P:
                    state <= (rx_data == "P") ? MATCH_R : WAIT_DOLLAR;

                MATCH_R:
                    state <= (rx_data == "R") ? MATCH_M : WAIT_DOLLAR;

                MATCH_M:
                    state <= (rx_data == "M") ? MATCH_C : WAIT_DOLLAR;

                MATCH_C: begin
                    if (rx_data == "C") begin
                        state <= SKIP_TIME;
                        comma_count <= 0;
                    end else begin
                        state <= WAIT_DOLLAR;
                    end
                end
                    
                    

                // Skip timestamp: "035952.00"
                SKIP_TIME: begin
                    if (rx_data == ",") begin
                        comma_count <= comma_count + 1;
                        if (comma_count == 1)
                            state <= FIND_STATUS; // next field is A/V
                    end
                end

                // Read A or V
                FIND_STATUS: begin
                    if (rx_data == "A") begin
                        fix_valid   <= 1;
                        fix_invalid <= 0;
                    end else if (rx_data == "V") begin
                        fix_valid   <= 0;
                        fix_invalid <= 1;
                    end
                    state <= WAIT_DOLLAR; // done
                end
            endcase
        end
    end
endmodule

