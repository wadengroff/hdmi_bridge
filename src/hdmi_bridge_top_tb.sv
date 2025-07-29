`timescale 1ns / 1ps







import core_pkg::*;

module hdmi_bridge_top_tb ();


    wire rx_cec;

    logic rx_clk, rx_clk_n, rx_clk_p;
    assign rx_clk_n = ~rx_clk;
    assign rx_clk_p = rx_clk;
    
    logic [2:0] rx_d, rx_d_n, rx_d_p;
    assign rx_d_n = ~rx_d;
    assign rx_d_p = rx_d;

    logic rx_hpd;
    logic rx_scl;
    

    wire tx_cec;
    
    logic tx_clk, tx_clk_n, tx_clk_p;
    assign tx_clk = tx_clk_p;

    logic [2:0] tx_d, tx_d_n, tx_d_p;
    assign tx_d = tx_d_p;

    logic tx_hpdn;
    logic tx_scl;

    logic [3:0] leds;

    localparam clk_period = 1ns;


    wire rx_sda_p;
    logic rx_sda_int_i, rx_sda_int_o;
    logic tmp;
    // tri-state driver for the SDA line to rx
    IOBUF rx_sda_buf (
        .IO(tmp),     // connected to top-level
        .I(rx_sda_int_i),             // data on tristate output. Only want 0 to do open drain
        .T(1'b0),  // tristate diver for rx out, coming from output of the tx buffer
        .O(rx_sda_int_o)   // output of the buffer
        );
    
    wire tx_sda_p;
    logic tx_sda_int_i, tx_sda_int_o;
    // tri-state driver for the SDA line to rx
    IOBUF tx_sda_buf (
        .IO(tx_sda_p),     // connected to top-level
        .I(tx_sda_int_i),             // data on tristate output. Only want 0 to do open drain
        .T(1'b0),  // tristate diver for rx out, coming from output of the tx buffer
        .O(tx_sda_int_o)   // output of the buffer
        );

    //////////////////////////////////////////////////
    // instantiate top-level
    hdmi_bridge_top inst_top (
        .clk(1'b1),
        .hdmi_rx_cec(rx_cec),
        .hdmi_rx_clk_n(rx_clk_n),
        .hdmi_rx_clk_p(rx_clk_p),
        .hdmi_rx_d_n(rx_d_n),
        .hdmi_rx_d_p(rx_d_p),
        .hdmi_rx_hpd(rx_hpd),
        .hdmi_rx_scl(rx_scl),
        .hdmi_rx_sda(rx_sda_p),

        .hdmi_tx_cec(tx_cec),
        .hdmi_tx_clk_n(tx_clk_n),
        .hdmi_tx_clk_p(tx_clk_p),
        .hdmi_tx_d_n(tx_d_n),
        .hdmi_tx_d_p(tx_d_p),
        .hdmi_tx_hpdn(tx_hpdn),
        .hdmi_tx_scl(tx_scl),
        .hdmi_tx_sda(tx_sda_p),

        .leds(leds)  
    );


    // Generate rx clock in
    always begin
        rx_clk <= 1;
        #(clk_period/2);
        rx_clk <= 0;
        #(clk_period/2);
    end


    initial begin

        @(posedge rx_clk);
        rx_d <= 1;
        rx_scl <= 1;
        rx_sda_int_i <= 0;
        tx_sda_int_i <= 0;
        tx_hpdn <= 1;
        @(posedge rx_clk);
        rx_d <= 0;
        rx_scl <= 0;
        rx_sda_int_i <= 1;
        tx_sda_int_i <= 1;
        tx_hpdn <= 0;
        @(posedge rx_clk);
        $finish;



    end









endmodule


