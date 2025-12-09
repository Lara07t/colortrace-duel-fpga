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
    input wire game_initiated,
    input  wire [$clog2(GRID_W)-1:0]  cell_x,
    input  wire [$clog2(GRID_H)-1:0]  cell_y,
    input  wire shift_left_req,
    input  wire shift_right_req,
    output logic cell_on,
    output logic [GRID_W*GRID_H-1:0] path_grid_out
);

    logic [GRID_W-1:0] grid [0:GRID_H-1];
    logic [$clog2(GRID_W)-1:0] head_x;

    localparam int TRACK_HALF_WIDTH = 9;
    logic [$clog2(TRACK_HALF_WIDTH+1)-1:0] cur_half_width;

    int head_v;
    localparam int MAX_VEL = 3
    ;

    logic [15:0] lfsr;

    localparam int STEPS_BEFORE_SHRINK = 60;
    localparam int STEPS_PER_SHRINK    = 50;

    logic [$clog2(STEPS_BEFORE_SHRINK+1)-1:0] step_count_before_shrink;
    logic [$clog2(STEPS_PER_SHRINK+1)-1:0]    shrink_step_cnt;
    logic                                      shrink_mode;

    logic [$clog2(GRID_W)-1:0] cell_x_r;
    logic [$clog2(GRID_H)-1:0] cell_y_r;

    integer y;
    integer r;

    localparam int MIN_CENTER = TRACK_HALF_WIDTH;
    localparam int MAX_CENTER = GRID_W - 1 - TRACK_HALF_WIDTH;

    //new-slow
    localparam int SCROLL_RATE = 4;   // scroll every 4 frames (1 = every frame)
    logic [$clog2(SCROLL_RATE):0] scroll_cnt;

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

            head_v <= 0;
            scroll_cnt <= '0; //new-slow

            if (MIN_CENTER <= (GRID_W/2) && (GRID_W/2) <= MAX_CENTER)
                head_x <= (GRID_W/2);
            else
                head_x <= MIN_CENTER[$clog2(GRID_W)-1:0];

            for (y = 0; y < GRID_H; y = y + 1) begin
                grid[y] <= build_track_row(head_x, cur_half_width);
            end

        end else if (new_frame) begin 
            if (game_initiated) begin // path condition , game_initiated
            // advance a frame counter while game is running
                if (scroll_cnt == SCROLL_RATE-1) begin //new-slow
                    scroll_cnt <= '0;
            //lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5]};
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13]};

            if (!shrink_mode) begin
                if (step_count_before_shrink == STEPS_BEFORE_SHRINK-1) begin 
                    shrink_mode <= 1'b1;
                end else begin
                    step_count_before_shrink <= step_count_before_shrink + 1'b1;
                end
            end else begin
                if (cur_half_width > 3) begin
                    if (shrink_step_cnt == STEPS_PER_SHRINK-1) begin
                        shrink_step_cnt <= '0;
                        cur_half_width  <= cur_half_width - 1'b1;
                    end else begin
                        shrink_step_cnt <= shrink_step_cnt + 1'b1;
                    end
                end
            end

            // begin
            //     int dv;
            //     int new_v;
            //     int new_x;

            //     // case (lfsr[1:0])
            //     //     2'b00: dv = -1;
            //     //     2'b11: dv =  1;
            //     //     default: dv = 0;
            //     // endcase
            //     case (lfsr[2:0])
            //         3'b000, 3'b001: dv = -1;
            //         3'b010, 3'b011: dv =  1;
            //         3'b100:         dv = -2;
            //         3'b101:         dv =  2;
            //         default:        dv =  0;
            //     endcase


            //     new_v = head_v + dv;
            //     if (new_v >  MAX_VEL) new_v =  MAX_VEL;
            //     if (new_v < -MAX_VEL) new_v = -MAX_VEL;

            //     if ((head_x <= MIN_CENTER+1) && (new_v < 0)) new_v = 0;
            //     if ((head_x >= MAX_CENTER-1) && (new_v > 0)) new_v = 0;

            //     new_x = head_x + new_v;

            //     if (new_x < MIN_CENTER)
            //         head_x <= MIN_CENTER[$clog2(GRID_W)-1:0];
            //     else if (new_x > MAX_CENTER)
            //         head_x <= MAX_CENTER[$clog2(GRID_W)-1:0];
            //     else
            //         head_x <= new_x[$clog2(GRID_W)-1:0];

            //     head_v <= new_v;
            // end

            begin
    int dv;
    int new_v;
    int new_x;
    int center_mid;

    case (lfsr[4:0])
    5'h00, 5'h01, 5'h02, 5'h03, 5'h0E,:  dv = -2;
    5'h04, 5'h05, 5'h06, 5'h07, 5'h08, 5'h09: dv = -1;
    5'h0A, 5'h0B, 5'h0C, 5'h0D, 5'h0F, 5'h10, 5'h11,: dv = 0;
    5'h13, 5'h14, 5'h15, 5'h16, 5'h17:  dv = 1;
    5'h18, 5'h19, 5'h1A, 5'h1B, 5'h12: dv = 2;
    default:  dv = 2;
endcase




    // 2) bias back toward middle of allowed band
    center_mid = (MIN_CENTER + MAX_CENTER) / 2;

    // // if we're noticeably left of center, push more to the right
    // if (head_x < center_mid - 4 && dv < 0)
    //     dv = -dv;    // flip left turns into right turns

    // // if we're noticeably right of center, push more to the left
    // if (head_x > center_mid + 4 && dv > 0)
    //     dv = -dv;    // flip right turns into left turns

    // 3) start from current velocity, but damp it toward 0
    new_v = head_v;
    if (new_v > 0)      new_v = new_v - 1;
    else if (new_v < 0) new_v = new_v + 1;

    // then apply steering
    new_v = new_v + dv;

    // 4) clamp velocity
    if (new_v >  MAX_VEL) new_v =  MAX_VEL;
    if (new_v < -MAX_VEL) new_v = -MAX_VEL;

    // still prevent pushing into walls
    if ((head_x <= MIN_CENTER+1) && (new_v < 0)) new_v = -new_v >>> 1;;
    if ((head_x >= MAX_CENTER-1) && (new_v > 0)) new_v = -new_v >>> 1;;

    // 5) update position
    new_x = head_x + new_v;

    if (new_x < MIN_CENTER)
        new_x = MIN_CENTER;
    else if (new_x > MAX_CENTER)
        new_x = MAX_CENTER;

    head_x <= new_x[$clog2(GRID_W)-1:0];
    head_v <= new_v;
end



            for (y = GRID_H-1; y > 0; y = y - 1) begin
                grid[y] <= grid[y-1];
            end
            grid[0] <= build_track_row(head_x, cur_half_width);
            end else begin
                    // not time to update yet
                    scroll_cnt <= scroll_cnt + 1'b1;
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
            cell_on  <= grid[cell_y_r][cell_x_r];
        end
    end

    always_comb begin
        for (r = 0; r < GRID_H; r = r + 1) begin
            path_grid_out[r*GRID_W +: GRID_W] = grid[r];
        end
    end

endmodule

`default_nettype wire

