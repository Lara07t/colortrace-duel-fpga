`default_nettype none // prevents system from inferring an undeclared logic (good practice)
module pong (
        input wire pixel_clk,
        input wire rst,
        input wire [1:0] control,
        input wire [3:0] puck_speed,
        input wire [3:0] paddle_speed,
        input wire new_frame,
        input wire [10:0] h_count,
        input wire [9:0] v_count,
        output logic [7:0] pixel_red,
        output logic [7:0] pixel_green,
        output logic [7:0] pixel_blue
    );

    //use these params!
    localparam PADDLE_WIDTH = 16;
    localparam PADDLE_HEIGHT = 128;
    localparam PUCK_WIDTH = 128;
    localparam PUCK_HEIGHT = 128;
    localparam GAME_WIDTH = 1280;
    localparam GAME_HEIGHT = 720;

    logic [10:0] puck_x, paddle_x; //puck x location, paddle x location
    logic [9:0] puck_y, paddle_y; //puck y location, paddle y location
    logic [7:0] puck_r,puck_g,puck_b; //puck red, green, blue (from block sprite)
    logic [7:0] paddle_r,paddle_g,paddle_b; //paddle colors from its block sprite)

    logic dir_x, dir_y; //use for direction of movement: 1 going positive, 0 going negative
    
    logic [10:0] next_puck_x;
    logic [9:0] next_puck_y;

    logic in_paddle_zone;
    logic x_overlap_next;
    logic y_overlap_next;
    logic overlap_next;
    logic [9:0] next_paddle_y ;
    logic [10:0] limit;

    logic [11:0] right_edge;
    logic [11:0] bottom_edge;



    logic up, down; //up down from buttons
    logic game_over; //signal to indicate game over (0 on game reset, 1 during play)
    assign up = control[1]; //up control
    assign down = control[0]; //down control



    block_sprite #(.WIDTH(PADDLE_WIDTH), .HEIGHT(PADDLE_HEIGHT))
    paddle(
        .h_count(h_count),
        .v_count(v_count),
        .x(paddle_x),
        .y(paddle_y),
        .pixel_red(paddle_r),
        .pixel_green(paddle_g),
        .pixel_blue(paddle_b)
    );

    block_sprite #(.WIDTH(PUCK_WIDTH), .HEIGHT(PUCK_HEIGHT))
    puck(
      .h_count(h_count),
      .v_count(v_count),
      .x(puck_x),
      .y(puck_y),
      .pixel_red(puck_r),
      .pixel_green(puck_g),
      .pixel_blue(puck_b)
    );

    assign pixel_red = puck_r | paddle_r; //merge color contributions from puck and paddle
    assign pixel_green =  puck_g | paddle_g; //merge color contribuations from puck and paddle
    assign pixel_blue = puck_b | paddle_b; //merge color contributsion from puck and paddle

    logic puck_overlap; //one bit signal indicating if puck and paddle overlap
    //this signal should be one when puck is red in the video included in lab.
    //make signal be derived combinationally. you will need to figure this out
    //remember numbers are not signed here...so there's no such thing as negative


always_comb begin 
    if (up && !down) begin
        if (paddle_y > paddle_speed) begin
                        next_paddle_y = paddle_y - paddle_speed;
        end else begin
                    // if alr at top
                        next_paddle_y = 10'd0;
        end 
    end else if (down && !up) begin
                    // down 
                    // max horizontal
                    limit = GAME_HEIGHT - PADDLE_HEIGHT;
                    if (paddle_y + paddle_speed < limit[9:0]) begin
                        next_paddle_y = paddle_y + paddle_speed;
                    end else begin
                        next_paddle_y = limit[9:0];
                    end
    end
end


    always_ff @(posedge pixel_clk)begin
        if (rst)begin
            //start puck in center of screen (you need to change!):
            puck_x <= (GAME_WIDTH  - PUCK_WIDTH ) >> 1; //change me
            puck_y <=  (GAME_HEIGHT - PUCK_HEIGHT) >> 1; //change me
            dir_x <= h_count[0]; //start at pseudorandom direction
            dir_y <= h_count[1]; //start with pseudorandom direction
            //start paddle in center of left half of screen (you need to change)
            paddle_x <= 0; //change me (maybe...or maybe not..?)
            paddle_y <= (GAME_HEIGHT - PADDLE_HEIGHT) >> 1; //change me
            game_over <= 0;
          end else begin
            if (~game_over && new_frame)begin
            // paddle same place
              paddle_y <= next_paddle_y;

                next_puck_x = puck_x;
                next_puck_y = puck_y;

                // X step by speed & dir
                if (dir_x) begin
                    // moving right
                    // where is edge after movement
                    right_edge = puck_x + PUCK_WIDTH + puck_speed;
                    if (right_edge >= GAME_WIDTH) begin
                        next_puck_x = GAME_WIDTH - PUCK_WIDTH;
                        dir_x <= 1'b0; // go left
                    end else begin
                        next_puck_x = puck_x + puck_speed;
                    end
                end else begin
                    // moving left
                    if (puck_speed >= puck_x) begin
                        next_puck_x = 11'd0; // would pass x=0
                    end else begin
                        next_puck_x = puck_x - puck_speed;
                    end
                end

                if (dir_y) begin
                    // moving down
                    bottom_edge = puck_y + PUCK_HEIGHT + puck_speed;
                    if (bottom_edge >= GAME_HEIGHT) begin
                        next_puck_y = GAME_HEIGHT - PUCK_HEIGHT;
                        dir_y <= 1'b0; // go up
                    end else begin
                        next_puck_y = puck_y + puck_speed;
                    end
                end else begin
                    // moving up
                    if (puck_speed >= puck_y) begin
                        next_puck_y = 10'd0;
                        dir_y <= 1'b1; // go down
                    end else begin
                        next_puck_y = puck_y - puck_speed;
                    end
                end

                // x < paddle width
                in_paddle_zone = (next_puck_x < (paddle_x + PADDLE_WIDTH));

                //puck left_edge < paddle && puck right edge > paddle left edge
                x_overlap_next = (next_puck_x < (paddle_x + PADDLE_WIDTH)) && ((next_puck_x + PUCK_WIDTH) > paddle_x);
                y_overlap_next = (next_puck_y < (paddle_y + PADDLE_HEIGHT)) && ((next_puck_y + PUCK_HEIGHT) > paddle_y);
                overlap_next = x_overlap_next && y_overlap_next;

                // moving left and overlap with paddle
                if (!dir_x && overlap_next) begin
                    // reflect 
                    // push puck to paddle’s right edge and go right
                    next_puck_x = paddle_x + PADDLE_WIDTH;
                    dir_x <= 1'b1;
                end else if (in_paddle_zone && !overlap_next && !dir_x) begin
                    // miss paddle on left
                    game_over   <= 1'b1;
                end
end
                if (!game_over) begin
                    puck_x <= next_puck_x;
                    puck_y <= next_puck_y;
                end
            end
        end
    
endmodule
`default_nettype wire
