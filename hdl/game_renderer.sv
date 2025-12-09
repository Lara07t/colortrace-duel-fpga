`timescale 1ns / 1ps
`default_nettype none

module game_renderer #(
    parameter GRID_W   = 40,
    parameter GRID_H   = 40,
    parameter PLAYER_R = 21
)(
    input  wire        clk,        // not strictly needed, but fine to keep
    input  wire        active,     // active_draw_hdmi
    input  wire [2:0]  game_state,
    input  wire        blink_p1,
    input  wire        blink_p2,

    // theme: 0 = red/blue, 1 = purple/green
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

    //----------------------------------
    //  Path decode: LEFT and RIGHT
    //----------------------------------
    integer addr_left, addr_right;
    logic   on_p1_cell, on_p2_cell;

    always_comb begin
        addr_left  = cell_y_left  * GRID_W + cell_x_left;
        addr_right = cell_y_right * GRID_W + cell_x_right;

        // default to off if out of range (defensive)
        on_p1_cell = 1'b0;
        on_p2_cell = 1'b0;

        if (addr_left >= 0 && addr_left < GRID_W*GRID_H)
            on_p1_cell = path_p1[addr_left];

        if (addr_right >= 0 && addr_right < GRID_W*GRID_H)
            on_p2_cell = path_p2[addr_right];
    end

    // “is this pixel on P1/P2 path?” (per half)
    wire on_p1_pix = active && region_left  && on_p1_cell;
    wire on_p2_pix = active && region_right && on_p2_cell;

    //----------------------------------
    //  Player circles
    //----------------------------------
    function logic inside_circle(input int px, py, cx, cy, r);
        inside_circle = ((px-cx)*(px-cx) + (py-cy)*(py-cy)) <= (r*r);
    endfunction

    logic draw_p1_circle;
    logic draw_p2_circle;

    always_comb begin
        draw_p1_circle = inside_circle(x, y, p1_x, p1_y, PLAYER_R);
        draw_p2_circle = inside_circle(x, y, p2_x, p2_y, PLAYER_R);
    end

    //----------------------------------
    //  Life indicators (simple circles)
    //----------------------------------
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
        heart_p1_1 = (p1_lives >= 2) ? inside_heart(x,y, 100, 650) : 1'b0;
        heart_p1_2 = (p1_lives == 3) ? inside_heart(x,y,130, 650) : 1'b0;

        heart_p2_0 = (p2_lives >= 1) ? inside_heart(x,y, 710,650) : 1'b0;
        heart_p2_1 = (p2_lives >= 2) ? inside_heart(x,y, 740,650) : 1'b0;
        heart_p2_2 = (p2_lives == 3) ? inside_heart(x,y,770,650) : 1'b0;

        draw_life =
            heart_p1_0 | heart_p1_1 | heart_p1_2 |
            heart_p2_0 | heart_p2_1 | heart_p2_2;   

    end

    //----------------------------------
    //  Text “blocks” (menu / winner)
    //----------------------------------
    function logic block_letter(
        input int px, py,
        input int x0, y0,
        input int w, input int h
    );
        block_letter = (px>=x0 && px<x0+w && py>=y0 && py<y0+h);
    endfunction

    logic draw_menu_text;
    logic draw_win_text;

    always_comb begin
        draw_menu_text =
            (game_state==3'd0) && block_letter(x,y, 500, 200, 280, 40);

        draw_win_text =
            (game_state==3'd4) && block_letter(x,y, 520, 200, 240, 40);
    end

    //----------------------------------
    //  PATH COLORS per theme
    //----------------------------------
    logic [7:0] p1_R, p1_G, p1_B;
    logic [7:0] p2_R, p2_G, p2_B;

    always_comb begin
        if (!theme) begin
            // theme 0 = red / blue
            p1_R = 8'hC0; p1_G = 8'h10; p1_B = 8'h10;
            p2_R = 8'h10; p2_G = 8'h10; p2_B = 8'hC0;
        end else begin
            // theme 1 = purple / green
            p1_R = 8'hA0; p1_G = 8'h20; p1_B = 8'hA0;
            p2_R = 8'h20; p2_G = 8'hA0; p2_B = 8'h20;
        end
    end

    //----------------------------------
    //  FINAL RENDER
    //----------------------------------
    always_comb begin
        // default background = black
        R = 8'd0;
        G = 8'd0;
        B = 8'd0;

        if (!active) begin
            R = 0; G = 0; B = 0;
        end

        // INIT / MENU
        else if (game_state == 3'd0) begin
            // show path preview with current theme
            if (on_p1_pix) begin R = p1_R; G = p1_G; B = p1_B; end
            else if (on_p2_pix) begin R = p2_R; G = p2_G; B = p2_B; end

            // big white block as "MENU"
            if (draw_menu_text)
                {R,G,B} = {8'hFF, 8'hFF, 8'hFF};
        end

        // READY + PLAY + LIFE_LOSS
        else if (game_state == 3'd1 ||
                 game_state == 3'd2 ||
                 game_state == 3'd3)
        begin
            // PATHS
            if (on_p1_pix) begin R = p1_R; G = p1_G; B = p1_B; end
            else if (on_p2_pix) begin R = p2_R; G = p2_G; B = p2_B; end

            // PLAYER CIRCLES (hide on blink in LIFE_LOSS)
            if (draw_p1_circle && !(game_state==3'd3 && blink_p1)) begin
                R = 8'hFF; G = 8'hFF; B = 8'hFF;
            end
            if (draw_p2_circle && !(game_state==3'd3 && blink_p2)) begin
                R = 8'hFF; G = 8'hFF; B = 8'h00;
            end

            // LIVES
            if (draw_life)
                {R,G,B} = {8'hFF, 8'd20, 8'd20};

            if (x == 640) begin
            // bright center line
            {R,G,B} = {8'd255, 8'd255, 8'd255};
        end else if (x >= 639 && x <= 641) begin
            // softer glow around it
            {R,G,B} = {8'd150, 8'd150, 8'd150};
        end
        
        end

        // GAME OVER
        else if (game_state == 3'd4) begin
            if (on_p1_pix) begin R = p1_R; G = p1_G; B = p1_B; end
            else if (on_p2_pix) begin R = p2_R; G = p2_G; B = p2_B; end

            // winner block
            if (draw_win_text)
                {R,G,B} = (winner==2'd1) ? {8'hFF, 8'd0, 8'd0}  // P1 wins = red
                                         : {8'd0,  8'hFF,8'd0}; // P2 wins = green

            if (draw_life)
                {R,G,B} = {8'hFF, 8'd20, 8'd20};

            
        end

        
        
    end

endmodule

`default_nettype wire
