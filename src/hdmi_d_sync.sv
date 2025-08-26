



// import package constants
`include "core_pkg.svh"
import core_pkg::*;



module hdmi_d_sync #(parameter logic [22:0] WAIT_CLKS_P = 50e-3 * 125e6)
   (
   input logic clk_125,
   input logic serial_clk,  // 5x tmds clock (sampled on rising/falling edge)
   input logic serial_clk_n,
   input logic word_clk,
   input logic rst,
   input logic sync_en_p,   // strobe for 1 cycle to enter synchronization
   input logic datai_p,
   output logic [9:0] word_out_p,
   output logic synchronized,
   output logic [1:0] sync_state_p,

   // DEBUG OUTPUTS
   output logic bitslip_p,
   output logic [4:0] taps_p,
   output logic past_50ms_p
);



sync_state_t sync_state_n, sync_state_reg = INIT;
assign synchronized = sync_state_reg == SYNC;
assign sync_state_p = sync_state_reg;

logic [9:0] word_out;
assign word_out_p = word_out;


logic [4:0] taps_n, taps_reg = 0;                   // using 15 tap states
assign taps_p = taps_reg;

logic [4:0] last_taps_n, last_taps_reg = 0;         // store the last tap count to check in synchronization
logic [2:0] bitslip_cnt_n, bitslip_cnt_reg = 0;     // 8 bitslip states
logic do_bitslip_n, do_bitslip_reg = 0;
assign bitslip_p = do_bitslip_n;
logic load_new_taps_n, load_new_taps_reg = 0;
logic load_new_taps_dly = 0;
logic[2:0] num_found_n, num_found_reg = 0;

// signal going to/from the clk_125 counter
logic start_cnt_n, start_cnt_reg = 0;
(* ASYNC_REG = "TRUE"*) logic past_50ms_reg0, past_50ms_reg1, past_50ms_reg2 = 0;

logic past_50ms_reg = 0; // ** ON clk_125 DOMAIN

// Cominationally determine if the current word out is a control word
logic is_control_word;
assign is_control_word = (
   word_out == CONTROL_PERIOD_ENCODINGS_C[0] ||
   word_out == CONTROL_PERIOD_ENCODINGS_C[1] ||
   word_out == CONTROL_PERIOD_ENCODINGS_C[2] ||
   word_out == CONTROL_PERIOD_ENCODINGS_C[3]
);

always_comb begin
   // default values
   sync_state_n = sync_state_reg;
   start_cnt_n = 0;
   last_taps_n = last_taps_reg;
   taps_n = taps_reg;
   do_bitslip_n = 0; // Go to 0 unless explicitly says to be 1
   bitslip_cnt_n = bitslip_cnt_reg;
   load_new_taps_n = 0;
   num_found_n = 0;

   

   // next_state logic for state machine
   case (sync_state_reg)

      INIT: begin
         if (sync_en_p) begin
            sync_state_n = SEARCH_CTRL;
            start_cnt_n = 1; // Start the 50ms counter
            last_taps_n = taps_reg - 1; // save current starting taps
         end
      end

      SEARCH_CTRL: begin
         // Check if it matches any of the patterns
         if (is_control_word) begin
            num_found_n = 1;
            sync_state_n = FOUND_CTRL;
         end else if (past_50ms_reg1 && !past_50ms_reg2) begin
            // rising edge passing 50ms, change the values

            // reset timer and change taps or bitslip
            start_cnt_n = 1;
            
            // NEED TO LOAD NEW TAPS IN
            // ANOTHER DELAY REGISTER AFTER load_new_taps_n to make sure correct data is loaded
            taps_n = taps_reg + 1;
            load_new_taps_n = 1;
            
            // check if we went through all tap counts
            if (taps_reg == last_taps_reg) begin
               bitslip_cnt_n = bitslip_cnt_reg + 1;
               do_bitslip_n = 1;
            end else begin
               do_bitslip_n = 0;
            end
         end
      end

      FOUND_CTRL: begin
         // IF WE HAD REPEATED, GO TO SYNC STATE
         if (is_control_word) begin
            num_found_n = num_found_reg + 1;
            if (num_found_reg == 3'b111) begin
               sync_state_n = SYNC;
            end
         // OTHERWISE, GO BACK TO SEARCHING
         end else begin
            sync_state_n = SEARCH_CTRL;
         end
      end

      SYNC: begin
         // just stay in the state for now
         sync_state_n <= SYNC;//(sync_en_p) ? INIT : SYNC;
      end
      
      default: begin

      end
   endcase
end

// Register block for state machine
always_ff @(posedge word_clk) begin
   
   sync_state_reg <= sync_state_n;

   num_found_reg <= num_found_n;

   start_cnt_reg <= start_cnt_n;
   last_taps_reg <= last_taps_n;


   taps_reg <= taps_n;
   load_new_taps_reg <= load_new_taps_n;    // This will go high at the same time as new taps hit the register
   load_new_taps_dly <= load_new_taps_reg;  // This output will go to the actual module to load correct data

   do_bitslip_reg <= do_bitslip_n;
   bitslip_cnt_reg <= bitslip_cnt_n;

   // CDC from clk_125
   past_50ms_reg0 <= past_50ms_reg;
   past_50ms_reg1 <= past_50ms_reg0;
   past_50ms_reg2 <= past_50ms_reg1;

end


///////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////
// COUNT TO 50 MS IN THE CLK_125 CLOCK DOMAIN BECAUSE WE KNOW THAT SPEED
// Maximum of 50ms between extended control periods
// Extended control periods are when Synchronization can be done, since that is the only time repeated, recognizable characters are sent
// clk_125 domain
logic [22:0] cntr_50_mil_reg = 0;
//localparam int CLKS_50_MIL_C = 50e-3 * 125e6; // 50*10^-3 seconds * 125*10^6 cycles/second = 625e4
(* ASYNC_REG = "TRUE"*) logic start_cnt_reg0 = 0;
(* ASYNC_REG = "TRUE"*) logic start_cnt_reg1 = 0;

assign past_50ms_p = past_50ms_reg;

always_ff @(posedge clk_125) begin
   start_cnt_reg0 <= start_cnt_reg;
   start_cnt_reg1 <= start_cnt_reg0;

   if (start_cnt_reg1 == 1) begin
      cntr_50_mil_reg <= 0;
   end else if (cntr_50_mil_reg == WAIT_CLKS_P) begin
      cntr_50_mil_reg <= cntr_50_mil_reg;
   end else begin
      cntr_50_mil_reg <= cntr_50_mil_reg + 1;
   end 

   past_50ms_reg <= (cntr_50_mil_reg == WAIT_CLKS_P);
end
///////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

logic shiftout1_s, shiftout2_s;
logic data_dly_s;

(* IODELAY_GROUP = "delay_group" *)
IDELAYE2 #(
   .CINVCTRL_SEL("FALSE"),          // Enable dynamic clock inversion (FALSE, TRUE)
   .DELAY_SRC("IDATAIN"),           // Delay input (IDATAIN, DATAIN)
   .HIGH_PERFORMANCE_MODE("TRUE"), // Reduced jitter ("TRUE"), Reduced power ("FALSE")
   .IDELAY_TYPE("VAR_LOAD"),           // FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
   .IDELAY_VALUE(16),                // Input delay tap setting (0-31)
   .PIPE_SEL("FALSE"),              // Select pipelined mode, FALSE, TRUE
   .REFCLK_FREQUENCY(300.0),        // IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
   .SIGNAL_PATTERN("DATA")          // DATA, CLOCK input signal
)
IDELAYE2_inst (
   .DATAOUT(data_dly_s),         // 1-bit output: Delayed data output
   .C(word_clk),              // 1-bit input: Clock input, connect to CLKDIV from iserdese2
   .CE(1'b0),                    // 1-bit input: Active high enable increment/decrement input
   .CINVCTRL(1'b0),              // 1-bit input: Dynamic clock inversion input
   .CNTVALUEIN(taps_reg), // 5-bit input: Counter value input, only using 16 here
   .CNTVALUEOUT(),            // 5-bit output: Counter value output (reports back CNTVALUEIN)
   .DATAIN(1'b0),                // 1-bit input: Internal delay data input
   .IDATAIN(datai_p),         // 1-bit input: Data input from the I/O USE THIS ONE
   .INC(1'b0),                 // 1-bit input: Increment / Decrement tap delay input
   .LD(load_new_taps_dly),        // 1-bit input: Load IDELAY_VALUE input
   .LDPIPEEN(1'b0),              // 1-bit input: Enable PIPELINE register to load data input
   .REGRST(1'b0)                // 1-bit input: Active-high reset tap-delay input
);

// Instantiate master serdees2
serdes_wrapper #(
   .SERDES_MODE("MASTER"),
   .OFB_USED("FALSE"),
   .IOBDELAY("BOTH")
) master_serdes (
   .serial_clk(serial_clk),
   .serial_clk_n(serial_clk_n),
   .word_clk(word_clk),
   .rst(rst),
   .D(1'b0),
   .DDLY(data_dly_s),
   .OFB(1'b0),
   .CE(1'b1),
   .BITSLIP(do_bitslip_reg),
   .SHIFTOUT1(shiftout1_s),
   .SHIFTOUT2(shiftout2_s),
   .SHIFTIN1(1'b0),
   .SHIFTIN2(1'b0),
   .Q1(word_out[9]),
   .Q2(word_out[8]),
   .Q3(word_out[7]),
   .Q4(word_out[6]),
   .Q5(word_out[5]),
   .Q6(word_out[4]),
   .Q7(word_out[3]),
   .Q8(word_out[2])
);

// Instantiate slave serdese2
serdes_wrapper  #(
   .SERDES_MODE("SLAVE"),
   .OFB_USED("FALSE"),
   .IOBDELAY("BOTH")
) slave_serdes (
   .serial_clk(serial_clk),
   .serial_clk_n(serial_clk_n),
   .word_clk(word_clk),
   .rst(rst),
   .D(1'b0),
   .DDLY(1'b0),
   .OFB(1'b0),
   .CE(1'b1),
   .BITSLIP(do_bitslip_reg),
   .SHIFTIN1(shiftout1_s),
   .SHIFTIN2(shiftout2_s),
   .SHIFTOUT1(),
   .SHIFTOUT2(),
   .Q3(word_out[1]),     // datasheet said to use these
   .Q4(word_out[0])
);

endmodule