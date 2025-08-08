//////////////////////////////////////////
// Code for a FIFO for a UART core
//////////////////////////////////////////

`ifndef CORE_PKG
    `include "core_pkg.svh"
    `define CORE_PKG
`endif

import core_pkg::*;

// will likely infer BRAM, especially since the output is registered

module fifo #(
    parameter ADDR_WIDTH = 3,  // determines the depth of the fifo
    parameter INT_FILL = 3,    // fill-level for an interrupt signal
    parameter DATA_WIDTH = 8
    ) (

    input logic clk,
    input logic rst,

    input logic wr_en,
    input logic[DATA_WIDTH-1:0] datai,

    output logic rd_rdy,
    input logic rd_en,
    output logic [DATA_WIDTH-1:0] datao,
    output logic fill_reached,
    output logic [ADDR_WIDTH - 1:0] rd_addro
);

    localparam FIFO_DEPTH = 2**ADDR_WIDTH;

    logic [DATA_WIDTH-1:0] data_arr [FIFO_DEPTH - 1:0]; // unpacked array of 256 8 bit data entries
    

    logic [DATA_WIDTH-1:0] data_read_reg = 0;
    logic [ADDR_WIDTH - 1:0] rd_addr = 0;
    assign rd_addro = rd_addr;
    logic inc_rd_addr = 0;
    logic do_read = 0;
    logic inc_rd_dly = 0;

    logic [ADDR_WIDTH - 1:0] wr_addr = 0;
    logic inc_wr_addr = 0;
    
    // needs to be able to count to the capacity
    logic [ADDR_WIDTH:0] fill_level = 0;


    assign datao = data_read_reg;


    always_ff @(posedge clk) begin
        // load the data onto the read register
        data_read_reg <= data_arr[rd_addr];

        // Output whether the FIFO is above whatever fill level is specified at instantiation
        fill_reached <= (fill_level >= INT_FILL) ? 1 : 0;
    end

    always_ff @(posedge clk) begin
        if (wr_en) begin
            data_arr[wr_addr] <= datai;
        end
    end

    always_comb begin
         // takes one clock to load new data onto the read register
        // Only want to disable the read pointer if an actual read is being done
        //      That's why we're not using inc_rd_addr, but rd_en_dly
        if (fill_level != '0 && !inc_rd_dly) begin
            rd_rdy = '1;
        end else begin
            rd_rdy = '0;
        end

        // need to increment if at max fill level.
        // otherwise, we would be getting newer data at the read pointer
        do_read = (rd_rdy & rd_en);
        inc_wr_addr = wr_en;
        inc_rd_addr =  do_read | (fill_level == FIFO_DEPTH & inc_wr_addr);
        
    end


    always_ff @(posedge clk) begin

        inc_rd_dly <= inc_rd_addr;
        // will loop around addresses
        if (inc_rd_addr) begin
            rd_addr <= rd_addr + 1'b1;
        end else begin
            rd_addr <= rd_addr;
        end

        if (inc_wr_addr) begin
            wr_addr <= wr_addr + 1'b1;
        end else begin
            wr_addr <= wr_addr;
        end

    end

    always_ff @(posedge clk) begin
        if (inc_wr_addr & inc_rd_addr || fill_level == FIFO_DEPTH) // don't increment size if reading and writing, or if full
            fill_level <= fill_level;
        else if (inc_wr_addr & ! inc_rd_addr )
            fill_level <= fill_level + 1;
        else if (!inc_wr_addr & inc_rd_addr)
            fill_level <= fill_level - 1; 
    end


endmodule