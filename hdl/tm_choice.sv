module tm_choice (
    input  wire [7:0] d,   // data byte in
    output logic [8:0] q_m // transition minimized output
);

  logic [3:0] ones;    // number of 1s in d
  logic x_nor;
  logic [8:0] qm;

  always_comb begin
    ones = d[0] + d[1] + d[2] + d[3] + d[4] + d[5] + d[6] + d[7];

// >4  ones use x_nor else XOR
// = 4 and 1st but =0 x_nor
    x_nor = (ones > 4) || ((ones == 4) && (d[0] == 1'b0));

    qm[0] = d[0];
    for (int i = 1; i < 8; i++) begin
      // XOR or x_nor relative to previous output bit
      if (x_nor) 
        qm[i] = ~(qm[i-1] ^ d[i]);
      else
        qm[i] = (qm[i-1] ^ d[i]);
    end

    qm[8] = ~x_nor;  // 0 if x_nor, 1 if XOR
    

  end

  assign q_m = qm;

endmodule