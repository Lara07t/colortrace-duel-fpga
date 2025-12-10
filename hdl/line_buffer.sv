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
        input  wire clk,              // system clock
        input  wire rst,              // system reset

        input  wire [10:0] h_count_in,    // current h_count being read
        input  wire [9:0]  v_count_in,    // current v_count being read
        input  wire [15:0] pixel_data_in, // incoming pixel
        input  wire        data_in_valid, // incoming valid data signal

        output logic [KERNEL_SIZE-1:0][15:0] line_buffer_out, // output pixels of data
        output logic [10:0] h_count_out,       // current h_count being read (aligned)
        output logic [9:0]  v_count_out,       // current v_count being read (aligned)
        output logic        data_out_valid     // valid data out signal
  );

  // 4 line buffers total: 3 used for kernel, 1 being written
  logic [3:0][15:0] ram_out;    // outputs from 4 BRAMs
  logic [3:0]       wea;        // write enables
  logic [1:0]       bram_i;     // which BRAM to write
  logic [1:0]       valid_pipe; // pipeline delay for valid

  // Simple coordinate pipeline (1-cycle delay for BRAM read)
  logic [10:0] h_count_d1;
  logic [9:0]  v_count_d1;

  // BRAMs: one per line in the ring buffer
  generate
    genvar i;
    for (i=0; i<4; i=i+1) begin : line_buffer_bram_gen
      xilinx_true_dual_port_read_first_1_clock_ram #(
        .RAM_WIDTH(16),
        .RAM_DEPTH(HRES),
        .RAM_PERFORMANCE("HIGH_PERFORMANCE")
      ) line_buffer_ram (
        .clka(clk),           // Clock

        // writing port:
        .addra(h_count_in),   // Port A address bus
        .dina(pixel_data_in), // Port A RAM input data
        .wea(wea[i] && data_in_valid), // Port A write enable

        // reading port:
        .addrb(h_count_d1),   // Port B address bus (delayed h)
        .doutb(ram_out[i]),   // Port B RAM output data

        .douta(),             // unused
        .dinb(16'd0),         // Port B input unused
        .web(1'b0),           // Port B write disabled
        .ena(1'b1),           // Port A enable
        .enb(1'b1),           // Port B enable
        .rsta(1'b0),          // Port A reset
        .rstb(1'b0),          // Port B reset
        .regcea(1'b1),        // Port A output register enable
        .regceb(1'b1)         // Port B output register enable
      );
    end
  endgenerate

  // Sequential logic: rotate BRAM index per line, and pipeline coords/valid
  always_ff @(posedge clk) begin
    if (rst) begin
      bram_i      <= 2'd0;
      valid_pipe  <= 2'd0;

      h_count_d1  <= 11'd0;
      h_count_out <= 11'd0;

      v_count_d1  <= 10'd0;
      v_count_out <= 10'd0;
    end else begin
      // Rotate which BRAM we are writing at end of each line
      if (data_in_valid && (h_count_in == HRES - 1)) begin
        bram_i <= bram_i + 2'd1;
      end

      // 1-cycle pipeline for coordinates to match BRAM read latency
      h_count_d1  <= h_count_in;
      h_count_out <= h_count_d1;

      v_count_d1  <= v_count_in;
      v_count_out <= v_count_d1;

      // 1-cycle delay for valid
      valid_pipe  <= {valid_pipe[0], data_in_valid};
    end
  end

  assign data_out_valid = valid_pipe[1];

  // Combinational: write enables + select which 3 lines to output
  always_comb begin
    wea = 4'b0000;
    if (data_in_valid) begin
      wea[bram_i] = 1'b1; // enable write on current BRAM
    end

    // Always present the last 3 *completed* lines in order
    case (bram_i)
      2'd0: line_buffer_out = {ram_out[1], ram_out[2], ram_out[3]};
      2'd1: line_buffer_out = {ram_out[2], ram_out[3], ram_out[0]};
      2'd2: line_buffer_out = {ram_out[3], ram_out[0], ram_out[1]};
      2'd3: line_buffer_out = {ram_out[0], ram_out[1], ram_out[2]};
    endcase
  end

endmodule

`default_nettype wire
