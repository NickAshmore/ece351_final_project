`timescale 1ns / 1ps

// spi_master_byte.v
// Simple SPI mode 0 byte-wide master, NO chip-select control.
// - CPOL = 0 (SCLK idle low)
// - CPHA = 0 (sample MISO on rising edge, change MOSI on falling edge)

module spi_master_byte #(
    parameter CLKS_PER_HALF_BIT = 50  // 100MHz / (2*50) = 1 MHz SCLK
)(
    input  wire       clk,
    input  wire       reset,

    input  wire       start,        // pulse high to start transfer
    input  wire [7:0] tx_byte,
    output reg        busy,
    output reg        done,         // 1 clk pulse when transfer completes
    output reg [7:0]  rx_byte,

    // SPI pins (no CS here)
    output reg        sclk,
    output reg        mosi,
    input  wire       miso
);

    localparam STATE_IDLE    = 2'd0;
    localparam STATE_TRANSFER= 2'd1;
    localparam STATE_DONE    = 2'd2;

    reg [1:0] state;

    reg [7:0] tx_shift;
    reg [7:0] rx_shift;
    reg [2:0] bit_index;     // 7..0
    reg [7:0] clk_count;     // enough bits for divider

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state     <= STATE_IDLE;
            sclk      <= 1'b0;
            mosi      <= 1'b0;
            busy      <= 1'b0;
            done      <= 1'b0;
            rx_byte   <= 8'h00;
            tx_shift  <= 8'h00;
            rx_shift  <= 8'h00;
            bit_index <= 3'd0;
            clk_count <= 8'd0;
        end else begin
            done <= 1'b0;  // default

            case (state)
            STATE_IDLE: begin
                sclk <= 1'b0;      // idle low
                busy <= 1'b0;
                if (start) begin
                    busy      <= 1'b1;
                    tx_shift  <= tx_byte;
                    rx_shift  <= 8'h00;
                    bit_index <= 3'd7;         // MSB first
                    clk_count <= 8'd0;
                    mosi      <= tx_byte[7];   // first bit on MOSI
                    state     <= STATE_TRANSFER;
                end
            end

            STATE_TRANSFER: begin
                busy <= 1'b1;

                if (clk_count == CLKS_PER_HALF_BIT - 1) begin
                    clk_count <= 8'd0;
                    sclk      <= ~sclk;  // toggle clock

                    if (sclk == 1'b0) begin
                        // we are about to go 0 -> 1 (rising edge)
                        // sample MISO
                        rx_shift <= {rx_shift[6:0], miso};
                    end else begin
                        // we are about to go 1 -> 0 (falling edge)
                        if (bit_index == 0) begin
                            // last bit just shifted, next state will finish
                            state <= STATE_DONE;
                        end else begin
                            bit_index <= bit_index - 1'b1;
                            tx_shift  <= {tx_shift[6:0], 1'b0};
                            mosi      <= tx_shift[6];   // next bit
                        end
                    end
                end else begin
                    clk_count <= clk_count + 1'b1;
                end
            end

            STATE_DONE: begin
                sclk    <= 1'b0;
                busy    <= 1'b0;
                done    <= 1'b1;
                rx_byte <= rx_shift;
                state   <= STATE_IDLE;
            end

            default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule

