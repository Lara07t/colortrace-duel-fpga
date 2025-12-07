`default_nettype none

module path_checker #(
    parameter GRID_W  = 40,
    parameter GRID_H  = 40,
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

    // GRID_W x GRID_H path grid: 1 = on path, 0 = off path (row-major)
    input  wire [GRID_W*GRID_H-1:0]      path_grid_p1,
    input  wire [GRID_W*GRID_H-1:0]      path_grid_p2, 

    output logic                         p1_life_lost,
    output logic                         p2_life_lost
);

    // R^2 for circle-rect intersection test
    localparam integer R2 = RADIUS * RADIUS;

    // window radius in tiles (±WINDOW_TILES around the player’s tile)
    localparam integer WINDOW_TILES = 2;      // 5×5 neighborhood

    // internal "OK" flags for each player
    logic p1_ok, p2_ok;

    // integer work vars (used in the always_ff block)
    integer cx1, cy1;      // p1 tile coords
    integer cx2, cy2;      // p2 tile coords

    integer tx, ty;
    integer idx;

    integer x_min, x_max, y_min, y_max;
    integer closest_x, closest_y;
    integer dx, dy;

    always_ff @(posedge clk) begin
        if (rst) begin
            p1_ok        <= 1'b1;
            p2_ok        <= 1'b1;
            p1_life_lost <= 1'b0;
            p2_life_lost <= 1'b0;
        end else if (new_frame) begin
            // Assume ok until we find a collision
            p1_ok <= 1'b1;
            p2_ok <= 1'b1;

            // Compute coarse tile coordinates for each player
            // (integer division by tile size)
            cx1 = p1_x / CELL_W;
            cy1 = p1_y / CELL_H;

            cx2 = p2_x / CELL_W;
            cy2 = p2_y / CELL_H;

            // -------------------------
            // Player 1: local neighborhood
            // -------------------------
            for (ty = -WINDOW_TILES; ty <= WINDOW_TILES; ty = ty + 1) begin
                integer tile_y;
                tile_y = cy1 + ty;

                if (tile_y < 0 || tile_y >= GRID_H)
                    continue;

                for (tx = -WINDOW_TILES; tx <= WINDOW_TILES; tx = tx + 1) begin
                    integer tile_x;
                    tile_x = cx1 + tx;

                    if (tile_x < 0 || tile_x >= GRID_W)
                        continue;

                    idx = tile_y * GRID_W + tile_x;

                    // only care about OFF-path tiles (0)
                    if (path_grid_p1[idx] == 1'b0) begin
                        // tile bounds in pixels
                        x_min = tile_x * CELL_W;
                        x_max = x_min + CELL_W - 1;
                        y_min = tile_y * CELL_H;
                        y_max = y_min + CELL_H - 1;

                        // clamp closest point on tile to circle center
                        if      (p1_x < x_min) closest_x = x_min;
                        else if (p1_x > x_max) closest_x = x_max;
                        else                   closest_x = p1_x;

                        if      (p1_y < y_min) closest_y = y_min;
                        else if (p1_y > y_max) closest_y = y_max;
                        else                   closest_y = p1_y;

                        dx = closest_x - p1_x;
                        dy = closest_y - p1_y;

                        if (dx*dx + dy*dy <= R2)
                            p1_ok <= 1'b0;
                    end
                end
            end

            // -------------------------
            // Player 2: local neighborhood
            // -------------------------
            for (ty = -WINDOW_TILES; ty <= WINDOW_TILES; ty = ty + 1) begin
                integer tile_y;
                tile_y = cy2 + ty;

                if (tile_y < 0 || tile_y >= GRID_H)
                    continue;

                for (tx = -WINDOW_TILES; tx <= WINDOW_TILES; tx = tx + 1) begin
                    integer tile_x;
                    tile_x = cx2 + tx;

                    if (tile_x < 0 || tile_x >= GRID_W)
                        continue;

                    idx = tile_y * GRID_W + tile_x;

                    if (path_grid_p2[idx] == 1'b0) begin
                        x_min = tile_x * CELL_W;
                        x_max = x_min + CELL_W - 1;
                        y_min = tile_y * CELL_H;
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
