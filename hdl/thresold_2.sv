// module threshold_2 (
//     input  logic [15:0] sw,
//     output logic [7:0]  thresh_p1,
//     output logic [7:0]  thresh_p2,
//     output logic [1:0]  chan_sel_p1,
//     output logic [1:0]  chan_sel_p2
// );
//     // 5 bits per threshold, 2 bits per channel select
//     logic [4:0] thresh_p1_raw;
//     logic [4:0] thresh_p2_raw;

//     // thresholds:
//     assign thresh_p1_raw = sw[4:0];   // SW0–SW4  → player 1 threshold
//     assign thresh_p2_raw = sw[9:5];   // SW5–SW9  → player 2 threshold

//     // scale 5-bit → 8-bit (×8)
//     assign thresh_p1 = {thresh_p1_raw, 3'b000};  // thresh_p1 = raw * 8
//     assign thresh_p2 = {thresh_p2_raw, 3'b000};

//     // channel: 0 → Y, 1 → Cr
//     assign chan_sel_p1 = sw[10] ? 2'b10 : 2'b01;  // player 1: SW10
//     assign chan_sel_p2 = sw[11] ? 2'b10 : 2'b01;  // player 2: SW11

//     // SW12–SW15 are now free
// endmodule
