module crc32_mpeg2(
    input  wire clk,
    input  wire rst,      
    input  wire din_valid, 
    input  wire din,   
    output logic [31:0] dout 
);
localparam logic [31:0] POLY = 32'h04C11DB7;
always_ff @(posedge clk) begin
    if (rst) begin
        dout <= 32'hFFFF_FFFF;
    end else if (din_valid) begin
        logic fb;
        logic [31:0] next_crc;
        fb = din ^ dout[31];
        // shift left by 1
        next_crc = {dout[30:0], 1'b0};

      // if feedback is 1, XOR
      if (fb) begin
        next_crc ^= POLY;
      end

      dout <= next_crc;
    end
    // else hold value
  end
endmodule

