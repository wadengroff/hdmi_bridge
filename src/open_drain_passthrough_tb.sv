`timescale 1ns / 1ps

import core_pkg::*;

module open_drain_passthrough_tb ();


    logic clk_tb = 0;
    logic ten_side0_tb;
    logic ten_side1_tb;

    logic side0_inout_tb = 1;
    logic side1_inout_tb = 1;

    logic side0_dly0_tb;
    logic side0_dly1_tb;
    logic side1_dly0_tb;
    logic side1_dly1_tb;


    // create clock
    localparam clk_period = 6ns;
    always begin
        clk_tb = ~clk_tb;
        #(clk_period/2);
    end

    open_drain_passthrough uut (
        .clk_p(clk_tb),
        .data_side0_p(side0_dly1_tb),
        .data_side1_p(side1_dly1_tb),
        .ten_side0_p(ten_side0_tb),
        .ten_side1_p(ten_side1_tb)
    );

    always_ff @(posedge clk_tb) begin
        if (ten_side0_tb) begin
            side0_dly0_tb <= side0_inout_tb;
        end else begin
            side0_dly0_tb <= 0;
        end

        side0_dly1_tb <= side0_dly0_tb;

        if (ten_side1_tb) begin
            side1_dly0_tb <= side1_inout_tb;
        end else begin
            side1_dly0_tb <= 0;
        end

        side1_dly1_tb <= side1_dly0_tb;
    end


    initial begin

        for (int i = 0; i < 5; i++) begin
            @(posedge clk_tb);
        end

        side0_inout_tb = 1;
        side1_inout_tb = 1;

        @(posedge clk_tb);
        @(posedge clk_tb);

        side0_inout_tb = 0;

        @(posedge clk_tb);

        side0_inout_tb = 1;

        for (int i = 0; i < 20; i++) begin
            @(posedge clk_tb);
        end

        side1_inout_tb = 0;

        @(posedge clk_tb);
        
        side1_inout_tb = 1;

        for (int i = 0; i < 20; i++) begin
            @(posedge clk_tb);
        end

        $finish;


    end


endmodule




