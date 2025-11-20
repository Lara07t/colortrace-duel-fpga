`timescale 1ns / 1ps
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"../data/X`"
`endif  /* ! SYNTHESIS */

module image_sprite_2 #(
        parameter WIDTH=256, HEIGHT=256)
    (
        input wire pixel_clk,
        input wire rst,
        input wire pop,
        input wire [10:0] x, h_count,
        input wire [9:0]  y, v_count,
        output logic [7:0] pixel_red,
        output logic [7:0] pixel_green,
        output logic [7:0] pixel_blue
    );

    // calculate ROM address
    logic [$clog2(WIDTH*HEIGHT*2)-1:0] image_addr;
    assign image_addr = (h_count - x) + ((v_count - y) * WIDTH) + (pop ? WIDTH*HEIGHT : 0);

    //in frame sort of?
    logic in_sprite;
    assign in_sprite = ((h_count >= x && h_count < (x + WIDTH)) &&
                        (v_count >= y && v_count < (y + HEIGHT)));


    logic [7:0] img_idx;  // palette index (0..255)
    logic [23:0] rgb24;


    // Modify the module below to use your BRAMs!
    // this will not do anything without you doing that!
    // assign pixel_red =    in_sprite ? 8'hF0 : 0;
    // assign pixel_green =  in_sprite ? 8'hF0 : 0;
    // assign pixel_blue =   in_sprite ? 8'hF0 : 0;

    // 2 cycle delay to read and output
    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(8), //8bits
        .RAM_DEPTH(WIDTH*HEIGHT*2),
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
        .INIT_FILE(`FPATH(image2.mem))
    ) u_img_rom (
        .addra  (image_addr),
        .dina   ('0),
        .clka   (pixel_clk),
        .wea    (1'b0), //no writing
        .ena    (1'b1), //enable
        .rsta   (rst),
        .regcea (1'b1),
        .douta  (img_idx)
    );

    //also 2 cycle delay to read and output
    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(24), //24 rgb color
        .RAM_DEPTH(256), //palette 256 entries
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
        .INIT_FILE(`FPATH(palette2.mem))
    ) u_pal_rom (
        .addra  (img_idx), //color corresponding to palette idx
        .dina   ('0),
        .clka   (pixel_clk),
        .wea    (1'b0),
        .ena    (1'b1),
        .rsta   (rst),
        .regcea (1'b1),            
        .douta  (rgb24)
    );

    logic inside1;
    logic inside2;
    logic inside3;
    logic inside4;
    
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
            pixel_red   = rgb24[23:16];
            pixel_green = rgb24[15:8];
            pixel_blue  = rgb24[7:0];
        end else begin
            pixel_red = 0;
            pixel_green = 0;
            pixel_blue = 0;
        end
    end
endmodule


`default_nettype none




