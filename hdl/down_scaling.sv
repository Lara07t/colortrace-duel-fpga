// `timescale 1ns / 1ps
// `default_nettype none


// module down_scaling #(
//     parameter CAM_WIDTH    = 1280,
//     parameter CAM_HEIGHT   = 720,
//     parameter DOWNSAMPLE   = 4,    // subsampling factor (fixed at 4 here)
//     parameter PIXEL_WIDTH  = 16    // RGB565
// )(
//     input  wire clk,
//     input  wire rst,
//     input  wire [10:0] camera_col,   // horizontal pixel index (0..1279)
//     input  wire [9:0] camera_row,   // vertical pixel index   (0..719)
//     input  wire [PIXEL_WIDTH-1:0]   camera_pixel, // RGB565 pixel data
//     input  wire camera_pixel_valid,

//     // outputs to BRAM 
//     output logic frame_wr_en,
//     output logic [$clog2((CAM_WIDTH/DOWNSAMPLE)*(CAM_HEIGHT/DOWNSAMPLE))-1:0] frame_wr_addr,
//     output logic [PIXEL_WIDTH-1:0]  frame_wr_data
// );

//     localparam FRAME_WIDTH  = CAM_WIDTH / DOWNSAMPLE;  // 320
//     localparam FRAME_HEIGHT = CAM_HEIGHT / DOWNSAMPLE; // 180

//     // sequential write logic
//     always_ff @(posedge clk) begin
//         if (rst) begin
//             frame_wr_en   <= 1'b0;
//             frame_wr_addr <= '0;
//             frame_wr_data <= '0;
//         end else begin
//             frame_wr_en <= 1'b0; // default off

//             // only keep every 4th pixel in both x and y
//             if (camera_pixel_valid &&(camera_col[1:0] == 2'b00) && // divisible by 4
//                 (camera_row[1:0] == 2'b00) &&
//                 (camera_col < CAM_WIDTH) && (camera_row < CAM_HEIGHT)) begin

//                 // compute downsampled coords
//                 logic [8:0] frame_col;
//                 logic [7:0] frame_row;
//                 frame_col = camera_col >> 2; // divide by 4
//                 frame_row = camera_row >> 2;

//                 if ((frame_col < FRAME_WIDTH) && (frame_row < FRAME_HEIGHT)) begin
//                     frame_wr_addr <= frame_col + FRAME_WIDTH * frame_row;
//                     frame_wr_data <= camera_pixel;
//                     frame_wr_en   <= 1'b1;
//                 end
//             end
//         end
//     end

// endmodule

// `default_nettype wire
