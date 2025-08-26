


module serdes_wrapper #(parameter SERDES_MODE = "Master", OFB_USED = "FALSE",
                        parameter IOBDELAY = "BOTH") (
    input logic serial_clk,  // 5x TMDS clock (sampled on +/- edges)
    input logic serial_clk_n, // USING THIS INVERTED CLOCK FROM THE MMCM IS BAD MAYBE
    input logic word_clk,    // TMDS clock speed (from serial_clk divider)
    input logic D, DDLY,
    input logic OFB,
    input logic CE,
    input logic BITSLIP,
    input logic SHIFTIN1,
    input logic SHIFTIN2,
    output logic SHIFTOUT1,
    output logic SHIFTOUT2,
    output logic Q1, Q2, Q3, Q4, Q5, Q6, Q7, Q8

);

ISERDESE2 #(
    .DATA_RATE("DDR"),           // DDR, SDR
    .DATA_WIDTH(10),              // Parallel data width (2-8,10,14)
    .DYN_CLKDIV_INV_EN("FALSE"), // Enable DYNCLKDIVINVSEL inversion (FALSE, TRUE)
    .DYN_CLK_INV_EN("FALSE"),    // Enable DYNCLKINVSEL inversion (FALSE, TRUE)
    // INIT_Q1 - INIT_Q4: Initial value on the Q outputs (0/1)
    .INIT_Q1(1'b0),
    .INIT_Q2(1'b0),
    .INIT_Q3(1'b0),
    .INIT_Q4(1'b0),
    .INTERFACE_TYPE("NETWORKING"),   // MEMORY, MEMORY_DDR3, MEMORY_QDR, NETWORKING, OVERSAMPLE
    .IOBDELAY(IOBDELAY),           // NONE, BOTH (USING DDLY), IBUF, IFD 
    .NUM_CE(1),                  // Number of clock enables (1,2)
    .OFB_USED(OFB_USED),          // Select OFB path (FALSE, TRUE)
    .SERDES_MODE(SERDES_MODE),      // MASTER, SLAVE
    // SRVAL_Q1 - SRVAL_Q4: Q output values when SR is used (0/1)
    .SRVAL_Q1(1'b0),
    .SRVAL_Q2(1'b0),
    .SRVAL_Q3(1'b0),
    .SRVAL_Q4(1'b0)
    )
    ISERDESE2_inst (
    .O(O),                       // 1-bit output: Combinatorial output
    // Q1 - Q8: 1-bit (each) output: Registered data outputs
    .Q1(Q1),
    .Q2(Q2),
    .Q3(Q3),
    .Q4(Q4),
    .Q5(Q5),
    .Q6(Q6),
    .Q7(Q7),
    .Q8(Q8),
    // SHIFTOUT1, SHIFTOUT2: 1-bit (each) output: Data width expansion output ports
    .SHIFTOUT1(SHIFTOUT1),
    .SHIFTOUT2(SHIFTOUT2),
    .BITSLIP(BITSLIP),           // 1-bit input: The BITSLIP pin performs a Bitslip operation synchronous to
                                    // CLKDIV when asserted (active High). Subsequently, the data seen on the Q1
                                    // to Q8 output ports will shift, as in a barrel-shifter operation, one
                                    // position every time Bitslip is invoked (DDR operation is different from
                                    // SDR).

    // CE1, CE2: 1-bit (each) input: Data register clock enable inputs
    .CE1(CE),
    .CLKDIVP(0),           // 1-bit input: TBD
    // Clocks: 1-bit (each) input: ISERDESE2 clock input ports
    .CLK(serial_clk),                   // 1-bit input: High-speed clock
    .CLKB(serial_clk_n),                 // 1-bit input: High-speed secondary clock
    .CLKDIV(word_clk),             // 1-bit input: Divided clock
    .OCLK(0),                 // 1-bit input: High speed output clock used when INTERFACE_TYPE="MEMORY"
    // Dynamic Clock Inversions: 1-bit (each) input: Dynamic clock inversion pins to switch clock polarity
    .DYNCLKDIVSEL(0), // 1-bit input: Dynamic CLKDIV inversion
    .DYNCLKSEL(0),       // 1-bit input: Dynamic CLK/CLKB inversion
    // Input Data: 1-bit (each) input: ISERDESE2 data input ports
    .D(D),                       // 1-bit input: Data input
    .DDLY(DDLY),                 // 1-bit input: Serial data from IDELAYE2
    .OFB(OFB),                   // 1-bit input: Data feedback from OSERDESE2
    .OCLKB(0),               // 1-bit input: High speed negative edge output clock
    .RST(0),                   // 1-bit input: Active high asynchronous reset
    // SHIFTIN1, SHIFTIN2: 1-bit (each) input: Data width expansion input ports
    .SHIFTIN1(SHIFTIN1),
    .SHIFTIN2(SHIFTIN2)
    );



endmodule