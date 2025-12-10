`timescale 1ns / 1ps
`default_nettype none

module autopath_gen #(
    parameter int GRID_W   = 40,
    parameter int GRID_H   = 40,
    parameter int FPS      = 60,
    parameter string INIT_FILE = "data/autopath_init.mem"
)(
    input  wire clk,
    input  wire rst,
    input  wire new_frame,         
    input wire game_initiated, // path updates only after game starts
    input  wire [$clog2(GRID_W)-1:0]  cell_x,
    input  wire [$clog2(GRID_H)-1:0]  cell_y,
    input  wire shift_left_req,     
    input  wire shift_right_req,     
    output logic cell_on,  // 1 if current cell is on the track
    output logic [GRID_W*GRID_H-1:0] path_grid_out
);

    logic [GRID_W-1:0] grid [0:GRID_H-1];
    logic [$clog2(GRID_W)-1:0] head_x;   

    localparam int TRACK_HALF_WIDTH = 9;  // initial half-width of path
    logic [$clog2(TRACK_HALF_WIDTH+1)-1:0] cur_half_width; // shrinking width

    // Velocity range: we only need about -3..+3, be generous and give -7..+7 // TIME REQ CHANGE
    typedef logic signed [3:0] vel_t;  // -8..+7
    typedef logic        [5:0] x_t;    // 0..63 (enough for GRID_W <= 40)

    vel_t head_v;

    //int head_v;  // horizontal velocity
    localparam int MAX_VEL = 3;  // clamp speed at this point 

    logic [15:0] lfsr;    

    localparam int STEPS_BEFORE_SHRINK = 60; // wait N updates before shrink
    localparam int STEPS_PER_SHRINK    = 50; // shrink width every N updates

    logic [$clog2(STEPS_BEFORE_SHRINK+1)-1:0] step_count_before_shrink;
    logic [$clog2(STEPS_PER_SHRINK+1)-1:0] shrink_step_cnt;
    logic shrink_mode;               

    logic [$clog2(GRID_W)-1:0] cell_x_r;    
    logic [$clog2(GRID_H)-1:0] cell_y_r;

    integer y;                      
    integer r;

    localparam int MIN_CENTER = TRACK_HALF_WIDTH;      
    localparam int MAX_CENTER = GRID_W - 1 - TRACK_HALF_WIDTH;

    localparam int SCROLL_RATE = 4;   // scroll every 4 frames
    logic [$clog2(SCROLL_RATE):0] scroll_cnt;

    // builds one row of the track given its center and half width
    function automatic logic [GRID_W-1:0] build_track_row(
        input logic [$clog2(GRID_W)-1:0] center,
        input logic [$clog2(TRACK_HALF_WIDTH+1)-1:0] half_width
    );
        logic [GRID_W-1:0] row;
        int c, hw;
        int left_idx, right_idx;

        row = '0;
        c   = center;
        hw  = half_width;

        left_idx  = c - hw;         
        right_idx = c + hw;       

        if (left_idx < 1)         left_idx  = 1;     
        if (right_idx > GRID_W-2) right_idx = GRID_W-2; 

        for (int i = 0; i < GRID_W; i++) begin
            if (i >= left_idx && i <= right_idx) begin
                row[i] = 1'b1;        
            end
        end
        return row;
    endfunction

    always_ff @(posedge clk) begin
        if (rst) begin
            lfsr <= 8'hA5;    

            step_count_before_shrink <= '0;
            shrink_step_cnt          <= '0;
            shrink_mode              <= 1'b0; 
            cur_half_width           <= TRACK_HALF_WIDTH;

            head_v <= 0;               // velocity starts at 0
            scroll_cnt <= '0;          // reset scroll counter

            // initialize head_x near center if legal
            if (MIN_CENTER <= (GRID_W>>1) && (GRID_W>>1) <= MAX_CENTER)
                head_x <= (GRID_W>>1);
            else
                head_x <= MIN_CENTER[$clog2(GRID_W)-1:0];

            // initialize full grid as straight corridor
            for (y = 0; y < GRID_H; y = y + 1) begin
                grid[y] <= build_track_row(head_x, cur_half_width);
            end

        end else if (new_frame) begin 
            if (game_initiated) begin // only move path after game starts

                if (scroll_cnt == SCROLL_RATE-1) begin // time to scroll
                    scroll_cnt <= '0;

                    // LFSR update (randomness source)
                    lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13]};

                    // shrinking logic 
                    if (!shrink_mode) begin
                        if (step_count_before_shrink == STEPS_BEFORE_SHRINK-1) begin 
                            shrink_mode <= 1'b1; 
                        end else begin
                            step_count_before_shrink <= step_count_before_shrink + 1'b1;
                        end
                    end else begin
                        if (cur_half_width > 3) begin // don't shrink past min
                            if (shrink_step_cnt == STEPS_PER_SHRINK-1) begin
                                shrink_step_cnt <= '0;
                                cur_half_width  <= cur_half_width - 1'b1; 
                            end else begin
                                shrink_step_cnt <= shrink_step_cnt + 1'b1;
                            end
                        end
                    end

                    begin
                        // int dv;  // delta-velocity from LFSR
                        // int new_v;  // updated velocity
                        // int new_x;  // updated center position
                        // int center_mid;
                        // TIME REQ CHANGE
                        vel_t dv;
                        vel_t new_v;
                        x_t   new_x;
                        x_t   center_mid;



                        // map random code to steering choices 
                        case (lfsr[4:0])
                            5'h00, 5'h01, 5'h02, 5'h03, 5'h0E,:  dv = -2;
                            5'h04, 5'h05, 5'h06, 5'h07, 5'h08, 5'h09: dv = -1;
                            5'h0A, 5'h0B, 5'h0C, 5'h0D, 5'h0F, 5'h10, 5'h11,: dv = 0;
                            5'h13, 5'h14, 5'h15, 5'h16, 5'h17:  dv = 1;
                            5'h18, 5'h19, 5'h1A, 5'h1B, 5'h12: dv = 2;
                            default:  dv = 2;
                        endcase

                        center_mid = (MIN_CENTER + MAX_CENTER) >> 1;

                        // damp velocity 
                        new_v = head_v;
                        if (new_v > 0)      new_v = new_v - 1;
                        else if (new_v < 0) new_v = new_v + 1;

                        // apply steering
                        new_v = new_v + dv;

                        // clamp velocity
                        if (new_v >  MAX_VEL) new_v =  MAX_VEL;
                        if (new_v < -MAX_VEL) new_v = -MAX_VEL;

                        // soften bounce if hitting near the boundary
                        if ((head_x <= MIN_CENTER+1) && (new_v < 0)) new_v = -new_v >>> 1;
                        if ((head_x >= MAX_CENTER-1) && (new_v > 0)) new_v = -new_v >>> 1;

                        // apply to position
                        new_x = head_x + new_v;

                        // if narrow, limit x-motion per row for smoother turns
                        if (cur_half_width <= 5) begin
                            int dx;
                            dx = new_x - head_x;
                            if (dx > 1)      new_x = head_x + 1;
                            else if (dx < -1) new_x = head_x - 1;
                        end

                        // clamp final x
                        if (new_x < MIN_CENTER)
                            new_x = MIN_CENTER;
                        else if (new_x > MAX_CENTER)
                            new_x = MAX_CENTER;

                        head_x <= new_x[$clog2(GRID_W)-1:0]; // commit center
                        head_v <= new_v;                     // commit velocity
                    end

                    // scroll grid downward 
                    for (y = GRID_H-1; y > 0; y = y - 1) begin
                        grid[y] <= grid[y-1];
                    end

                    // add new top row based on updated head_x and width
                    grid[0] <= build_track_row(head_x, cur_half_width);

                end else begin
                    scroll_cnt <= scroll_cnt + 1'b1; // wait for next scroll
                end
            end 
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            cell_x_r <= '0;
            cell_y_r <= '0;
            cell_on  <= 1'b0;
        end else begin
            cell_x_r <= cell_x;
            cell_y_r <= cell_y;
            cell_on  <= grid[cell_y_r][cell_x_r]; // return bit at location
        end
    end

    // flatten 2D grid into 1D 
    always_comb begin
        for (r = 0; r < GRID_H; r = r + 1) begin
            path_grid_out[r*GRID_W +: GRID_W] = grid[r];
        end
    end

endmodule

`default_nettype wire
