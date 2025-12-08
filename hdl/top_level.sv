`timescale 1ns / 1ps
`default_nettype none

module top_level
    (
        input wire          clk_100mhz,
        output logic [15:0] led,
        // camera bus
        input wire [7:0]    camera_d, // 8 parallel data wires
        output logic        cam_xclk, // XC driving camera
        input wire          cam_h_sync, // camera h_sync wire
        input wire          cam_v_sync, // camera v_sync wire
        input wire          cam_pclk, // camera pixel clock
        inout wire          i2c_scl, // i2c inout clock
        inout wire          i2c_sda, // i2c inout data
        input wire [15:0]   sw,
        input wire [3:0]    btn,
        output logic [2:0]  rgb0,
        output logic [2:0]  rgb1,
        // seven segment
        output logic [3:0]  ss0_an,//anode control for upper four digits of seven-seg display
        output logic [3:0]  ss1_an,//anode control for lower four digits of seven-seg display
        output logic [6:0]  ss0_c, //cathode controls for the segments of upper four digits
        output logic [6:0]  ss1_c, //cathod controls for the segments of lower four digits
        // hdmi port
        output logic [2:0]  hdmi_tx_p, //hdmi output signals (positives) (blue, green, red)
        output logic [2:0]  hdmi_tx_n, //hdmi output signals (negatives) (blue, green, red)
        output logic        hdmi_clk_p, hdmi_clk_n //differential hdmi clock
    );
    // shut up those RGBs
    assign rgb1 = 0;

    // Clock and Reset Signals
    logic          sys_rst_camera;
    logic          sys_rst_pixel;

    logic          clk_camera;
    logic          clk_pixel;
    logic          clk_5x;
    logic          clk_xc;

    logic clk_camera_locked;

    logic          clk_100_passthrough;

    // clocking wizards to generate the clock speeds we need for our different domains
    // clk_camera: 200MHz, fast enough to comfortably sample the cameera's PCLK (50MHz)
    cw_hdmi_clk_wiz wizard_hdmi(
        .sysclk(clk_100_passthrough),
        .clk_pixel(clk_pixel),
        .clk_tmds(clk_5x),
        .reset(0)
    );

    cw_fast_clk_wiz wizard_migcam(
        .clk_in1(clk_100mhz),
        .clk_camera(clk_camera),
        .locked(clk_camera_locked),
        .clk_xc(clk_xc),
        .clk_100(clk_100_passthrough),
        .reset(0)
    );

    // assign camera's xclk to pmod port: drive the operating clock of the camera!
    // this port also is specifically set to high drive by the XDC file.
    assign cam_xclk = clk_xc;
    //assign sys_rst_camera = btn[0]; //use for resetting camera side of logic
    //assign sys_rst_pixel = btn[0]; //use for resetting hdmi/draw side of logic


    // video signal generator signals
    logic           h_sync_hdmi;
    logic           v_sync_hdmi;
    logic [10:0]    h_count_hdmi;
    logic [9:0]     v_count_hdmi;
    logic           active_draw_hdmi;
    logic           new_frame_hdmi;
    logic [5:0]     frame_count_hdmi;

    // rgb output values
    logic [7:0]     red,green,blue;

    // ** Handling input from the camera **

    // synchronizers to prevent metastability
    logic [7:0]     camera_d_buf [1:0];
    logic           cam_h_sync_buf [1:0];
    logic           cam_v_sync_buf [1:0];
    logic           cam_pclk_buf [1:0];

    logic           sys_rst_camera_buf [1:0];
    logic           sys_rst_pixel_buf  [1:0];

    always_ff @(posedge clk_pixel )begin
        sys_rst_pixel_buf <= {btn[0], sys_rst_pixel_buf[0]};
    end
    assign sys_rst_pixel = sys_rst_pixel_buf[1];

    always_ff @(posedge clk_camera) begin
        camera_d_buf       <= {camera_d, camera_d_buf[0]};
        cam_pclk_buf       <= {cam_pclk, cam_pclk_buf[0]};
        cam_h_sync_buf     <= {cam_h_sync, cam_h_sync_buf[0]};
        cam_v_sync_buf     <= {cam_v_sync, cam_v_sync_buf[0]};
        sys_rst_camera_buf <= {btn[0], sys_rst_camera_buf[0]};
    end

    assign sys_rst_camera = sys_rst_camera_buf[1] || !clk_camera_locked;

    logic [10:0]    camera_h_count;
    logic [9:0]     camera_v_count;
    logic [15:0]    camera_pixel;
    logic           camera_valid;

    // your pixel_reconstruct module, from the exercise!
    // hook it up to buffered inputs.
    pixel_reconstruct pixel_rec (
        .clk(clk_camera),
        .rst(sys_rst_camera),
        .camera_pclk(cam_pclk_buf[1]),
        .camera_h_sync(cam_h_sync_buf[1]),
        .camera_v_sync(cam_v_sync_buf[1]),
        .camera_data(camera_d_buf[1]),
        .pixel_valid(camera_valid),
        .pixel_h_count(camera_h_count),
        .pixel_v_count(camera_v_count),
        .pixel_data(camera_pixel)
    );


    //----------------BEGIN NEW STUFF FOR LAB 07------------------
    //clock domain cross (from clk_camera to clk_pixel)
    //switching from camera clock domain to pixel clock domain early
    //this lets us do convolution on the 74.25 MHz clock rather than the
    //200 MHz clock domain that the camera lives on.
    logic empty;
    logic cdc_valid;
    logic [15:0] cdc_pixel;
    logic [10:0] cdc_h_count;
    logic [9:0]  cdc_v_count;


    xpm_fifo_async #(
       .CASCADE_HEIGHT(0),            // DECIMAL
       .CDC_SYNC_STAGES(2),           // DECIMAL
       .DOUT_RESET_VALUE("0"),        // String
       .ECC_MODE("no_ecc"),           // String
       .EN_SIM_ASSERT_ERR("warning"), // String
       .FIFO_MEMORY_TYPE("auto"),     // String
       .FIFO_READ_LATENCY(1),         // DECIMAL
       .FIFO_WRITE_DEPTH(64),         // DECIMAL
       .FULL_RESET_VALUE(0),          // DECIMAL
       .PROG_EMPTY_THRESH(10),        // DECIMAL
       .PROG_FULL_THRESH(10),         // DECIMAL
       .RD_DATA_COUNT_WIDTH(1),       // DECIMAL
       .READ_DATA_WIDTH(37),          // DECIMAL
       .READ_MODE("std"),             // String
       .RELATED_CLOCKS(0),            // DECIMAL
       .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
       .USE_ADV_FEATURES("0707"),     // String
       .WAKEUP_TIME(0),               // DECIMAL
       .WRITE_DATA_WIDTH(37),         // DECIMAL
       .WR_DATA_COUNT_WIDTH(1)        // DECIMAL
    )
    cdc_fifo (
        .wr_clk(clk_camera),
        .full(),
        .din({camera_h_count, camera_v_count, camera_pixel}),
        .wr_en(camera_valid),

        .rd_clk(clk_pixel),
        .empty(empty),
        .dout({cdc_h_count, cdc_v_count, cdc_pixel}),
        .rd_en(1) //always read
    );

    assign cdc_valid = ~empty; //watch when empty. Ready immediately if something there


    logic [10:0] lb_h_count;  //h_count to filter modules
    logic [9:0]  lb_v_count;  //v_count to filter modules
    logic [15:0] lb_pixel;    //pixel data to filter modules
    logic        lb_valid;    //valid signals to filter modules

    //downsample inputs
    logic [10:0] ds_h_count;  //h_count to downsample line buffer
    logic [9:0]  ds_v_count;  //v_count to downsample line buffer
    logic [15:0] ds_pixel;    //pixel data to downsample line buffer
    logic        ds_valid;    //valid signals to downsample line buffer

    // One-shot enable for camera streaming, triggered by btn[2]
    logic [1:0] btn2_pix_sync;
    logic       cam_stream_en;

    // Sync btn[2] into pixel clock domain
    always_ff @(posedge clk_pixel) begin
        if (sys_rst_pixel) begin
            btn2_pix_sync <= 2'b00;
        end else begin
            btn2_pix_sync <= {btn[2], btn2_pix_sync[1]};
        end
    end

    // Rising edge detect (in pixel domain)
    wire btn2_pix_rise = btn2_pix_sync[1] & ~btn2_pix_sync[0];

    // Latch camera streaming enable when btn[2] is pressed
    always_ff @(posedge clk_pixel) begin
        if (sys_rst_pixel) begin
            cam_stream_en <= 1'b0;
        end else if (btn2_pix_rise) begin
            cam_stream_en <= 1'b1;
        end
    end

    //selection logic:
    // once cam_stream_en is set by pressing btn[2], we
    // continuously pass camera pixels into the downsample line buffer.
    // (you no longer need to hold btn[1]; btn[1] is just an extra override)
    always_ff @(posedge clk_pixel) begin
        if (sys_rst_pixel) begin
            ds_h_count <= '0;
            ds_v_count <= '0;
            ds_pixel   <= 16'd0;
            ds_valid   <= 1'b0;
        end else if (cam_stream_en || btn[1]) begin
            ds_h_count <= cdc_h_count;
            ds_v_count <= cdc_v_count;
            ds_pixel   <= cdc_pixel;
            ds_valid   <= cdc_valid;
        end else begin
            ds_valid   <= 1'b0;
        end
    end

    //----
    //A line buffer that, in conjunction with the control signal will down sample
    //the camera (or f0 filter) values from 1280x720 to 320x180
    //in reality we could get by without this, but it does make things a little easier
    //and we've also added it since it gives us a means of testing the line buffer
    //design outside of the filter.
    logic [2:0][15:0] lb_buffs;   //grab output of down sample line buffer
    logic             ds_control; //controlling when to write (every fourth pixel and line)
    assign ds_control = ds_valid&&(ds_h_count[1:0]==2'b0)&&(ds_v_count[1:0]==2'b0);

    line_buffer #(.HRES(320), .VRES(180)) ds_lbuff (
        .clk(clk_pixel),
        .rst(sys_rst_pixel),
        .data_in_valid(ds_control),
        .pixel_data_in(ds_pixel),
        .h_count_in(ds_h_count[10:2]),
        .v_count_in(ds_v_count[9:2]),
        .data_out_valid(lb_valid),
        .line_buffer_out(lb_buffs),
        .h_count_out(lb_h_count),
        .v_count_out(lb_v_count)
    );

    assign lb_pixel = lb_buffs[1]; //pass on only the middle one.

    

    localparam FB_DEPTH = 320*180;
    localparam FB_SIZE  = $clog2(FB_DEPTH);
    logic [FB_SIZE-1:0] addra;            //used to specify address to write to in frame buffer
    logic               valid_camera_mem; //used to enable writing pixel data to frame buffer
    logic [15:0]        camera_mem;       //used to pass pixel data into frame buffer

    // Write downsampled camera pixels into frame buffer
    always_ff @(posedge clk_pixel) begin
        if (sys_rst_pixel) begin
            addra            <= '0;
            camera_mem       <= 16'd0;
            valid_camera_mem <= 1'b0;
        end else begin
            if (lb_valid) begin
                // 320x180 addressing: addr = x + 320*y
                addra            <= lb_h_count + (320 * lb_v_count);
                camera_mem       <= lb_pixel;
                valid_camera_mem <= 1'b1;
            end else begin
                valid_camera_mem <= 1'b0;
            end
        end
    end

    //two-port BRAM used to hold image from camera.
    //The camera is producing video at 720p and 30fps, but we can't store all of that
    //we're going to down-sample by a factor of 4 in both dimensions
    //so we have 320 by 180.  this is kinda a bummer, but we'll fix it
    //in future weeks by using off-chip DRAM.
    //even with the down-sample, because our camera is producing data at 30fps
    //and  our display is running at 720p at 60 fps, there's no hope to have the
    //production and consumption of inew_frameormation be synchronized in this system.
    //even if we could line it up once, the clocks of both systems will drift over time
    //so to avoid this sync issue, we use a conew_framelict-resolution device...the frame buffer
    //instead we use a frame buffer as a go-between. The camera sends pixels in at
    //its own rate, and we pull them out for display at the 720p rate/requirement
    //this avoids the whole sync issue. It will however result in artifacts when you
    //introduce fast motion in front of the camera. These lines/tears in the image
    //are the result of unsynced frame-rewriting happening while displaying. It won't
    //matter for slow movement

    logic [15:0]        frame_buff_raw; //data out of frame buffer (565)
    logic [FB_SIZE-1:0] addrb;          //used to lookup address in memory for reading from buffer
    logic               good_addrb;     //used to indicate within valid frame for scaling

    xilinx_true_dual_port_read_first_2_clock_ram #(
        .RAM_WIDTH(16), //each entry in this memory is 16 bits
        .RAM_DEPTH(FB_DEPTH)) //there are 320*180 or 57600 entries for full frame
    frame_buffer (
        .addra(addra),       //pixels are stored using this math
        .clka(clk_pixel),    //was previous clk_camera!!! but clock-domain crossing happens earlier now!
        .wea(valid_camera_mem),
        .dina(camera_mem),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(sys_rst_camera),
        .douta(), //never read from this side
        .addrb(addrb),//transformed lookup pixel
        .dinb(16'b0),
        .clkb(clk_pixel),
        .web(1'b0),
        .enb(1'b1),
        .rstb(sys_rst_pixel),
        .regceb(1'b1),
        .doutb(frame_buff_raw)
    );

    //TO DO in camera part 1:
    // Scale pixel coordinates from HDMI to the frame buffer to grab the right pixel
    //scaling logic!!! You need to complete!!! We want 1X, 2X, and 4X!
    always_ff @(posedge clk_pixel)begin
        addrb      <= ((h_count_hdmi >> 2)) + 320*(v_count_hdmi >> 2);
        good_addrb <= (h_count_hdmi<1280)&&(v_count_hdmi<720);
    end

    //split fame_buff into 3 8 bit color channels (5:6:5 adjusted accordingly)
    //remapped frame_buffer outputs with 8 bits for r, g, b
    logic [7:0] fb_red, fb_green, fb_blue;
    always_ff @(posedge clk_pixel)begin
        fb_red   <= good_addrb ? {frame_buff_raw[15:11],3'b0} : 8'b0;
        fb_green <= good_addrb ? {frame_buff_raw[10:5], 2'b0} : 8'b0;
        fb_blue  <= good_addrb ? {frame_buff_raw[4:0],3'b0}  : 8'b0;
    end
    // Pixel Processing pre-HDMI output

    // RGB to YCrCb

    //output of rgb to ycrcb conversion (10 bits due to module):
    logic [9:0] y_full, cr_full, cb_full; //ycrcb conversion of full pixel
    //bottom 8 of y, cr, cb conversions:
    logic [7:0] y, cr, cb; //ycrcb conversion of full pixel
    //Convert RGB of full pixel to YCrCb
    //See lecture 07 for YCrCb discussion.
    //Module has a 3 cycle latency
    rgb_to_ycrcb rgbtoycrcb_m(
        .clk(clk_pixel),
        .r(fb_red),
        .g(fb_green),
        .b(fb_blue),
        .y(y_full),
        .cr(cr_full),
        .cb(cb_full)
    );

    //take lower 8 of full outputs.
    // treat cr and cb as signed numbers, invert the MSB to get an unsigned equivalent ( [-128,128) maps to [0,256) )
    assign y  = y_full[7:0];
    assign cr = {!cr_full[7],cr_full[6:0]};
    assign cb = {!cb_full[7],cb_full[6:0]};


    logic [10:0] h_d1, h_d2, h_d3, h_d4;
    logic [9:0]  v_d1, v_d2, v_d3, v_d4;
    logic        active_d1, active_d2, active_d3, active_d4;

    // pipelined: delay h/v/active to line up with YCrCb + threshold latency
    always_ff @(posedge clk_pixel) begin
        if (sys_rst_pixel) begin
            h_d1 <= 0; h_d2 <= 0; h_d3 <= 0; h_d4 <= 0;
            v_d1 <= 0; v_d2 <= 0; v_d3 <= 0; v_d4 <= 0;
            active_d1 <= 1'b0;
            active_d2 <= 1'b0;
            active_d3 <= 1'b0;
            active_d4 <= 1'b0;
        end else begin
            // stage 1: raw HDMI counts
            h_d1      <= h_count_hdmi;
            v_d1      <= v_count_hdmi;
            active_d1 <= active_draw_hdmi;

            // stage 2
            h_d2      <= h_d1;
            v_d2      <= v_d1;
            active_d2 <= active_d1;

            // stage 3
            h_d3      <= h_d2;
            v_d3      <= v_d2;
            active_d3 <= active_d2;

            // stage 4: aligned with YCrCb + threshold
            h_d4      <= h_d3;
            v_d4      <= v_d3;
            active_d4 <= active_d3;
        end
    end


    logic [2:0] channel_sel;
    // Red player (chroma red): Cr in [160, 240]
    // can change based on light
    localparam logic [7:0] RED_CR_MIN = 8'd160;
    localparam logic [7:0] RED_CR_MAX = 8'd240;
    localparam logic [7:0] THRESH1    = RED_CR_MIN; // left: show red's Cr lower
    localparam logic [1:0] CHAN1      = 2'b01;      // Cr

    // Yellow player: Cb in [0, 80]
    localparam logic [7:0] YEL_CB_MIN = 8'd00;
    localparam logic [7:0] YEL_CB_MAX = 8'd80;
    localparam logic [7:0] THRESH2    = YEL_CB_MAX; // right: show yellow's Cb upper
    localparam logic [1:0] CHAN2      = 2'b10;      // Cb

    logic [7:0]  thresh_active;
    logic [1:0]  chan_sel_active;
    logic        half_sel;
    logic [2:0]  channel_sel_active_3b;
    logic [7:0]  selected_channel; 


    screen_half #(.H_RES(1280)) half_det (
        .x        (h_d4),
        .half_sel (half_sel)
    );

    half_mux mux_inst (
        .half_sel       (half_sel),
        .thresh_p1      (THRESH1),
        .thresh_p2      (THRESH2),
        .chan_sel_p1    (CHAN1),
        .chan_sel_p2    (CHAN2),
        .thresh_active  (thresh_active),
        .chan_sel_active(chan_sel_active)
    );


    //threshold module (apply masking threshold):
    logic [7:0] lower_threshold;
    logic [7:0] upper_threshold;

    // Per-player masks
    logic mask_red_raw;
    logic mask_yel_raw; 
    logic mask_p1;   
    logic mask_p2;

    // Center of Mass variables (two players)
    logic [10:0] x_com1, x_com1_calc;
    logic [9:0]  y_com1, y_com1_calc;
    logic        new_com1;

    logic [10:0] x_com2, x_com2_calc;
    logic [9:0]  y_com2, y_com2_calc;
    logic        new_com2;


    // Map 2-bit channel selection to the 3-bit channel_select encoding:
    // * 2'b00 → y  (3'b100)
    // * 2'b01 → Cr (3'b101)
    // * 2'b10 → Cb (3'b110)
    // * 2'b11 → red fallback (3'b001)
    always_comb begin
        case (chan_sel_active)
            2'b00: channel_sel_active_3b = 3'b100; // y (luminance)
            2'b01: channel_sel_active_3b = 3'b101; // Cr (chroma red)
            2'b10: channel_sel_active_3b = 3'b110; // Cb (chroma blue)
            default: channel_sel_active_3b = 3'b001; // red (fallback)
        endcase
    end

    //assign channel_sel = {1'b1, sw[4:3]}; //[3:1];
    assign channel_sel = channel_sel_active_3b;

    //threshold values used to determine what value  passes:
    // assign lower_threshold = {sw[11:8],4'b0};
    // assign upper_threshold = {sw[15:12],4'b0};
    assign lower_threshold = thresh_active;
    assign upper_threshold = 8'hFF;

    threshold red_thresh (
        .clk         (clk_pixel),
        .rst         (sys_rst_pixel),
        .pixel       (cr),
        .lower_bound (RED_CR_MIN),
        .upper_bound (RED_CR_MAX),
        .mask        (mask_red_raw)
    );

    // Yellow player = Cb in [0, 80]
    threshold yel_thresh (
        .clk         (clk_pixel),
        .rst         (sys_rst_pixel),
        .pixel       (cb),
        .lower_bound (YEL_CB_MIN),
        .upper_bound (YEL_CB_MAX),
        .mask        (mask_yel_raw)
    );


    assign mask_p1 = mask_red_raw 
                    && active_d4
                    && (h_d4 < 11'd640);

    assign mask_p2 = mask_yel_raw 
                    && active_d4 
                    && (h_d4 >= 11'd640);

    logic [6:0] ss_c;

    score_ssc #(.COUNT_TO(100000)) score_disp (
        .clk     (clk_pixel),
        .rst     (sys_rst_pixel),
        .state   (game_state),  // from game_fsm
        .p1_lives(p1_lives),
        .p2_lives(p2_lives),
        .cathode (ss_c),
        .anode   ({ss0_an, ss1_an})
    );


    assign ss0_c = ss_c; //control upper four digit's cathodes!
    assign ss1_c = ss_c; //same as above but for lower four digits!

    //Center of Mass Calculation: (you need to do)
    //using x_com_calc and y_com_calc values
    //Center of Mass:


    // Center of Mass: Player 1 (red / Cr)
    center_of_mass com_p1 (
        .clk         (clk_pixel),
        .rst         (sys_rst_pixel),
        .pixel_x     (h_d4),
        .pixel_y     (v_d4),
        .pixel_valid (mask_p1),
        .calculate   (new_frame_hdmi),
        .com_x       (x_com1_calc),
        .com_y       (y_com1_calc),
        .com_valid   (new_com1)
    );

    center_of_mass com_p2 (
        .clk         (clk_pixel),
        .rst         (sys_rst_pixel),
        .pixel_x     (h_d4),
        .pixel_y     (v_d4),
        .pixel_valid (mask_p2),
        .calculate   (new_frame_hdmi),
        .com_x       (x_com2_calc),
        .com_y       (y_com2_calc),
        .com_valid   (new_com2)
    );


    // Latch COM values once per frame
    always_ff @(posedge clk_pixel) begin
        if (sys_rst_pixel) begin
            x_com1 <= 0;
            y_com1 <= 0;
            x_com2 <= 0;
            y_com2 <= 0;
        end else begin
            if (new_com1) begin
                x_com1 <= x_com1_calc;
                y_com1 <= y_com1_calc;
            end
            if (new_com2) begin
                x_com2 <= x_com2_calc;
                y_com2 <= y_com2_calc;
            end
        end
    end

    //image_sprite output:
    logic [7:0] img_red, img_green, img_blue;

    //bring in an instance of your popcat image sprite! remember the correct mem files too!

    logic [31:0] pop_counter;
    logic        pop;

    always_ff @(posedge clk_pixel)begin
        if (pop_counter==30_000_000)begin
            pop_counter <= 0;
            pop         <= ~pop;
        end else begin
            pop_counter <= pop_counter + 1 ;
        end
    end
    //bring in an instance of your popcat image sprite! remember the correct mem files too!
    image_sprite #(
        .WIDTH(256),
        .HEIGHT(256))
    com_sprite_m (
        .pixel_clk (clk_pixel),
        .rst       (sys_rst_pixel),
        .pop       (pop),
        .h_count   (h_count_hdmi),   
        .v_count   (v_count_hdmi),   
        // .x(x_com>128 ? x_com-128 : 0),
        // .y(y_com>128 ? y_com-128 : 0),
        .x         (x_com1>128 ? x_com1-128 : 0),
        .y         (y_com1>128 ? y_com1-128 : 0),
        .pixel_red (img_red),
        .pixel_green(img_green),
        .pixel_blue(img_blue)); //output colors

    //crosshair output:
    logic [7:0] ch_red, ch_green, ch_blue;

    //Create Crosshair patter on center of mass:
    //0 cycle latency
    // always_comb begin
    //     ch_red   = ((v_count_hdmi==y_com) || (h_count_hdmi==x_com))?8'hFF:8'h00;
    //     ch_green = ((v_count_hdmi==y_com) || (h_count_hdmi==x_com))?8'hFF:8'h00;
    //     ch_blue  = ((v_count_hdmi==y_com) || (h_count_hdmi==x_com))?8'hFF:8'h00;
    // end

    always_comb begin
        ch_red   = ((v_count_hdmi==y_com1) || (h_count_hdmi==x_com1))?8'hFF:8'h00;
        ch_green = ch_red;
        ch_blue  = ch_red;
    end


    // HDMI video signal generator
    video_sig_gen vsg(
        .pixel_clk   (clk_pixel),
        .rst         (sys_rst_pixel),
        .h_count     (h_count_hdmi),
        .v_count     (v_count_hdmi),
        .v_sync      (v_sync_hdmi),
        .h_sync      (h_sync_hdmi),
        .new_frame   (new_frame_hdmi),
        .active_draw (active_draw_hdmi),
        .frame_count (frame_count_hdmi)
    );


    localparam int GRID_W = 40;
    localparam int GRID_H = 40;
    localparam int HALF_W = 640;
    localparam int CELL_W = HALF_W / GRID_W; // 640/40
    localparam int CELL_H = 720 / GRID_H;    // 720/40

    logic [7:0] base_red, base_green, base_blue;

    always_ff @(posedge clk_pixel) begin
        base_red   <= fb_red;
        base_green <= fb_green;
        base_blue  <= fb_blue;
    end
    // Logical grid coords for each half
    logic [$clog2(GRID_W)-1:0] cell_x_left,  cell_x_right;
    logic [$clog2(GRID_H)-1:0] cell_y_left,  cell_y_right;
    logic                      region_left,  region_right;
    logic [10:0]               x_rel;


    always_comb begin
        cell_x_left  = '0;
        cell_y_left  = '0;
        cell_x_right = '0;
        cell_y_right = '0;
        region_left  = 1'b0;
        region_right = 1'b0;
        x_rel        = 11'd0;

        if (active_draw_hdmi && (v_count_hdmi < 720)) begin
            // Left half: 0 .. 639
            if (h_count_hdmi < HALF_W) begin
                region_left  = 1'b1;
                cell_x_left  = h_count_hdmi / CELL_W;
                cell_y_left  = v_count_hdmi / CELL_H;
            end
            // Right half: 640 .. 1279
            else if (h_count_hdmi < 2*HALF_W) begin
                region_right = 1'b1;
                x_rel        = h_count_hdmi - HALF_W; // 0..639
                cell_x_right = x_rel / CELL_W;
                cell_y_right = v_count_hdmi / CELL_H;
            end
        end
    end

    // Path bits for each half-screen
    logic cell_on_left, cell_on_right;
    logic [GRID_W*GRID_H-1:0] path_grid_left;
    logic [GRID_W*GRID_H-1:0] path_grid_right;

    // Left player auto path (40x40 static pattern from BRAM, shrinks after 30s)
    autopath_gen #(
        .GRID_W(GRID_W),
        .GRID_H(GRID_H),
        .FPS(60),
        .INIT_FILE("data/autopath_init.mem")
    ) path_left (
        .clk          (clk_pixel),
        .rst          (sys_rst_pixel),
        .new_frame    (new_frame_hdmi),
        .cell_x       (cell_x_left),
        .cell_y       (cell_y_left),
        .shift_left_req (1'b0),  // hook to buttons later if desired
        .shift_right_req(1'b0),
        .cell_on      (cell_on_left),
        .path_grid_out(path_grid_left) 
    );

    // Right player auto path (can use same or different init file)
    autopath_gen #(
        .GRID_W(GRID_W),
        .GRID_H(GRID_H),
        .FPS(60),
        .INIT_FILE("data/autopath_init.mem")
    ) path_right (
        .clk          (clk_pixel),
        .rst          (sys_rst_pixel),
        .new_frame    (new_frame_hdmi),
        .cell_x       (cell_x_right),
        .cell_y       (cell_y_right),
        .shift_left_req (1'b0),
        .shift_right_req(1'b0),
        .cell_on      (cell_on_right),
        .path_grid_out(path_grid_right) 
    );

    logic [10:0] p1_x_local, p2_x_local;
    assign p1_x_local = x_com1;
    assign p2_x_local = (x_com2 > HALF_W) ? (x_com2 - HALF_W) : 11'd0;


    localparam int PLAYER_RADIUS    = 24;
    localparam int PLAYER_RADIUS_SQ = PLAYER_RADIUS * PLAYER_RADIUS; // 576

    logic signed [11:0] dx1, dy1, dx2, dy2;
    logic [23:0]        dx1_sq, dy1_sq, dx2_sq, dy2_sq;
    logic [24:0]        dist2_1, dist2_2;
    logic               player1_pix, player2_pix;

    always_comb begin
        // Player 1 (red)
        dx1 = $signed({1'b0, h_count_hdmi}) - $signed({1'b0, x_com1});
        dy1 = $signed({1'b0, v_count_hdmi}) - $signed({1'b0, y_com1});
        dx1_sq = dx1 * dx1;
        dy1_sq = dy1 * dy1;
        dist2_1 = dx1_sq + dy1_sq;

        // Player 2 (yellow)
        dx2 = $signed({1'b0, h_count_hdmi}) - $signed({1'b0, x_com2});
        dy2 = $signed({1'b0, v_count_hdmi}) - $signed({1'b0, y_com2});
        dx2_sq = dx2 * dx2;
        dy2_sq = dy2 * dy2;
        dist2_2 = dx2_sq + dy2_sq;

        // True circle: dx^2 + dy^2 <= R^2
        player1_pix = active_draw_hdmi && (dist2_1 <= PLAYER_RADIUS_SQ);
        player2_pix = active_draw_hdmi && (dist2_2 <= PLAYER_RADIUS_SQ);
    end



    // Final overlay: draw path cells on top of base video.
    // Left half path = red, right half path = blue (just for visualization).
    wire path_pix_left  = cell_on_left  && region_left  && active_draw_hdmi;
    wire path_pix_right = cell_on_right && region_right && active_draw_hdmi;

    always_comb begin
        // Default: camera image
        red   = base_red;
        green = base_green;
        blue  = base_blue;

        if (active_draw_hdmi) begin
            // PATH background
            if (path_pix_left) begin
                red   = 8'hC0;
                green = 8'h10;
                blue  = 8'h10;
            end else if (path_pix_right) begin
                red   = 8'h10;
                green = 8'h10;
                blue  = 8'hC0;
            end

            // CIRCLES on top
            if (player1_pix) begin
                red   = 8'hFF;
                green = 8'hFF;
                blue  = 8'hFF;
            end else if (player2_pix) begin
                red   = 8'hFF;
                green = 8'hFF;
                blue  = 8'h00;
            end
        end
    end




////////////////////////////////////////
    // HDMI Output: just like before!

    logic [9:0] tmds_10b [0:2]; //output of each TMDS encoder!
    logic       tmds_signal [2:0]; //output of each TMDS serializer!

    //three tmds_encoders (blue, green, red)
    //note green should have no control signal like red
    //the blue channel DOES carry the two sync signals:
    //  * control[0] = horizontal sync signal
    //  * control[1] = vertical sync signal

    tmds_encoder tmds_red(
        .clk         (clk_pixel),
        .rst         (sys_rst_pixel),
        .video_data  (red),
        .control     (2'b0),
        .video_enable(active_draw_hdmi),
        .tmds        (tmds_10b[2])
    );
    tmds_encoder tmds_green(
        .clk         (clk_pixel),
        .rst         (sys_rst_pixel),
        .video_data  (green),
        .control     (2'b0),
        .video_enable(active_draw_hdmi),
        .tmds        (tmds_10b[1])
    );
    tmds_encoder tmds_blue(
        .clk         (clk_pixel),
        .rst         (sys_rst_pixel),
        .video_data  (blue),
        .control     ({v_sync_hdmi,h_sync_hdmi}),
        .video_enable(active_draw_hdmi),
        .tmds        (tmds_10b[0])
    );


    //three tmds_serializers (blue, green, red):
    tmds_serializer red_ser(
        .clk_pixel (clk_pixel),
        .clk_5x    (clk_5x),
        .rst       (sys_rst_pixel),
        .tmds_in   (tmds_10b[2]),
        .tmds_out  (tmds_signal[2])
    );
    tmds_serializer green_ser(
        .clk_pixel (clk_pixel),
        .clk_5x    (clk_5x),
        .rst       (sys_rst_pixel),
        .tmds_in   (tmds_10b[1]),
        .tmds_out  (tmds_signal[1])
    );
    tmds_serializer blue_ser(
        .clk_pixel (clk_pixel),
        .clk_5x    (clk_5x),
        .rst       (sys_rst_pixel),
        .tmds_in   (tmds_10b[0]),
        .tmds_out  (tmds_signal[0])
    );

    //output buffers generating differential signals:
    //three for the r,g,b signals and one that is at the pixel clock rate
    //the HDMI receivers use recover logic coupled with the control signals asserted
    //during blanking and sync periods to synchronize their faster bit clocks off
    //of the slower pixel clock (so they can recover a clock of about 742.5 MHz from
    //the slower 74.25 MHz clock)
    OBUFDS OBUFDS_blue (.I(tmds_signal[0]), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
    OBUFDS OBUFDS_green(.I(tmds_signal[1]), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
    OBUFDS OBUFDS_red  (.I(tmds_signal[2]), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
    OBUFDS OBUFDS_clock(.I(clk_pixel),      .O(hdmi_clk_p),   .OB(hdmi_clk_n));

    // Nothing To Touch Down Here:
    // register writes to the camera

    // The OV5640 has an I2C bus connected to the board, which is used
    // for setting all the hardware settings (gain, white balance,
    // compression, image quality, etc) needed to start the camera up.
    // We've taken care of setting these all these values for you:
    // "rom.mem" holds a sequence of bytes to be sent over I2C to get
    // the camera up and running, and we've written a design that sends
    // them just after a reset completes.

    // If the camera is not giving data, press your reset button.

    logic  busy, bus_active;
    logic  cr_init_valid, cr_init_ready;

    logic  request_config;

    localparam DELAY_CLOCK_CYCLES = 200_000_000 * 1;
    logic [$clog2(DELAY_CLOCK_CYCLES):0] count_delay;

    always_ff @(posedge clk_camera) begin
        if (sys_rst_camera) begin
            request_config <= 1'b0;
            cr_init_valid  <= 1'b0;
            count_delay    <= 'b0;
        end else if (btn[2]) begin
            request_config <= 1'b1;
            cr_init_valid  <= 1'b0;
            count_delay    <= 'b0;
        end else if (request_config) begin
            if (count_delay >= DELAY_CLOCK_CYCLES) begin
                cr_init_valid  <= 1'b1;
                request_config <= 1'b0;
                count_delay    <= 'b0;
            end else begin
                count_delay    <= count_delay + 1;
            end
        end else if (cr_init_valid && cr_init_ready) begin
            cr_init_valid <= 1'b0;
            count_delay   <= 'b0;
        end
    end

    logic [23:0] bram_dout;
    logic [7:0]  bram_addr;

    // ROM holding pre-built camera settings to send
    xilinx_single_port_ram_read_first
    #(
        .RAM_WIDTH(24),
        .RAM_DEPTH(256),
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
        .INIT_FILE("rom.mem")
    ) registers
    (
        .addra (bram_addr),     // Address bus, width determined from RAM_DEPTH
        .dina  (24'b0),         // RAM input data, width determined from RAM_WIDTH
        .clka  (clk_camera),    // Clock
        .wea   (1'b0),          // Write enable
        .ena   (1'b1),          // RAM Enable, for additional power savings, disable port when not in use
        .rsta  (sys_rst_camera),// Output reset (does not affect memory contents)
        .regcea(1'b1),          // Output register enable
        .douta (bram_dout)      // RAM output data, width determined from RAM_WIDTH
    );

    logic [23:0] registers_dout;
    logic [7:0]  registers_addr;
    assign registers_dout = bram_dout;
    assign bram_addr      = registers_addr;

    logic       con_scl_i, con_scl_o, con_scl_t;
    logic       con_sda_i, con_sda_o, con_sda_t;

    // NOTE these also have pullup specified in the xdc file!
    // access our inouts properly as tri-state pins
    IOBUF IOBUF_scl (.I(con_scl_o), .IO(i2c_scl), .O(con_scl_i), .T(con_scl_t) );
    IOBUF IOBUF_sda (.I(con_sda_o), .IO(i2c_sda), .O(con_sda_i), .T(con_sda_t) );

    // provided module to send data BRAM -> I2C
    camera_registers crw
    (   .clk_in    (clk_camera),
        .rst_in    (sys_rst_camera),
        .init_valid(cr_init_valid),
        .init_ready(cr_init_ready),
        .scl_i     (con_scl_i),
        .scl_o     (con_scl_o),
        .scl_t     (con_scl_t),
        .sda_i     (con_sda_i),
        .sda_o     (con_sda_o),
        .sda_t     (con_sda_t),
        .bram_dout (registers_dout),
        .bram_addr (registers_addr)
    );
    // a handful of debug signals for writing to registers

    assign rgb0[0] = crw.bus_active;
    assign rgb0[2] = ~clk_camera_locked;
    assign rgb0[1] = 0;

    assign led[0]  = cam_h_sync_buf[1];
    assign led[1]  = cam_v_sync_buf[1];
    assign led[2]  = cam_pclk_buf[1];
    assign led[3]  = cr_init_valid;
    assign led[4]  = cr_init_ready;
    assign led[15:5] = 0;

       //*********************************************************
    //PATH CHECKER

    // TODO give path grid values 
    // TODO also center of mass values XCOM YCOM 1 & 2
    //*********************************************************
    // PATH CHECKER

    logic p1_life_lost_raw, p2_life_lost_raw;
    logic p1_life_lost, p2_life_lost;

    // Only count hits while in PLAY state
    logic [2:0] game_state;
    assign p1_life_lost = (game_state == 3'd2) ? p1_life_lost_raw : 1'b0;
    assign p2_life_lost = (game_state == 3'd2) ? p2_life_lost_raw : 1'b0;

    path_checker #(
        .GRID_W(GRID_W),
        .GRID_H(GRID_H),
        .CELL_W(CELL_W),
        .CELL_H(CELL_H),
        .RADIUS(PLAYER_RADIUS)
    ) checker_inst (
        .clk         (clk_pixel),
        .rst         (sys_rst_pixel),
        .new_frame   (new_frame_hdmi),

        .p1_x        (p1_x_local),
        .p1_y        (y_com1),

        .p2_x        (p2_x_local),
        .p2_y        (y_com2),

        .path_grid_p1(path_grid_left), 
        .path_grid_p2(path_grid_right), 

        .p1_life_lost(p1_life_lost_raw),
        .p2_life_lost(p2_life_lost_raw)
    );


    //*********************************************************
    //GAME FSM 

    logic [1:0] p1_lives, p2_lives;
    logic       blink_p1, blink_p2;
    logic [1:0] winner;

    game_fsm fsm_inst (
        .clk         (clk_pixel),
        .rst         (sys_rst_pixel),
        .new_frame   (new_frame_hdmi),
        .p1_life_lost(p1_life_lost),
        .p2_life_lost(p2_life_lost),
        .state       (game_state),
        .p1_lives    (p1_lives),
        .p2_lives    (p2_lives),
        .blink_p1    (blink_p1),
        .blink_p2    (blink_p2),
        .winner      (winner)
    );

    //*********************************************************
    //GAME RENDERER 

    // TODO 

endmodule // top_level


`default_nettype wire
