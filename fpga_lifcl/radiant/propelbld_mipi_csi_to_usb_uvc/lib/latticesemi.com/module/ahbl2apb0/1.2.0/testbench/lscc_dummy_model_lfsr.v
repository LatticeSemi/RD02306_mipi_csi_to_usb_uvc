// =============================================================================
// >>>>>>>>>>>>>>>>>>>>>>>>> COPYRIGHT NOTICE <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
// -----------------------------------------------------------------------------
//   Copyright (c) 2019 by Lattice Semiconductor Corporation
//   ALL RIGHTS RESERVED
// -----------------------------------------------------------------------------
//
//   Permission:
//
//      Lattice SG Pte. Ltd. grants permission to use this code
//      pursuant to the terms of the Lattice Reference Design License Agreement.
//
//
//   Disclaimer:
//
//      This VHDL or Verilog source code is intended as a design reference
//      which illustrates how these types of functions can be implemented.
//      It is the user's responsibility to verify their design for
//      consistency and functionality through the use of formal
//      verification methods.  Lattice provides no warranty
//      regarding the use or functionality of this code.
//
// -----------------------------------------------------------------------------
//
//                  Lattice SG Pte. Ltd.
//                  101 Thomson Road, United Square #07-02
//                  Singapore 307591
//
//
//                  TEL: 1-800-Lattice (USA and Canada)
//                       +65-6631-2000 (Singapore)
//                       +1-503-268-8001 (other locations)
//
//                  web: http://www.latticesemi.com/
//                  email: techsupport@latticesemi.com
//
// -----------------------------------------------------------------------------
//
// =============================================================================
//                         FILE DETAILS
// Project               :
// File                  : lscc_dummy_model_lfsr.v
// Title                 :
// Dependencies          : 1.
//                       : 2.
// Description           :
// =============================================================================
//                        REVISION HISTORY
// Version               : 1.0.0
// Author(s)             :
// Mod. Date             :
// Changes Made          : Initial release.
// =============================================================================
`ifndef LSCC_DUMMY_MODEL_LFSR
`define LSCC_DUMMY_MODEL_LFSR

`timescale 1 ns / 1 ps


module lscc_dummy_model_lfsr 
#(
parameter integer          LFSR_WIDTH = 8,
parameter [LFSR_WIDTH-1:0] POLYNOMIAL = 1,
parameter [LFSR_WIDTH-1:0] LFSR_INIT  = 1,
parameter                  O_PARALLEL = 1,  // 1 for inputs, 0 for outputs - 1 bit output
parameter integer          OUT_WIDTH  = (O_PARALLEL) ? LFSR_WIDTH : 1
)
(
input                   clk_i   , 
input                   rst_i   , 
input                   enb_i   , 
input                   add_i   , 
input  [LFSR_WIDTH-1:0] din_i   ,
output [OUT_WIDTH-1:0]  dout_o 
);
    
  reg                lfsr_xor  ;
  reg [LFSR_WIDTH-1:0] lfsr_mask ;
  reg [LFSR_WIDTH-1:0] lshifter_c;
  reg [LFSR_WIDTH-1:0] lshifter  ;

  always @( * ) begin
    lfsr_mask  = (lshifter & POLYNOMIAL);
    lfsr_xor   = ^lfsr_mask            ;
    
    lshifter_c = {lshifter[LFSR_WIDTH-2:0], (lfsr_xor)};
  end

always @(posedge clk_i or posedge rst_i)
begin
  if(rst_i) 
    lshifter <= LFSR_INIT ;
  else 
    if (add_i)
      lshifter <= din_i ^ lshifter_c;
    else if (enb_i) 
      lshifter <= lshifter_c;
end
assign dout_o = (O_PARALLEL) ? lshifter : lshifter[LFSR_WIDTH-1:LFSR_WIDTH-1];

endmodule

`endif