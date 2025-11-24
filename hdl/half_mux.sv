`timescale 1ns / 1ps
`default_nettype none

module half_mux (
    input  wire       half_sel,        // 0 = left, 1 = right
    input  wire [7:0] thresh_p1,       // threshold for left half
    input  wire [7:0] thresh_p2,       // threshold for right half
    input  wire [1:0] chan_sel_p1,     // channel select for left half
    input  wire [1:0] chan_sel_p2,     // channel select for right half
    output wire [7:0] thresh_active,   // active threshold based on half_sel
    output wire [1:0] chan_sel_active  // active channel select based on half_sel
);

    // 0 = left (P1), 1 = right (P2)
    assign thresh_active   = (half_sel == 1'b0) ? thresh_p1   : thresh_p2;
    assign chan_sel_active = (half_sel == 1'b0) ? chan_sel_p1 : chan_sel_p2;

endmodule

`default_nettype wire
