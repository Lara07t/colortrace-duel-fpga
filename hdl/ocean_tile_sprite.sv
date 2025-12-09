`timescale 1ns / 1ps
`default_nettype none

module ocean_tile_sprite #(
    parameter integer TILE_W       = 64,
    parameter integer TILE_H       = 64,
    parameter string  IMG_INIT_FILE = "ocean_image.mem",
    parameter string  PAL_INIT_FILE = "ocean_palette.mem"
)(
    input  wire        clk,
    input  wire [10:0] x,   // screen coords (we'll wrap them)
    input  wire [9:0]  y,
    output logic [7:0] R,
    output logic [7:0] G,
    output logic [7:0] B
);
    // assuming TILE_W = TILE_H = 64 (2^6)
    localparam int XW = $clog2(TILE_W);
    localparam int YW = $clog2(TILE_H);
    localparam int PIXELS = TILE_W * TILE_H;
    localparam int AW = $clog2(PIXELS);

    logic [XW-1:0] local_x;
    logic [YW-1:0] local_y;
    logic [AW-1:0] img_addr;

    // wrap coords into tile (mod 64 using low bits)
    always_comb begin
        local_x = x[XW-1:0];
        local_y = y[YW-1:0];
    end

    // row-major: addr = y*W + x
    assign img_addr = {local_y, local_x}; // works because TILE_W = 2^XW

    logic [7:0]  idx;
    logic [23:0] rgb24;

    // index ROM
    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),
        .RAM_DEPTH(PIXELS),
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
        .INIT_FILE(IMG_INIT_FILE)
    ) u_img (
        .addra   (img_addr),
        .dina    ('0),
        .clka    (clk),
        .wea     (1'b0),
        .ena     (1'b1),
        .rsta    (1'b0),
        .regcea  (1'b1),
        .douta   (idx)
    );

    // palette ROM (RRGGBB per line)
    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(24),
        .RAM_DEPTH(256),
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
        .INIT_FILE(PAL_INIT_FILE)
    ) u_pal (
        .addra   (idx),
        .dina    ('0),
        .clka    (clk),
        .wea     (1'b0),
        .ena     (1'b1),
        .rsta    (1'b0),
        .regcea  (1'b1),
        .douta   (rgb24)
    );

    always_comb begin
        R = rgb24[23:16];
        G = rgb24[15:8];
        B = rgb24[7:0];
    end

endmodule

`default_nettype wire
