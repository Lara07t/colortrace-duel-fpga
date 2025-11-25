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
    input  wire [GRID_W*GRID_H-1:0]      path_grid,

    output logic                         p1_life_lost,
    output logic                         p2_life_lost
);

    localparam integer R2 = RADIUS * RADIUS;

    integer tx, ty;

    logic p1_ok, p2_ok;

    always_ff @(posedge clk) begin
        if (rst) begin
            p1_ok <= 1'b1;
            p2_ok <= 1'b1;
            p1_life_lost <= 1'b0;
            p2_life_lost <= 1'b0;
        end else if (new_frame) begin
            p1_ok <= 1'b1;
            p2_ok <= 1'b1;

            // Player 1
            for (ty = 0; ty < GRID_H; ty = ty + 1) begin
                for (tx = 0; tx < GRID_W; tx = tx + 1) begin
                    integer idx = ty * GRID_W + tx;

                    if (path_grid[idx] == 1'b0) begin
                        // Compute tile bounds
                        integer x_min = tx * CELL_W;
                        integer x_max = x_min + CELL_W - 1;
                        integer y_min = ty * CELL_H;
                        integer y_max = y_min + CELL_H - 1;

                        // Clamp closest point on tile to circle center
                        integer closest_x;
                        integer closest_y;

                        if      (p1_x < x_min) closest_x = x_min;
                        else if (p1_x > x_max) closest_x = x_max;
                        else                   closest_x = p1_x;

                        if      (p1_y < y_min) closest_y = y_min;
                        else if (p1_y > y_max) closest_y = y_max;
                        else                   closest_y = p1_y;

                        // Check circle-rectangle intersection
                        integer dx = closest_x - p1_x;
                        integer dy = closest_y - p1_y;
                        if (dx*dx + dy*dy <= R2)
                            p1_ok <= 1'b0;
                    end
                end
            end

            // Player 2 (same logic)
            for (ty = 0; ty < GRID_H; ty = ty + 1) begin
                for (tx = 0; tx < GRID_W; tx = tx + 1) begin
                    integer idx = ty * GRID_W + tx;

                    if (path_grid[idx] == 1'b0) begin
                        integer x_min = tx * CELL_W;
                        integer x_max = x_min + CELL_W - 1;
                        integer y_min = ty * CELL_H;
                        integer y_max = y_min + CELL_H - 1;

                        integer closest_x;
                        integer closest_y;

                        if      (p2_x < x_min) closest_x = x_min;
                        else if (p2_x > x_max) closest_x = x_max;
                        else                   closest_x = p2_x;

                        if      (p2_y < y_min) closest_y = y_min;
                        else if (p2_y > y_max) closest_y = y_max;
                        else                   closest_y = p2_y;

                        integer dx = closest_x - p2_x;
                        integer dy = closest_y - p2_y;
                        if (dx*dx + dy*dy <= R2)
                            p2_ok <= 1'b0;
                    end
                end
            end

            p1_life_lost <= ~p1_ok;
            p2_life_lost <= ~p2_ok;
        end
    end

endmodule
`default_nettype wire

