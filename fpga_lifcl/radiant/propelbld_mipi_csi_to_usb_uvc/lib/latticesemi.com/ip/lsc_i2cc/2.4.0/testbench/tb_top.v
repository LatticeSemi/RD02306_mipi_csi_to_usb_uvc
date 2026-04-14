// =============================================================================
// >>>>>>>>>>>>>>>>>>>>>>>>> COPYRIGHT NOTICE <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
// -----------------------------------------------------------------------------
// Copyright (c) 2019 by Lattice Semiconductor Corporation
// ALL RIGHTS RESERVED
// --------------------------------------------------------------------
//
// Permission:
//
// Lattice SG Pte. Ltd. grants permission to use this code
// pursuant to the terms of the Lattice Reference Design License Agreement.
//
//
// Disclaimer:
//
// This VHDL or Verilog source code is intended as a design reference
// which illustrates how these types of functions can be implemented.
// It is the user's responsibility to verify their design for
// consistency and functionality through the use of formal
// verification methods. Lattice provides no warranty
// regarding the use or functionality of this code.
//
// -----------------------------------------------------------------------------
//
//                     Lattice SG Pte. Ltd.
//                     101 Thomson Road, United Square #07-02
//                     Singapore 307591
//
//
//                     TEL: 1-800-Lattice (USA and Canada)
//                     +65-6631-2000 (Singapore)
//                     +1-503-268-8001 (other locations)
//
//                     web: http://www.latticesemi.com/
//                     email: techsupport@latticesemi.com
//
// -----------------------------------------------------------------------------
//
// =============================================================================
// FILE DETAILS
// Project : <UART>
// File : tb_top.v
// Title :
// Dependencies : 1.
//              : 2.
// Description :
// =============================================================================
// REVISION HISTORY
// Version : 1.0
// Author(s) :
// Mod. Date : 06/28/2019
// Changes Made : Initial version of RTL
// -----------------------------------------------------------------------------
// Version : 1.0
// Author(s) :
// Mod. Date :
// Changes Made :
// =============================================================================
//--------------------------------------------------------------------------------------------------

`ifndef TB_TOP
`define TB_TOP
`timescale 1ns/1ps

`include "tb_lmmi_mst.v"
`include "lscc_lmmi2apb.v"
`include "i2c_target_model.v"

module tb_top;

`include "dut_params.v"

// -----------------------------------------------------------------------------
// Parameters
// -----------------------------------------------------------------------------
parameter  integer SYS_CLK_PERIOD    = 1000 / SYS_CLOCK_FREQ;

// Localparams
localparam    REG_OUTPUT   = 1 ;
localparam    DATA_WIDTH   = 8;

//********************************************************************************
// Internal Reg/Wires
//********************************************************************************

// Clock and Reset Signals
reg                      clk_i      ;
reg                      rst_i      ;
reg                      rst_n_i    ;

// wires connected to DUT when LMMI I/F
wire                     lmmi_request_i    ; 
wire                     lmmi_wr_rdn_i     ; 
wire [3:0]               lmmi_offset_i     ; 
wire [DATA_WIDTH-1:0]    lmmi_wdata_i      ; 
wire                     lmmi_ready_o      ;
wire [DATA_WIDTH-1:0]    lmmi_rdata_o      ; 
wire                     lmmi_rdata_valid_o; 
// wires connected to DUT when APB I/F
wire                     apb_penable_i   ; 
wire                     apb_psel_i      ; 
wire                     apb_pwrite_i    ; 
wire [5:0]               apb_paddr_i     ; 
wire [31:0]              apb_pwdata_i    ; 
wire                     apb_pready_o    ; 
wire                     apb_pslverr_o   ; 
wire [31:0]              apb_prdata_o    ; 

// Interrupt
wire                     int_o;

// I2C I/F
tri1                     scl_io;
tri1                     sda_io;
wire                     scl_i;
wire                     scl_oe_o;
wire                     sda_i;
wire                     sda_oe_o;

wire rx_flag;
wire tx_flag;

// -----------------------------------------------------------------------------
// Clock Generator
// -----------------------------------------------------------------------------
initial begin
  clk_i     = 0;
end

always #(SYS_CLK_PERIOD/2) clk_i = ~clk_i;

// -----------------------------------------------------------------------------
// Reset Signals
// -----------------------------------------------------------------------------
initial begin
  rst_i     = 1;
  rst_n_i   = 0;
  #(10*SYS_CLK_PERIOD)
  rst_i     = 0;
  rst_n_i   = 1;
end
  
// ----------------------------
// GSR instance
// ----------------------------
`ifndef iCE40UP
  `ifdef ap6a00a
  GSRA GSR_INST (.GSR_N  (rst_n_i));
  `elsif LAV_AT
  GSRA GSR_INST (.GSR_N  (rst_n_i));
  `elsif LKH_CT_20
  GSRA GSR_INST (.GSR_N  (rst_n_i));
  `elsif LKH_MH_20
  GSRA GSR_INST (.GSR_N  (rst_n_i));
  `elsif LFMXO4
  GSR GSR_INST (.CLK(clk_i) ,.GSR  (~rst_n_i), .GSROUT());
  `else
  GSR GSR_INST (.CLK(clk_i) ,.GSR_N  (rst_n_i));
  `endif
`endif

`include "dut_inst.v"

i2c_slave_model #(
  .I2C_ADR   (7'b0101_1010),
  .MEM_DEPTH (FIFO_DEPTH  ),
  .MDL_NAME  ("I2C_SLV_0")
)
i2c_slv_0 (
  .scl       (scl_io),
  .sda       (sda_io),
  .rx_flag   (rx_flag),
  .tx_flag   (tx_flag)
);


tb_lmmi_mst #(
  .AWIDTH          (4         ),
  .DWIDTH          (DATA_WIDTH))
lmmi_mst_0 (
  .lmmi_clk        (clk_i             ),
  .lmmi_resetn     (rst_n_i           ),
  .lmmi_rdata      (lmmi_rdata_o      ),
  .lmmi_rdata_valid(lmmi_rdata_valid_o),
  .lmmi_ready      (lmmi_ready_o      ),
  .lmmi_offset     (lmmi_offset_i     ),
  .lmmi_request    (lmmi_request_i    ),
  .lmmi_wdata      (lmmi_wdata_i      ),
  .lmmi_wr_rdn     (lmmi_wr_rdn_i     )
);

generate
  if (APB_ENABLE == 1) begin: apb_en
    lscc_lmmi2apb # (
      .DATA_WIDTH(DATA_WIDTH   ),
      .ADDR_WIDTH(6            ),
      .REG_OUTPUT(1            ))
    lmmi2apb_0 (
      .clk_i             (clk_i             ),
      .rst_n_i           (rst_n_i           ),
      .lmmi_request_i    (lmmi_request_i    ),
      .lmmi_wr_rdn_i     (lmmi_wr_rdn_i     ),
      .lmmi_offset_i     ({lmmi_offset_i,2'b00}),
      .lmmi_wdata_i      (lmmi_wdata_i      ),
      .lmmi_ready_o      (lmmi_ready_o      ),
      .lmmi_rdata_valid_o(lmmi_rdata_valid_o),
      .lmmi_ext_error_o  (                  ), // unconnected
      .lmmi_rdata_o      (lmmi_rdata_o      ),
      .lmmi_resetn_o     (                  ), // unconnected
      .apb_pready_i      (apb_pready_o      ),
      .apb_pslverr_i     (apb_pslverr_o     ),
      .apb_prdata_i      (apb_prdata_o[DATA_WIDTH-1:0]),
      .apb_penable_o     (apb_penable_i     ),
      .apb_psel_o        (apb_psel_i        ),
      .apb_pwrite_o      (apb_pwrite_i      ),
      .apb_paddr_o       (apb_paddr_i       ),
      .apb_pwdata_o      (apb_pwdata_i[7:0] ));
      
    assign apb_pwdata_i[31:8] = 24'h000000;
  end
endgenerate

generate
    if (REMOVE_TRISTATE == 1) begin
        BB
        u_BB_sclk(
          .B(scl_io),
          .I(scl_o),
          .O(scl_i),
          .T(scl_oe_o)
        );
        BB
        u_BB_sda(
          .B(sda_io),
          .I(sda_o),
          .O(sda_i),
          .T(sda_oe_o)
        );
    end
endgenerate

integer i, j;
integer error_count;

localparam ADDR_DATA         = 4'h0;
localparam ADDR_SLV_ADDRL    = 4'h1;
localparam ADDR_SLV_ADDRH    = 4'h2;
localparam ADDR_CONTROL      = 4'h3;
localparam ADDR_TGT_BYTE_CNT = 4'h4;
localparam ADDR_MODE_REG     = 4'h5;
localparam ADDR_CLK_PRESCL   = 4'h6;
localparam ADDR_INT_STATUS1  = 4'h7;
localparam ADDR_INT_ENABLE1  = 4'h8;
localparam ADDR_INT_SET1     = 4'h9;
localparam ADDR_INT_STATUS2  = 4'hA;
localparam ADDR_INT_ENABLE2  = 4'hB;
localparam ADDR_INT_SET2     = 4'hC;
localparam ADDR_FIFO_STATUS  = 4'hD;
localparam ADDR_SCL_TIMEOUT  = 4'hE;

localparam TARGET_COUNT  = (FIFO_DEPTH-TX_FIFO_AE_FLAG+1);

//localparam ADDR_10B = (ADDR_MODE == 7) ? 1'b0: 1'b1;

reg [25:0]   reg_list[0:13];
reg [8*23:1] reg_names[0:13];

reg [8:0] tx_fifo_count;
reg [8:0] rx_fifo_count;
reg [8:0] tx_i2c_count_r;

reg [7:0] exp_status;
reg [7:0] int_status;
reg [7:0] int_enable;
reg [7:0] trg_count;



initial begin // initialize register list
  // reg_type = 2'b00 - do not check
  // reg_type = 2'b01 - read only
  // reg_type = 2'b10 - write only
  // reg_type = 2'b11 - R/W
  // { reg_type, exp_value, writable_bits, reset value}
  reg_list[0]  = {2'b00, 8'h00, 8'h00, 8'h00};            // DATA_REG
  reg_list[1]  = {2'b11, 8'h00, 8'h7F, 8'h00};            // SLV_ADDRL
  reg_list[2]  = {2'b11, 8'h00, 8'h07, 8'h00};            // SLV_ADDRH
  reg_list[3]  = {2'b00, 8'h00, 8'h07, 8'h00};            // CONTROL     
  reg_list[4]  = {2'b11, 8'h00, 8'hFF, 8'h00};            // TGT_BYTE_CNT
  reg_list[5]  = {2'b00, 8'h00, 8'hFF, {5'h00,PRESCALER[10:8]}};  // MODE        
  reg_list[6]  = {2'b11, 8'h00, 8'hFF, PRESCALER[7:0]};   // CLK_PRESCL  
  reg_list[7]  = {2'b00, 8'h00, 8'hBF, 8'h00};            // INT_STATUS1 
  reg_list[8]  = {2'b11, 8'h00, 8'hBF, 8'h00};            // INT_ENABLE1 
  reg_list[9]  = {2'b10, 8'h00, 8'hBF, 8'h00};            // INT_SET1    
  reg_list[10] = {2'b00, 8'h00, 8'h0F, 8'h00};            // INT_STATUS2 
  reg_list[11] = {2'b11, 8'h00, 8'h0F, 8'h00};            // INT_ENABLE2 
  reg_list[12] = {2'b10, 8'h00, 8'h0F, 8'h00};            // INT_SET2    
  reg_list[13] = {2'b01, 8'h00, 8'h00, 8'h19};            // FIFO_STATUS 
  reg_list[14] = {2'b11, 8'h00, 8'hFF, 8'h00};            // SCL_TIMEOUT 
  reg_names[ 0] = "DATA_REG";
  reg_names[ 1] = "SLV_ADDRL_REG";
  reg_names[ 2] = "SLV_ADDRH_REG";
  reg_names[ 3] = "CONTROL_REG";
  reg_names[ 4] = "TGT_BYTE_CNT_REG";
  reg_names[ 5] = "MODE_REG";
  reg_names[ 6] = "CLK_PRESCL_REG";
  reg_names[ 7] = "INT_STATUS1_REG";
  reg_names[ 8] = "INT_ENABLE1_REG";
  reg_names[ 9] = "INT_SET1_REG";
  reg_names[10] = "INT_STATUS2_REG";
  reg_names[11] = "INT_ENABLE2_REG";
  reg_names[12] = "INT_SET2_REG";
  reg_names[13] = "FIFO_STATUS_REG";
  reg_names[14] = "SCL_TIMEOUT_REG";
end

// Test
initial begin
  error_count = 0;
  trg_count = TARGET_COUNT < 256 ? TARGET_COUNT : {8{1'b1}};
  repeat(20) @(posedge clk_i); // wait for some time
  register_check();
  reset_during_idle();
  normal_operation_test();
  @(posedge clk_i);
  if ((error_count == 0) && (i2c_slv_0.error_cnt== 0))
    $display("\n[%010t] [TEST]: SIMULATION PASSED \n", $time);
  else
    $display("\n[%010t] [TEST]: SIMULATION FAILED - No of Errors = %0d.\n", $time, error_count);
  $finish;
end

task reduce_tx_fifo();
    begin
        @(negedge rx_flag)
        for (i=1; i<7; i=i+1) @(posedge clk_i); // just wait for some time
        if (tx_i2c_count_r != trg_count)
            tx_fifo_count = tx_fifo_count - 1;
    end
endtask

task increment_rx_fifo();
    begin
        @(negedge tx_flag)
        for (i=1; i<7; i=i+1) @(posedge clk_i); // just wait for some time
        rx_fifo_count = rx_fifo_count + 1;
    end
endtask

always @(posedge rx_flag)
    begin
        tx_i2c_count_r = tx_i2c_count_r + 1;
        reduce_tx_fifo();
    end

always @(posedge tx_flag)
    begin
        tx_i2c_count_r = tx_i2c_count_r + 1;
        increment_rx_fifo();
    end

// Test routines
task register_check();
  reg [DATA_WIDTH-1:0]  wr_data;
  reg [DATA_WIDTH-1:0]  rd_data;
  begin
    $display("\n[%010t] [TEST]: Register access test start!", $time);
    // Set Expected read data to default
    rd_check_all_regs_default();
    $display("[%010t] [TEST]: Register access check Start.", $time);
    for (j=0; j < 5; j=j+1) begin
      for (i=0; i < 15; i=i+1) begin    // write random data to testable regs
        if (reg_list[i][25:24] != 2'b00) begin
          if (j==0)
            wr_data    = {DATA_WIDTH{1'b1}};
          else if (j==1)
            wr_data    = {DATA_WIDTH{1'b0}};
          else
            wr_data    = $random;
          lmmi_mst_0.m_write(i[3:0], wr_data);
          reg_list[i][23:16] = get_exp_data(reg_list[i][25:24], reg_list[i][15:8], wr_data[7:0], reg_list[i][7:0]);
        end
      end      
      if ((j == 1) || (j == 3)) begin
        $display("[%010t] [TEST]: Reserved address check start.", $time);
        wr_data = $random;
        lmmi_mst_0.m_write(4'hF, wr_data);
        lmmi_mst_0.m_read(4'hF, rd_data);
        data_compare_reg(rd_data,8'h00, "Reserved", 4'hF);
        $display("[%010t] [TEST]: Reserved address check end.", $time);
      end
      rd_check_all_regs(); 
    end
    $display("[%010t] [TEST]: Register access check end.", $time);
    $display("[%010t] [TEST]:Register test end!\n", $time);
  end
endtask

task rd_check_all_regs_default();
  reg [DATA_WIDTH-1:0]  rd_data;
  begin
    $display("\n[%010t] [TEST]: Register default data check start.", $time);
    for (i=0; i < 15; i=i+1) begin
      lmmi_mst_0.m_read(i[3:0], rd_data);
      data_compare_reg(rd_data[7:0],reg_list[i][7:0], reg_names[i], i[3:0]);
    end
    $display("[%010t] [TEST]: Register default data check end.\n", $time);
  end
endtask

task rd_check_all_regs();
  reg [DATA_WIDTH-1:0]  rd_data;
  begin
    for (i=0; i < 15; i=i+1) begin
      if (reg_list[i][25:24] != 2'b00) begin
        lmmi_mst_0.m_read(i[3:0], rd_data);
        data_compare_reg(rd_data[7:0],reg_list[i][23:16], reg_names[i], i[3:0]);
      end
    end
  end
endtask

task reset_during_idle();
  begin
    $display("[%010t] [TEST]: Reset during IDLE start.", $time);
    // Previous register test updated the register values  
    @(posedge clk_i);
    @(posedge clk_i);
    @(posedge clk_i);

    $display("[%010t] [TEST]: Asserting reset for 2 clock cycles.", $time);
    @(posedge clk_i);
    rst_i     <= 1'b1;
    rst_n_i   <= 1'b0;
    @(posedge clk_i);
    @(posedge clk_i);
    rst_i     <= 1'b0;
    rst_n_i   <= 1'b1;
    @(posedge clk_i);
    $display("[%010t] [TEST]: Check that register default values are correct.", $time);
    for (i=1; i < 14; i=i+1) begin
      reg_list[i][23:16] = reg_list[i][7:0];
    end
    rd_check_all_regs_default();
    $display("[%010t] [TEST]: Reset during IDLE end.", $time);

    tx_fifo_count = {9{1'b1}};
    rx_fifo_count = {9{1'b1}};
    reset_i2c_count();
  end
endtask

task reg_write(
  input  [3:0] addr,
  input  [7:0] data
);
  reg [DATA_WIDTH-1:0] wr_data;
  begin
    wr_data      = {DATA_WIDTH{1'b0}};
    wr_data[7:0] = data;
    lmmi_mst_0.m_write(addr, wr_data);
  end
endtask

task reg_read(
  input  [3:0] addr,
  output [7:0] data
);
  reg [DATA_WIDTH-1:0] rd_data;
  begin
    lmmi_mst_0.m_read(addr, rd_data);
    data = rd_data[7:0];
  end
endtask

task reset_i2c_count();
    begin
        tx_i2c_count_r = 0;
    end
endtask
  
task check_int_status();
  begin
    int_status[7] = (tx_i2c_count_r == trg_count) ? 1'b1 : 1'b0;
    int_status[6] = 1'b0;
    int_status[5] = 1'b0;
    int_status[4] = (tx_fifo_count == (TX_FIFO_AE_FLAG-1)) ? 1'b1 : 1'b0;
    int_status[3] = (tx_fifo_count == {9{1'b1}}) ? 1'b1 : 1'b0;
    int_status[2] = (rx_fifo_count == FIFO_DEPTH-1) ? 1'b1 : 1'b0;
    int_status[1] = (rx_fifo_count == RX_FIFO_AF_FLAG-1) ? 1'b1 : 1'b0;
    int_status[0] = (rx_fifo_count == 0) ? 1'b1 : 1'b0;
  end
endtask

task interrupt_check(
  input   [8*30:1] int_name
);
  reg [DATA_WIDTH-1:0]  rd_data;
  reg            [7:0]  int_mask;
  reg            [7:0]  int_enable;
  begin
    check_int_status();
    int_mask = ~int_status;
    lmmi_mst_0.m_read(ADDR_INT_ENABLE1, rd_data);
    int_enable = rd_data[7:0];
    lmmi_mst_0.m_read(ADDR_INT_STATUS1, rd_data);
    if (rd_data[7:0] == int_status) begin
      $display("[%010t] [TEST]: %0s asserted as expected. INT_STATUS_REG = 0x%02x", $time, int_name, rd_data[7:0]);
      // interrupt masking check
      reg_write(ADDR_INT_ENABLE1, int_mask);
      lmmi_mst_0.m_read(ADDR_INT_ENABLE1, rd_data); // dummy read
      if (int_o) begin
        $error("[%010t] [TEST]: Error: interrupt is still asserted when %0s is disabled", $time, int_name);
        error_count = error_count + 1;
      end
      reg_write(ADDR_INT_ENABLE1, int_enable);
      lmmi_mst_0.m_read(ADDR_INT_ENABLE1, rd_data); // dummy read
      if (~int_o) begin
        $error("[%010t] [TEST]: Error: interrupt did not re-assert when %0s is enabled", $time, int_name);
        error_count = error_count + 1;
      end      
      
      // interrupt clearing check
      reg_write(ADDR_INT_STATUS1, int_status);
      lmmi_mst_0.m_read(ADDR_INT_STATUS1, rd_data);
      if (rd_data[7:0] != 8'h00) begin
        $error("[%010t] [TEST]: Error: INT_STATUS_REG = 0x%02x when %0s is cleared", $time, rd_data[7:0], int_name);
        error_count = error_count + 1;
      end
      if (int_o) begin
        $error("[%010t] [TEST]: Error: interrupt is still asserted when %0s is cleared", $time, int_name);
        error_count = error_count + 1;
      end
    end
    else begin
      $error("[%010t] [TEST]: Error: INT_STATUS_REG = 0x%02x while checking for 0x%02x", $time, rd_data[7:0], int_status);
      error_count = error_count + 1;
    end
  end
endtask

task check_exp_status();
    reg [8:0]  i_tx_fifo_count;
    reg [8:0]  i_rx_fifo_count;
  begin
    i_tx_fifo_count = tx_fifo_count+1;
    i_rx_fifo_count = rx_fifo_count+1;
    exp_status[7:6] = 2'b0;
    exp_status[5] = (i_tx_fifo_count ==  FIFO_DEPTH) ? 1'b1 : 1'b0;
    exp_status[4] = (tx_fifo_count[8] ==  {1'b1}) ? 1'b1 : (i_tx_fifo_count <=  (TX_FIFO_AE_FLAG)) ? 1'b1 : 1'b0;
    exp_status[3] = (tx_fifo_count[8] ==  {1'b1}) ? 1'b1 : 1'b0;
    exp_status[2] = (i_rx_fifo_count >=  FIFO_DEPTH) ? 1'b1 : 1'b0;
    exp_status[1] = (i_rx_fifo_count >=  (RX_FIFO_AF_FLAG)) ? 1'b1 : 1'b0;
    exp_status[0] = (rx_fifo_count ==  {9{1'b1}}) ? 1'b1 : 1'b0;
  end
endtask

task check_fifo_status(
    input [8*30:1] comment
);
  reg [DATA_WIDTH-1:0]  rd_data;
  begin
    lmmi_mst_0.m_read(ADDR_FIFO_STATUS, rd_data);
    check_exp_status();
    if (rd_data[7:0] == exp_status) 
      $display("[%010t] [TEST]: FIFO_STATUS_REG=%02x as expected. (%0s)", $time, exp_status, comment);
    else begin
      $error("[%010t] [TEST]: Error: FIFO_STATUS_REG=%02x when expecting 0x%x. (%0s)", $time, rd_data[7:0], exp_status, comment);
      error_count = error_count + 1;
    end
  end
endtask

task normal_operation_test();
  reg [DATA_WIDTH-1:0]  tx_data_lst[0:FIFO_DEPTH];
  reg [DATA_WIDTH-1:0]  rx_data_lst[0:FIFO_DEPTH];
  reg [DATA_WIDTH-1:0]  rd_data;
  reg [DATA_WIDTH-1:0]  wr_data;
  reg [DATA_WIDTH-1:0]  mdl_rx_data;
  reg [7:0]             exp_fsr;

  begin
    $display("[%010t] [TEST]: Normal operation test start.", $time);
    check_fifo_status("FSR_Check0"); //RX_FIFO & TX_FIFO empty check
	// Let's use register default values as set in the GUI
    reg_write(ADDR_SLV_ADDRL, 8'h5A);
    reg_write(ADDR_TGT_BYTE_CNT, trg_count);
    wr_data      = 8'h00;
    wr_data[2:0] = PRESCALER[10:8];
    reg_write(ADDR_MODE_REG, wr_data);
    reg_write(ADDR_CONTROL, 8'h1);

    for(i=0;i<FIFO_DEPTH+1;i=i+1) begin // generate data to transmit and receive
      tx_data_lst[i] = $random;
      rx_data_lst[i] = $random;
    end
    i2c_slv_0.enable_check_on_rx(); // enable data compare for data from I2C Master to I2C Slave model
    
	// Write 2 data to Transmit FIFO and set it as expected data
    for(i=0;i<2;i=i+1) begin 
      lmmi_mst_0.m_write(ADDR_DATA, tx_data_lst[i]);
      i2c_slv_0.set_expected_data(i, tx_data_lst[i]);
	  tx_fifo_count = tx_fifo_count + 1;
    end

 // Added delay for correct timing of FIFO status check, consider more robust checking
	repeat (5) @(posedge clk_i);
  	check_fifo_status("FSR_Check1");

	// Write 9 data to Transmit FIFO and set it as expected data
    for(i=2;i<FIFO_DEPTH;i=i+1) begin 
      lmmi_mst_0.m_write(ADDR_DATA, tx_data_lst[i]);
      i2c_slv_0.set_expected_data(i, tx_data_lst[i]);
	  tx_fifo_count = tx_fifo_count + 1;
    end

	for (i=1; i<5; i=i+1) @(posedge clk_i); // just wait for some time    
	// Interrupt and FIFO status checks
    check_fifo_status("FSR_Check2");
	tx_fifo_count = tx_fifo_count - 1;
	for (i=1; i<20; i=i+1) @(posedge clk_i); // just wait for some time
    reg_write(ADDR_INT_STATUS1, 8'hFF);  // Enable all interrupts for checking those will assert
    reg_write(ADDR_INT_ENABLE1, 8'hFF);  // Enable all interrupts for checking those will assert

    wait_for_int(32'hFFFFFFFF, "tx_fifo_aempty_int"); 
    interrupt_check("tx_fifo_aempty_int");
    check_fifo_status(  "FSR_Check3");

    wait_for_int(32'hFFFFFFFF, "tr_cmp_int");
    interrupt_check("tr_cmp_int");
    check_fifo_status(  "FSR_Check4");
	
	for (i=1; i<10; i=i+1) @(posedge clk_i); // just wait for some time
	reset_i2c_count();

    j = FIFO_DEPTH - TX_FIFO_AE_FLAG + 1;
    for(i=0;i<TX_FIFO_AE_FLAG;i=i+1) begin 
      i2c_slv_0.set_expected_data(i, tx_data_lst[j]);
	  j = j+1;
    end
	trg_count = (TX_FIFO_AE_FLAG == 1) ? 8'h1 : (TX_FIFO_AE_FLAG - 1);
    reg_write(ADDR_TGT_BYTE_CNT, trg_count);
    reg_write(ADDR_CONTROL, 8'h1);	

	tx_fifo_count = tx_fifo_count - 1;

    wait_for_int(32'hFFFFFFFF, "tx_fifo_empty_int");
    interrupt_check("tx_fifo_empty_int");
    check_fifo_status(  "FSR_Check5");
//    $display("[%010t] [TEST]: DUT sequence done.", $time);
    wait_for_int(32'hFFFFFFFF, "tr_cmp_int");
    reg_read(ADDR_INT_STATUS1, rd_data);
    if (rd_data[7:0] != 8'h80) begin
      $error("[%010t] [TEST]: Error: INT_STATUS_REG = 0x%02x when 0x80 is expected", $time, rd_data[7:0]);
      error_count = error_count + 1;
    end
    reg_write(ADDR_INT_STATUS1, rd_data);
    reg_read(ADDR_INT_STATUS1, rd_data);
    if (rd_data[7:0] != 8'h00) begin
      $error("[%010t] [TEST]: Error: INT_STATUS_REG = 0x%02x when tr_cmp_int is cleared", $time, rd_data[7:0]);
      error_count = error_count + 1;
    end

    for (i=14; i<1000; i=i+1) @(posedge clk_i); // just wait for some time
    reset_i2c_count();


    // Read test
    reg_write(ADDR_DATA, tx_data_lst[i]);
    tx_fifo_count = tx_fifo_count + 1;

    wr_data      = 8'h00;
    wr_data[3]   = 1'b1; //READ
    wr_data[2:0] = PRESCALER[10:8];
    reg_write(ADDR_MODE_REG, wr_data);
    reg_write(ADDR_INT_ENABLE1, 8'hBF);

    if (RX_FIFO_AF_FLAG > 1) begin
        // RX FIFO Ready Interrupt
        for(i=0;i<RX_FIFO_AF_FLAG-1;i=i+1) begin // Put data to be read from FIFO
          i2c_slv_0.set_expected_data(i, rx_data_lst[i]);
        end
        trg_count = RX_FIFO_AF_FLAG-1;
        reg_write(ADDR_TGT_BYTE_CNT, RX_FIFO_AF_FLAG-1);
        reg_write(ADDR_CONTROL, 8'h1);
        wait_for_int(32'hFFFFFFFF, "rx_fifo_ready_int");
        interrupt_check("rx_fifo_ready_int");
        check_fifo_status("FSR_Check6");

        // RX Transfer Complete Interrupt (RX_FIFO_AF_FLAG - 1)
        wait_for_int(32'hFFFFFFFF, "tr_cmp_int");
        interrupt_check("tr_cmp_int");
        check_fifo_status("FSR_Check7");
    end

    // RX FIFO Almost Full Interrupt
    reset_i2c_count();
    i2c_slv_0.set_expected_data(0, rx_data_lst[RX_FIFO_AF_FLAG-1]);
    trg_count = 1;
    reg_write(ADDR_TGT_BYTE_CNT, 1);
    reg_write(ADDR_CONTROL, 8'h1);
    wait_for_int(32'hFFFFFFFF, "rx_fifo_afull_int");
    interrupt_check("rx_fifo_afull_int");
    check_fifo_status("FSR_Check8");

    //RX FIFO Full Interrupt
    if ((FIFO_DEPTH-RX_FIFO_AF_FLAG) > 0) begin
        reset_i2c_count();
        for(i=0;i<(FIFO_DEPTH-RX_FIFO_AF_FLAG);i=i+1) begin // Put data to be read from FIFO
            i2c_slv_0.set_expected_data(i, rx_data_lst[RX_FIFO_AF_FLAG+i]);
        end
        trg_count = FIFO_DEPTH-RX_FIFO_AF_FLAG;
        reg_write(ADDR_TGT_BYTE_CNT, FIFO_DEPTH-RX_FIFO_AF_FLAG);
        reg_write(ADDR_CONTROL, 8'h1);
        wait_for_int(32'hFFFFFFFF, "rx_fifo_full_int");
        interrupt_check("rx_fifo_full_int");
        check_fifo_status("FSR_Check10");
    end

    for(i=0;i<FIFO_DEPTH;i=i+1) begin // Put data to be read from FIFO
      reg_read(ADDR_DATA, rd_data);
      rx_fifo_count = rx_fifo_count-1;
      if (rd_data[7:0] == rx_data_lst[i]) 
        $display("[%010t] [TEST]: Read data is as expected: %02x", $time, rd_data[7:0]);
      else begin
        $error("[%010t] [TEST]: Read data is not as expected. Expected: %02x; Actual: %02x", $time, rx_data_lst[i], rd_data[7:0]);
        error_count = error_count + 1;
      end
    end

    for (i=14; i<1000; i=i+1) @(posedge clk_i); // just wait for some time
    $display("[%010t] [TEST]: Normal operation test end.", $time);
  end
endtask // normal_operation_fifo_full_test

task wait_for_int(
  input     [31:0] timeout_val,
  input   [8*15:1] comment      // To identify the call
);
  reg [31:0] count;
  begin
    $display("[%010t] [TEST]: Waiting for interrupt to assert (Timeout=%0d).", $time, timeout_val);
    count = 32'h0;
    while(~int_o && (count < timeout_val)) begin 
      @(posedge clk_i);
      count = count+1;
      if (int_o)
        $display("[%010t] [TEST]: Interrupt asserted.", $time);
    end
    if (count < timeout_val)
      $display("[%010t] [TEST]: Interrupt asserted.", $time);
    else begin
      error_count = error_count + 1;
      $error("[%010t] [TEST]: Timeout occured while waiting for interrupt (%0s).", $time, comment);
      $display("\n[%010t] [TEST]: SIMULATION FAILED - No of Errors = %0d.\n", $time, error_count);
      $finish;
    end
  end
endtask

task data_compare_reg(
  input     [7:0]         act,
  input     [7:0]         exp,
  input reg [8*23:1]      reg_name,
  input     [3:0]         addr
);
  begin
    if (exp != act) begin
      error_count = error_count + 1;
      $error("[%010t] [reg_test]: Data compare error on %0s register (LMMI Addr=0x%02x). Actual (0x%02x) != Expected (0x%02x)!", $time, reg_name, addr, act, exp);
    end
  end
endtask

//functions
function [7:0] get_exp_data(input [1:0] access,
                            input [7:0] wrbits, 
                            input [7:0] data,
                            input [7:0] def);
  begin
    if (access == 2'b10) // write-only
      get_exp_data = 8'h00;
    else if ((access == 2'b01) || (wrbits == 8'h00))
      get_exp_data = def;
    else
      get_exp_data = (wrbits & data) | (~wrbits & def);
  end
endfunction

endmodule
`endif
