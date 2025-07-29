`timescale 1ns / 1ps



import core_pkg::*;

module i2c_tristate_handler_tb ();


    logic i2c_scl_tb;
    logic controller_sda_tb;
    logic subordinate_sda_tb;
    logic controller_sda_ten_tb;
    logic subordinate_sda_ten_tb;
    logic [2:0] i2c_state_tb;



    
    // Create Clock signal
    localparam clk_period = 6ns;

    logic clk_tb = 0;
    always begin
        clk_tb = ~clk_tb;
        #(clk_period/2);
    end


    // instantiate UUT
    i2c_tristate_handler inst_uut (
        .clk_p(clk_tb),
        .i2c_scl_p(i2c_scl_tb),
        .controller_sda_p(controller_sda_tb),
        .subordinate_sda_p(subordinate_sda_tb),
        .controller_sda_ten_p(controller_sda_ten_tb),
        .subordinate_sda_ten_p(subordinate_sda_ten_tb),
        .i2c_state_p(i2c_state_tb)
    );


    task send_byte;
        input [7:0] wdata;
        begin

            for (int ind = 7; ind >= 0; ind--) begin
                controller_sda_tb = wdata[ind];

                i2c_scl_tb = 0;
                for (int i = 0; i < 5; i++) begin
                    @(posedge clk_tb);
                end
                i2c_scl_tb = 1;
                for (int i = 0; i < 5; i++) begin
                    @(posedge clk_tb);
                end
                
            end
        end
    endtask

    initial begin

        i2c_scl_tb = 1;
        controller_sda_tb = 1;
        subordinate_sda_tb = 1;
        for (int i = 0; i < 10; i++) begin
            @(posedge clk_tb);
        end

        controller_sda_tb = 0;
        @(posedge clk_tb);
        @(posedge clk_tb);

        // This will be a write operation
        send_byte(8'hAA);

        i2c_scl_tb = 0;

        @(posedge clk_tb);
        @(posedge clk_tb);

        i2c_scl_tb = 1;

        @(posedge clk_tb);
        @(posedge clk_tb);

        send_byte(8'h47);

        i2c_scl_tb = 0;

        for (int i = 0; i < 10; i++) begin
            @(posedge clk_tb);
        end

        $finish;


    end


endmodule