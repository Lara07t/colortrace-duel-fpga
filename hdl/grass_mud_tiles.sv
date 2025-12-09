// `timescale 1ns / 1ps
// `default_nettype none

// // Same path macro style as your other sprite file
// `ifdef SYNTHESIS
// `define FPATH(X) `"X`"
// `else
// `define FPATH(X) `"../data/X`"
// `endif

// // ----------------------------------------------------------
// // 64x64 grass background tile, repeated across the screen
// // Uses: four_grass_image.mem / four_grass_palette.mem
// // ----------------------------------------------------------
// module grass_tile_bg (
//     input  wire        pixel_clk,
//     input  wire        rst,
//     input  wire [10:0] h_count,
//     input  wire [9:0]  v_count,
//     output logic [7:0] pixel_red,
//     output logic [7:0] pixel_green,
//     output logic [7:0] pixel_blue
// );

//     // 64x64 → 4096 pixels → 12-bit address
//     // local tile coordinates (mod 64) = low 6 bits
//     wire [5:0] tx = h_count[5:0];
//     wire [5:0] ty = v_count[5:0];

//     wire [11:0] image_addr = {ty, 6'b0} + tx; // ty*64 + tx

//     logic [7:0]  img_idx;
//     logic [23:0] rgb24;

//     // INDEX ROM
//     xilinx_single_port_ram_read_first #(
//         .RAM_WIDTH(8),
//         .RAM_DEPTH(4096),
//         .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
//         .INIT_FILE(`FPATH(four_grass_image.mem))
//     ) u_img_rom (
//         .addra  (image_addr),
//         .dina   ('0),
//         .clka   (pixel_clk),
//         .wea    (1'b0),
//         .ena    (1'b1),
//         .rsta   (rst),
//         .regcea (1'b1),
//         .douta  (img_idx)
//     );

//     // PALETTE ROM
//     xilinx_single_port_ram_read_first #(
//         .RAM_WIDTH(24),
//         .RAM_DEPTH(256),
//         .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
//         .INIT_FILE(`FPATH(four_grass_palette.mem))
//     ) u_pal_rom (
//         .addra  (img_idx),
//         .dina   ('0),
//         .clka   (pixel_clk),
//         .wea    (1'b0),
//         .ena    (1'b1),
//         .rsta   (rst),
//         .regcea (1'b1),
//         .douta  (rgb24)
//     );

//     // Pipeline flag to match ROM latency (always "inside")
//     logic inside1, inside2, inside3, inside4;

//     always_ff @(posedge pixel_clk) begin
//         if (rst) begin
//             inside1 <= 1'b0;
//             inside2 <= 1'b0;
//             inside3 <= 1'b0;
//             inside4 <= 1'b0;
//         end else begin
//             inside1 <= 1'b1;      // always in tile
//             inside2 <= inside1;
//             inside3 <= inside2;
//             inside4 <= inside3;
//         end
//     end

//     // NOTE: palette format = 0xBBGGRR (same as your menu sprites)
//     always_comb begin
//         if (inside4) begin
//             pixel_red   = rgb24[7:0];      // R
//             pixel_green = rgb24[15:8];     // G
//             pixel_blue  = rgb24[23:16];    // B
//         end else begin
//             pixel_red   = 8'd0;
//             pixel_green = 8'd0;
//             pixel_blue  = 8'd0;
//         end
//     end
// endmodule


// // ----------------------------------------------------------
// // 64x64 mud path tile, repeated across the screen
// // Uses: mud_image.mem / mud_palette.mem
// // ----------------------------------------------------------
// module mud_tile_bg (
//     input  wire        pixel_clk,
//     input  wire        rst,
//     input  wire [10:0] h_count,
//     input  wire [9:0]  v_count,
//     output logic [7:0] pixel_red,
//     output logic [7:0] pixel_green,
//     output logic [7:0] pixel_blue
// );

//     wire [5:0] tx = h_count[5:0];
//     wire [5:0] ty = v_count[5:0];

//     wire [11:0] image_addr = {ty, 6'b0} + tx; // ty*64 + tx

//     logic [7:0]  img_idx;
//     logic [23:0] rgb24;

//     xilinx_single_port_ram_read_first #(
//         .RAM_WIDTH(8),
//         .RAM_DEPTH(4096),
//         .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
//         .INIT_FILE(`FPATH(mud_image.mem))
//     ) u_img_rom (
//         .addra  (image_addr),
//         .dina   ('0),
//         .clka   (pixel_clk),
//         .wea    (1'b0),
//         .ena    (1'b1),
//         .rsta   (rst),
//         .regcea (1'b1),
//         .douta  (img_idx)
//     );

//     xilinx_single_port_ram_read_first #(
//         .RAM_WIDTH(24),
//         .RAM_DEPTH(256),
//         .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
//         .INIT_FILE(`FPATH(mud_palette.mem))
//     ) u_pal_rom (
//         .addra  (img_idx),
//         .dina   ('0),
//         .clka   (pixel_clk),
//         .wea    (1'b0),
//         .ena    (1'b1),
//         .rsta   (rst),
//         .regcea (1'b1),
//         .douta  (rgb24)
//     );

//     logic inside1, inside2, inside3, inside4;

//     always_ff @(posedge pixel_clk) begin
//         if (rst) begin
//             inside1 <= 1'b0;
//             inside2 <= 1'b0;
//             inside3 <= 1'b0;
//             inside4 <= 1'b0;
//         end else begin
//             inside1 <= 1'b1;
//             inside2 <= inside1;
//             inside3 <= inside2;
//             inside4 <= inside3;
//         end
//     end

//     always_comb begin
//         if (inside4) begin
//             pixel_red   = rgb24[7:0];      // R
//             pixel_green = rgb24[15:8];     // G
//             pixel_blue  = rgb24[23:16];    // B
//         end else begin
//             pixel_red   = 8'd0;
//             pixel_green = 8'd0;
//             pixel_blue  = 8'd0;
//         end
//     end
// endmodule

// `default_nettype wire
