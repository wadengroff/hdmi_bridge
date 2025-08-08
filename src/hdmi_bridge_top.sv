//
//    Date Created : 06/03/2025
//    Author       : Wade Groff
//    
//    Description :
//        Initial design linking a laptop or other HDMI video source to
//        an external display with the intention of processing the video
//        and make changes or take other actions.
//
//
//
//
//    Revisions :
//
//    Date       Who       Description
//    ------     ---      -----------------------------------------------------------
//    060325     wng      1. Created initial file.
//
//    072825     wng      1. Added block diagram to make ILA easier to use. Don't need to do in constraints file anymore
//                        2. Discovered that there is a problem with the I2C bus
//                              - Feedback loop when either side is driven to 0 because of setup. Need to keep track of I2C states
//
//
//
//
//
//




module hdmi_bridge_top (

    input logic clk_p,

    // HDMI RX signals
    inout logic hdmi_rx_cec_p,
    input hdmi_rx_clk_n_p,
    input hdmi_rx_clk_p_p, // this clock isn't necessarily the exact speed that pixels come
                                        // need to do synchronization to get the correct speed. Done during the control period
    input [2:0] hdmi_rx_d_n_p,
    input [2:0] hdmi_rx_d_p_p,
    output logic hdmi_rx_hpd_p,
    input logic hdmi_rx_scl_p,
    inout hdmi_rx_sda_p,

    // HDMI TX signals
    inout logic hdmi_tx_cec_p,
    output hdmi_tx_clk_n_p, hdmi_tx_clk_p_p,
    output [2:0] hdmi_tx_d_n_p, hdmi_tx_d_p_p,
    input logic hdmi_tx_hpdn_p,
    output logic hdmi_tx_scl_p,
    inout hdmi_tx_sda_p,
    
    // leds_p
    output logic [3:0] leds_p
);

logic hdmi_clk;
logic [2:0] hdmi_d;

// I2C signals
logic hdmi_tx_sda_int;
logic hdmi_rx_sda_int;
logic [2:0] i2c_state_s;

// CEC signals
logic hdmi_tx_cec_int;
logic hdmi_rx_cec_int;
logic hdmi_tx_cec_ten_s; // enable/disable tristate for IO buffers
logic hdmi_rx_cec_ten_s;


logic hdmi_rx_ten_s;
logic hdmi_tx_ten_s;

assign leds_p[0] = hdmi_rx_hpd_p;

// directly link together the non-differential pairs
assign hdmi_rx_hpd_p = hdmi_rx_hpd_dly1;

assign hdmi_tx_scl_p = hdmi_rx_scl_dly1;

localparam clk_freq = 125*10**6;

//////////////////////////////////////////////////////////////////
// Delay all of the internal signals into the current clock domain
logic hdmi_clk_dly0, hdmi_clk_dly1;
logic [2:0] hdmi_d_dly0, hdmi_d_dly1;
logic hdmi_rx_sda_dly0, hdmi_rx_sda_dly1;
logic hdmi_tx_sda_dly0, hdmi_tx_sda_dly1;
logic hdmi_rx_cec_dly0, hdmi_rx_cec_dly1;
logic hdmi_tx_cec_dly0, hdmi_tx_cec_dly1;
logic hdmi_rx_hpd_dly0, hdmi_rx_hpd_dly1;
logic hdmi_rx_scl_dly0, hdmi_rx_scl_dly1;

always_ff @(posedge clk_p) begin

    hdmi_rx_sda_dly0 <= hdmi_rx_sda_int;
    hdmi_rx_sda_dly1 <= hdmi_rx_sda_dly0;

    hdmi_tx_sda_dly0 <= hdmi_tx_sda_int;
    hdmi_tx_sda_dly1 <= hdmi_tx_sda_dly0;

    hdmi_rx_cec_dly0 <= hdmi_rx_cec_int;
    hdmi_rx_cec_dly1 <= hdmi_rx_cec_dly0;

    hdmi_tx_cec_dly0 <= hdmi_tx_cec_int;
    hdmi_tx_cec_dly1 <= hdmi_tx_cec_dly0;

    hdmi_rx_hpd_dly0 <= ~hdmi_tx_hpdn_p;
    hdmi_rx_hpd_dly1 <= hdmi_rx_hpd_dly0;

    hdmi_rx_scl_dly0 <= hdmi_rx_scl_p;
    hdmi_rx_scl_dly1 <= hdmi_rx_scl_dly0;

end




//////////////////////////////////////////////
//////////////////////////////////////////////
// CLOCKING FOR DATA LINES
// read online that the standard pixel clock is 148.5 MHz
// The pixel clock is 10x what is sent on the hdmi_clk line, which almost matches
// the measurement found before (<8 cycles of 125MHz per clock => ~15.625MHz)

// Input buffer for rx clock
// IBUFDS #(
//     .IOSTANDARD("TMDS_33"),
//     .DIFF_TERM("TRUE")
// ) hdmi_clk_buf_in (
//     .O(hdmi_clk),        // This clock is at 14.85MHz
//     .I(hdmi_rx_clk_p_p), // positive
//     .IB(hdmi_rx_clk_n_p) // negative
// );


logic hdmi_clk_buf;
// // Use global clock buffer
// BUFG bufg_pixel_clk (
//     .I(hdmi_clk),
//     .O(hdmi_clk_buf)    // on global clock routing
// );


  // THIS IS NOT ALL WE NEED
  // THE REASON SYNCRHONIZATION NEEDS TO HAPPEN IS BECAUSE IT'S NOT GUARANTEED FOR
  // TMDS CLOCK AND DATA TO LINE UP. NEED TO DETECT WITH FANCY BITSLIP LOGIC IN 
  // SERDES INTERFACE
logic serial_clk_unbuff, serial_clk_n_unbuff;  // 5x tmds_clk
logic serial_clk, serial_clk_n;
logic serial_clk_locked;
clk_wiz_0 tmds_mult_5
    (
    // Clock out ports
    .serial_clk(serial_clk),//serial_clk_unbuff),     // output pixel_clk
    .serial_clk_n(serial_clk_n),
    // Status and control signals
    .reset(0), // input reset
    .input_clk_stopped(),
    .locked(serial_clk_locked),       // output locked
    // Clock in ports
    .clk_in1_p(hdmi_rx_clk_p_p),    // input clk_in1_p
    .clk_in1_n(hdmi_rx_clk_n_p)    // input clk_in1_n
    );

// 
// BUFIO buff_serial (
//     .I(serial_clk_unbuff),
//     .O(serial_clk)
// );

// BUFIO buff_serial_n (
//     .I(serial_clk_n_unbuff),
//     .O(serial_clk_n)
// );

logic word_clk_prebuf, word_clk;
BUFR #(
    .BUFR_DIVIDE("5"),
    .SIM_DEVICE("7SERIES")
) div_word_clk (
    .O(word_clk_prebuf),
    .CE(1),
    .CLR(0),
    .I(serial_clk)
);

BUFG glob_word_clk (
    .I(word_clk_prebuf),
    .O(word_clk)
);

logic clk_200; // USED TO GENERATE TAP DELAYS
clk_wiz_1 gen_clk200
   (
    // Clock out ports
    .clk_200(clk_200),     // output clk_200
    // Status and control signals
    .reset(0), // input reset
    .locked(),       // output locked
   // Clock in ports
    .clk_in1(clk_p)      // input clk_in1
);


// instantiate a delay control module for all idelaye2 instantiations
logic rdy;
(* IODELAY_GROUP = "delay_group" *)
IDELAYCTRL IDELAYCTRL_inst (
   .RDY(rdy),       // 1-bit output: Ready output
   .REFCLK(clk_200), // 1-bit input: Reference clock input
   .RST(0)        // 1-bit input: Active high reset input
);


logic [2:0] synchronized;
logic [2:0][9:0] hdmi_data_words;
logic [2:0] bitslip_s;

genvar i;
for (i = 0; i <= 2; i++) begin
    hdmi_d_sync inst_sync (
        .serial_clk(serial_clk),
        .serial_clk_n(serial_clk_n),
        .word_clk(word_clk),
        .sync_en_p(~synchronized[i]),
        .datai_p(hdmi_d[i]),
        .word_out_p(hdmi_data_words[i]),
        .synchronized(synchronized[i]),
        .bitslip_p(bitslip_s[i])
    );
end


logic [2:0][9:0] hdmi_data_word_outputs;
always_ff @(posedge word_clk) begin
    if (synchronized == 3'b111) begin
        hdmi_data_word_outputs <= hdmi_data_words;
    end else begin
        hdmi_data_word_outputs <= {0,0,0};
    end
end

logic [2:0] reset_output;
logic [2:0] hdmi_tx_data_out;
for (i = 0; i <= 2; i++) begin
    hdmi_d_output inst_otp (
        .serial_clk(serial_clk),
        .serial_clk_locked(serial_clk_locked),
        .word_clk(word_clk),
        .data_in(hdmi_data_word_outputs[i]),
        .data_out(hdmi_tx_data_out[i]),
        .reset_out(reset_output)
    );
end



// Output buffer for tx clock
OBUFDS #(
    .IOSTANDARD("TMDS_33")
) hdmi_clk_buf_out (
    .I(word_clk),
    .O(hdmi_tx_clk_p_p), // output p-side
    .OB(hdmi_tx_clk_n_p) // Output n-side
);



// NEED TO SAMPLE THIS AT 10X TMDS CLOCK (PIXEL CLOCK)
// logic [9:0] [2:0] hdmi_d_dly; // need to delay by 10 to keep aligned to clock out
// always_ff @(posedge pixel_clk) begin
//     hdmi_d_dly[0] <= hdmi_d;
//     for (int i = 1; i < 10; i++) begin
//         hdmi_d_dly[i] <= hdmi_d_dly[i-1];
//     end
//     //hdmi_d_dly0 <= hdmi_d;
//     //hdmi_d_dly1 <= hdmi_d_dly0;
// end

//////////////////////////////////////////////
//////////////////////////////////////////////
// Input buffer for hdmi_rx_d_n_p
for (i = 0; i <= 2; i++) begin
    IBUFDS #(
        .IOSTANDARD("TMDS_33")
    ) hdmi_d_buf_in (
        .O(hdmi_d[i]),
        .I(hdmi_rx_d_p_p[i]),
        .IB(hdmi_rx_d_n_p[i])
    );

    // Output buffer for hdmi_tx_d_n_p
    OBUFDS #(
        .IOSTANDARD("TMDS_33")
    ) hdmi_d_buf_out (
        .I(hdmi_tx_data_out[i]),//hdmi_d_dly1[i]),
        .O(hdmi_tx_d_p_p[i]),
        .OB(hdmi_tx_d_n_p[i])
    );
end



//////////////////////////////////////////////
//////////////////////////////////////////////
// Module that keeps track of the I2C state to drive tristate inputs
i2c_tristate_handler inst_i2c (
    .clk_p(clk_p),
    .i2c_scl_p(hdmi_rx_scl_dly1),
    .controller_sda_p(hdmi_rx_sda_dly1),
    .subordinate_sda_p(hdmi_tx_sda_dly1),
    .controller_sda_ten_p(hdmi_rx_ten_s),
    .subordinate_sda_ten_p(hdmi_tx_ten_s),
    .i2c_state_p(i2c_state_s)
);


//////////////////////////////////////////////
//////////////////////////////////////////////
// tri-state driver for the SDA line to rx
IOBUF rx_sda (
    .IO(hdmi_rx_sda_p),     // connected to top-level
    .I(1'b0),             // data on tristate output. Only want 0 to do open drain
    .T(hdmi_rx_ten_s),  // tristate diver for rx out
    .O(hdmi_rx_sda_int)   // output of the buffer
    );
    
//////////////////////////////////////////////
//////////////////////////////////////////////
// tri-state receiver for SDA line to tx
IOBUF tx_sda (
    .IO(hdmi_tx_sda_p),
    .I(1'b0),
    .T(hdmi_tx_ten_s),
    .O(hdmi_tx_sda_int)
    );



//////////////////////////////////////////////
//////////////////////////////////////////////
// Module to control tristate for CEC lines
open_drain_passthrough inst_cec (
    .clk_p(clk_p),
    .data_side0_p(hdmi_tx_cec_dly1),
    .data_side1_p(hdmi_rx_cec_dly1),
    .ten_side0_p(hdmi_tx_cec_ten_s),
    .ten_side1_p(hdmi_rx_cec_ten_s)
);
    
//////////////////////////////////////////////
//////////////////////////////////////////////
// open-drain driver for the cec line
IOBUF rx_cec (
    .IO(hdmi_rx_cec_p),
    .I(1'b0),
    .T(hdmi_rx_cec_ten_s),
    .O(hdmi_rx_cec_int)
    );
    
//////////////////////////////////////////////
//////////////////////////////////////////////
// open-drain driver for the tx cec line
IOBUF tx_cec (
    .IO(hdmi_tx_cec_p),
    .I(1'b0),
    .T(hdmi_tx_cec_ten_s),
    .O(hdmi_tx_cec_int)
    );


// Instantiate ILA block diagram
// Putting in a block diagram makes it easier, since all of the constraints are auto-generated
// probes probes_inst (
//     .clk_p(clk_p),
//     .ila0_p(hdmi_d_dly[9]),
//     .ila1_p(pixel_clk),
//     .ila2_p(hdmi_clk_buf),
//     .ila3_p(hdmi_tx_cec_dly1),
//     .ila4_p(hdmi_rx_scl_dly1),
//     .ila5_p(hdmi_rx_sda_dly1),
//     .ila6_p(hdmi_tx_sda_dly1),
//     .ila7_p(i2c_state_s),
//     .ila8_p(r_data)
// );

// logic [3:0] pixel_clk_cntr = 0;
// logic [9:0] r_data = 0;
// always_ff @(posedge pixel_clk) begin
//     if (pixel_clk_cntr == 9) begin
//         pixel_clk_cntr <= 0;
//         r_data <= hdmi_d_dly[9][0];
//     end else begin
//         pixel_clk_cntr <= pixel_clk_cntr + 1;
//         r_data <= {r_data[8:0], hdmi_d_dly[9][0]};
//     end
// end

// // create out clock
// always_ff @(posedge pixel_clk) begin
//     if (pixel_clk_cntr > 4) begin
//         tmds_clk_out <= 0;
//     end else begin
//         tmds_clk_out <= 1;
//     end
// end

logic [2:0] sync_dly0, sync_dly1;
logic [2:0] bitslip_dly0, bitslip_dly1;
logic [9:0] deb_dat0, deb_dat1;
always_ff @(posedge clk_p) begin
   sync_dly0 <= synchronized;
   sync_dly1 <= sync_dly0;

   bitslip_dly0 <= bitslip_s;
   bitslip_dly1 <= bitslip_dly0;

   deb_dat0 <= hdmi_data_words[0];
   deb_dat1 <= deb_dat0;
end

probes pixel_ila_inst (
    .clk_p(clk_p),      // use the slower clock so it doesn't blow up
    .ila0_p(sync_dly1),
    .ila1_p(0),
    .ila2_p(bitslip_dly1[0]),
    .ila3_p(bitslip_dly1[1]),
    .ila4_p(bitslip_dly1[2]),
    .ila5_p(reset_output),
    .ila6_p(serial_clk_locked),
    .ila7_p(0),
    .ila8_p(deb_dat1)
);



endmodule