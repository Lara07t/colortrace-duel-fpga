`default_nettype none
`timescale 1ns / 1ps

/*
temporarily hold a few lines of our image 
in storage for the benefit of downstream filters.
*/
module line_buffer #(
    parameter KERNEL_SIZE = 3,
    parameter HRES = 1280,
    parameter VRES = 720
    )(
            input wire clk, //system clock
            input wire rst, //system reset

            input wire [10:0] h_count_in, //current h_count being read
            input wire [9:0] v_count_in, //current v_count being read
            input wire [15:0] pixel_data_in, //incoming pixel
            input wire data_in_valid, //incoming  valid data signal

            output logic [KERNEL_SIZE-1:0][15:0] line_buffer_out, //output pixels of data
            output logic [10:0] h_count_out, //current h_count being read
            output logic [9:0] v_count_out, //current v_count being read
            output logic data_out_valid //valid data out signal
  );



  logic [3:0][15:0] ram_out;    // outputs from 4 BRAMs
  logic [3:0] wea;              // write enables
  logic [1:0] bram_i;        // which BRAM to write
  logic [1:0] valid_pipe;       // pipeline delay

  generate
    genvar i;
    for (i=0; i<4; i=i+1)begin
      xilinx_true_dual_port_read_first_1_clock_ram #(
      .RAM_WIDTH(16),
      .RAM_DEPTH(HRES),
      .RAM_PERFORMANCE("HIGH_PERFORMANCE")) line_buffer_ram (
      .clka(clk),     // Clock
      //writing port:
      .addra(h_count_in),   // Port A address bus,
      .dina(pixel_data_in),     // Port A RAM input data
      .wea(wea[i] && data_in_valid),       // Port A write enable
      // Port A write enable
      //reading port:
      .addrb(h_count_in),   // Port B address bus,
      .doutb(ram_out[i]),    // Port B RAM output data,
      .douta(),   // Port A RAM output data, width determined from RAM_WIDTH
      .dinb(0),     // Port B RAM input data, width determined from RAM_WIDTH
      .web(1'b0),       // Port B write enable
      .ena(1'b1),       // Port A RAM Enable
      .enb(1'b1),       // Port B RAM Enable,
      .rsta(1'b0),     // Port A output reset
      .rstb(1'b0),     // Port B output reset
      .regcea(1'b1), // Port A output register enable
      .regceb(1'b1) // Port B output register enable
      );
    end
  endgenerate


  always_ff @(posedge clk) begin
    if (rst) begin
      bram_i <= 0;
      h_count_out <= 0;
      v_count_out <= 0;
      valid_pipe <= 0;
    end else begin
      if (data_in_valid && (h_count_in == HRES - 1)) begin // last pxl

        bram_i <= bram_i + 1;
        // end
        
      if (v_count_in >= 2) begin
        v_count_out <= v_count_in - 2;
      end else begin
        v_count_out <= v_count_in + VRES - 2;
      end

      end
      valid_pipe <= {valid_pipe[0], data_in_valid};// delay 1
      h_count_out <= h_count_in;
    end
  end
  assign data_out_valid = valid_pipe[1]; //delay 2


  always_comb begin
    wea = 0;
    if (data_in_valid) begin  // only write to bram when data_in_valid
      wea[bram_i] = 1'b1; // endable write on current bram
    end
    case (bram_i)
      0: line_buffer_out = {ram_out[1], ram_out[2], ram_out[3]};
      1: line_buffer_out = {ram_out[2], ram_out[3], ram_out[0]};
      2: line_buffer_out = {ram_out[3], ram_out[0], ram_out[1]};
      3: line_buffer_out = {ram_out[0], ram_out[1], ram_out[2]};
    endcase
  end

endmodule


`default_nettype wire

