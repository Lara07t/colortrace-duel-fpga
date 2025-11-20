module tmds_encoder(
        input wire clk,
        input wire rst,
        input wire [7:0] video_data,  // video data (red, green or blue)
        input wire [1:0] control,   //for blue set to {vs,hs}, else will be 0
        input wire video_enable,    //choose between control (0) or video (1)
        output logic [9:0] tmds
    );
    logic [8:0] q_m;
 
    tm_choice mtm(
        .d(video_data),
        .q_m(q_m)
    );
 
  //your code here.
  logic signed [5:0] tally;
  logic signed [5:0] tally_next;

  logic [9:0] tmds_next;   // Next-output combinational
  logic [3:0] ones8; // num of ones in q_m[7:0]
  logic invert8;   // invert lower 8 bits this
  logic top_tmds_bit;    // tmds[9]
  logic [7:0] lower8;    // tmds[7:0]
  logic signed [5:0] d8; 
  logic signed [5:0] delta8;


  // control ins
  localparam logic [9:0] control_00 = 10'b1101010100;
  localparam logic [9:0] control_01 = 10'b0010101011;
  localparam logic [9:0] control_10 = 10'b0101010100;
  localparam logic [9:0] control_11 = 10'b1010101011;

  always_comb begin
    tmds_next  = 10'b0;
    tally_next = tally;

    if (rst) begin
      tmds_next  = 10'b0;
      tally_next = '0;

    end else if (!video_enable) begin
    case (control)
        2'b00: tmds_next = control_00;
        2'b01: tmds_next = control_01;
        2'b10: tmds_next = control_10;
        2'b11: tmds_next = control_11;
      endcase
      tally_next = '0;

    end else begin
      // Video path

      ones8 = $countones(q_m[7:0]);
      d8 = (ones8 <<< 1) - 6'sd8;

      if ((tally == 0) || (ones8 == 4)) begin
        invert8 = ~q_m[8]; // invert iff XOR
        top_tmds_bit = ~q_m[8];
      end
      else if ( (tally > 0 && ones8 > 4) || (tally < 0 && ones8 < 4) ) begin
        invert8 = 1'b1;
        top_tmds_bit  = 1'b1;
      end
      else begin
        invert8 = 1'b0; // keep as it is
        top_tmds_bit  = 1'b0;
      end

      lower8    = invert8 ? ~q_m[7:0] : q_m[7:0];
      tmds_next = { top_tmds_bit, q_m[8], lower8 };

      delta8 = invert8 ? -d8 : d8;
      tally_next = tally + delta8 + (q_m[8] ? 6'sd1 : -6'sd1)+ (top_tmds_bit  ? 6'sd1 : -6'sd1);

    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      tmds  <= 10'b0;
      tally <= '0;
    end else begin
      tmds <= tmds_next;
      tally <= tally_next;
    end
  end

endmodule

`default_nettype wire

