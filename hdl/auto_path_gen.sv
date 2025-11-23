`timescale 1ns / 1ps
`default_nettype none

// autopath_gen
module autopath_gen #(
    parameter int GRID_W = 10,
    parameter int GRID_H = 10,
    parameter int FPS = 60,
    parameter string INIT_FILE = "data/autopath_init.mem"
)(
    input  wire clk,
    input  wire rst,
    input  wire new_frame,
    input  wire [$clog2(GRID_W)-1:0]  cell_x, //x idx into 10*10 grid
    input  wire [$clog2(GRID_H)-1:0]  cell_y,
    input  wire shift_left_req,
    input  wire shift_right_req,
    output logic cell_on //(cell_x,cell_y)
);

    localparam int FRAMES_30S = 30 * FPS;
    localparam int SHRINK_STEP_FRAMES = FPS; // shrink once every 30s

    logic [$clog2(GRID_W)-1:0] cell_x_r; //cellx curr
    logic [$clog2(GRID_H)-1:0] cell_y_r; //celly_cur

    logic [$clog2(GRID_H)-1:0] row_cur; 
    logic [GRID_W-1:0] row_bits;
    logic [ $clog2(GRID_W)-1:0] col_offset;

    logic [$clog2(FRAMES_30S+1)-1:0] frame_cnt_30s;
    logic [$clog2(SHRINK_STEP_FRAMES+1)-1:0] shrink_frame_cnt;
    logic shrink_mode;

    logic [$clog2(GRID_W)-1:0] min_x, max_x;
    logic [ $clog2(GRID_W)-1:0] col_idx_BRAM_row; // which col we look at
    logic [ $clog2(GRID_W):0] sum_x;
    wire in_window;
    wire base_cell_on; 


    // Xilinx single-port, read-first RAM wrapper (you already have this file).
    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(GRID_W),
        .RAM_DEPTH(GRID_H),
        .RAM_PERFORMANCE("LOW_LATENCY"),
        .INIT_FILE(INIT_FILE)
    ) path_rom (
        .addra(row_cur),         
        .dina({GRID_W{1'b0}}),  
        .clka(clk),
        .wea(1'b0),       
        .ena(1'b1),   
        .rsta(rst),
        .regcea(1'b1),
        .douta(row_bits)     
    );


    assign base_cell_on = row_bits[col_idx_BRAM_row];

    always_comb begin
        sum_x = cell_x_r + col_offset;
        if (sum_x >= GRID_W)
            col_idx_BRAM_row = sum_x - GRID_W;
        else
            col_idx_BRAM_row = sum_x[ $clog2(GRID_W)-1:0];
    end

    assign in_window = (cell_x_r >= min_x) && (cell_x_r <= max_x);


    always_ff @(posedge clk) begin
        if (rst) begin
            cell_x_r <= '0;
            cell_y_r <= '0;
            row_cur <= '0;
            col_offset <= '0;
            frame_cnt_30s <= '0;
            shrink_mode <= 1'b0;
            shrink_frame_cnt <= '0;
            min_x <= '0;
            max_x <= GRID_W-1;
            cell_on <= 1'b0;

        end else begin
            // pipeline
            cell_x_r <= cell_x;
            cell_y_r <= cell_y;
            row_cur <= cell_y_r;

            // sift left
            if (shift_left_req && !shift_right_req) begin
                if (col_offset == GRID_W-1)
                    col_offset <= '0;
                else
                    col_offset <= col_offset + 1'b1;

            //shift right
            end else if (shift_right_req && !shift_left_req) begin
                if (col_offset == '0) begin
                    col_offset <= GRID_W-1;
                end else begin 
                    col_offset <= col_offset - 1'b1;
                end
            end

            //shrink by 1
            if (!shrink_mode && new_frame) begin
                if (frame_cnt_30s == FRAMES_30S-1) begin
                    shrink_mode <= 1'b1; // start shrinking
                    frame_cnt_30s <= frame_cnt_30s; // hold
                end else begin
                    frame_cnt_30s <= frame_cnt_30s + 1'b1;
                end
            end

            if (shrink_mode && new_frame) begin
                if (shrink_frame_cnt == SHRINK_STEP_FRAMES-1) begin
                    shrink_frame_cnt <= '0;
                    // Shrink 
                    if (min_x < max_x) begin
                        min_x <= min_x + 1'b1;
                        max_x <= max_x - 1'b1;
                    end

                // min_x==max_x
                end else begin
                    shrink_frame_cnt <= shrink_frame_cnt + 1'b1;
                end
            end
            cell_on <= base_cell_on && in_window;

        end
    end







endmodule

`default_nettype wire
