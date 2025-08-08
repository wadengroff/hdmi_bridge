



// import package constants
`include "core_pkg.svh"
import core_pkg::*;



module hdmi_d_sync
   (
   input logic serial_clk,  // 5x tmds clock (sampled on rising/falling edge)
   input logic serial_clk_n,
   input logic word_clk,
   input logic sync_en_p,   // strobe for 1 cycle to enter synchronization
   input logic datai_p,
   output logic [9:0] word_out_p,
   output logic synchronized,
   output logic [1:0] control_outputs_p,

   // DEBUG OUTPUTS
   output bitslip_p
);


logic bitslip_s;
assign bitslip_p = bitslip_s; // DEBUG

logic shiftout1_s, shiftout2_s;

logic [3:0] taps = 0;
logic change_taps_s;
logic data_dly_s;

logic [3:0] tap_cnt_s = 0;
logic [2:0] bitslip_cnt_s = 0; // There are 8 bitslip states


logic [9:0] word_out;
assign word_out_p = word_out;

typedef enum logic {
   UNSYNC,
   SYNC
} sync_state_t;



sync_state_t sync_state_s = UNSYNC;

assign synchronized = (sync_state_s == SYNC) ? 1:0;

always_ff @(posedge word_clk) begin
   sync_state_s <= sync_state_s;
   tap_cnt_s <= tap_cnt_s;
   bitslip_cnt_s <= bitslip_cnt_s;
   bitslip_s <= 0;
   change_taps_s <= 0;

   if (sync_state_s == SYNC) begin
      if (sync_en_p) begin       // go into synchronization mode
         sync_state_s <= UNSYNC;
         bitslip_cnt_s <= 0;
         tap_cnt_s <= 0;
      end
   end else if (sync_state_s == UNSYNC) begin

      // Check if it matches any of the patterns, otherwise change parameters
      case (word_out)
         CONTROL_PERIOD_ENCODINGS_C[0]: begin
            sync_state_s <= SYNC;
            control_outputs_p <= 0;
         end
         CONTROL_PERIOD_ENCODINGS_C[1]: begin
            sync_state_s <= SYNC;
            control_outputs_p <= 1;
         end
         CONTROL_PERIOD_ENCODINGS_C[2]: begin
            sync_state_s <= SYNC;
            control_outputs_p <= 2;
         end
         CONTROL_PERIOD_ENCODINGS_C[3]: begin
            sync_state_s <= SYNC;
            control_outputs_p <= 3;
         end
         default: begin
            // always add 1 to the number of taps
            taps <= taps + 1;
            change_taps_s <= 1;

            // If we went through all taps, reset and change bitslip
            if (tap_cnt_s == 4'b1111) begin
               tap_cnt_s <= 0;
               bitslip_cnt_s <= bitslip_cnt_s + 1;
               bitslip_s <= 1;
            end else begin
               tap_cnt_s <= tap_cnt_s + 1;
            end
         end
      endcase

   end
end


(* IODELAY_GROUP = "delay_group" *)
IDELAYE2 #(
   .CINVCTRL_SEL("FALSE"),          // Enable dynamic clock inversion (FALSE, TRUE)
   .DELAY_SRC("IDATAIN"),           // Delay input (IDATAIN, DATAIN)
   .HIGH_PERFORMANCE_MODE("TRUE"), // Reduced jitter ("TRUE"), Reduced power ("FALSE")
   .IDELAY_TYPE("VAR_LOAD"),           // FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
   .IDELAY_VALUE(16),                // Input delay tap setting (0-31)
   .PIPE_SEL("FALSE"),              // Select pipelined mode, FALSE, TRUE
   .REFCLK_FREQUENCY(200.0),        // IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
   .SIGNAL_PATTERN("DATA")          // DATA, CLOCK input signal
)
IDELAYE2_inst (
   .DATAOUT(data_dly_s),         // 1-bit output: Delayed data output
   .C(word_clk),              // 1-bit input: Clock input, connect to CLKDIV from iserdese2
   .CE(0),                    // 1-bit input: Active high enable increment/decrement input
   .CINVCTRL(0),              // 1-bit input: Dynamic clock inversion input
   .CNTVALUEIN({1'b0, taps}), // 5-bit input: Counter value input, only using 16 here
   .CNTVALUEOUT(),            // 5-bit output: Counter value output (reports back CNTVALUEIN)
   .DATAIN(0),                // 1-bit input: Internal delay data input
   .IDATAIN(datai_p),         // 1-bit input: Data input from the I/O USE THIS ONE
   .INC(0),                 // 1-bit input: Increment / Decrement tap delay input
   .LD(change_taps_s),        // 1-bit input: Load IDELAY_VALUE input
   .LDPIPEEN(0),              // 1-bit input: Enable PIPELINE register to load data input
   .REGRST(0)                // 1-bit input: Active-high reset tap-delay input
);

// Instantiate master serdees2
serdes_wrapper #(
   .SERDES_MODE("Master")
) master_serdes (
   .serial_clk(serial_clk),
   .serial_clk_n(serial_clk_n),
   .word_clk(word_clk),
   .D(datai_p),
   .DDLY(data_dly_s),
   .CE(1),
   .BITSLIP(bitslip_s),
   .SHIFTOUT1(shiftout1_s),
   .SHIFTOUT2(shiftout2_s),
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
   .SERDES_MODE("Slave")
) slave_serdes (
   .serial_clk(serial_clk),
   .serial_clk_n(serial_clk_n),
   .word_clk(word_clk),
   .D(0),
   .DDLY(0),
   .CE(1),
   .BITSLIP(bitslip_s),
   .SHIFTIN1(shiftout1_s),
   .SHIFTIN2(shiftout2_s),
   .Q3(word_out[1]),     // datasheet said to use these
   .Q4(word_out[0])
);

endmodule