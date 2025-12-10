`timescale 1ns / 1ps
`default_nettype none

// Takes (x,y) and returns RGB from a palettized tile image.

module mud_tile_sprite #(
    parameter integer TILE_W         = 64,
    parameter integer TILE_H         = 64,
    parameter string  IMG_INIT_FILE  = "mud_image.mem",
    parameter string  PAL_INIT_FILE  = "mud_palette.mem"
)(
    input  wire        clk,
    input  wire [10:0] x,    
    input  wire [9:0]  y,    
    output logic [7:0] R,
    output logic [7:0] G,
    output logic [7:0] B
);
    // Tile coordinates: wrap every TILE_W/TILE_H
    localparam int TX_BITS = $clog2(TILE_W);
    localparam int TY_BITS = $clog2(TILE_H);

    wire [TX_BITS-1:0] tile_x = x[TX_BITS-1:0];   // x % TILE_W
    wire [TY_BITS-1:0] tile_y = y[TY_BITS-1:0];   // y % TILE_H

    // Address in tile: tile_y * TILE_W + tile_x
    localparam int TILE_SIZE = TILE_W * TILE_H;
    logic [$clog2(TILE_SIZE)-1:0] tile_addr;

    always_comb begin
        tile_addr = tile_y * TILE_W + tile_x;
    end

    // 8-bit palette index from mud_image.mem
    logic [7:0] idx;

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH      (8),
        .RAM_DEPTH      (TILE_SIZE),
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
        .INIT_FILE      (IMG_INIT_FILE)
    ) mud_img_rom (
        .addra  (tile_addr),
        .dina   (8'b0),
        .clka   (clk),
        .wea    (1'b0),
        .ena    (1'b1),
        .rsta   (1'b0),
        .regcea (1'b1),
        .douta  (idx)
    );

    // 16-bit RGB565 from palette
    logic [15:0] c565;

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH      (16),
        .RAM_DEPTH      (256),
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
        .INIT_FILE      (PAL_INIT_FILE)
    ) mud_pal_rom (
        .addra  (idx),
        .dina   (16'b0),
        .clka   (clk),
        .wea    (1'b0),
        .ena    (1'b1),
        .rsta   (1'b0),
        .regcea (1'b1),
        .douta  (c565)
    );

    // Split RGB565 → R5:G6:B5
    wire [4:0] R5 = c565[15:11];
    wire [5:0] G6 = c565[10:5];
    wire [4:0] B5 = c565[4:0];

    // Expand to 8-bit 
    always_comb begin
        R = {R5, R5[4:2]};  
        G = {G6, G6[5:4]};  
        B = {B5, B5[4:2]};  
    end

endmodule

`default_nettype wire
