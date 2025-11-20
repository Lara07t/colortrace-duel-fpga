`default_nettype none
module center_of_mass (
        input wire clk,
        input wire rst,
        input wire [10:0] pixel_x,
        input wire [9:0]  pixel_y,
        input wire pixel_valid,
        input wire calculate,
        output logic [10:0] com_x,
        output logic [9:0] com_y,
        output logic com_valid
    );
    // REPLACE ME!
    //assign com_valid = 0;

    //counter of pixels 
    logic [31:0] number_pixels; 
    logic [31:0] pixel_x_sum;
    logic [31:0] pixel_y_sum;

    logic [31:0] remainderx;
    logic [31:0] remaindery;
    logic busy_y;
    logic error_y; 
    logic busy_x;
    logic error_x; 
    logic com_valid_x; 
    logic com_valid_y; 
    logic [31:0] com_x_div; 
    logic [31:0] com_y_div;

    //instantiation 
    divider #(.WIDTH(32)) 
    divider_x (.clk(clk),
        .rst(rst),
        .dividend(pixel_x_sum),
        .divisor(number_pixels),
        .data_in_valid(calculate),
        .quotient(com_x_div),
        .remainder(remainderx),
        .data_out_valid(com_valid_x),
        .error(error_x),
        .busy(busy_x));

    divider #(.WIDTH(32)) divider_y
        (.clk(clk),
        .rst(rst),
        .dividend(pixel_y_sum),
        .divisor(number_pixels),
        .data_in_valid(calculate),
        .quotient(com_y_div),
        .remainder(remaindery),
        .data_out_valid(com_valid_y),
        .error(error_y),
        .busy(busy_y));

    typedef enum {
    DIVIDING = 0,
    ADDING = 1
    } state_in;
 
        logic x_high; 
        logic y_high; 

    state_in state;


    always_ff @(posedge clk)begin
        if (rst) begin
         com_x <= 0; 
         state <= ADDING;
         com_y <=0;
         com_valid<=0; 
         pixel_x_sum<=0;
         pixel_y_sum<=0; 
         number_pixels<=0;
         x_high<=0;
        y_high<=0;
        end else begin
            case (state)
            DIVIDING: begin 
                state <= (busy_x || busy_y)? DIVIDING:ADDING;
                if (com_valid_y) begin 
                    y_high <= 1;
                end 
                if (com_valid_x) begin 
                    x_high <= 1;
                end 
                //if (x_high && y_high) begin 
                if ((x_high && com_valid_y) || (y_high && com_valid_x) || (com_valid_x && com_valid_y) ) begin 
                    com_valid <=1; 
                    com_x <= com_x_div;
                    com_y <= com_y_div;
                    pixel_x_sum <= 0;
                    pixel_y_sum <= 0;
                    number_pixels <= 0;
                    x_high<=0;
                    y_high<=0;  
                end else begin 
                    com_valid <=0;
                end 
            end
            ADDING: begin 
                com_valid <=0;
                if (pixel_valid) begin 
                number_pixels <= number_pixels+1'b1;
                pixel_x_sum <= pixel_x_sum+pixel_x;
                pixel_y_sum <= pixel_y_sum+pixel_y;
            end 
            state <= (calculate && number_pixels!=0)? DIVIDING : ADDING;
            end 
            endcase 
        end 
    //your code here
    end 
endmodule

`default_nettype wire