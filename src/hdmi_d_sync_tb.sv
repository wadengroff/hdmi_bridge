`timescale 1ns / 1ps


import core_pkg::*;

module hdmi_d_sync_tb ();

    localparam clk_125_period = 8ns;
    localparam word_clk_period = 8.333ns;
    localparam clk_skew = 0.81ns;

    logic clk_125 = 0;
    logic word_clk = 0;

    // need a separate data clk to simulate misalignment, see if we compensate
    logic serial_clk = 0;
    logic serial_data_clk = 0;
    logic serial_clk_n = 1;
    logic serial_data_clk_n = 1;

    logic enable_data_clk = 0;


    always begin
        clk_125 <= ~clk_125;
        #(clk_125_period/2);
    end

    always begin    
        word_clk <= ~word_clk;
        #(word_clk_period/2);
    end

    // serial clk at 10x the speed
    always begin
        serial_clk <= ~serial_clk;
        serial_clk_n <= ~serial_clk_n;
        #(word_clk_period/5/2);
    end

    always begin
        if (!enable_data_clk) begin
            #(clk_skew);
            enable_data_clk <= 1;
        end else begin
            serial_data_clk <= ~serial_data_clk;
            serial_data_clk_n <= ~serial_data_clk_n;
            #(word_clk_period/5/2);
        end
    end


    logic sync_en_tb = 0;
    logic datai_tb;
    // SHIFTED VERSION, needs to go through other bitslips to find
    logic [9:0] word_send_tb = {
        CONTROL_PERIOD_ENCODINGS_C[0][1:0],
        CONTROL_PERIOD_ENCODINGS_C[0][9:2]
    };
    logic [9:0] word_out_tb;
    logic synchronized_tb;
    logic [1:0] control_outputs_tb;
    logic rst_tb = 1;
    logic bitslip_tb;
    logic [4:0] taps_tb;
    logic [1:0] sync_state_tb;
    logic data_out_tb;
    
    hdmi_d_sync #(.WAIT_CLKS_P(100)) UUT (
        .clk_125(clk_125),
        .serial_clk(serial_clk),
        .serial_clk_n(serial_clk_n),
        .word_clk(word_clk),
        .rst(rst_tb),
        .sync_en_p(sync_en_tb),
        .datai_p(datai_tb),
        .word_out_p(word_out_tb),
        .synchronized(synchronized_tb),
        .sync_state_p(sync_state_tb),
        .bitslip_p(bitslip_tb),
        .taps_p(taps_tb)
    );

    // // Testing with OSERDESE2 Output interface as well
    // hdmi_d_output inst_otp (
    //     .serial_clk(serial_clk),
    //     .rst(rst_tb),
    //     .word_clk(word_clk),
    //     .data_in(word_out_tb),
    //     .data_out(data_out_tb),
    //     .data_out_fb()
    // );

    assign datai_tb = word_send_tb[0];
    always @(posedge serial_data_clk, posedge serial_data_clk_n) begin
        word_send_tb <= {word_send_tb[0], word_send_tb[9:1]};
    end

    initial begin

        
        @(posedge word_clk);
        rst_tb <= 1;
        
        for (int i = 0; i < 10; i++) begin
            @(posedge word_clk);
        end
        rst_tb <= 0;
        @(posedge word_clk);
        sync_en_tb <= 1;
        @(posedge word_clk);
        sync_en_tb <= 0;
        @(posedge synchronized_tb);
        for (int i = 0; i < 50; i++) begin
            @(posedge word_clk);
        end
        $finish;


    end



endmodule


