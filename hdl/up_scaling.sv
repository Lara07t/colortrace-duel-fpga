`timescale 1ns / 1ps
`default_nettype none

// up_scaling.sv
// Map 1280x720 HDMI (hdmi_col,row) to 320x180 framebuffer address.
// 1x/2x/4x nearest-neighbor via address sharing.

module up_scaling #(
  parameter int HDMI_WIDTH = 1280,
  parameter int HDMI_HEIGHT = 720,
  parameter int FB_WIDTH = 320,
  parameter int FB_HEIGHT = 180,
  parameter int ADDR_WIDTH    = $clog2(FB_WIDTH*FB_HEIGHT)
)(
  input  wire clk,
  input  wire rst,

  // from video_sig_gen
  input  wire [10:0] hdmi_col,   // 0..1279
  input  wire [9:0] hdmi_row,   // 0..719

  // scale control (btn[1], sw[0])
  input  wire scale_1x,       // btn[1]==1 -> 1x
  input  wire scale_4x_sel,   // when btn[1]==0: 0->2x, 1->4x

  // to BRAM read side
  output logic [ADDR_WIDTH-1:0] frame_rd_addr,
  output logic frame_rd_valid
);
  //by1
  localparam SCALE2_W = FB_WIDTH  << 1; // 640
  localparam SCALE2_H = FB_HEIGHT << 1; // 360
  //by2
  localparam SCALE4_W = FB_WIDTH  << 2; // 1280
  localparam SCALE4_H = FB_HEIGHT << 2; // 720

  always_ff @(posedge clk) begin
    if (rst) begin
      frame_rd_addr  <= '0;
      frame_rd_valid <= 1'b0;
    end else begin
      logic [10:0] fb_col;
      logic [9:0]  fb_row;
      logic inside_region;

      if (scale_1x) begin
        fb_col = hdmi_col;
        fb_row = hdmi_row;
        inside_region = (hdmi_col < FB_WIDTH) && (hdmi_row < FB_HEIGHT);
      end else if (!scale_4x_sel) begin // 2x
        fb_col = hdmi_col >> 1;
        fb_row = hdmi_row >> 1;
        inside_region = (hdmi_col < SCALE2_W) && (hdmi_row < SCALE2_H);
      end else begin // 4x
        fb_col = hdmi_col >> 2;
        fb_row = hdmi_row >> 2;
        inside_region = (hdmi_col < SCALE4_W) && (hdmi_row < SCALE4_H);
      end

      //logic in_bounds = (fb_col < FB_WIDTH) && (fb_row < FB_HEIGHT);

      frame_rd_valid <= inside_region;
      frame_rd_addr  <= fb_col + FB_WIDTH * fb_row; // row-major
    end
  end

endmodule

`default_nettype wire
