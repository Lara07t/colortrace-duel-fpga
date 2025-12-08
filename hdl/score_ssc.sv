`timescale 1ns / 1ps
`default_nettype none

module score_ssc #(
    parameter COUNT_TO = 100000
)(
    input  wire        clk,
    input  wire        rst,

    input  wire [2:0]  state,      // from game_fsm
    input  wire [1:0]  p1_lives,   // 0..3
    input  wire [1:0]  p2_lives,   // 0..3
    input  wire [1:0]  winner,     // 0=none,1=P1,2=P2

    output logic [6:0] cathode,
    output logic [7:0] anode
);


    //which of the 8 digits is currently active
    logic [7:0]  segment_state;
    logic [31:0] segment_counter;

    logic [6:0] led_out;
    logic [3:0] routed_vals;
    logic [6:0] bto7s_led_out;

    //active-low hardware
    assign cathode = ~led_out;
    assign anode   = ~segment_state;

    bto7s mbto7s (
        .x(routed_vals),
        .s(bto7s_led_out)
    );

    //rotate through digits (time-multiplexing)
    always_ff @(posedge clk) begin
        if (rst) begin
            segment_state   <= 8'b0000_0001;  // start on digit 0
            segment_counter <= 32'd0;
        end else begin
            if (segment_counter == COUNT_TO) begin
                segment_counter <= 32'd0;
                segment_state   <= {segment_state[6:0], segment_state[7]};
            end else begin
                segment_counter <= segment_counter + 1;
            end
        end
    end

    // decide what each digit displays
    //   - digit with bit 0  => P1 score (bottom-right)
    //   - digit with bit 4  => P2 score (top-right)
    // Everything else is blank.
    always_comb begin
        // default = blank
        routed_vals = 4'h0;
        led_out     = 7'b0000000;

        if (state == 3'd4) begin
            // GAME_OVER: show "P1" or "P2"
            unique case (segment_state)
                // Lower-right digit: show "1" or "2"
                8'b0000_0001: begin
                    case (winner)
                        2'd1: routed_vals = 4'd1;  // P1
                        2'd2: routed_vals = 4'd2;  // P2
                        default: routed_vals = 4'd0;
                    endcase
                    led_out = bto7s_led_out;       // use normal digit encoding
                end

                // Upper-right digit: show "P"
                8'b0001_0000: begin
                    // segments for "P": a, b, e, f, g on; c, d off
                    // {g,f,e,d,c,b,a} = 7'b1110011
                    led_out = 7'b1110011;
                end

                default: begin
                    led_out     = 7'b0000000; // blank other digits
                    routed_vals = 4'h0;
                end
            endcase
        end else begin
            // NORMAL GAME: show lives
            unique case (segment_state)
                // Lower-right digit: player 1 lives
                8'b0000_0001: begin
                    routed_vals = {2'b00, p1_lives}; // 0..3
                    led_out     = bto7s_led_out;
                end

                // Upper-right digit: player 2 lives
                8'b0001_0000: begin
                    routed_vals = {2'b00, p2_lives};
                    led_out     = bto7s_led_out;
                end

                default: begin
                    led_out     = 7'b0000000;
                    routed_vals = 4'h0;
                end
            endcase
        end
    end


endmodule


module bto7s(
        input wire [3:0]   x,
        output logic [6:0] s
    );

    logic sa, sb, sc, sd, se, sf, sg;
    assign s = {sg, sf, se, sd, sc, sb, sa};

    // array of bits that are "one hot" with numbers 0 through 15
    logic [15:0] num;

    assign num[0] = ~x[3] && ~x[2] && ~x[1] && ~x[0];
    assign num[1] = ~x[3] && ~x[2] && ~x[1] && x[0];
    assign num[2] = x == 4'd2;
    assign num[3] = x == 4'd3;
    assign num[4] = x == 4'd4;
    assign num[5] = x == 4'd5;
    assign num[6] = x == 4'd6;
    assign num[7] = x == 4'd7;
    assign num[8] = x == 4'd8;
    assign num[9] = x == 4'd9;
    assign num[10] = x == 4'd10;
    assign num[11] = x == 4'd11;
    assign num[12] = x == 4'd12;
    assign num[13] = x == 4'd13;
    assign num[14] = x == 4'd14;
    assign num[15] = x == 4'd15;

    assign sa = num[0] || num[2] || num[3] || num[5] || num[6] || num[7] || num[8] || num[9] || num[10] || num[12] ||num[14] ||num[15];
    assign sb = num[0] || num[1] || num[2] || num[3] || num[4] || num[7] || num[8] || num[9] || num[10] || num[13];
    assign sc = num[0] || num[1] || num[3] || num[4] || num[5] || num[6] || num[7] || num[8] || num[9] || num[10] || num[11] || num[13];
    assign sd = num[0] || num[2] || num[3] || num[5] || num[6] || num[8] || num[9] || num[11] || num[12] || num[13] || num[14];
    assign se = num[0] || num[2] || num[6] || num[8] || num[10] || num[11] || num[12] || num[13] || num[14] || num[15];
    assign sf = num[0] || num[4] || num[5] || num[6] || num[8] || num[9] || num[10] || num[11] || num[12] || num[14] || num[15];
    assign sg = num[2] || num[3] || num[4] || num[5] || num[6] || num[8] || num[9] || num[10] || num[11] || num[13] || num[14] ||num[15];
endmodule


`default_nettype wire

