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
// File                  : ahbl2apb_top.v
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

`ifndef AHBL2APB_TOP
`define AHBL2APB_TOP

`timescale 1 ns / 1 ps

`include "lscc_ahbl_master_dummy.v"
`include "lscc_apb_slave_dummy.v"

module ahbl2apb_top (
input     clk_i              ,
input     rst_n_i            ,
input     pclk_i             ,
input     presetn_i          ,

input     ahbl_mstr_dummy_in ,
output    ahbl_mstr_dummy_out,
input     apb_slv_dummy_in   ,
output    apb_slv_dummy_out
);
`include "dut_params.v"

wire                  pclk_w          ;
wire                  presetn_w       ;
wire                  ahbl_hsel_i     ;
wire                  ahbl_hready_i   ;
wire [ADDR_WIDTH-1:0] ahbl_haddr_i    ;
wire [2:0]            ahbl_hburst_i   ;
wire [2:0]            ahbl_hsize_i    ;
wire                  ahbl_hmastlock_i;
wire [3:0]            ahbl_hprot_i    ;
wire [1:0]            ahbl_htrans_i   ;
wire                  ahbl_hwrite_i   ;
wire [DATA_WIDTH-1:0] ahbl_hwdata_i   ;
wire                  ahbl_hreadyout_o;
wire                  ahbl_hresp_o    ;
wire [DATA_WIDTH-1:0] ahbl_hrdata_o   ;
wire                  apb_psel_o      ;
wire [ADDR_WIDTH-1:0] apb_paddr_o     ;
wire [DATA_WIDTH-1:0] apb_pwdata_o    ;
wire                  apb_pwrite_o    ;
wire                  apb_penable_o   ;
wire                  apb_pready_i    ;
wire                  apb_pslverr_i   ;
wire [DATA_WIDTH-1:0] apb_prdata_i    ;

generate 
  if (APB_CLK_EN) begin : dual_clk 
    assign pclk_w     = pclk_i   ;
    assign presetn_w  = presetn_i;
  end
  else begin : single_clk
    assign pclk_w     = clk_i ;
    assign presetn_w  = rst_n_i;
  end
endgenerate

`include "dut_inst.v"

lscc_ahbl_master_dummy #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDR_WIDTH(ADDR_WIDTH)) 
ahbl_mst (
  .ahbl_hclk_i        (clk_i              ),
  .ahbl_hresetn_i     (rst_n_i            ),
  .ahbl_hsel_o        (ahbl_hsel_i        ),
  .ahbl_hready_o      (ahbl_hready_i      ),
  .ahbl_haddr_o       (ahbl_haddr_i       ),
  .ahbl_hburst_o      (ahbl_hburst_i      ),
  .ahbl_hsize_o       (ahbl_hsize_i       ),
  .ahbl_hmastlock_o   (ahbl_hmastlock_i   ),
  .ahbl_hprot_o       (ahbl_hprot_i       ),
  .ahbl_htrans_o      (ahbl_htrans_i      ),
  .ahbl_hwdata_o      (ahbl_hwdata_i      ),
  .ahbl_hwrite_o      (ahbl_hwrite_i      ),
  .ahbl_hreadyout_i   (ahbl_hreadyout_o   ),
  .ahbl_hresp_i       (ahbl_hresp_o       ),
  .ahbl_hrdata_i      (ahbl_hrdata_o      ),
  .ahbl_mstr_dummy_in (ahbl_mstr_dummy_in ),
  .ahbl_mstr_dummy_out(ahbl_mstr_dummy_out));
  
lscc_apb_slave_dummy #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDR_WIDTH(ADDR_WIDTH)) 
apb_slv (
  .apb_pclk_i       (pclk_w           ),
  .apb_presetn_i    (presetn_w        ),
  .apb_psel_i       (apb_psel_o       ),
  .apb_paddr_i      (apb_paddr_o      ),
  .apb_pwdata_i     (apb_pwdata_o     ),
  .apb_pwrite_i     (apb_pwrite_o     ),
  .apb_penable_i    (apb_penable_o    ),
  .apb_pready_o     (apb_pready_i     ),
  .apb_pslverr_o    (apb_pslverr_i    ),
  .apb_prdata_o     (apb_prdata_i     ),
  .apb_slv_dummy_in (apb_slv_dummy_in ),
  .apb_slv_dummy_out(apb_slv_dummy_out));
  
endmodule
`endif
