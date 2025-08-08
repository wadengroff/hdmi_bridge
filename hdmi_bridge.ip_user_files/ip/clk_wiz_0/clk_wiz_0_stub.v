// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2023.2 (win64) Build 4029153 Fri Oct 13 20:14:34 MDT 2023
// Date        : Thu Aug  7 23:28:56 2025
// Host        : wgroff running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               c:/Users/waden/Documents/VivadoProjects/hdmi_bridge/hdmi_bridge.gen/sources_1/ip/clk_wiz_0/clk_wiz_0_stub.v
// Design      : clk_wiz_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z020clg400-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
module clk_wiz_0(serial_clk, serial_clk_n, reset, 
  input_clk_stopped, locked, clk_in1_p, clk_in1_n)
/* synthesis syn_black_box black_box_pad_pin="reset,input_clk_stopped,locked,clk_in1_p,clk_in1_n" */
/* synthesis syn_force_seq_prim="serial_clk" */
/* synthesis syn_force_seq_prim="serial_clk_n" */;
  output serial_clk /* synthesis syn_isclock = 1 */;
  output serial_clk_n /* synthesis syn_isclock = 1 */;
  input reset;
  output input_clk_stopped;
  output locked;
  input clk_in1_p;
  input clk_in1_n;
endmodule
