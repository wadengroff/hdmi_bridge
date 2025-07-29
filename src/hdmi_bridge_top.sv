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
    input hdmi_rx_clk_n_p, hdmi_rx_clk_p_p, // this clock isn't necessarily the exact speed that pixels come
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

logic hdmi_rx_hpd_int;

logic hdmi_rx_ten_s;
logic hdmi_tx_ten_s;

assign leds_p[0] = hdmi_rx_hpd_p;

// directly link together the non-differential pairs
assign hdmi_rx_hpd_p = hdmi_rx_hpd_dly1;
assign hdmi_rx_hpd_int = ~hdmi_tx_hpdn_p;
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

    hdmi_clk_dly0 <= hdmi_clk;
    hdmi_clk_dly1 <= hdmi_clk_dly0;

    hdmi_d_dly0 <= hdmi_d;
    hdmi_d_dly1 <= hdmi_d_dly0;

    hdmi_rx_sda_dly0 <= hdmi_rx_sda_int;
    hdmi_rx_sda_dly1 <= hdmi_rx_sda_dly0;

    hdmi_tx_sda_dly0 <= hdmi_tx_sda_int;
    hdmi_tx_sda_dly1 <= hdmi_tx_sda_dly0;

    hdmi_rx_cec_dly0 <= hdmi_rx_cec_int;
    hdmi_rx_cec_dly1 <= hdmi_rx_cec_dly0;

    hdmi_tx_cec_dly0 <= hdmi_tx_cec_int;
    hdmi_tx_cec_dly1 <= hdmi_tx_cec_dly0;

    hdmi_rx_hpd_dly0 <= hdmi_rx_hpd_int;
    hdmi_rx_hpd_dly1 <= hdmi_rx_hpd_dly0;

    hdmi_rx_scl_dly0 <= hdmi_rx_scl_p;
    hdmi_rx_scl_dly1 <= hdmi_rx_scl_dly0;

end




//////////////////////////////////////////////
//////////////////////////////////////////////
// Input buffer for rx clock
IBUFDS #(
    .IOSTANDARD("TMDS_33")
) hdmi_clk_buf_in (
    .O(hdmi_clk),
    .I(hdmi_rx_clk_p_p), // positive
    .IB(hdmi_rx_clk_n_p) // negative
);



// Output buffer for tx clock
OBUFDS #(
    .IOSTANDARD("TMDS_33")
) hdmi_clk_buf_out (
    .I(hdmi_clk_dly1),
    .O(hdmi_tx_clk_p_p), // output p-side
    .OB(hdmi_tx_clk_n_p) // Output n-side
);
//////////////////////////////////////////////
//////////////////////////////////////////////
// Input buffer for hdmi_rx_d_n_p
genvar i;
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
        .I(hdmi_d_dly1[i]),
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

// open_drain_passthrough inst_i2c (
//     .clk_p(clk_p),
//     .data_side0_p(hdmi_tx_sda_dly1),
//     .data_side1_p(hdmi_rx_sda_dly1),
//     .ten_side0_p(hdmi_tx_ten_s),
//     .ten_side1_p(hdmi_rx_ten_s)
// );


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
probes probes_inst (
    .clk_p(clk_p),
    .ila0_p(hdmi_d_dly1),
    .ila1_p(hdmi_tx_cec_ten_s),
    .ila2_p(hdmi_rx_cec_ten_s),
    .ila3_p(hdmi_clk_dly1),
    .ila4_p(hdmi_rx_scl_dly1),
    .ila5_p(hdmi_rx_sda_dly1),
    .ila6_p(hdmi_tx_sda_dly1),
    .ila7_p(i2c_state_s)
);


// INSTANTIATE LOGIC PROBE
//ila_0 probe0 (
//    .clk_p(clk_p),
//    .probe0(hdmi_d_dly1),
//    .probe1(hdmi_rx_hpd_dly1),
//    .probe2(hdmi_rx_cec_dly1),
//    .probe3(hdmi_clk_dly1)
//);


endmodule