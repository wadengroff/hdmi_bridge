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
//    091925     wng      1. Changed the serdes reset to go based on the negative edge of the locked
//                           clock. This way, it's not driven by a LUT.
//                        2. Changed clocking topology
//
//
//

// import package constants
`include "core_pkg.svh"
import core_pkg::*;


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

    input logic [3:0] buttons_p,
    
    // leds_p
    output logic [3:0] leds_p
);

logic clk_125;
assign clk_125 = clk_p;

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

// Delay all of the internal signals into the current clock domain
logic hdmi_clk_dly0, hdmi_clk_dly1;
logic [2:0] hdmi_d_dly0, hdmi_d_dly1;
logic hdmi_rx_sda_dly0, hdmi_rx_sda_dly1;
logic hdmi_tx_sda_dly0, hdmi_tx_sda_dly1;
logic hdmi_rx_cec_dly0, hdmi_rx_cec_dly1;
logic hdmi_tx_cec_dly0, hdmi_tx_cec_dly1;
logic hdmi_rx_hpd_dly0, hdmi_rx_hpd_dly1;
logic hdmi_rx_scl_dly0, hdmi_rx_scl_dly1;

assign leds_p[0] = hdmi_rx_hpd_p;

// directly link together the non-differential pairs
assign hdmi_rx_hpd_p = hdmi_rx_hpd_dly1;

assign hdmi_tx_scl_p = hdmi_rx_scl_dly1;

localparam clk_freq = 125*10**6;

//////////////////////////////////////////////////////////////////


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



// trying using clocks directly from the mmcm
logic serial_clk_unbuff, serial_clk_n_unbuff;  // 5x tmds_clk
logic serial_clk_mr, serial_clk_n_mr;
logic rx_serial_clk, rx_serial_clk_n;
logic tx_serial_clk, tx_serial_clk_n;
logic serial_clk_locked;
logic word_clk_unbuf, word_clk_mr;
logic rx_word_clk, tx_word_clk;

clk_wiz_0 tmds_mult_5
    (
    // Clock out ports
    .serial_clk(serial_clk_unbuff),//serial_clk_unbuff),     // output pixel_clk
    .serial_clk_n(serial_clk_n_unbuff),
    .word_clk(word_clk_unbuf),
    // Status and control signals
    .reset(0), // input reset
    .input_clk_stopped(),
    .locked(serial_clk_locked),       // output locked
    // Clock in ports
    .clk_in1_p(hdmi_rx_clk_p_p),    // input clk_in1_p
    .clk_in1_n(hdmi_rx_clk_n_p)    // input clk_in1_n
    );


// ONLY TWO BUFMR COMPONENTS IN EACH CLOCK REGION.
// SO, WE NEED TO USE A DIFFERENT CLOCKING STRUCTURE THAN ALL ON BUFMRCE
// instead, put buff_serial_n and buff_serial on one, then derive word_clk from that with a BUFR

// Generates a multiregional clock
// allows us to send this to the OSERDES module
BUFMRCE buff_serial (
    .CE(serial_clk_locked),
    .I(serial_clk_unbuff),
    .O(serial_clk_mr)
);

BUFMRCE buff_serial_n (
    .CE(serial_clk_locked),
    .I(serial_clk_n_unbuff),
    .O(serial_clk_n_mr)
);

// BUFMRCE buff_word (
//     .CE(serial_clk_locked),
//     .I(word_clk_unbuf),
//     .O(word_clk_mr)
// );

// Generate the local bufio buffer to drive ISERDESE2
BUFIO rx_serial_bufio (
    .I(serial_clk_mr),
    .O(rx_serial_clk)
);

BUFIO rx_serial_n_bufio (
    .I(serial_clk_n_mr),
    .O(rx_serial_clk_n)
);

BUFR #(
    .BUFR_DIVIDE("5")
) rx_word_bufr(
    .CE(1),
    .CLR(0),
    .I(serial_clk_mr),
    .O(rx_word_clk)
);


// BUFIO rx_word_bufio (
//     .I(word_clk_mr),
//     .O(rx_word_clk)
// );

// Generate the local bufio buffer to drive OSERDESE2
BUFIO tx_serial_bufio (
    .I(serial_clk_mr),
    .O(tx_serial_clk)
);

BUFIO tx_serial_n_bufio (
    .I(serial_clk_n_mr),
    .O(tx_serial_clk_n)
);

BUFR #(
    .BUFR_DIVIDE("5")
) tx_word_bufr(
    .CE(1),
    .CLR(0),
    .I(serial_clk_mr),
    .O(tx_word_clk)
);

// BUFIO tx_word_bufio (
//     .I(word_clk_mr),
//     .O(tx_word_clk)
// );


logic word_clk_global;
logic serial_clk_global;
logic serial_clk_n_global;

// BUFG glob_word (
//     .I(word_clk),
//     .O(word_clk_global)
// );

// BUFG glob_serial (
//     .I(serial_clk),
//     .O(serial_clk_global)
// );

// BUFG glob_serial_n (
//     .I(serial_clk_n),
//     .O(serial_clk_n_global)
// );

// BUFR #(
//     .BUFR_DIVIDE("5"),
//     .SIM_DEVICE("7SERIES")
// ) div_word_clk (
//     .O(word_clk_prebuf),
//     .CE(1),
//     .CLR(0),
//     .I(serial_clk)
// );

// BUFG glob_word_clk (
//     .I(word_clk_prebuf),
//     .O(word_clk)
// );


// MAYBE ADD A GLOBAL BUFFER FOR SERIAL_CLK

logic clk_300; // USED TO GENERATE TAP DELAYS
clk_wiz_1 gen_clk300
   (
    // Clock out ports
    .clk_300(clk_300),     // output clk_300
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
   .REFCLK(clk_300), // 1-bit input: Reference clock input
   .RST(0)        // 1-bit input: Active high reset input
);


logic [2:0] synchronized;
logic [2:0][9:0] hdmi_data_words;
logic [2:0][3:0] taps_s;
logic [2:0] bitslip_s;
sync_state_t [2:0] sync_states;
logic [2:0] past_50ms_s;

// Resets if hpd goes down, then sets when word_clk is enabled and hpd
// asynchronous reset
logic reset_serdes_reg = 1;
always @(posedge rx_word_clk or negedge serial_clk_locked) begin
    if (!serial_clk_locked) begin
        reset_serdes_reg <= 1;
    end else begin
        reset_serdes_reg <= 0;
    end
end


genvar i;
// // Instantiate Button Debouncers
// for (i = 0; i <= 3; i++) begin
//     button_debouncer #(
//         .DEBOUNCE_CYCLES(100)
//     ) inst_debounce (
//         .clk_p(clk_p)
//     )

// end




for (i = 0; i <= 2; i++) begin
    hdmi_d_sync inst_sync (
        .clk_125(clk_125),
        .serial_clk(rx_serial_clk),
        .serial_clk_n(rx_serial_clk_n),
        .word_clk(rx_word_clk),
        .rst(reset_serdes_reg),
        .sync_en_p(~synchronized[i]),
        .datai_p(hdmi_d[i]),
        .word_out_p(hdmi_data_words[i]),
        .synchronized(synchronized[i]),
        .sync_state_p(sync_states[i]),
        .bitslip_p(bitslip_s[i]),
        .taps_p(taps_s[i]),
        .past_50ms_p(past_50ms_s[i])
    );
end


logic [2:0][9:0] hdmi_data_word_outputs;
always_ff @(posedge word_clk_global) begin
    if (synchronized == 3'b111) begin
        hdmi_data_word_outputs <= hdmi_data_words;
    end else begin
        hdmi_data_word_outputs <= {0,0,0};
    end
end

logic [2:0] hdmi_tx_data_out;
logic [2:0] hdmi_tx_d_fb;
for (i = 0; i <= 2; i++) begin
    hdmi_d_output inst_otp (
        .serial_clk(tx_serial_clk),
        .rst(reset_serdes_reg),
        .word_clk(tx_word_clk),
        .data_in(hdmi_data_word_outputs[i]),
        .data_out(hdmi_tx_data_out[i]),
        .data_out_fb(hdmi_tx_d_fb[i])
    );
end

// // FEEDBACK DATA SYNC
// logic [2:0][9:0] hdmi_fb_data;
// for (i = 0; i <= 2; i++) begin
//     // Instantiate master serdees2
//     serdes_wrapper #(
//         .SERDES_MODE("Master"),
//         .OFB_USED("TRUE")
//     ) master_serdes (
//         .serial_clk(serial_clk_global),
//         .serial_clk_n(serial_clk_n_global),
//         .word_clk(word_clk_global),
//         .D(0),
//         .DDLY(0),
//         .OFB(hdmi_tx_d_fb[i]),
//         .CE(1),
//         .BITSLIP(0),
//         .SHIFTOUT1(shiftout1_s),
//         .SHIFTOUT2(shiftout2_s),
//         .Q1(hdmi_fb_data[i][9]),
//         .Q2(hdmi_fb_data[i][8]),
//         .Q3(hdmi_fb_data[i][7]),
//         .Q4(hdmi_fb_data[i][6]),
//         .Q5(hdmi_fb_data[i][5]),
//         .Q6(hdmi_fb_data[i][4]),
//         .Q7(hdmi_fb_data[i][3]),
//         .Q8(hdmi_fb_data[i][2])
//     );

//     // Instantiate slave serdese2
//     serdes_wrapper  #(
//         .SERDES_MODE("Slave"),
//         .OFB_USED("TRUE")
//     ) slave_serdes (
//         .serial_clk(serial_clk_global),
//         .serial_clk_n(serial_clk_n_global),
//         .word_clk(word_clk_global),
//         .D(0),
//         .DDLY(0),
//         .OFB(0),
//         .CE(1),
//         .BITSLIP(bitslip_s),
//         .SHIFTIN1(shiftout1_s),
//         .SHIFTIN2(shiftout2_s),
//         .Q3(hdmi_fb_data[i][1]),     // datasheet said to use these
//         .Q4(hdmi_fb_data[i][0])
//     );
// end


// Output buffer for tx clock
OBUFDS #(
    .IOSTANDARD("TMDS_33"),
    .SLEW("FAST")
) hdmi_clk_buf_out (
    .I(word_clk_global),
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
        .IOSTANDARD("TMDS_33"),
        .SLEW("FAST")
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

(* ASYNC_REG = "TRUE"*) logic [2:0] sync_dly0, sync_dly1;
(* ASYNC_REG = "TRUE"*) logic [2:0] bitslip_dly0, bitslip_dly1;
(* ASYNC_REG = "TRUE"*) logic [2:0] taps_dly0, taps_dly1;
(* ASYNC_REG = "TRUE"*) logic [9:0] par_data0, par_data0_dly;
(* ASYNC_REG = "TRUE"*) logic [9:0] par_data1, par_data1_dly;
(* ASYNC_REG = "TRUE"*) logic [9:0] par_data2, par_data2_dly;
(* ASYNC_REG = "TRUE"*) logic rst_dly0, rst_dly1;
(* ASYNC_REG = "TRUE"*) sync_state_t sync_state_dly0, sync_state_dly1;
always_ff @(posedge clk_p) begin
   sync_dly0 <= synchronized;
   sync_dly1 <= sync_dly0;

   sync_state_dly0 <= sync_states[0];
   sync_state_dly1 <= sync_state_dly0;

   bitslip_dly0 <= bitslip_s;
   bitslip_dly1 <= bitslip_dly0;

   taps_dly0 <= taps_s[0];
   taps_dly1 <= taps_dly0;



    rst_dly0 <= reset_serdes_reg;
    rst_dly1 <= rst_dly0;

    par_data0 <= hdmi_data_words[0];//hdmi_data_word_outputs[0];
    par_data0_dly <= par_data0;

   //par_data0 <= hdmi_fb_data[0]; //hdmi_data_words[0];
   //par_data0_dly <= par_data0;

   par_data1 <= hdmi_data_words[1]; //hdmi_data_words[0];
   par_data1_dly <= par_data1;

   par_data2 <= hdmi_data_words[2]; //hdmi_data_words[0];
   par_data2_dly <= par_data2;
end

probes pixel_ila_inst (
    .clk_p(clk_p),      // use the slower clock so it doesn't blow up
    .ila0_p(sync_dly1),
    .ila1_p(rst_dly1),
    .ila2_p(taps_dly1[0]),
    .ila3_p(taps_dly1[1]),
    .ila4_p(taps_dly1[2]),
    .ila5_p(bitslip_dly1[0]),
    .ila6_p(bitslip_dly1[1]),
    .ila7_p(past_50ms_s),
    .ila8_p(par_data0_dly),
    .ila9_p(par_data1_dly),
    .ila10_p(par_data2_dly)
);



endmodule