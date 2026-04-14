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
// File                  : lscc_ahbl_master_dummy.v
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

`ifndef LSCC_AHBL_MASTER_DUMMY
`define LSCC_AHBL_MASTER_DUMMY

`include "lscc_dummy_model_lfsr.v"

module lscc_ahbl_master_dummy 
#(
parameter               DATA_WIDTH = 32,
parameter               ADDR_WIDTH = 32
) 
(
// Clock and Reset
input                   ahbl_hclk_i        ,
input                   ahbl_hresetn_i     ,
// AHB-Lite I/F
output                  ahbl_hsel_o        ,
output                  ahbl_hready_o      ,
output [ADDR_WIDTH-1:0] ahbl_haddr_o       ,
output [2:0]            ahbl_hburst_o      ,
output [2:0]            ahbl_hsize_o       ,
output                  ahbl_hmastlock_o   ,
output [3:0]            ahbl_hprot_o       ,
output [1:0]            ahbl_htrans_o      ,
output [DATA_WIDTH-1:0] ahbl_hwdata_o      ,
output                  ahbl_hwrite_o      ,
input                   ahbl_hreadyout_i   ,
input                   ahbl_hresp_i       ,
input  [DATA_WIDTH-1:0] ahbl_hrdata_i      ,

input                   ahbl_mstr_dummy_in ,
output                  ahbl_mstr_dummy_out
);

localparam [ADDR_WIDTH-1:0] ADDR_POLY  = {1'b1,{(ADDR_WIDTH/2-1){1'b0}},1'b1,{(ADDR_WIDTH/2-4){1'b0}},3'h4};
localparam [ADDR_WIDTH-1:0] ADDR_INIT  = {{(ADDR_WIDTH-3){1'b0}},3'h4};
localparam                  CTRL_WIDTH = 15;
localparam [CTRL_WIDTH-1:0] CTRL_POLY  = 15'h6000;
localparam [CTRL_WIDTH-1:0] CTRL_INIT  = 15'h0005;
localparam [DATA_WIDTH-1:0] DATA_POLY  = {8'hB8,{(DATA_WIDTH-8){1'b0}}};
localparam [DATA_WIDTH-1:0] DATA_INIT  = {(DATA_WIDTH/8){8'hA5}};


reg                   dummy_in_r;
reg                   wdata_en_r;
reg                   rdata_en_r;

wire                  addr_gen_en_w;
wire                  wdata_gen_en_w;
wire                  rdata_ld_en_w;
wire                  rdata_gen_en_w;
wire [CTRL_WIDTH-1:0] ahbl_control_w;
wire                  hreset_w;

assign hreset_w         = ~ahbl_hresetn_i;

assign addr_gen_en_w    = dummy_in_r & ahbl_hreadyout_i & ~ahbl_hresp_i;
assign wdata_gen_en_w   = wdata_en_r & ahbl_hreadyout_i;
assign rdata_ld_en_w    = rdata_en_r & ahbl_hreadyout_i;
assign rdata_gen_en_w   = rdata_en_r & ~ahbl_hreadyout_i;

assign ahbl_hready_o    = ahbl_hreadyout_i     ;
assign ahbl_hsel_o      = 1'b1;
//assign ahbl_hsel_o      = ahbl_control_w[14:14];
assign ahbl_hburst_o    = ahbl_control_w[13:11];
assign ahbl_hsize_o     = ahbl_control_w[10: 8];
assign ahbl_hmastlock_o = ahbl_control_w[7 : 7];
assign ahbl_hprot_o     = ahbl_control_w[6 : 3];
assign ahbl_htrans_o    = ahbl_control_w[2 : 1];
assign ahbl_hwrite_o    = ahbl_control_w[0 : 0];



  always @(posedge ahbl_hclk_i or negedge ahbl_hresetn_i) begin
    if (~ahbl_hresetn_i) begin
      dummy_in_r        <= 1'b0;
      wdata_en_r        <= 1'b0; 
      rdata_en_r        <= 1'b0;
    end
    else begin
      dummy_in_r        <= ahbl_mstr_dummy_in;
      if (ahbl_control_w[2:2] & ahbl_hreadyout_i) begin
        if (ahbl_control_w[0:0]) begin
          wdata_en_r    <= 1'b1;
          rdata_en_r    <= 1'b0;
        end
        else begin
          wdata_en_r    <= 1'b0;
          rdata_en_r    <= 1'b1;
        end
      end
      else if (ahbl_hreadyout_i) begin
        wdata_en_r      <= 1'b0;
        rdata_en_r      <= 1'b0;
      end
    end
  end

  // LFSR for address
  lscc_dummy_model_lfsr #(
      .LFSR_WIDTH (ADDR_WIDTH),
      .POLYNOMIAL (ADDR_POLY ),
      .LFSR_INIT  (ADDR_INIT ),
      .O_PARALLEL (1         ))
    addr_gen (
      .clk_i      (ahbl_hclk_i   ), 
      .rst_i      (hreset_w      ), 
      .add_i      (1'b0          ),
      .enb_i      (addr_gen_en_w ),
      .din_i      ({ADDR_WIDTH{1'b0}}),
      .dout_o     (ahbl_haddr_o  ));
      
  // LFSR for control
  lscc_dummy_model_lfsr #(
      .LFSR_WIDTH (CTRL_WIDTH),
      .POLYNOMIAL (CTRL_POLY ),
      .LFSR_INIT  (CTRL_INIT ),
      .O_PARALLEL (1         ))
    ctrl_gen (
      .clk_i      (ahbl_hclk_i   ), 
      .rst_i      (hreset_w), 
      .add_i      (1'b0          ),
      .enb_i      (addr_gen_en_w ), 
      .din_i      ({CTRL_WIDTH{1'b0}}),
      .dout_o     (ahbl_control_w));
      
  // LFSR for write data
  lscc_dummy_model_lfsr #(
      .LFSR_WIDTH (DATA_WIDTH),
      .POLYNOMIAL (DATA_POLY ),
      .LFSR_INIT  (DATA_INIT ),
      .O_PARALLEL (1         ))
    wdata_gen (
      .clk_i      (ahbl_hclk_i       ), 
      .rst_i      (hreset_w          ), 
      .add_i      (1'b0              ),
      .enb_i      (wdata_gen_en_w    ),
      .din_i      ({DATA_WIDTH{1'b0}}),      
      .dout_o     (ahbl_hwdata_o     ));

  // LFSR for read data
  lscc_dummy_model_lfsr #(
      .LFSR_WIDTH (DATA_WIDTH),
      .POLYNOMIAL (DATA_POLY ),
      .LFSR_INIT  (DATA_INIT ),
      .O_PARALLEL (0         ))
    rdata_gen (
      .clk_i      (ahbl_hclk_i        ), 
      .rst_i      (hreset_w           ), 
      .add_i      (rdata_ld_en_w      ),
      .enb_i      (rdata_gen_en_w     ), 
      .din_i      (ahbl_hrdata_i      ),
      .dout_o     (ahbl_mstr_dummy_out));
endmodule

`endif
