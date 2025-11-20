`timescale 1ns / 1ps
`default_nettype none

module convolution #(
    parameter KERNEL_DIMENSION = 3,
    parameter K_SELECT = 0
)(
    input  wire clk,
    input  wire rst,

    input  wire [KERNEL_DIMENSION-1:0][15:0] data_in,
    input  wire [10:0] h_count_in,
    input  wire [9:0]  v_count_in,
    input  wire        data_in_valid,

    output logic       data_out_valid,
    output logic [10:0] h_count_out,
    output logic [9:0]  v_count_out,
    output logic [15:0] line_out
);

    logic signed [2:0][2:0][7:0] coeffs;
    logic [7:0] shift;
    kernels #(.K_SELECT(K_SELECT)) kernel_inst (.coeffs(coeffs), .shift(shift));

    logic [2:0][2:0][15:0] cache;
    logic data_valid_pipe;
    logic [10:0] h_pipe;
    logic [9:0]  v_pipe;

    logic signed [2:0][2:0][15:0] prod_r, prod_g, prod_b;

    logic signed [19:0] sum_r, sum_g, sum_b;
    logic signed [19:0] conv_r, conv_g, conv_b;

    logic [4:0] r_q;
    logic [5:0] g_q;
    logic [4:0] b_q;


    always_comb begin
        for (int i = 0; i < 3; i++) begin
            for (int j = 0; j < 3; j++) begin
                prod_r[i][j] = $signed({1'b0, cache[i][j][15:11]}) * $signed(coeffs[i][j]);
                prod_g[i][j] = $signed({1'b0, cache[i][j][10:5]}) * $signed(coeffs[i][j]);
                prod_b[i][j] = $signed({1'b0, cache[i][j][4:0]})* $signed(coeffs[i][j]);
            end
        end
    end


    always_comb begin
        sum_r = 0; 
        sum_g = 0; 
        sum_b = 0;
        for (int i = 0; i < 3; i++) begin
            for (int j = 0; j < 3; j++) begin
                sum_r += prod_r[i][j];
                sum_g += prod_g[i][j];
                sum_b += prod_b[i][j];
            end
        end
    end


    always_ff @(posedge clk) begin
        if (rst) begin
            cache <= 0;
            data_valid_pipe <=0;
            h_pipe <=0;
            v_pipe <=0;
            data_out_valid <= 0;
            h_count_out <= 0;
            v_count_out <= 0;
            conv_r <= 0;
            conv_g <=0;
            conv_b <=0; 
            r_q = 0; 
            g_q = 0; 
            b_q = 0;
            line_out <= 0;
        end else begin
            data_valid_pipe <= data_in_valid;
            // data_valid_pipe[1] <= data_valid_pipe[0];
            // data_valid_pipe[2] <= data_valid_pipe[1];

            h_pipe <= h_count_in;
            // h_pipe[1] <= h_pipe[0];
            // h_pipe[2] <= h_pipe[1];

            v_pipe <= v_count_in;
            // v_pipe[1] <= v_pipe[0];
            // v_pipe[2] <= v_pipe[1];

            // h_pipe <= {h_pipe[2:0], h_count_in};
            // v_pipe <= {v_pipe[2:0], v_count_in};

            if (data_in_valid) begin
                cache[0] <= cache[1];
                cache[1] <= cache[2];
                cache[2] <= data_in;
            end
            
            conv_r <= $signed(sum_r) >>> shift;
            conv_g <= $signed(sum_g) >>> shift;
            conv_b <= $signed(sum_b) >>> shift;

            // data_out_valid <= data_valid_pipe[2];
            // h_count_out <= h_pipe[2];
            // v_count_out <= v_pipe[2];
            // // h_count_out <= h_count_in



            if (conv_r <  $signed(0)) begin
                r_q <= 0;
            end else if (conv_r > $signed(31)) begin 
                r_q <= 31;
            end else 
                r_q <= conv_r[4:0];

            if (conv_g < $signed(0)) begin
                g_q <= 0;
            end else if (conv_g > $signed(63)) begin 
                g_q <= 63;
            end else begin
                g_q <= conv_g[5:0];
            end

            if (conv_b < $signed(0)) begin 
                b_q <= 0;
            end else if (conv_b > $signed(31)) begin 
                b_q <= 31;
            end else begin
                b_q <= conv_b[4:0];
            end

            data_out_valid <= data_valid_pipe;
            h_count_out <= h_pipe;
            v_count_out <= v_pipe;

            line_out <= {r_q, g_q, b_q};
        end
    end

endmodule

`default_nettype wire


