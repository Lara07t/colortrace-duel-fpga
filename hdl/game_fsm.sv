`default_nettype none
module game_fsm #(
    parameter LIVES         = 3,
    parameter PAUSE_FRAMES  = 120, // ~2 sec @ 60fps
    parameter BLINK_PERIOD  = 15   // toggle every 15 frames
)(
    input  wire clk,
    input  wire rst,
    input  wire new_frame,

    // From path checker 
    input  wire p1_life_lost,
    input  wire p2_life_lost,

    output logic [2:0] state,
    output logic [1:0] p1_lives,
    output logic [1:0] p2_lives,
    output logic       blink_p1,
    output logic       blink_p2,
    output logic [1:0] winner    // 0=none,1=P1,2=P2
);

    typedef enum logic [2:0] {
        INIT      = 3'd0,
        READY     = 3'd1,
        PLAY      = 3'd2,
        LIFE_LOSS = 3'd3,
        GAME_OVER = 3'd4
    } state_t;

    state_t cs, ns;

    logic [7:0] pause_ctr;  // counts frames in LIFE_LOSS
    logic [7:0] blink_ctr;  // counts frames between toggles
    logic        blink_flag;
    logic        hit_p1, hit_p2; // who got hit

    always_ff @(posedge clk) begin
        if (rst) begin
            cs        <= INIT;
            p1_lives  <= LIVES;
            p2_lives  <= LIVES;
            pause_ctr <= 0;
            blink_ctr <= 0;
            blink_flag <= 0;
        end else begin
            cs <= ns;

            // Count pause frames in LIFE_LOSS
            if (cs == LIFE_LOSS && new_frame)
                pause_ctr <= pause_ctr + 1;
            else if (cs != LIFE_LOSS)
                pause_ctr <= 0;

            // Blink toggle every BLINK_PERIOD frames
            if (cs == LIFE_LOSS && new_frame) begin
                if (blink_ctr == BLINK_PERIOD - 1) begin
                    blink_ctr  <= 0;
                    blink_flag <= ~blink_flag;
                end else begin
                    blink_ctr <= blink_ctr + 1;
                end
            end else begin
                blink_ctr  <= 0;
                blink_flag <= 0;
            end

            // Decrement lives entry to LIFE_LOSS
            if (cs == PLAY && ns == LIFE_LOSS) begin
                if (hit_p1 && p1_lives > 0)
                    p1_lives <= p1_lives - 1;
                if (hit_p2 && p2_lives > 0)
                    p2_lives <= p2_lives - 1;
            end
        end
    end

    always_comb begin
        ns = cs;
        winner = 0;
        hit_p1 = 1'b0;
        hit_p2 = 1'b0;

        case (cs)

            // once per reset
            INIT: begin
                ns = READY;
            end

            // One-frame state
            READY: begin
                ns = PLAY;
            end
            PLAY: begin
                if (p1_life_lost || p2_life_lost) begin
                    hit_p1 = p1_life_lost;
                    hit_p2 = p2_life_lost;
                    ns = LIFE_LOSS;
                end
            end

            // Blink pause
            LIFE_LOSS: begin
                if (p1_lives == 0 || p2_lives == 0)
                    ns = GAME_OVER;
                else if (pause_ctr >= PAUSE_FRAMES)
                    ns = PLAY; 
            end

            //freeze until reset
            GAME_OVER: begin
                if (p1_lives == 0) winner = 2;
                else               winner = 1;

                if (rst)
                    ns = INIT;
            end

        endcase
    end

    //blink outputs 
    assign blink_p1 = (cs == LIFE_LOSS && hit_p1) ? blink_flag : 1'b0;
    assign blink_p2 = (cs == LIFE_LOSS && hit_p2) ? blink_flag : 1'b0;

    assign state = cs;

endmodule
`default_nettype wire

