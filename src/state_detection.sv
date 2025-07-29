//
//    Date Created : 06/28/2025
//    Author       : Wade Groff
//    
//    Description :
//        Takes in the HDMI signal and determines the current HDMI state.
//
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
//
//
//
//
//
//


`ifndef CORE_PKG
    `include "core_pkg.svh"
    `define CORE_PKG
`endif 

import core_pkg::*;

module state_detection (

    input logic clk,
    input logic hdmi_clk,     // Clock coming from rx_hdmi, used for synchronization
                              //      Only need to be able to detect how many pixels are transmitted each pixel clock
    input logic hdmi_rx_hpd,  // Used to detect the start of an HDMI stream
    input rx_data,

);




    









endmodule


