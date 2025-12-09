`timescale 1ns / 1ps
`default_nettype none

module game_renderer #(
    parameter GRID_W   = 40,
    parameter GRID_H   = 40,
    parameter PLAYER_R = 21,
    parameter HALF_W    = 640,
    parameter integer TILE_W = 64,
    parameter integer TILE_H = 64
)(
    input  wire        clk,        // not strictly needed, but fine to keep
    input  wire        active,     // active_draw_hdmi
    input  wire [2:0]  game_state,
    input  wire        blink_p1,
    input  wire        blink_p2,

    // theme: 0 = mud/grass, 1 = ocean/ice
    input  wire        theme,

    // full path grids (40x40 each)
    input  wire [GRID_W*GRID_H-1:0] path_p1,
    input  wire [GRID_W*GRID_H-1:0] path_p2,

    // current pixel coordinates
    input  wire [10:0] x,
    input  wire [9:0]  y,

    // half-screen info + per-half cell coordinates from top_level
    input  wire                      region_left,
    input  wire                      region_right,
    input  wire [$clog2(GRID_W)-1:0] cell_x_left,
    input  wire [$clog2(GRID_H)-1:0] cell_y_left,
    input  wire [$clog2(GRID_W)-1:0] cell_x_right,
    input  wire [$clog2(GRID_H)-1:0] cell_y_right,

    // COMs
    input  wire [10:0] p1_x,
    input  wire [9:0]  p1_y,
    input  wire [10:0] p2_x,
    input  wire [9:0]  p2_y,

    // lives
    input  wire [1:0] p1_lives,
    input  wire [1:0] p2_lives,

    // winner (GAME_OVER)
    input  wire [1:0] winner,

    output logic [7:0] R,
    output logic [7:0] G,
    output logic [7:0] B
);

    //  Path decode: LEFT and RIGHT
    integer addr_left, addr_right;
    logic   on_p1_cell, on_p2_cell;

    always_comb begin
        addr_left  = cell_y_left  * GRID_W + cell_x_left;
        addr_right = cell_y_right * GRID_W + cell_x_right;

        on_p1_cell = 1'b0;
        on_p2_cell = 1'b0;

        if (addr_left >= 0 && addr_left < GRID_W*GRID_H)
            on_p1_cell = path_p1[addr_left];

        if (addr_right >= 0 && addr_right < GRID_W*GRID_H)
            on_p2_cell = path_p2[addr_right];
    end

    // “is this pixel on P1/P2 path?” (per half)
    wire on_p1_pix   = active && region_left  && on_p1_cell;
    wire on_p2_pix   = active && region_right && on_p2_cell;
    wire on_any_path = on_p1_pix | on_p2_pix;

    //  Player circles
    function logic inside_circle(input int px, py, cx, cy, r);
        inside_circle = ((px-cx)*(px-cx) + (py-cy)*(py-cy)) <= (r*r);
    endfunction

    logic draw_p1_circle;
    logic draw_p2_circle;

    always_comb begin
        draw_p1_circle = inside_circle(x, y, p1_x, p1_y, PLAYER_R);
        draw_p2_circle = inside_circle(x, y, p2_x, p2_y, PLAYER_R);
    end

    //  Life indicators (simple circles)
    function logic inside_heart(
        input int px, py,
        input int cx, cy
    );
        inside_heart =
            ((px-cx)*(px-cx) + (py-cy)*(py-cy)) <= 12*12;
    endfunction

    logic heart_p1_0, heart_p1_1, heart_p1_2;
    logic heart_p2_0, heart_p2_1, heart_p2_2;
    logic draw_life;

    always_comb begin
        heart_p1_0 = (p1_lives >= 1) ? inside_heart(x,y, 70, 650) : 1'b0;
        heart_p1_1 = (p1_lives >= 2) ? inside_heart(x,y,100, 650) : 1'b0;
        heart_p1_2 = (p1_lives == 3) ? inside_heart(x,y,130, 650) : 1'b0;

        heart_p2_0 = (p2_lives >= 1) ? inside_heart(x,y,710, 650) : 1'b0;
        heart_p2_1 = (p2_lives >= 2) ? inside_heart(x,y,740, 650) : 1'b0;
        heart_p2_2 = (p2_lives == 3) ? inside_heart(x,y,770, 650) : 1'b0;

        draw_life =
            heart_p1_0 | heart_p1_1 | heart_p1_2 |
            heart_p2_0 | heart_p2_1 | heart_p2_2;
    end

    // path colors per theme (only used if you ever want solid colors)
    logic [7:0] p1_R, p1_G, p1_B;
    logic [7:0] p2_R, p2_G, p2_B;

    //  MENU THEME IMAGES (grass & snow)
    logic [7:0] grass_R, grass_G, grass_B;
    logic [7:0] snow_R,  snow_G,  snow_B;

    // grass + mud tiled background (used in mud theme during game)
    logic [7:0] mud_R,   mud_G,   mud_B;

    // ocean tiled path
    logic [7:0] ocean_R, ocean_G, ocean_B;

    // ice tiled background (theme=1 off-path)
    logic [7:0] ice_R,   ice_G,   ice_B;

    // treat each half-screen independently for tiling
    wire [10:0] x_local = (x < HALF_W) ? x : (x - HALF_W);

    // mud tiles (theme=0)
    mud_tile_sprite #(
        .TILE_W       (TILE_W),
        .TILE_H       (TILE_H),
        .IMG_INIT_FILE("data/mud_image.mem"),
        .PAL_INIT_FILE("data/mud_palette.mem")
    ) mud_tex (
        .clk (clk),
        .x   (x_local),
        .y   (y),
        .R   (mud_R),
        .G   (mud_G),
        .B   (mud_B)
    );

    // ocean tiles (theme=1 path)
    ocean_tile_sprite #(
        .TILE_W       (TILE_W),
        .TILE_H       (TILE_H),
        .IMG_INIT_FILE("data/ocean_image.mem"),
        .PAL_INIT_FILE("data/ocean_palette.mem")
    ) ocean_tex (
        .clk (clk),
        .x   (x_local),
        .y   (y),
        .R   (ocean_R),
        .G   (ocean_G),
        .B   (ocean_B)
    );

    // ice tiles (theme=1 background)
    ice_tile_sprite #(
        .TILE_W       (TILE_W),
        .TILE_H       (TILE_H),
        .IMG_INIT_FILE("data/ice_image.mem"),
        .PAL_INIT_FILE("data/ice_palette.mem")
    ) ice_tex (
        .clk (clk),
        .x   (x_local),
        .y   (y),
        .R   (ice_R),
        .G   (ice_G),
        .B   (ice_B)
    );

    //  Menu theme sprites (INIT state)
    grass_menu_sprite #(
        .WIDTH (128),
        .HEIGHT(128)
    ) grass_menu_inst (
        .pixel_clk  (clk),
        .rst        (1'b0),
        .pop        (1'b0),
        .x          (11'd256),
        .h_count    (x),
        .y          (9'd296),
        .v_count    (y),
        .pixel_red  (grass_R),
        .pixel_green(grass_G),
        .pixel_blue (grass_B)
    );

    snow_menu_sprite #(
        .WIDTH (128),
        .HEIGHT(128)
    ) snow_menu_inst (
        .pixel_clk  (clk),
        .rst        (1'b0),
        .pop        (1'b0),
        .x          (11'd896),
        .h_count    (x),
        .y          (9'd296),
        .v_count    (y),
        .pixel_red  (snow_R),
        .pixel_green(snow_G),
        .pixel_blue (snow_B)
    );

    always_comb begin
        if (!theme) begin
            p1_R = 8'hC0; p1_G = 8'h10; p1_B = 8'h10;
            p2_R = 8'h10; p2_G = 8'h10; p2_B = 8'hC0;
        end else begin
            p1_R = 8'hA0; p1_G = 8'h20; p1_B = 8'hA0;
            p2_R = 8'h20; p2_G = 8'hA0; p2_B = 8'h20;
        end
    end

    //  FINAL RENDER
    always_comb begin
        R = 8'd0;
        G = 8'd0;
        B = 8'd0;

        if (!active) begin
            R = 8'd0; G = 8'd0; B = 8'd0;
        end

        // INIT / MENU
        else if (game_state == 3'd0) begin
            R = 8'd20;
            G = 8'd20;
            B = 8'd20;

            if (x < 11'd640) begin
                R = grass_R;
                G = grass_G;
                B = grass_B;
            end

            if (x >= 11'd640) begin
                R = snow_R;
                G = snow_G;
                B = snow_B;
            end
        end

        // READY + PLAY + LIFE_LOSS
        else if (game_state == 3'd1 ||
                 game_state == 3'd2 ||
                 game_state == 3'd3)
        begin
            // PATH + BACKGROUND
            if (!theme) begin
                // theme 0: grass + mud path
                if (on_any_path) begin
                    R = mud_R;
                    G = mud_G;
                    B = mud_B;
                end else begin
                    R = 8'd10; G = 8'd70; B = 8'd10; // grass background
                end
            end else begin
                // theme 1: ocean path, ice background
                if (on_any_path) begin
                    R = ocean_R;
                    G = ocean_G;
                    B = ocean_B;
                end else begin
                    R = ice_R;
                    G = ice_G;
                    B = ice_B;
                end
            end

            // PLAYER CIRCLES (hide on blink in LIFE_LOSS)
            if (draw_p1_circle && !(game_state==3'd3 && blink_p1)) begin
                R = 8'hFF; G = 8'hFF; B = 8'hFF;
            end
            if (draw_p2_circle && !(game_state==3'd3 && blink_p2)) begin
                R = 8'hFF; G = 8'hFF; B = 8'h00;
            end

            // LIVES
            if (draw_life)
                {R,G,B} = {8'hFF, 8'hFF, 8'hFF};

            // Center divider line
            if (x == HALF_W) begin
                {R,G,B} = {8'd255, 8'd255, 8'd255};
            end else if (x >= 639 && x <= 641) begin
                {R,G,B} = {8'd150, 8'd150, 8'd150};
            end
        end

        // GAME OVER
        else if (game_state == 3'd4) begin
            if (!theme) begin
                if (on_any_path) begin
                    R = mud_R;
                    G = mud_G;
                    B = mud_B;
                end else begin
                    R = 8'd10;
                    G = 8'd70;
                    B = 8'd10;
                end
            end else begin
                if (on_any_path) begin
                    R = ocean_R;
                    G = ocean_G;
                    B = ocean_B;
                end else begin
                    R = ice_R;
                    G = ice_G;
                    B = ice_B;
                end
            end

            if (draw_life)
                {R,G,B} = {8'hFF, 8'd20, 8'd20};
        end

        else begin
            R = 8'd80;
            G = 8'd0;
            B = 8'd80;
        end
    end

endmodule

`default_nettype wire
