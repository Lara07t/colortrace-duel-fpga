`timescale 1ns / 1ps
`default_nettype none

//-----------------------------------------------------------------------------
// File: menu_sprites.sv
// Purpose: Draw grass / snow menu images using palette + index ROMs.
//
// *** IMPORTANT FORMAT ASSUMPTION ***
//   grass_palette.mem / snow_palette.mem:
//       - 256 lines
//       - each line is 24-bit hex: RRGGBB (R in bits [23:16], G in [15:8], B in [7:0])
//
//   grass_image.mem / snow_image.mem:
//       - WIDTH * HEIGHT * 2 lines (because of "pop" toggle: frame0 + frame1)
//       - each line is 8-bit palette index: 00..FF
//
// If your Python script writes the palette in any other order (e.g. BBGGRR,
// or one byte per line, or decimal), colors will look "wrong" even though the
// shapes are correct.
//-----------------------------------------------------------------------------

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* !SYNTHESIS */
`define FPATH(X) `"../data/X`"
`endif  /* !SYNTHESIS */


//---------------------------
// Grass menu sprite
//---------------------------
module grass_menu_sprite #(
        parameter WIDTH  = 128,
                  HEIGHT = 128
    )(
        input  wire        pixel_clk,
        input  wire        rst,

        // pop = 0 → first frame
        // pop = 1 → second frame (if you ever animate; right now both frames can be identical)
        input  wire        pop,

        // sprite top-left position on screen
        input  wire [10:0] x,       // sprite origin X
        input  wire [10:0] h_count, // current pixel X
        input  wire [9:0]  y,       // sprite origin Y
        input  wire [9:0]  v_count, // current pixel Y

        // RGB output for this sprite
        output logic [7:0] pixel_red,
        output logic [7:0] pixel_green,
        output logic [7:0] pixel_blue
    );

    // ----------------------------------------------------------------
    // 1) Compute address into the image index ROM
    // ----------------------------------------------------------------
    // For a WIDTH×HEIGHT image, we store:
    //   [0            .. WIDTH*HEIGHT-1]      → frame 0
    //   [WIDTH*HEIGHT .. 2*WIDTH*HEIGHT-1]    → frame 1 (pop=1)
    //
    // Address is (local_x + local_y * WIDTH) + frame_offset
    // ----------------------------------------------------------------
    logic [$clog2(WIDTH*HEIGHT*2)-1:0] image_addr;

    assign image_addr =
          (h_count - x)                     // local x
        + ((v_count - y) * WIDTH)          // local y * width
        + (pop ? WIDTH*HEIGHT : 0);        // frame select

    // "Are we inside sprite rectangle?"
    logic in_sprite;
    assign in_sprite =
           (h_count >= x) && (h_count < (x + WIDTH)) &&
           (v_count >= y) && (v_count < (y + HEIGHT));

    // ----------------------------------------------------------------
    // 2) Image ROM: index → palette index (0..255)
    // ----------------------------------------------------------------
    logic [7:0]  img_idx;
    logic [23:0] rgb24;

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),
        .RAM_DEPTH(WIDTH*HEIGHT*2),
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
        .INIT_FILE(`FPATH(grass_image.mem))
    ) u_img_rom (
        .addra  (image_addr),
        .dina   ('0),
        .clka   (pixel_clk),
        .wea    (1'b0),
        .ena    (1'b1),
        .rsta   (rst),
        .regcea (1'b1),
        .douta  (img_idx)
    );

    // ----------------------------------------------------------------
    // 3) Palette ROM: palette index → 24-bit RGB color
    //
    // *** ASSUMED FORMAT: ***
    //   Each line is a 24-bit hex number: RRGGBB
    //   e.g. bright green = 00FF00
    // ----------------------------------------------------------------
    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(24),
        .RAM_DEPTH(256),
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
        .INIT_FILE(`FPATH(grass_palette.mem))
    ) u_pal_rom (
        .addra  (img_idx),
        .dina   ('0),
        .clka   (pixel_clk),
        .wea    (1'b0),
        .ena    (1'b1),
        .rsta   (rst),
        .regcea (1'b1),
        .douta  (rgb24)
    );

    // ----------------------------------------------------------------
    // 4) Pipeline "inside" flag to match ROM latency
    //
    // HIGH_PERFORMANCE mode usually adds ~2 cycles of latency per ROM.
    // With two back-to-back ROMs, 4 cycles is safe.
    // ----------------------------------------------------------------
    logic inside1, inside2, inside3, inside4;

    always_ff @(posedge pixel_clk) begin
        if (rst) begin
            inside1 <= 1'b0;
            inside2 <= 1'b0;
            inside3 <= 1'b0;
            inside4 <= 1'b0;
        end else begin
            inside1 <= in_sprite;
            inside2 <= inside1;
            inside3 <= inside2;
            inside4 <= inside3;
        end
    end

    // ----------------------------------------------------------------
    // 5) Final RGB output
    // ----------------------------------------------------------------
    always_comb begin
        if (inside4) begin
            // rgb24 is 0xRRGGBB as written by Python
            pixel_red   = rgb24[23:16];  // R
            pixel_green = rgb24[15:8];   // G
            pixel_blue  = rgb24[7:0];    // B
        end else begin
            // transparent / not in sprite
            pixel_red   = 8'd0;
            pixel_green = 8'd0;
            pixel_blue  = 8'd0;
        end
    end

endmodule


//---------------------------
// Snow menu sprite
//---------------------------
module snow_menu_sprite #(
        parameter WIDTH  = 128,
                  HEIGHT = 128
    )(
        input  wire        pixel_clk,
        input  wire        rst,
        input  wire        pop,
        input  wire [10:0] x, h_count,
        input  wire [9:0]  y, v_count,
        output logic [7:0] pixel_red,
        output logic [7:0] pixel_green,
        output logic [7:0] pixel_blue
    );

    logic [$clog2(WIDTH*HEIGHT*2)-1:0] image_addr;

    assign image_addr =
          (h_count - x)
        + ((v_count - y) * WIDTH)
        + (pop ? WIDTH*HEIGHT : 0);

    logic in_sprite;
    assign in_sprite =
           (h_count >= x) && (h_count < (x + WIDTH)) &&
           (v_count >= y) && (v_count < (y + HEIGHT));

    logic [7:0]  img_idx;
    logic [23:0] rgb24;

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8),
        .RAM_DEPTH(WIDTH*HEIGHT*2),
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
        .INIT_FILE(`FPATH(snow_image.mem))
    ) u_img_rom (
        .addra  (image_addr),
        .dina   ('0),
        .clka   (pixel_clk),
        .wea    (1'b0),
        .ena    (1'b1),
        .rsta   (rst),
        .regcea (1'b1),
        .douta  (img_idx)
    );

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(24),
        .RAM_DEPTH(256),
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
        .INIT_FILE(`FPATH(snow_palette.mem))
    ) u_pal_rom (
        .addra  (img_idx),
        .dina   ('0),
        .clka   (pixel_clk),
        .wea    (1'b0),
        .ena    (1'b1),
        .rsta   (rst),
        .regcea (1'b1),
        .douta  (rgb24)
    );

    logic inside1, inside2, inside3, inside4;

    always_ff @(posedge pixel_clk) begin
        if (rst) begin
            inside1 <= 1'b0;
            inside2 <= 1'b0;
            inside3 <= 1'b0;
            inside4 <= 1'b0;
        end else begin
            inside1 <= in_sprite;
            inside2 <= inside1;
            inside3 <= inside2;
            inside4 <= inside3;
        end
    end

    always_comb begin
        if (inside4) begin
            // Same RRGGBB assumption
            pixel_red   = rgb24[23:16];
            pixel_green = rgb24[15:8];
            pixel_blue  = rgb24[7:0];
        end else begin
            pixel_red   = 8'd0;
            pixel_green = 8'd0;
            pixel_blue  = 8'd0;
        end
    end

endmodule

`default_nettype wire
