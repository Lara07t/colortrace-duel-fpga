`default_nettype none

module path_checker #(
    parameter GRID_W  = 10,
    parameter GRID_H  = 10,
    parameter CELL_W  = 64,
    parameter CELL_H  = 72,
    parameter RADIUS  = 32
)(
    input  wire                          clk,
    input  wire                          rst,
    input  wire                          new_frame,

    // Player centers in pixel coords (0..639, 0..719 for each half)
    input  wire [10:0]                   p1_x,
    input  wire [9:0]                    p1_y,
    input  wire [10:0]                   p2_x,
    input  wire [9:0]                    p2_y,

    // 10x10 path grid: 1 = on path, 0 = off path (row-major)
    input  wire [GRID_W*GRID_H-1:0]      path_grid_p1,
    input  wire [GRID_W*GRID_H-1:0]      path_grid_p2, 

    output logic                         p1_life_lost,
    output logic                         p2_life_lost
);

    // R^2 for circle-rect intersection test
    localparam integer R2 = RADIUS * RADIUS;

    // Loop indices
    integer tx, ty;

    // Shared tile / geometry variables
    integer idx;
    integer x_min, x_max, y_min, y_max;
    integer closest_x, closest_y;
    integer dx, dy;

    logic p1_ok, p2_ok;

    always_ff @(posedge clk) begin
        if (rst) begin
            p1_ok        <= 1'b1;
            p2_ok        <= 1'b1;
            p1_life_lost <= 1'b0;
            p2_life_lost <= 1'b0;
        end else if (new_frame) begin
            // assume ok until we find a collision
            p1_ok <= 1'b1;
            p2_ok <= 1'b1;

            // Player 1: check circle vs. all "off-path" tiles
            for (ty = 0; ty < GRID_H; ty = ty + 1) begin
                for (tx = 0; tx < GRID_W; tx = tx + 1) begin
                    idx = ty * GRID_W + tx;

                    if (path_grid_p1[idx] == 1'b0) begin
                        // tile bounds in pixels
                        x_min = tx * CELL_W;
                        x_max = x_min + CELL_W - 1;
                        y_min = ty * CELL_H;
                        y_max = y_min + CELL_H - 1;

                        // clamp closest point on tile to circle center
                        if      (p1_x < x_min) closest_x = x_min;
                        else if (p1_x > x_max) closest_x = x_max;
                        else                   closest_x = p1_x;

                        if      (p1_y < y_min) closest_y = y_min;
                        else if (p1_y > y_max) closest_y = y_max;
                        else                   closest_y = p1_y;

                        // circle-rectangle intersection via distance^2
                        dx = closest_x - p1_x;
                        dy = closest_y - p1_y;

                        if (dx*dx + dy*dy <= R2)
                            p1_ok <= 1'b0;
                    end
                end
            end

            // Player 2: same logic, but using p2_x / p2_y
            for (ty = 0; ty < GRID_H; ty = ty + 1) begin
                for (tx = 0; tx < GRID_W; tx = tx + 1) begin
                    idx = ty * GRID_W + tx;

                    if (path_grid_p2[idx] == 1'b0) begin
                        x_min = tx * CELL_W;
                        x_max = x_min + CELL_W - 1;
                        y_min = ty * CELL_H;
                        y_max = y_min + CELL_H - 1;

                        if      (p2_x < x_min) closest_x = x_min;
                        else if (p2_x > x_max) closest_x = x_max;
                        else                   closest_x = p2_x;

                        if      (p2_y < y_min) closest_y = y_min;
                        else if (p2_y > y_max) closest_y = y_max;
                        else                   closest_y = p2_y;

                        dx = closest_x - p2_x;
                        dy = closest_y - p2_y;

                        if (dx*dx + dy*dy <= R2)
                            p2_ok <= 1'b0;
                    end
                end
            end

            // latch results for this frame
            p1_life_lost <= ~p1_ok;
            p2_life_lost <= ~p2_ok;
        end
    end

endmodule

`default_nettype wire
