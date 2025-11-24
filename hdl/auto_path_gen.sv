`timescale 1ns / 1ps
`default_nettype none

module autopath_gen #(
    parameter int GRID_W   = 10,
    parameter int GRID_H   = 10,
    parameter int FPS      = 60,
    parameter string INIT_FILE = "data/autopath_init.mem"
)(
    input  wire clk,
    input  wire rst,
    input  wire new_frame,
    input  wire [$clog2(GRID_W)-1:0]  cell_x,
    input  wire [$clog2(GRID_H)-1:0]  cell_y,
    input  wire shift_left_req,
    input  wire shift_right_req,
    output logic cell_on
);

    logic [GRID_W-1:0] grid [0:GRID_H-1];
    logic [$clog2(GRID_W)-1:0] head_x;

    localparam int TRACK_HALF_WIDTH = 3;
    logic [$clog2(TRACK_HALF_WIDTH+1)-1:0] cur_half_width;

    logic [7:0] lfsr;

    localparam int STEP_BITS = 23;
    logic [STEP_BITS-1:0] step_cnt;

    localparam int STEPS_BEFORE_SHRINK = 60;
    localparam int STEPS_PER_SHRINK    = 50;

    logic [$clog2(STEPS_BEFORE_SHRINK+1)-1:0] step_count_before_shrink;
    logic [$clog2(STEPS_PER_SHRINK+1)-1:0]    shrink_step_cnt;
    logic                                      shrink_mode;

    logic [$clog2(GRID_W)-1:0] cell_x_r;
    logic [$clog2(GRID_H)-1:0] cell_y_r;

    integer y;

    localparam int MIN_CENTER = TRACK_HALF_WIDTH;
    localparam int MAX_CENTER = GRID_W - 1 - TRACK_HALF_WIDTH;

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
            step_cnt <= '0;

            step_count_before_shrink <= '0;
            shrink_step_cnt          <= '0;
            shrink_mode              <= 1'b0;
            cur_half_width           <= TRACK_HALF_WIDTH;

            if (MIN_CENTER <= (GRID_W/2) && (GRID_W/2) <= MAX_CENTER)
                head_x <= (GRID_W/2);
            else
                head_x <= MIN_CENTER[$clog2(GRID_W)-1:0];

            for (y = 0; y < GRID_H; y = y + 1) begin
                grid[y] <= build_track_row(head_x, cur_half_width);
            end

        end else begin
            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5]};

            if (step_cnt == {STEP_BITS{1'b1}}) begin
                step_cnt <= '0;

                if (!shrink_mode) begin
                    if (step_count_before_shrink == STEPS_BEFORE_SHRINK-1) begin
                        shrink_mode <= 1'b1;
                    end else begin
                        step_count_before_shrink <= step_count_before_shrink + 1'b1;
                    end
                end else begin
                    if (cur_half_width > 1) begin
                        if (shrink_step_cnt == STEPS_PER_SHRINK-1) begin
                            shrink_step_cnt <= '0;
                            cur_half_width  <= cur_half_width - 1'b1;
                        end else begin
                            shrink_step_cnt <= shrink_step_cnt + 1'b1;
                        end
                    end
                end

                if (lfsr[3:0] <= 4'd8) begin
                    if (head_x > MIN_CENTER[$clog2(GRID_W)-1:0])
                        head_x <= head_x - 1'b1;
                    else if (head_x < MAX_CENTER[$clog2(GRID_W)-1:0])
                        head_x <= head_x + 1'b1;
                    else
                        head_x <= head_x;
                end else begin
                    if (head_x < MAX_CENTER[$clog2(GRID_W)-1:0])
                        head_x <= head_x + 1'b1;
                    else if (head_x > MIN_CENTER[$clog2(GRID_W)-1:0])
                        head_x <= head_x - 1'b1;
                    else
                        head_x <= head_x;
                end

                for (y = GRID_H-1; y > 0; y = y - 1) begin
                    grid[y] <= grid[y-1];
                end

                grid[0] <= build_track_row(head_x, cur_half_width);

            end else begin
                step_cnt <= step_cnt + 1'b1;
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

endmodule

`default_nettype wire
