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
// File                  : lscc_apb_slave_dummy.v
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

`ifndef LSCC_APB_SLAVE_DUMMY
`define LSCC_APB_SLAVE_DUMMY

`include "lscc_dummy_model_lfsr.v"

module lscc_apb_slave_dummy 
#(
parameter               DATA_WIDTH = 32,
parameter               ADDR_WIDTH = 32
) 
(
// Clock and Reset
input                   apb_pclk_i   ,
input                   apb_presetn_i,
// AHB-Lite I/F
input                   apb_psel_i   ,
input  [ADDR_WIDTH-1:0] apb_paddr_i  ,
input  [DATA_WIDTH-1:0] apb_pwdata_i ,
input                   apb_pwrite_i ,
input                   apb_penable_i,
output reg              apb_pready_o ,
output reg              apb_pslverr_o,
output [DATA_WIDTH-1:0] apb_prdata_o ,

input                   apb_slv_dummy_in ,
output reg              apb_slv_dummy_out
);

localparam [ADDR_WIDTH-1:0] ADDR_POLY  = {1'b1,{(ADDR_WIDTH/2-1){1'b0}},1'b1,{(ADDR_WIDTH/2-4){1'b0}},3'h4};
localparam [ADDR_WIDTH-1:0] ADDR_INIT  = {{(ADDR_WIDTH-3){1'b0}},3'h4};
localparam [DATA_WIDTH-1:0] DATA_POLY  = {8'hB8,{(DATA_WIDTH-8){1'b0}}};
localparam [DATA_WIDTH-1:0] DATA_INIT  = {(DATA_WIDTH/8){8'hA5}};


reg                   dummy_in_r    ;
reg                   rdata_gen_en_r;

wire                  addr_gen_en_w   ;
wire                  wdata_gen_en_w  ;
wire                  addr_lfsr_out_w ;
wire                  wdata_lfsr_out_w;
wire                  preset_w        ;


assign addr_gen_en_w    = dummy_in_r & apb_psel_i & ~apb_penable_i;
assign wdata_gen_en_w   = dummy_in_r & apb_psel_i & ~apb_penable_i;
assign preset_w         = ~apb_presetn_i;


  always @(posedge apb_pclk_i or negedge apb_presetn_i) begin
    if (~apb_presetn_i) begin
      dummy_in_r         <= 1'b0;
      apb_pready_o       <= 1'b0;
      apb_pslverr_o      <= 1'b0;
      rdata_gen_en_r     <= 1'b0;
      apb_slv_dummy_out  <= 1'b0;
    end
    else begin
      dummy_in_r         <= apb_slv_dummy_in;
      if (~apb_pready_o & dummy_in_r & apb_psel_i & apb_penable_i) begin
        apb_pready_o     <= 1'b1;
        apb_pslverr_o    <= addr_lfsr_out_w ^ wdata_lfsr_out_w ^ apb_prdata_o[DATA_WIDTH-1];
      end
      else if (apb_pready_o) begin
        apb_pready_o     <= 1'b0;
        apb_pslverr_o    <= 1'b0;
      end
      rdata_gen_en_r     <= (apb_psel_i && ~apb_penable_i) ? ~apb_pwrite_i : 1'b0;
      apb_slv_dummy_out  <= addr_lfsr_out_w ^ wdata_lfsr_out_w;
    end
  end

  // LFSR for address
  lscc_dummy_model_lfsr #(
      .LFSR_WIDTH (ADDR_WIDTH),
      .POLYNOMIAL (ADDR_POLY ),
      .LFSR_INIT  (ADDR_INIT ),
      .O_PARALLEL (0         ))
    addr_gen (
      .clk_i      (apb_pclk_i     ), 
      .rst_i      (preset_w       ), 
      .enb_i      (dummy_in_r     ), 
      .add_i      (addr_gen_en_w  ),
      .din_i      (apb_paddr_i    ),
      .dout_o     (addr_lfsr_out_w));

  // LFSR for write data
  lscc_dummy_model_lfsr #(
      .LFSR_WIDTH (DATA_WIDTH),
      .POLYNOMIAL (DATA_POLY ),
      .LFSR_INIT  (DATA_INIT ),
      .O_PARALLEL (0         ))
    wdata_gen (
      .clk_i      (apb_pclk_i      ), 
      .rst_i      (preset_w        ), 
      .enb_i      (dummy_in_r      ), 
      .add_i      (wdata_gen_en_w  ),
      .din_i      (apb_pwdata_i    ),
      .dout_o     (wdata_lfsr_out_w));

  // LFSR for read data
  lscc_dummy_model_lfsr #(
      .LFSR_WIDTH (DATA_WIDTH),
      .POLYNOMIAL (DATA_POLY ),
      .LFSR_INIT  (DATA_INIT ),
      .O_PARALLEL (1         ))
    rdata_gen (
      .clk_i      (apb_pclk_i    ), 
      .rst_i      (preset_w      ), 
      .add_i      (1'b0          ),
      .din_i      ({DATA_WIDTH{1'b0}}),
      .enb_i      (rdata_gen_en_r), 
      .dout_o     (apb_prdata_o  ));
endmodule
`endif

