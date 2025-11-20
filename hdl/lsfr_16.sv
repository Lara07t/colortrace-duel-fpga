`timescale 1ns / 1ps
`default_nettype none

module lfsr_16 (
        input wire clk,
        input wire rst,
        input wire [15:0] seed,
        output logic [15:0] q
    );

    localparam logic [15:0] MASK = 16'h8005; // 1000_0000_0000_0101

    always_ff @(posedge clk) begin
        if (rst) begin
            q <= seed;
        end else begin
            q <= q[15] ? ({ q[14:0], 1'b0 } ^ MASK) : { q[14:0], 1'b0 };
        end
    end
endmodule


`default_nettype wire
