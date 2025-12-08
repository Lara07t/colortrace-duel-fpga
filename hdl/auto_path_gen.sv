// `timescale 1ns / 1ps
// `default_nettype none

// module autopath_gen #(
//     parameter int GRID_W   = 40,
//     parameter int GRID_H   = 40,
//     parameter int FPS      = 60,
//     parameter string INIT_FILE = "data/autopath_init.mem"
// )(
//     input  wire clk,
//     input  wire rst,
//     input  wire new_frame,
//     input  wire [$clog2(GRID_W)-1:0]  cell_x,
//     input  wire [$clog2(GRID_H)-1:0]  cell_y,
//     input  wire shift_left_req,
//     input  wire shift_right_req,
//     output logic cell_on,

//     output logic [GRID_W*GRID_H-1:0] path_grid_out
// );

//     logic [GRID_W-1:0] grid [0:GRID_H-1];
//     logic [$clog2(GRID_W)-1:0] head_x;

//     localparam int TRACK_HALF_WIDTH = 9;
//     logic [$clog2(TRACK_HALF_WIDTH+1)-1:0] cur_half_width;

//     logic [7:0] lfsr;

//     localparam int STEP_BITS = 23;
//     logic [STEP_BITS-1:0] step_cnt;

//     localparam int STEPS_BEFORE_SHRINK = 60;
//     localparam int STEPS_PER_SHRINK    = 50;

//     logic [$clog2(STEPS_BEFORE_SHRINK+1)-1:0] step_count_before_shrink;
//     logic [$clog2(STEPS_PER_SHRINK+1)-1:0]    shrink_step_cnt;
//     logic                                      shrink_mode;

//     logic [$clog2(GRID_W)-1:0] cell_x_r;
//     logic [$clog2(GRID_H)-1:0] cell_y_r;

//     integer y;
//     integer r;  // extra loop index


//     localparam int MIN_CENTER = TRACK_HALF_WIDTH;
//     localparam int MAX_CENTER = GRID_W - 1 - TRACK_HALF_WIDTH;

//     function automatic logic [GRID_W-1:0] build_track_row(
//         input logic [$clog2(GRID_W)-1:0] center,
//         input logic [$clog2(TRACK_HALF_WIDTH+1)-1:0] half_width
//     );
//         logic [GRID_W-1:0] row;
//         int c, hw;
//         int left_idx, right_idx;
//         row = '0;
//         c   = center;
//         hw  = half_width;

//         left_idx  = c - hw;
//         right_idx = c + hw;

//         if (left_idx < 1)         left_idx  = 1;
//         if (right_idx > GRID_W-2) right_idx = GRID_W-2;

//         for (int i = 0; i < GRID_W; i++) begin
//             if (i >= left_idx && i <= right_idx) begin
//                 row[i] = 1'b1;
//             end
//         end
//         return row;
//     endfunction

//     always_ff @(posedge clk) begin
//         if (rst) begin
//             lfsr <= 8'hA5;
//             step_cnt <= '0;

//             step_count_before_shrink <= '0;
//             shrink_step_cnt          <= '0;
//             shrink_mode              <= 1'b0;
//             cur_half_width           <= TRACK_HALF_WIDTH;

//             if (MIN_CENTER <= (GRID_W/2) && (GRID_W/2) <= MAX_CENTER)
//                 head_x <= (GRID_W/2);
//             else
//                 head_x <= MIN_CENTER[$clog2(GRID_W)-1:0];

//             for (y = 0; y < GRID_H; y = y + 1) begin
//                 grid[y] <= build_track_row(head_x, cur_half_width);
//             end

//         end else begin
//             lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5]};

//             if (step_cnt == {STEP_BITS{1'b1}}) begin
//                 step_cnt <= '0;

//                 if (!shrink_mode) begin
//                     if (step_count_before_shrink == STEPS_BEFORE_SHRINK-1) begin
//                         shrink_mode <= 1'b1;
//                     end else begin
//                         step_count_before_shrink <= step_count_before_shrink + 1'b1;
//                     end
//                 end else begin
//                     if (cur_half_width > 3) begin // 3 original 1
//                         if (shrink_step_cnt == STEPS_PER_SHRINK-1) begin
//                             shrink_step_cnt <= '0;
//                             cur_half_width  <= cur_half_width - 1'b1;
//                         end else begin
//                             shrink_step_cnt <= shrink_step_cnt + 1'b1;
//                         end
//                     end
//                 end

//                 if (lfsr[3:0] <= 4'd8) begin
//                    if (head_x > MIN_CENTER[$clog2(GRID_W)-1:0])
//                        head_x <= head_x - 1'b1;
//                    else if (head_x < MAX_CENTER[$clog2(GRID_W)-1:0])
//                        head_x <= head_x + 1'b1;
//                    else
//                        head_x <= head_x;
//                 end else begin
//                    if (head_x < MAX_CENTER[$clog2(GRID_W)-1:0])
//                        head_x <= head_x + 1'b1;
//                    else if (head_x > MIN_CENTER[$clog2(GRID_W)-1:0])
//                        head_x <= head_x - 1'b1;
//                    else
//                        head_x <= head_x;
//                 end

//                 for (y = GRID_H-1; y > 0; y = y - 1) begin
//                     grid[y] <= grid[y-1];
//                 end

//                 grid[0] <= build_track_row(head_x, cur_half_width);

//             end else begin
//                 step_cnt <= step_cnt + 1'b1;
//             end
//         end
//     end

//     always_ff @(posedge clk) begin
//         if (rst) begin
//             cell_x_r <= '0;
//             cell_y_r <= '0;
//             cell_on  <= 1'b0;
//         end else begin
//             cell_x_r <= cell_x;
//             cell_y_r <= cell_y;
//             cell_on  <= grid[cell_y_r][cell_x_r];
//         end
//     end

//     // Flatten 2D grid[y][x] into row-major vector path_grid_out
//     always_comb begin
//         for (r = 0; r < GRID_H; r = r + 1) begin
//             path_grid_out[r*GRID_W +: GRID_W] = grid[r];
//         end
//     end
// endmodule



// `default_nettype wire


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
    input  wire [$clog2(GRID_W)-1:0]  cell_x,
    input  wire [$clog2(GRID_H)-1:0]  cell_y,
    input  wire shift_left_req,
    input  wire shift_right_req,
    output logic cell_on,

    output logic [GRID_W*GRID_H-1:0] path_grid_out
);

    // Grid of cells: grid[y][x]
    logic [GRID_W-1:0] grid [0:GRID_H-1];
    logic [$clog2(GRID_W)-1:0] head_x;

    // Track width control
    localparam int TRACK_HALF_WIDTH = 9;
    logic [$clog2(TRACK_HALF_WIDTH+1)-1:0] cur_half_width;

    // Smooth horizontal motion: velocity of the path center
    int head_v;
    localparam int MAX_VEL = 3;  // max speed in cells per step (tuneable)

    // LFSR for pseudo-randomness
    logic [7:0] lfsr;

    // Step timing
    localparam int STEP_BITS = 23;
    logic [STEP_BITS-1:0] step_cnt;

    // Shrink timing
    localparam int STEPS_BEFORE_SHRINK = 60;
    localparam int STEPS_PER_SHRINK    = 50;

    logic [$clog2(STEPS_BEFORE_SHRINK+1)-1:0] step_count_before_shrink;
    logic [$clog2(STEPS_PER_SHRINK+1)-1:0]    shrink_step_cnt;
    logic                                      shrink_mode;

    // Registered coordinates for cell_on lookup
    logic [$clog2(GRID_W)-1:0] cell_x_r;
    logic [$clog2(GRID_H)-1:0] cell_y_r;

    integer y;
    integer r;  // extra loop index

    // Center bounds so track stays away from outermost edges
    localparam int MIN_CENTER = TRACK_HALF_WIDTH;
    localparam int MAX_CENTER = GRID_W - 1 - TRACK_HALF_WIDTH;

    // Build one row of the track given center and half-width
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

        // Keep track away from hard borders at x=0 and x=GRID_W-1
        if (left_idx < 1)         left_idx  = 1;
        if (right_idx > GRID_W-2) right_idx = GRID_W-2;

        for (int i = 0; i < GRID_W; i++) begin
            if (i >= left_idx && i <= right_idx) begin
                row[i] = 1'b1;
            end
        end
        return row;
    endfunction

    // Main state update
    always_ff @(posedge clk) begin
        if (rst) begin
            lfsr <= 8'hA5;
            step_cnt <= '0;

            step_count_before_shrink <= '0;
            shrink_step_cnt          <= '0;
            shrink_mode              <= 1'b0;
            cur_half_width           <= TRACK_HALF_WIDTH;

            head_v <= 0;  // start straight

            // Initialize center
            if (MIN_CENTER <= (GRID_W/2) && (GRID_W/2) <= MAX_CENTER)
                head_x <= (GRID_W/2);
            else
                head_x <= MIN_CENTER[$clog2(GRID_W)-1:0];

            // Fill initial grid with straight track
            for (y = 0; y < GRID_H; y = y + 1) begin
                grid[y] <= build_track_row(head_x, cur_half_width);
            end

        end else begin
            // Update LFSR
            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5]};

            if (step_cnt == {STEP_BITS{1'b1}}) begin
                step_cnt <= '0;

                // --- Shrink control ---
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

                // --- Smooth curvy motion: random ACCELERATION, not random jumps ---
                begin
                    int dv;
                    int new_v;
                    int new_x;

                    // Small random change to velocity: -1, 0, or +1
                    case (lfsr[1:0])
                        2'b00: dv = -1;  // curve more left
                        2'b11: dv =  1;  // curve more right
                        default: dv = 0; // usually keep current curvature
                    endcase

                    // Update velocity and clamp to [-MAX_VEL, MAX_VEL]
                    new_v = head_v + dv;
                    if (new_v >  MAX_VEL) new_v =  MAX_VEL;
                    if (new_v < -MAX_VEL) new_v = -MAX_VEL;

                    // Avoid hugging borders forever: damp outward velocity near edges
                    if ((head_x <= MIN_CENTER+1) && (new_v < 0)) new_v = 0;
                    if ((head_x >= MAX_CENTER-1) && (new_v > 0)) new_v = 0;

                    // Move the head by this smooth velocity
                    new_x = head_x + new_v;

                    // Clamp position to legal range
                    if (new_x < MIN_CENTER)
                        head_x <= MIN_CENTER[$clog2(GRID_W)-1:0];
                    else if (new_x > MAX_CENTER)
                        head_x <= MAX_CENTER[$clog2(GRID_W)-1:0];
                    else
                        head_x <= new_x[$clog2(GRID_W)-1:0];

                    // Commit the new velocity
                    head_v <= new_v;
                end

                // Scroll grid down and insert new row at the top
                for (y = GRID_H-1; y > 0; y = y - 1) begin
                    grid[y] <= grid[y-1];
                end
                grid[0] <= build_track_row(head_x, cur_half_width);

            end else begin
                step_cnt <= step_cnt + 1'b1;
            end
        end
    end

    // Lookup: is current cell on the path?
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

    // Flatten 2D grid[y][x] into row-major vector path_grid_out
    always_comb begin
        for (r = 0; r < GRID_H; r = r + 1) begin
            path_grid_out[r*GRID_W +: GRID_W] = grid[r];
        end
    end

endmodule

`default_nettype wire
