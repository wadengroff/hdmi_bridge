






module hdmi_d_output (
    input logic serial_clk,
    input logic hpd,
    input logic word_clk,
    input logic [9:0] data_in,
    output logic data_out,
    output logic data_out_fb,
    output logic reset_out
);


// FIRST BIT OUT IS THE LSB
// prot D1 appears first at output

logic reset = 0;
assign reset_out = reset;

always @(posedge word_clk or negedge hpd) begin
    if (!hpd) begin
        reset <= 1;
    end else if (hpd) begin
        reset <= 0;
    end else begin
        reset <= 1;
    end
end

logic SHIFTOUT1;
logic SHIFTOUT2;

OSERDESE2 #(
   .DATA_RATE_OQ("DDR"),   // DDR, SDR
   .DATA_RATE_TQ("DDR"),   // DDR, BUF, SDR
   .DATA_WIDTH(10),         // Parallel data width (2-8,10,14)
   .INIT_OQ(1'b0),         // Initial value of OQ output (1'b0,1'b1)
   .INIT_TQ(1'b0),         // Initial value of TQ output (1'b0,1'b1)
   .SERDES_MODE("MASTER"), // MASTER, SLAVE
   .SRVAL_OQ(1'b0),        // OQ output value when SR is used (1'b0,1'b1)
   .SRVAL_TQ(1'b0),        // TQ output value when SR is used (1'b0,1'b1)
   .TBYTE_CTL("FALSE"),    // Enable tristate byte operation (FALSE, TRUE)
   .TBYTE_SRC("FALSE"),    // Tristate byte source (FALSE, TRUE)
   .TRISTATE_WIDTH(1)      // 3-state converter width (1,4)
) master (
   .OFB(data_out_fb),             // 1-bit output: Feedback path for data
   .OQ(data_out),               // 1-bit output: Data path output
   // SHIFTOUT1 / SHIFTOUT2: 1-bit (each) output: Data output expansion (1-bit each)
   .TBYTEOUT(),   // 1-bit output: Byte group tristate
   .TFB(TFB),             // 1-bit output: 3-state control
   .TQ(TQ),               // 1-bit output: 3-state control
   .CLK(serial_clk),             // 1-bit input: High speed clock
   .CLKDIV(word_clk),       // 1-bit input: Divided clock
   // D1 - D8: 1-bit (each) input: Parallel data inputs (1-bit each)
   .D1(data_in[0]),
   .D2(data_in[1]),
   .D3(data_in[2]),
   .D4(data_in[3]),
   .D5(data_in[4]),
   .D6(data_in[5]),
   .D7(data_in[6]),
   .D8(data_in[7]),
   .OCE(1),                 // 1-bit input: Output data clock enable
   .RST(reset),             // 1-bit input: Reset
   // SHIFTIN1 / SHIFTIN2: 1-bit (each) input: Data input expansion (1-bit each)
   .SHIFTIN1(SHIFTOUT1),
   .SHIFTIN2(SHIFTOUT2),
   // T1 - T4: 1-bit (each) input: Parallel 3-state inputs
   .T1(0),
   .T2(0),
   .T3(0),
   .T4(0),
   .TBYTEIN(0),     // 1-bit input: Byte group tristate
   .TCE(1)              // 1-bit input: 3-state clock enable
);


OSERDESE2 #(
   .DATA_RATE_OQ("DDR"),   // DDR, SDR
   .DATA_RATE_TQ("DDR"),   // DDR, BUF, SDR
   .DATA_WIDTH(10),         // Parallel data width (2-8,10,14)
   .INIT_OQ(1'b0),         // Initial value of OQ output (1'b0,1'b1)
   .INIT_TQ(1'b0),         // Initial value of TQ output (1'b0,1'b1)
   .SERDES_MODE("SLAVE"), // MASTER, SLAVE
   .SRVAL_OQ(1'b0),        // OQ output value when SR is used (1'b0,1'b1)
   .SRVAL_TQ(1'b0),        // TQ output value when SR is used (1'b0,1'b1)
   .TBYTE_CTL("FALSE"),    // Enable tristate byte operation (FALSE, TRUE)
   .TBYTE_SRC("FALSE"),    // Tristate byte source (FALSE, TRUE)
   .TRISTATE_WIDTH(1)      // 3-state converter width (1,4)
) slave (
   .OFB(),             // 1-bit output: Feedback path for data
   .OQ(),               // 1-bit output: Data path output

   .CLK(serial_clk),             // 1-bit input: High speed clock
   .CLKDIV(word_clk),       // 1-bit input: Divided clock
   // D1 - D8: 1-bit (each) input: Parallel data inputs (1-bit each)
   .D3(data_in[8]),     // datasheet said to use these
   .D4(data_in[9]),     // https://docs.amd.com/v/u/en-US/ug471_7Series_SelectIO
   .OCE(1),             // 1-bit input: Output data clock enable
   .RST(reset),             // 1-bit input: Reset
   // SHIFTIN1 / SHIFTIN2: 1-bit (each) input: Data input expansion (1-bit each)
   .SHIFTOUT1(SHIFTOUT1),
   .SHIFTOUT2(SHIFTOUT2),
   // T1 - T4: 1-bit (each) input: Parallel 3-state inputs
   .T1(0),
   .T2(0),
   .T3(0),
   .T4(0),
   .TBYTEIN(0),         // 1-bit input: Byte group tristate
   .TCE(1)              // 1-bit input: 3-state clock enable SET TO 1 TO MAKE SURE THEY ARE DISABLED
);








endmodule