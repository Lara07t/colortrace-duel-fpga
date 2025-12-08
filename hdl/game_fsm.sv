`default_nettype none
module game_fsm #(
    parameter LIVES         = 3,
    parameter PAUSE_FRAMES  = 120, // ~2 sec @ 60fps between life loss and resume
    parameter BLINK_PERIOD  = 15,  // toggle every 15 frames
    parameter WARMUP_FRAMES = 120  // ~2 sec after reset before life loss is enabled
)(
    input  wire clk,
    input  wire rst,
    input  wire new_frame,

    // From path checker: 1 = player is off-path this frame
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

    logic [7:0]  pause_ctr;   // counts frames in LIFE_LOSS
    logic [7:0]  blink_ctr;   // counts frames between blink toggles
    logic        blink_flag;

    // Warm-up counter: how many frames since reset
    logic [15:0] warmup_ctr;
    logic        life_loss_enabled;

    // Latched info: who was hit for this LIFE_LOSS phase
    logic hit_p1_reg, hit_p2_reg;

    // Sequential logic
    always_ff @(posedge clk) begin
        if (rst) begin
            cs         <= INIT;
            p1_lives   <= LIVES[1:0];
            p2_lives   <= LIVES[1:0];
            pause_ctr  <= 0;
            blink_ctr  <= 0;
            blink_flag <= 0;
            hit_p1_reg <= 1'b0;
            hit_p2_reg <= 1'b0;
            warmup_ctr <= 16'd0;
        end else begin
            cs <= ns;

            // Warm-up frame counter: starts right after reset
            if (new_frame && cs != GAME_OVER) begin
                if (warmup_ctr < WARMUP_FRAMES)
                    warmup_ctr <= warmup_ctr + 1;
            end

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

            // Handle lives + latch who was hit on transition PLAY -> LIFE_LOSS
            if (cs == PLAY && ns == LIFE_LOSS) begin
                hit_p1_reg <= p1_life_lost;
                hit_p2_reg <= p2_life_lost;

                if (p1_life_lost && p1_lives > 0)
                    p1_lives <= p1_lives - 1;
                if (p2_life_lost && p2_lives > 0)
                    p2_lives <= p2_lives - 1;
            end else if (cs == LIFE_LOSS && ns != LIFE_LOSS) begin
                // Leaving LIFE_LOSS: clear hit info
                hit_p1_reg <= 1'b0;
                hit_p2_reg <= 1'b0;
            end
        end
    end

    assign life_loss_enabled = (warmup_ctr >= WARMUP_FRAMES);

    // Combinational next-state logic
    always_comb begin
        ns     = cs;
        winner = 2'd0;

        case (cs)

            // once per reset
            INIT: begin
                ns = READY;
            end

            // Wait here until:
            //  1) warm-up finished, AND
            //  2) both players are on-path (no life_lost)
            READY: begin
                if (!life_loss_enabled) begin
                    ns = READY; // still warming up
                end else if (!p1_life_lost && !p2_life_lost) begin
                    ns = PLAY;  // both safe → start game
                end else begin
                    ns = READY; // someone is off path, keep waiting
                end
            end

            // Active play: now we react to hits
            PLAY: begin
                if (life_loss_enabled && (p1_life_lost || p2_life_lost)) begin
                    ns = LIFE_LOSS;
                end
            end

            // Blink pause after a life loss
            LIFE_LOSS: begin
                if (p1_lives == 0 || p2_lives == 0)
                    ns = GAME_OVER;
                else if (pause_ctr >= PAUSE_FRAMES)
                    ns = PLAY; 
            end

            //freeze until reset
            GAME_OVER: begin
                if (p1_lives == 0) winner = 2; // P2 wins
                else               winner = 1; // P1 wins

                if (rst)
                    ns = INIT;
            end

        endcase
    end

    // Outputs
    // blink outputs – use latched hit info
    assign blink_p1 = (cs == LIFE_LOSS && hit_p1_reg) ? blink_flag : 1'b0;
    assign blink_p2 = (cs == LIFE_LOSS && hit_p2_reg) ? blink_flag : 1'b0;

    assign state = cs;

endmodule
`default_nettype wire
