module video_sig_gen
#(
  parameter ACTIVE_H_PIXELS = 1280,
  parameter H_FRONT_PORCH = 110,
  parameter H_SYNC_WIDTH = 40,
  parameter H_BACK_PORCH = 220,
  parameter ACTIVE_LINES = 720,
  parameter V_FRONT_PORCH = 5,
  parameter V_SYNC_WIDTH = 5,
  parameter V_BACK_PORCH = 20,
  parameter FPS = 60
)
(
  input wire pixel_clk,
  input wire rst,
  output logic [$clog2(TOTAL_PIXELS)-1:0] h_count,
  output logic [$clog2(TOTAL_LINES)-1:0] v_count,
  output logic v_sync, //vertical sync out
  output logic h_sync, //horizontal sync out
  output logic active_draw,
  output logic new_frame, //single cycle enable signal
  output logic [5:0] frame_count); //frame
  localparam TOTAL_PIXELS = ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH + H_BACK_PORCH;  // 1650
  localparam TOTAL_LINES = ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH + V_BACK_PORCH;  // 750
  //your code here

  logic [$clog2(ACTIVE_H_PIXELS + H_FRONT_PORCH)-1:0]  h_sync_start;
  logic [$clog2(ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH)-1:0]  h_sync_end;

  logic [$clog2(ACTIVE_LINES + V_FRONT_PORCH)-1:0]  v_sync_start;
  logic [$clog2(ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH)-1:0]  v_sync_end;

  always_comb begin
    active_draw = (h_count < ACTIVE_H_PIXELS) && (v_count < ACTIVE_LINES);
  end

    //h sync
  always_comb begin
    h_sync_start = ACTIVE_H_PIXELS + H_FRONT_PORCH;
    h_sync_end = h_sync_start + H_SYNC_WIDTH; // exclusive
    h_sync = (h_count >= h_sync_start) && (h_count < h_sync_end);
  end

    //v sync 
  always_comb begin
    v_sync_start = ACTIVE_LINES + V_FRONT_PORCH;
    v_sync_end   = v_sync_start + V_SYNC_WIDTH; // exclusive
    v_sync = (v_count >= v_sync_start) && (v_count < v_sync_end);
  end


  // Horizontal and vertical
  // counters + frames
  always_ff @(posedge pixel_clk) begin
    if (rst) begin
      h_count <= '0;
      v_count <= '0;
      new_frame <= 1'b0;
      frame_count <= 6'd0;
    end else begin
        // pix counter
      if (h_count == TOTAL_PIXELS-1) begin 
        // if end or h line
        h_count <= '0;
        if (v_count == TOTAL_LINES-1) 
          // end of v count = end of frame
          v_count <= '0;
        else
        // go to next line
          v_count <= v_count + 1'b1;
      end else begin
    
        h_count <= h_count + 1'b1;
      end

      // new_frame asserted exactly when:
      // v_count was at the last active line
      new_frame <= (h_count == (ACTIVE_H_PIXELS-1)) && (v_count == (ACTIVE_LINES-1));

    // frame count
      if (new_frame) begin
        if (frame_count == FPS-1)
          frame_count <= 6'd0;
        else
          frame_count <= frame_count + 6'd1;
      end
    end
  end


endmodule

