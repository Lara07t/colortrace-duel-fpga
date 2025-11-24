`timescale 1ns / 1ps
`default_nettype none

module screen_half #(
    parameter integer H_RES = 1280  // match your top_level use
)(
    // horizontal pixel coordinate (e.g. h_count_hdmi)
    input  wire [$clog2(H_RES)-1:0] x,
    // 0 = left half, 1 = right half
    output wire                     half_sel
);

    // left if x < H_RES/2, otherwise right
    assign half_sel = (x < H_RES/2) ? 1'b0 : 1'b1;

endmodule

`default_nettype wire
