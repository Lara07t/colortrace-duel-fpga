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

    // Player centers in pixel coords
    input  wire [10:0]                   p1_x,
    input  wire [9:0]                    p1_y,
    input  wire [10:0]                   p2_x,
    input  wire [9:0]                    p2_y,

    input  wire [GRID_W*GRID_H-1:0]      path_grid_p1,
    input  wire [GRID_W*GRID_H-1:0]      path_grid_p2, 

    output logic                         p1_life_lost,
    output logic                         p2_life_lost
);

    localparam int WINDOW_TILES = 2;              
    localparam int WIN_DIAM     = 2*WINDOW_TILES+1; 
    localparam int OFF_BITS     = $clog2(WIN_DIAM);

    localparam int MAX_X     = GRID_W * CELL_W;
    localparam int MAX_Y     = GRID_H * CELL_H;
    localparam int XY_MAX    = (MAX_X > MAX_Y) ? MAX_X : MAX_Y;
    localparam int XY_BITS   = $clog2(XY_MAX + 1);
    localparam int D_BITS    = XY_BITS + 1;
    localparam int DIST_BITS = 2*D_BITS + 1;

    localparam int GRID_W_BITS = $clog2(GRID_W);
    localparam int GRID_H_BITS = $clog2(GRID_H);
    localparam int IDX_BITS    = $clog2(GRID_W*GRID_H);

    localparam logic [DIST_BITS-1:0] R2 = RADIUS * RADIUS;

    logic [XY_BITS-1:0] p1_x_reg, p1_y_reg;
    logic [XY_BITS-1:0] p2_x_reg, p2_y_reg;

    logic [GRID_W_BITS-1:0] cx1_reg, cx2_reg;
    logic [GRID_H_BITS-1:0] cy1_reg, cy2_reg;

    logic                    scanning;    
    logic                    cur_player;  // 0 = p1, 1 = p2
    logic [OFF_BITS-1:0]     off_x, off_y;
    logic                    new_frame_d; // for edge detect

    logic                    p1_ok_reg, p2_ok_reg;
    logic                    p1_life_lost_reg, p2_life_lost_reg;

    assign p1_life_lost = p1_life_lost_reg;
    assign p2_life_lost = p2_life_lost_reg;

    // tile coordinates around current player
    logic signed [GRID_W_BITS:0] tile_x_s;
    logic signed [GRID_H_BITS:0] tile_y_s;
    logic [GRID_W_BITS-1:0]      tile_x_u;
    logic [GRID_H_BITS-1:0]      tile_y_u;
    logic [IDX_BITS-1:0]         idx;

    logic [XY_BITS-1:0] x_min, x_max, y_min, y_max;
    logic [XY_BITS-1:0] closest_x, closest_y;
    logic signed [D_BITS-1:0] dx, dy;
    logic [DIST_BITS-1:0]     dist2;

    logic hit_tile;  // "this tile causes a violation" for current player

    always_comb begin
        hit_tile = 1'b0;

        if (scanning) begin
            // pick which player we’re currently checking
            logic [GRID_W_BITS-1:0] cx;
            logic [GRID_H_BITS-1:0] cy;
            logic [XY_BITS-1:0]     px, py;

            if (cur_player == 1'b0) begin
                cx = cx1_reg;
                cy = cy1_reg;
                px = p1_x_reg;
                py = p1_y_reg;
            end else begin
                cx = cx2_reg;
                cy = cy2_reg;
                px = p2_x_reg;
                py = p2_y_reg;
            end

            // signed tile coordinates: cx + (off - WINDOW_TILES)
            tile_x_s = $signed({1'b0, cx}) + $signed(off_x) - WINDOW_TILES;
            tile_y_s = $signed({1'b0, cy}) + $signed(off_y) - WINDOW_TILES;

            // check if tile is in-bounds of the grid
            if (tile_x_s >= 0 && tile_x_s < GRID_W &&
                tile_y_s >= 0 && tile_y_s < GRID_H) begin

                tile_x_u = tile_x_s[GRID_W_BITS-1:0];
                tile_y_u = tile_y_s[GRID_H_BITS-1:0];

                idx = tile_y_u * GRID_W + tile_x_u;

                // Only care if this tile is OFF path 
                if ( (cur_player == 1'b0 && path_grid_p1[idx] == 1'b0) ||
                     (cur_player == 1'b1 && path_grid_p2[idx] == 1'b0) ) begin

                    // tile bounds in pixels
                    x_min = tile_x_u * CELL_W;
                    x_max = x_min + CELL_W - 1;
                    y_min = tile_y_u * CELL_H;
                    y_max = y_min + CELL_H - 1;

                    // Clamp closest point on tile to circle center
                    if      (px < x_min) closest_x = x_min;
                    else if (px > x_max) closest_x = x_max;
                    else                 closest_x = px;

                    if      (py < y_min) closest_y = y_min;
                    else if (py > y_max) closest_y = y_max;
                    else                 closest_y = py;

                    // dx, dy and distance squared
                    dx    = $signed(closest_x) - $signed(px);
                    dy    = $signed(closest_y) - $signed(py);
                    dist2 = dx*dx + dy*dy;

                    if (dist2 <= R2)
                        hit_tile = 1'b1;
                end
            end
        end
    end

    // sweep the neighborhood
    always_ff @(posedge clk) begin
        if (rst) begin
            new_frame_d      <= 1'b0;
            scanning         <= 1'b0;
            cur_player       <= 1'b0;
            off_x            <= '0;
            off_y            <= '0;
            p1_ok_reg        <= 1'b1;
            p2_ok_reg        <= 1'b1;
            p1_life_lost_reg <= 1'b0;
            p2_life_lost_reg <= 1'b0;

            p1_x_reg <= '0;
            p1_y_reg <= '0;
            p2_x_reg <= '0;
            p2_y_reg <= '0;
            cx1_reg  <= '0;
            cy1_reg  <= '0;
            cx2_reg  <= '0;
            cy2_reg  <= '0;

        end else begin
            new_frame_d <= new_frame;

            if (new_frame && !new_frame_d) begin
                p1_x_reg <= p1_x;
                p1_y_reg <= p1_y;
                p2_x_reg <= p2_x;
                p2_y_reg <= p2_y;

                // coarse tile coords
                cx1_reg <= p1_x / CELL_W;
                cy1_reg <= p1_y / CELL_H;
                cx2_reg <= p2_x / CELL_W;
                cy2_reg <= p2_y / CELL_H;

                // assume good until a bad tile
                p1_ok_reg        <= 1'b1;
                p2_ok_reg        <= 1'b1;
                p1_life_lost_reg <= 1'b0;
                p2_life_lost_reg <= 1'b0;

                scanning   <= 1'b1;
                cur_player <= 1'b0;   // start with player 1
                off_x      <= '0;
                off_y      <= '0;

            end else if (scanning) begin
                // Update OK flags based on the tile
                if (cur_player == 1'b0) begin
                    if (hit_tile)
                        p1_ok_reg <= 1'b0;
                end else begin
                    if (hit_tile)
                        p2_ok_reg <= 1'b0;
                end

                if (off_x == WIN_DIAM-1) begin
                    off_x <= '0;
                    if (off_y == WIN_DIAM-1) begin
                        // Finished this player’s window
                        if (cur_player == 1'b0) begin
                            // move on to player 2
                            cur_player <= 1'b1;
                            off_y      <= '0;
                        end else begin
                            // finished both players for this frame
                            scanning         <= 1'b0;
                            p1_life_lost_reg <= ~p1_ok_reg;
                            p2_life_lost_reg <= ~p2_ok_reg;
                        end
                    end else begin
                        off_y <= off_y + 1'b1;
                    end
                end else begin
                    off_x <= off_x + 1'b1;
                end
            end
        end
    end

endmodule

`default_nettype wire
