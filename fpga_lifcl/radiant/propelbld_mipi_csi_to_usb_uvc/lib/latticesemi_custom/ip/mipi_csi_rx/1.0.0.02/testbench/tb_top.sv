//===========================================================================
// Filename: tb_top.sv
// Copyright(c) 2025 Lattice Semiconductor Corporation. All rights reserved. 
//===========================================================================

`timescale 1 ps / 1 ps

// TB Files
`include "bus_driver.sv"
`include "clk_driver.sv"
`include "dphy_csi2_model.sv"
`include "dphy_dsi2_model.sv"
`include "cphy_csi2_model.sv"
`include "cphy_dsi2_model.sv"

`ifndef TB_TOP
`define TB_TOP

module tb_top();

//////////////////////////////////////////////////
// Testbench Parameters - DO NOT EDIT           //
//////////////////////////////////////////////////
`include "dut_params.v"
localparam BPP                = (RGB888_ENABLED == "ON") ? 24 :
                                (RGB565_ENABLED == "ON") ? 16 :
                                (RAW10_ENABLED  == "ON") ? 10 :
						      /*(RAW12_ENABLED  == "ON") ? 12 :*/
								                           12;
localparam SYNCCLK_PERIOD     = 1000000/SYNCCLK_MHZ;
localparam PHY_CLK_PERIOD     = $ceil(2000000/RX_LINE_RATE); 
localparam UI                 = $ceil(PHY_CLK_PERIOD/2);
localparam CLK_FR_PERIOD      = (PHY_MODE == "HARD_CPHY") ? (PHY_CLK_PERIOD*PHY_DATA_WIDTH/2*7/16) : (PHY_CLK_PERIOD*PHY_DATA_WIDTH/2);
localparam CLK_FR_PERIOD_ADJ  = (CLK_FR_PERIOD <= 16667) ? CLK_FR_PERIOD : 16667;
localparam AXIS_CLK_CALC      = CLK_FR_PERIOD_ADJ*BPP*PIXELS_PER_CLOCK/NUM_RX_LANE/PHY_DATA_WIDTH;
localparam AXIS_CLK_PERIOD    = (AXIS_CLK_CALC > CLK_FR_PERIOD_ADJ) ? CLK_FR_PERIOD_ADJ : AXIS_CLK_CALC;
localparam PCLK_PERIOD        = 10000;
localparam SOFT_DPHY_CLK_MODE = RX_CLK_MODE;
localparam SIM_WEAK           = (PHY_MODE == "SOFT_DPHY") ? "OFF" : "ON";
localparam SEND_CAL           = (RX_LINE_RATE > 1500)     ? "ON"  : "OFF";
localparam SEND_ALT_CAL       = (RX_LINE_RATE > 2500)     ? "ON"  : "OFF";
localparam VID_DT             = (RX_TYPE == "DSI2") ? ((RGB888_ENABLED == "ON") ? 6'h3E :
                                                     /*(RGB565_ENABLED == "ON") ? 6'h0E*/
                                                                                  6'h0E) :
									                  ((RGB888_ENABLED == "ON") ? 6'h24 :
													   (RGB565_ENABLED == "ON") ? 6'h22 :
													   (RAW10_ENABLED  == "ON") ? 6'h2B :
													 /*(RAW12_ENABLED  == "ON") ? 6'h2C :*/
													                              6'h2C);

//////////////////////////////////////////////////
// User Configurable Parameters                 //
//////////////////////////////////////////////////
localparam NUM_FRAMES         = 2;                                                // Number of Frames
localparam NUM_PIXELS         = 1920;                                             // Number of Horizontal Pixels, In Multiple of 4 for RAW10, In Multiple of 2 for RAW12
localparam NUM_LINES          = 8;                                                // Number of Vertical Lines
localparam VC_ID              = 2'h0;                                             // Virtual Channel ID
localparam T_FRAME_GAP        = 5000000;                                          // In Picoseconds. Delay Duration Between Frames.
localparam T_INIT             = 100000;                                           // In Picoseconds.
localparam T_LPX              = 60000;                                            // In Picoseconds. (T_LPX >= 50ns)
// DPHY Specific
localparam HARD_DPHY_CLK_MODE = "HS_LP";                                          // "HS_ONLY" - Continuous Clocking, "HS_LP" - Non-Continuous Clocking
localparam T_CLK_PREPARE      = 50000;                                            // In Picoseconds. (38ns <= T_CLK_PREPARE <= 95ns). For SOFT_DPHY, LP State Period Must Be >= Free Running Clock Period (Min 20MHz, 50ns).
localparam T_CLK_ZERO         = 300000-T_CLK_PREPARE;                             // In Picoseconds. ((T_CLK_PREPARE + T_CLK_ZERO) >= 300ns)
localparam T_CLK_PRE          = 8*UI;                                             // In Picoseconds. (T_CLK_PRE >= (8*UI))
localparam T_CLK_POST         = (60000+(208*UI))*1.1;                             // In Picoseconds. For SOFT_DPHY, (T_CLK_POST >= (60ns+(52*UI))). For HARD_DPHY, (T_CLK_POST >= ((60ns+(208*UI))*1.1)).
localparam T_CLK_TRAIL        = 60000;                                            // In Picoseconds. (T_CLK_TRAIL >= 60ns)
localparam T_HS_PREPARE       = 50000+(4*UI);                                     // In Picoseconds. ((40ns+(4*UI)) <= T_HS_PREPARE <= (85ns+(6*UI))). For SOFT_DPHY, LP State Period Must Be >= Free Running Clock Period (Min 20MHz, 50ns).
localparam T_HS_ZERO          = (145000+(10*UI)+(8*SYNCCLK_PERIOD))-T_HS_PREPARE; // In Picoseconds. ((T_HS_PREPARE+T_HS_ZERO) >= (145ns+(10*UI)+(8*SYNCCLK_PERIOD))). For HARD_DPHY, SYNCCLK_PERIOD is 0.
localparam T_HS_TRAIL         = 60000+(4*UI);                                     // In Picoseconds. ((60ns+(4*UI)) <= T_HS_TRAIL <= (105ns+(12*UI)))
localparam T_SKEWCAL          = 32768*UI;                                         // In Picoseconds. ((2^15*UI) <= T_SKEWCAL <= 100us)
localparam T_ALTCAL           = 32768*UI;                                         // In Picoseconds. ((2^15*UI) <= T_SKEWCAL <= 100us)
// CPHY Specifc
localparam T3_PREPARE         = 50000;                                            // In Picoseconds. (38ns <= T3_PREPARE <= 95ns).
localparam T3_PREBEGIN        = 21*UI;                                            // In Picoseconds. ((7*UI) <= T3_PREBEGIN <= (448*UI)). ((T3_PREPARE + T3_PREBEGIN + T3_PREEND) >= (112.5ns + (5*UI))).
localparam T3_POST            = 266*UI;                                           // In Picoseconds. (T3_POST >= (266*UI)). In Multiple of 7 UI.
// DSI Specific
localparam DSI_TIMING_FORMAT  = "ONOFF";                                          // "ONOFF" - Non-Burst Sync Pulse, "OFF" - Non-Burst Sync Event, "ON" - Burst
localparam DSI_BLANKING       = "ON";                                             // "ON" - Send Blanking Packet, "OFF" - Skip Blanking Packet (Not Applicable for HARD_CPHY - Always ON).
localparam DSI_EOTP           = "ON";                                             // "ON" - Send EOTp, "OFF" - Skip EOTp (Not Applicable for HARD_CPHY - Always OFF), 
localparam DSI_VSA_LINES      = 5;                                                // Number of Vertical Sync Active Lines.
localparam DSI_VBP_LINES      = 36;                                               // Number of Vertical Back Porch Lines.
localparam DSI_VFP_LINES      = 4;                                                // Number of Vertical Front Porch Lines.
localparam DSI_HSA_WC         = 16'h0084;                                         // Horizontal Sync Active Blanking Packet Word Count. For Non-Burst Sync Pulse Mode.
localparam DSI_BLLP_WC        = 16'h193A;                                         // BLLP Period Blanking Packet Word Count. For Continuous Clocking Mode.
localparam DSI_HBP_WC         = 16'h01AC;                                         // Horizontal Back Porch Blanking Packet Word Count. For Continuous Clocking Mode and Non-Burst Sync Pulse Mode.
localparam DSI_HFP_WC         = 16'h0102;                                         // Horizontal Front Porch Blanking Packet Word Count. For Continuous Clocking Mode and Non-Burst Sync Pulse Mode.
localparam DSI_T_BLLP         = 2470000;                                          // In Picoseconds. BLLP Period Delay Duration. For Non-Continuous Clocking Mode.
localparam DSI_T_HBP          = 800000;                                           // In Picoseconds. Horizontal Back Porch Delay Duration. For Non-Continuous Clocking Non-Burst Sync Event Mode and Burst Mode.
localparam DSI_T_HFP          = 500000;                                           // In Picoseconds. Horizontal Front Porch Delay Duration. For Non-Continuous Clocking Non-Burst Sync Event Mode and Burst Mode.
// CSI Specific
localparam CSI_LS_LE          = "ON";                                             // "ON" - Send Line Start + Line End, "OFF" - Skip Line Start + Line End
localparam CSI_T_LPS          = 100000;                                           // In Picoseconds. Delay Duration Between Packets.

//////////////////////////////////////////////////
// Testbench Parameters - DO NOT EDIT           //
//////////////////////////////////////////////////
localparam CLK_MODE           = (PHY_MODE == "SOFT_DPHY") ? SOFT_DPHY_CLK_MODE : HARD_DPHY_CLK_MODE;
localparam NUM_PIXELS_ADJ     = (RAW10_ENABLED  == "ON")  ? (NUM_PIXELS - (NUM_PIXELS % 4)) :
                                (RAW12_ENABLED  == "ON")  ? (NUM_PIXELS - (NUM_PIXELS % 2)) :
								                             NUM_PIXELS;
localparam int SKEWCAL_UI     = int'($ceil(T_SKEWCAL/UI));
localparam SKEWCAL_UI_ADJ     = SKEWCAL_UI - (SKEWCAL_UI%8);
localparam int ALTCAL_UI      = int'($ceil(T_ALTCAL /UI));
localparam ALTCAL_UI_ADJ      = ALTCAL_UI  - (ALTCAL_UI %8);
localparam T3_PREEND          = 7*UI;
localparam T3_PREAMBLE        = ((T3_PREPARE + T3_PREBEGIN + T3_PREEND) >= (112500 + (5*UI))) ? (T3_PREBEGIN + T3_PREEND) : (112500 + (5*UI));

//////////////////////////////////////////////////
// Signals                                      //
//////////////////////////////////////////////////
reg                    CLK_GSR            = 1'b0;
reg                    USER_GSR           = 1'b1;
wire                   GSROUT;

reg                    dphy_clk           = 1'b0;
reg                    clk_byte_tb        = 1'b0;
reg                    tb_reset_n         = 1'b0; 
wire                   clk_p_io;
wire                   clk_n_io;
wire [3:0]             d_p_io;
wire [3:0]             d_n_io;
wire [2:0]             d_a_io;
wire [2:0]             d_b_io;
wire [2:0]             d_c_io;
reg                    phy_active         = 1'b0;

reg  [TDATA_WIDTH-1:0] axis_vid_tdata_r   =  'd0;
reg  [TDATA_WIDTH-1:0] axis_vid_tdata_rr  =  'd0;
reg  [TDATA_WIDTH-1:0] axis_vid_tdata_rrr =  'd0;
reg  [1:0]             axis_vid_tdata_ctr = 2'd0;
reg  [31:0]            num_pixels_ctr     = PIXELS_PER_CLOCK;
wire [3:0]             num_pixels_mask;
wire                   ready_o;
wire                   clk_fr_i;
wire                   clk_byte_o;
reg                    reset_fr_n_i       = 1'b0;
reg                    axis_vid_clk_i     = 1'b0;
reg                    axis_vid_rstn_i    = 1'b0;
reg                    axis_vid_tready_i  = 1'b1;
wire                   axis_vid_tvalid_o;
wire [TDATA_WIDTH-1:0] axis_vid_tdata_o;
wire [2:0]             axis_vid_tuser_o;
wire                   axis_vid_tlast_o;

reg                    pclk               = 1'b0;
reg                    preset_n           = 1'b0;
reg                    rx_soft_rst_n      = 1'b0;
reg                    rx_soft_shutdown_n = 1'b0;
reg                    mipi_refclk_p      = 1'b0;
reg                    mipi_refclk_n      = 1'b1;

reg                    sync_clk_i         = 1'b0;
reg                    sync_rst_i         = 1'b1;
reg                    pll_lock_i         = 1'b0;



//////////////////////////////////////////////////
// Main Code                                    //
//////////////////////////////////////////////////
// Clocks
always #(5)                   CLK_GSR        <= ~CLK_GSR;
always #(PHY_CLK_PERIOD/2)    dphy_clk       <= ~dphy_clk;
always #(CLK_FR_PERIOD_ADJ/2) clk_byte_tb    <= ~clk_byte_tb;
always #(AXIS_CLK_PERIOD/2)   axis_vid_clk_i <= ~axis_vid_clk_i;
always #(PCLK_PERIOD/2)       pclk           <= ~pclk;
always #(500000/PLL_REF_CLK)  mipi_refclk_p  <= ~mipi_refclk_p;
always #(500000/PLL_REF_CLK)  mipi_refclk_n  <= ~mipi_refclk_n;
always #(500000/SYNCCLK_MHZ)  sync_clk_i     <= ~sync_clk_i;

assign clk_fr_i = ((CLK_MODE == "HS_ONLY") && (CLK_FR_PERIOD <= 16667)) ? clk_byte_o : clk_byte_tb;

// GSR
GSR GSR_INST (
    .GSR_N (USER_GSR),
    .CLK   (CLK_GSR)
);

// DPHY Model
generate if (RX_TYPE == "DSI2") begin : GEN_DSI2_MODEL
    if (PHY_MODE == "HARD_CPHY") begin : CPHY_MODEL
	    cphy_dsi2_model #(
		    .NUM_RX_LANE       (NUM_RX_LANE),
			.UI                (UI),
			.NUM_FRAMES        (NUM_FRAMES),
			.NUM_PIXELS        (NUM_PIXELS_ADJ),
			.NUM_LINES         (NUM_LINES),
			.VID_DT            (VID_DT),
			.BPP               (BPP),
			.VC_ID             (VC_ID),
			.T_FRAME_GAP       (T_FRAME_GAP),
			.T_INIT            (T_INIT),
			.T_LPX             (T_LPX),
			.T3_PREPARE        (T3_PREPARE),
			.T3_PREAMBLE       (T3_PREAMBLE),
			.T3_POST           (T3_POST),
			.DSI_TIMING_FORMAT (DSI_TIMING_FORMAT),
			.DSI_VSA_LINES     (DSI_VSA_LINES),
			.DSI_VBP_LINES     (DSI_VBP_LINES),
			.DSI_VFP_LINES     (DSI_VFP_LINES),
			.DSI_HSA_WC        (DSI_HSA_WC),
			.DSI_BLLP_WC       (DSI_BLLP_WC),
			.DSI_HBP_WC        (DSI_HBP_WC),
			.DSI_HFP_WC        (DSI_HFP_WC),
			.DSI_T_BLLP        (DSI_T_BLLP),
			.DSI_T_HBP         (DSI_T_HBP),
			.DSI_T_HFP         (DSI_T_HFP)
        ) cphy_dsi2_model_inst (
		    .tb_reset_n        (tb_reset_n),
		    .d_a_io            (d_a_io),
		    .d_b_io            (d_b_io),
		    .d_c_io            (d_c_io)
		);
		
	    initial begin
	        @(posedge phy_active);
	        GEN_DSI2_MODEL.CPHY_MODEL.cphy_dsi2_model_inst.cphy_active = 1;
	    	@(negedge GEN_DSI2_MODEL.CPHY_MODEL.cphy_dsi2_model_inst.cphy_active);
	    	phy_active = 1'b0;
	    end
	end else begin : DPHY_MODEL
        dphy_dsi2_model #(
	    .dphy_num_lane         (NUM_RX_LANE),
	    .dphy_clk_period       (PHY_CLK_PERIOD),
	    .CLK_MODE              (CLK_MODE),
	    .BURST_MODE            (DSI_TIMING_FORMAT),
	    .LP_BLANKING           (DSI_BLANKING),
	    .EOTP                  (DSI_EOTP),
	    .sim_weak              (SIM_WEAK),
		.send_cal              (SEND_CAL),
		.send_alt_cal          (SEND_ALT_CAL),
		.skewcal_ui            (SKEWCAL_UI_ADJ),
		.altcal_ui             (ALTCAL_UI_ADJ),
	    .num_frames            (NUM_FRAMES),
		.num_pixels            (NUM_PIXELS),
	    .num_lines             (NUM_LINES),
	    .t_lpx                 (T_LPX),
	    .t_clk_prepare         (T_CLK_PREPARE),
	    .t_clk_zero            (T_CLK_ZERO),
	    .t_clk_pre             (T_CLK_PRE),
	    .t_clk_post            (T_CLK_POST),
	    .t_clk_trail           (T_CLK_TRAIL),
	    .t_hs_prepare          (T_HS_PREPARE),
	    .t_hs_zero             (T_HS_ZERO),
	    .t_hs_trail            (T_HS_TRAIL),
	    .t_init                (T_INIT),
	    .hsa_payload           (DSI_HSA_WC),
	    .bllp_payload          (DSI_BLLP_WC),
	    .hbp_payload           (DSI_HBP_WC),
	    .hfp_payload           (DSI_HFP_WC),
	    .lps_bllp_duration     (DSI_T_BLLP),
	    .lps_hbp_duration      (DSI_T_HBP),
	    .lps_hfp_duration      (DSI_T_HFP),
	    .virtual_channel       (VC_ID),
	    .video_data_type       (VID_DT),
	    .vsa_lines             (DSI_VSA_LINES),
	    .vbp_lines             (DSI_VBP_LINES),
	    .vfp_lines             (DSI_VFP_LINES),
	    .frame_gap             (T_FRAME_GAP)
	) dphy_dsi2_model_inst (
	    .resetn   (tb_reset_n),
		.clk_p_io (clk_p_io),
		.clk_n_io (clk_n_io),
		.d_p_io   (d_p_io),
		.d_n_io   (d_n_io)
	);
	
	initial begin
	    @(posedge phy_active);
	        GEN_DSI2_MODEL.DPHY_MODEL.dphy_dsi2_model_inst.dphy_active = 1;
	    	@(negedge GEN_DSI2_MODEL.DPHY_MODEL.dphy_dsi2_model_inst.dphy_active);
		    phy_active = 1'b0;
	    end
	end
end else begin : GEN_CSI2_MODEL
    if (PHY_MODE == "HARD_CPHY") begin : CPHY_MODEL
	    cphy_csi2_model #(
		    .NUM_RX_LANE (NUM_RX_LANE),
			.UI          (UI),
			.NUM_FRAMES  (NUM_FRAMES),
			.NUM_PIXELS  (NUM_PIXELS_ADJ),
			.NUM_LINES   (NUM_LINES),
			.VID_DT      (VID_DT),
			.BPP         (BPP),
			.VC_ID       (VC_ID),
			.T_FRAME_GAP (T_FRAME_GAP),
			.T_INIT      (T_INIT),
			.T_LPX       (T_LPX),
			.T3_PREPARE  (T3_PREPARE),
			.T3_PREAMBLE (T3_PREAMBLE),
			.T3_POST     (T3_POST),
			.CSI_LS_LE   (CSI_LS_LE),
			.CSI_T_LPS   (CSI_T_LPS)
        ) cphy_csi2_model_inst (
		    .tb_reset_n  (tb_reset_n),
		    .d_a_io      (d_a_io),
		    .d_b_io      (d_b_io),
		    .d_c_io      (d_c_io)
		);
		
		initial begin
	    @(posedge phy_active);
	        GEN_CSI2_MODEL.CPHY_MODEL.cphy_csi2_model_inst.cphy_active = 1;
	    	@(negedge GEN_CSI2_MODEL.CPHY_MODEL.cphy_csi2_model_inst.cphy_active);
		    phy_active = 1'b0;
	    end
	end else begin : DPHY_MODEL
        dphy_csi2_model #(
	    .num_frames        (NUM_FRAMES),
	    .num_pixels        (NUM_PIXELS),
	    .num_lines         (NUM_LINES),
	    .active_dphy_lanes (NUM_RX_LANE),
	    .data_type         (VID_DT),
	    .RX_CLK_MODE       (CLK_MODE),
	    .dphy_clk_period   (PHY_CLK_PERIOD),
	    .t_lpx             (T_LPX),
	    .t_clk_prepare     (T_CLK_PREPARE),
	    .t_clk_zero        (T_CLK_ZERO),
	    .t_clk_trail       (T_CLK_TRAIL),
	    .t_clk_post        (T_CLK_POST),
	    .t_clk_pre         (T_CLK_PRE),
	    .t_hs_prepare      (T_HS_PREPARE),
	    .t_hs_zero         (T_HS_ZERO),
	    .t_hs_trail        (T_HS_TRAIL),
	    .lps_gap           (CSI_T_LPS),
	    .frame_gap         (T_FRAME_GAP),
	    .t_init            (T_INIT),
	    .dphy_vc           (VC_ID),
	    .LS_LE             (CSI_LS_LE),
	    .sim_weak          (SIM_WEAK),
		.send_cal          (SEND_CAL),
		.send_alt_cal      (SEND_ALT_CAL),
		.skewcal_ui        (SKEWCAL_UI_ADJ),
		.altcal_ui         (ALTCAL_UI_ADJ)
	) dphy_csi2_model_inst (
	    .refclk_i (dphy_clk),
	    .resetn   (tb_reset_n),
		.clk_p_io (clk_p_io),
		.clk_n_io (clk_n_io),
		.d_p_io   (d_p_io),
		.d_n_io   (d_n_io)
	);
	
	initial begin
	    @(posedge phy_active);
	        GEN_CSI2_MODEL.DPHY_MODEL.dphy_csi2_model_inst.dphy_active = 1;
	    	@(negedge GEN_CSI2_MODEL.DPHY_MODEL.dphy_csi2_model_inst.dphy_active);
		    phy_active = 1'b0;
	    end
	end
end
endgenerate

// File Processing
integer f = $fopen("tb_received_data.txt","w");

// Tasks
// Data Checker
task data_checker();
    integer tb_expected_data;
    integer tb_received_data;
    integer expected_data_scan;
    integer received_data_scan;
    reg [7:0]  expected_data_value;
    reg [7:0]  received_data_value;
    automatic reg [31:0] data_matched_ctr    = 32'd0;
    automatic reg [31:0] data_mismatched_ctr = 32'd0;
    tb_expected_data = $fopen("tb_expected_data.txt","r");
	if (tb_expected_data == 0) begin
	    $display("%t TEST FAILED! FAILED TO OPEN tb_expected_data.txt\n",$time);
		$finish;
	end
	tb_received_data = $fopen("tb_received_data.txt","r");
	if (tb_received_data == 0) begin
	    $display("%t TEST FAILED! FAILED TO OPEN tb_received_data.txt\n",$time);
		$finish;
	end
	while (!$feof(tb_expected_data) | !$feof(tb_received_data)) begin
	    expected_data_scan = $fscanf(tb_expected_data,"%h\n",expected_data_value);
	    received_data_scan = $fscanf(tb_received_data,"%h\n",received_data_value);
		if (expected_data_value == received_data_value)
		    data_matched_ctr    = data_matched_ctr + 1;
		else
		    data_mismatched_ctr = data_mismatched_ctr + 1;
	end
	if (expected_data_scan & received_data_scan) begin
	    if (data_mismatched_ctr != 0)
		    $display("%t TEST FAILED! DATA MISMATCH FOUND!\n",$time);
		else
		    $display("%t SIMULATION PASSED!\n",$time);
	end else if (expected_data_scan & !received_data_scan)
	    $display("%t TEST FAILED! TESTBENCH RECEIVED LESS DATA THAN EXPECTED!\n",$time);
	else if (!expected_data_scan & received_data_scan)
	    $display("%t TEST FAILED! TESTBENCH RECEIVED MORE DATA THAN EXPECTED!\n",$time);
	$display("%t DATA MATCHED: %0d, DATA MISMATCHED: %0d\n",$time,data_matched_ctr,data_mismatched_ctr);
	$fclose(tb_expected_data);
	$fclose(tb_received_data);
endtask

// RGB888
task axis_data_dsi_rgb888();
    $fwrite(f,"%0x\n",axis_vid_tdata_o[( 2*8)+:8]); // R
    $fwrite(f,"%0x\n",axis_vid_tdata_o[( 1*8)+:8]); // G
    $fwrite(f,"%0x\n",axis_vid_tdata_o[( 0*8)+:8]); // B
	if (((PIXELS_PER_CLOCK == 2) && (num_pixels_mask == 'd0)) || ((PIXELS_PER_CLOCK == 4) && (num_pixels_mask <= 'd2))) begin
    $fwrite(f,"%0x\n",axis_vid_tdata_o[( 5*8)+:8]);
    $fwrite(f,"%0x\n",axis_vid_tdata_o[( 4*8)+:8]);
    $fwrite(f,"%0x\n",axis_vid_tdata_o[( 3*8)+:8]);
	end
    if (PIXELS_PER_CLOCK == 4) begin
	if (num_pixels_mask <= 'd1) begin
    $fwrite(f,"%0x\n",axis_vid_tdata_o[( 8*8)+:8]);
    $fwrite(f,"%0x\n",axis_vid_tdata_o[( 7*8)+:8]);
    $fwrite(f,"%0x\n",axis_vid_tdata_o[( 6*8)+:8]);
	end
	if (num_pixels_mask == 'd0) begin
    $fwrite(f,"%0x\n",axis_vid_tdata_o[(11*8)+:8]);
    $fwrite(f,"%0x\n",axis_vid_tdata_o[(10*8)+:8]);
    $fwrite(f,"%0x\n",axis_vid_tdata_o[( 9*8)+:8]);
	end
	end
endtask

task axis_data_csi_rgb888();
    $fwrite(f,"%0x\n",axis_vid_tdata_o[( 0*8)+:8]); // B
    $fwrite(f,"%0x\n",axis_vid_tdata_o[( 1*8)+:8]); // G
    $fwrite(f,"%0x\n",axis_vid_tdata_o[( 2*8)+:8]); // R
	if (((PIXELS_PER_CLOCK == 2) && (num_pixels_mask == 'd0)) || ((PIXELS_PER_CLOCK == 4) && (num_pixels_mask <= 'd2))) begin
    $fwrite(f,"%0x\n",axis_vid_tdata_o[( 3*8)+:8]);
    $fwrite(f,"%0x\n",axis_vid_tdata_o[( 4*8)+:8]);
    $fwrite(f,"%0x\n",axis_vid_tdata_o[( 5*8)+:8]);
	end
    if (PIXELS_PER_CLOCK == 4) begin
	if (num_pixels_mask <= 'd1) begin
    $fwrite(f,"%0x\n",axis_vid_tdata_o[( 6*8)+:8]);
    $fwrite(f,"%0x\n",axis_vid_tdata_o[( 7*8)+:8]);
    $fwrite(f,"%0x\n",axis_vid_tdata_o[( 8*8)+:8]);
	end
	if (num_pixels_mask == 'd0) begin
    $fwrite(f,"%0x\n",axis_vid_tdata_o[( 9*8)+:8]);
    $fwrite(f,"%0x\n",axis_vid_tdata_o[(10*8)+:8]);
    $fwrite(f,"%0x\n",axis_vid_tdata_o[(11*8)+:8]);
	end
	end
endtask

// RGB565
task axis_data_dsi_rgb565();
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(2+( 1*8))+:3],axis_vid_tdata_o[(3+( 2*8))+:5]}); // G[2:0],R
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(3+( 0*8))+:5],axis_vid_tdata_o[(5+( 1*8))+:3]}); // B,G[5:3]
	if (((PIXELS_PER_CLOCK == 2) && (num_pixels_mask == 'd0)) || ((PIXELS_PER_CLOCK == 4) && (num_pixels_mask <= 'd2)) || ((PIXELS_PER_CLOCK == 8) && (num_pixels_mask <= 'd6))) begin
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(2+( 4*8))+:3],axis_vid_tdata_o[(3+( 5*8))+:5]});
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(3+( 3*8))+:5],axis_vid_tdata_o[(5+( 4*8))+:3]});
	end
	if (((PIXELS_PER_CLOCK == 4) && (num_pixels_mask <= 'd1)) || ((PIXELS_PER_CLOCK == 8) && (num_pixels_mask <= 'd5))) begin
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(2+( 7*8))+:3],axis_vid_tdata_o[(3+( 8*8))+:5]});
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(3+( 6*8))+:5],axis_vid_tdata_o[(5+( 7*8))+:3]});
	end
	if (((PIXELS_PER_CLOCK == 4) && (num_pixels_mask == 'd0)) || ((PIXELS_PER_CLOCK == 8) && (num_pixels_mask <= 'd4))) begin
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(2+(10*8))+:3],axis_vid_tdata_o[(3+(11*8))+:5]});
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(3+( 9*8))+:5],axis_vid_tdata_o[(5+(10*8))+:3]});
	end
	if ((PIXELS_PER_CLOCK == 8) && (num_pixels_mask <= 'd3)) begin
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(2+(13*8))+:3],axis_vid_tdata_o[(3+(14*8))+:5]});
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(3+(12*8))+:5],axis_vid_tdata_o[(5+(13*8))+:3]});
	end
	if ((PIXELS_PER_CLOCK == 8) && (num_pixels_mask <= 'd2)) begin
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(2+(16*8))+:3],axis_vid_tdata_o[(3+(17*8))+:5]});
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(3+(15*8))+:5],axis_vid_tdata_o[(5+(16*8))+:3]});
	end
	if ((PIXELS_PER_CLOCK == 8) && (num_pixels_mask <= 'd1)) begin
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(2+(19*8))+:3],axis_vid_tdata_o[(3+(20*8))+:5]});
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(3+(18*8))+:5],axis_vid_tdata_o[(5+(19*8))+:3]});
	end
	if ((PIXELS_PER_CLOCK == 8) && (num_pixels_mask == 'd0)) begin
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(2+(22*8))+:3],axis_vid_tdata_o[(3+(23*8))+:5]});
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(3+(21*8))+:5],axis_vid_tdata_o[(5+(22*8))+:3]});
	end
endtask

task axis_data_csi_rgb565();
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(2+( 1*8))+:3],axis_vid_tdata_o[(3+( 0*8))+:5]}); // G[2:0],B
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(3+( 2*8))+:5],axis_vid_tdata_o[(5+( 1*8))+:3]}); // R,G[5:3]
	if (((PIXELS_PER_CLOCK == 2) && (num_pixels_mask == 'd0)) || ((PIXELS_PER_CLOCK == 4) && (num_pixels_mask <= 'd2)) || ((PIXELS_PER_CLOCK == 8) && (num_pixels_mask <= 'd6))) begin
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(2+( 4*8))+:3],axis_vid_tdata_o[(3+( 3*8))+:5]});
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(3+( 5*8))+:5],axis_vid_tdata_o[(5+( 4*8))+:3]});
	end
	if (((PIXELS_PER_CLOCK == 4) && (num_pixels_mask <= 'd1)) || ((PIXELS_PER_CLOCK == 8) && (num_pixels_mask <= 'd5))) begin
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(2+( 7*8))+:3],axis_vid_tdata_o[(3+( 6*8))+:5]});
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(3+( 8*8))+:5],axis_vid_tdata_o[(5+( 7*8))+:3]});
	end
	if (((PIXELS_PER_CLOCK == 4) && (num_pixels_mask == 'd0)) || ((PIXELS_PER_CLOCK == 8) && (num_pixels_mask <= 'd4))) begin
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(2+(10*8))+:3],axis_vid_tdata_o[(3+( 9*8))+:5]});
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(3+(11*8))+:5],axis_vid_tdata_o[(5+(10*8))+:3]});
	end
	if ((PIXELS_PER_CLOCK == 8) && (num_pixels_mask <= 'd3)) begin
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(2+(13*8))+:3],axis_vid_tdata_o[(3+(12*8))+:5]});
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(3+(14*8))+:5],axis_vid_tdata_o[(5+(13*8))+:3]});
	end
	if ((PIXELS_PER_CLOCK == 8) && (num_pixels_mask <= 'd2)) begin
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(2+(16*8))+:3],axis_vid_tdata_o[(3+(15*8))+:5]});
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(3+(17*8))+:5],axis_vid_tdata_o[(5+(16*8))+:3]});
	end
	if ((PIXELS_PER_CLOCK == 8) && (num_pixels_mask <= 'd1)) begin
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(2+(19*8))+:3],axis_vid_tdata_o[(3+(18*8))+:5]});
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(3+(20*8))+:5],axis_vid_tdata_o[(5+(19*8))+:3]});
	end
	if ((PIXELS_PER_CLOCK == 8) && (num_pixels_mask == 'd0)) begin
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(2+(22*8))+:3],axis_vid_tdata_o[(3+(21*8))+:5]});
    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(3+(23*8))+:5],axis_vid_tdata_o[(5+(22*8))+:3]});
	end
endtask

task axis_data_csi_raw10();
    if (PIXELS_PER_CLOCK == 16) begin
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(0*16))+:8]); // P0[9:2]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(1*16))+:8]); // P1[9:2]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(2*16))+:8]); // P2[9:2]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(3*16))+:8]); // P3[9:2]
	    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(3*16)+:2],axis_vid_tdata_o[(2*16)+:2],axis_vid_tdata_o[(1*16)+:2],axis_vid_tdata_o[(0*16)+:2]}); // P3[1:0],P2[1:0],P1[1:0],P0[1:0]
	    if (num_pixels_mask <= 'd8) begin
		$fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(4*16))+:8]); // P4[9:2]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(5*16))+:8]); // P5[9:2]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(6*16))+:8]); // P6[9:2]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(7*16))+:8]); // P7[9:2]
	    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(7*16)+:2],axis_vid_tdata_o[(6*16)+:2],axis_vid_tdata_o[(5*16)+:2],axis_vid_tdata_o[(4*16)+:2]}); // P7[1:0],P6[1:0],P5[1:0],P4[1:0]
		end
	    if (num_pixels_mask <= 'd4) begin
		$fwrite(f,"%0x\n",axis_vid_tdata_o[(2+( 8*16))+:8]); // P8 [9:2]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+( 9*16))+:8]); // P9 [9:2]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(10*16))+:8]); // P10[9:2]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(11*16))+:8]); // P11[9:2]
	    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(11*16)+:2],axis_vid_tdata_o[(10*16)+:2],axis_vid_tdata_o[(9*16)+:2],axis_vid_tdata_o[(8*16)+:2]}); // P11[1:0],P10[1:0],P9[1:0],P8[1:0]
		end
	    if (num_pixels_mask == 'd0) begin
		$fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(12*16))+:8]); // P12[9:2]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(13*16))+:8]); // P13[9:2]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(14*16))+:8]); // P14[9:2]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(15*16))+:8]); // P15[9:2]
	    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(15*16)+:2],axis_vid_tdata_o[(14*16)+:2],axis_vid_tdata_o[(13*16)+:2],axis_vid_tdata_o[(12*16)+:2]}); // P15[1:0],P14[1:0],P13[1:0],P12[1:0]
		end
    end else if (PIXELS_PER_CLOCK == 8) begin
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(0*16))+:8]); // P0[9:2]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(1*16))+:8]); // P1[9:2]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(2*16))+:8]); // P2[9:2]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(3*16))+:8]); // P3[9:2]
	    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(3*16)+:2],axis_vid_tdata_o[(2*16)+:2],axis_vid_tdata_o[(1*16)+:2],axis_vid_tdata_o[(0*16)+:2]}); // P3[1:0],P2[1:0],P1[1:0],P0[1:0]
	    if (num_pixels_mask == 'd0) begin
		$fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(4*16))+:8]); // P4[9:2]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(5*16))+:8]); // P5[9:2]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(6*16))+:8]); // P6[9:2]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(7*16))+:8]); // P7[9:2]
	    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(7*16)+:2],axis_vid_tdata_o[(6*16)+:2],axis_vid_tdata_o[(5*16)+:2],axis_vid_tdata_o[(4*16)+:2]}); // P7[1:0],P6[1:0],P5[1:0],P4[1:0]
		end
    end else if (PIXELS_PER_CLOCK == 4) begin
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(0*16))+:8]); // P0[9:2]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(1*16))+:8]); // P1[9:2]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(2*16))+:8]); // P2[9:2]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(3*16))+:8]); // P3[9:2]
	    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(3*16)+:2],axis_vid_tdata_o[(2*16)+:2],axis_vid_tdata_o[(1*16)+:2],axis_vid_tdata_o[(0*16)+:2]}); // P3[1:0],P2[1:0],P1[1:0],P0[1:0]
	end else if (PIXELS_PER_CLOCK == 2) begin
	    if (axis_vid_tdata_ctr % 2 == 1) begin
	    $fwrite(f,"%0x\n",axis_vid_tdata_r[(2+(0*16))+:8]);
	    $fwrite(f,"%0x\n",axis_vid_tdata_r[(2+(1*16))+:8]);
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(0*16))+:8]);
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(1*16))+:8]);
	    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(1*16)+:2],axis_vid_tdata_o[(0*16)+:2],axis_vid_tdata_r[(1*16)+:2],axis_vid_tdata_r[(0*16)+:2]});
		end
  /*end else if (PIXELS_PER_CLOCK == 1) begin*/
	end else begin
	    if (&axis_vid_tdata_ctr) begin
	    $fwrite(f,"%0x\n",axis_vid_tdata_rrr[(2+(0*16))+:8]);
	    $fwrite(f,"%0x\n",axis_vid_tdata_rr [(2+(0*16))+:8]);
	    $fwrite(f,"%0x\n",axis_vid_tdata_r  [(2+(0*16))+:8]);
	    $fwrite(f,"%0x\n",axis_vid_tdata_o  [(2+(0*16))+:8]);
	    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(0*16)+:2],axis_vid_tdata_r[(0*16)+:2],axis_vid_tdata_rr[(0*16)+:2],axis_vid_tdata_rrr[(0*16)+:2]});
		end
	end
endtask

task axis_data_csi_raw12();
    if (PIXELS_PER_CLOCK == 8) begin
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(4+(0*16))+:8]); // P0[11:4]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(4+(1*16))+:8]); // P1[11:4]
	    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(1*16)+:4],axis_vid_tdata_o[(0*16)+:4]}); // P1[3:0],P0[3:0]
		if (num_pixels_mask <= 'd4) begin
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(4+(2*16))+:8]); // P2[11:4]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(4+(3*16))+:8]); // P3[11:4]
	    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(3*16)+:4],axis_vid_tdata_o[(2*16)+:4]}); // P3[3:0],P2[3:0]
		end
		if (num_pixels_mask <= 'd2) begin
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(4+(4*16))+:8]); // P4[11:4]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(4+(5*16))+:8]); // P5[11:4]
	    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(5*16)+:4],axis_vid_tdata_o[(4*16)+:4]}); // P5[3:0],P4[3:0]
		end
		if (num_pixels_mask == 'd0) begin
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(4+(6*16))+:8]); // P6[11:4]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(4+(7*16))+:8]); // P7[11:4]
	    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(7*16)+:4],axis_vid_tdata_o[(6*16)+:4]}); // P7[3:0],P6[3:0]
		end
    end else if (PIXELS_PER_CLOCK == 4) begin
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(4+(0*16))+:8]); // P8[11:4]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(4+(1*16))+:8]); // P9[11:4]
	    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(1*16)+:4],axis_vid_tdata_o[(0*16)+:4]}); // P9[3:0],P8[3:0]
		if (num_pixels_mask == 'd0) begin
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(4+(2*16))+:8]); // P10[11:4]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(4+(3*16))+:8]); // P11[11:4]
	    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(3*16)+:4],axis_vid_tdata_o[(2*16)+:4]}); // P11[3:0],P10[3:0]
		end
	end else if (PIXELS_PER_CLOCK == 2) begin
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(4+(0*16))+:8]);
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(4+(1*16))+:8]);
	    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(1*16)+:4],axis_vid_tdata_o[(0*16)+:4]});
  /*end else if (PIXELS_PER_CLOCK == 1) begin*/
	end else begin
	    if (axis_vid_tdata_ctr % 2 == 1) begin
	    $fwrite(f,"%0x\n",axis_vid_tdata_r[(4+(0*16))+:8]); // P0[11:4]
	    $fwrite(f,"%0x\n",axis_vid_tdata_o[(4+(0*16))+:8]); // P1[11:4]
	    $fwrite(f,"%0x\n",{axis_vid_tdata_o[(0*16)+:4],axis_vid_tdata_r[(0*16)+:4]}); // P1[3:0],P0[3:0]
		end
	end
endtask

// Testbench
initial begin
    $display("%t TEST START\n",$time);
	#(T_INIT);
	$display("%t Testbench is Out of Reset.\n",$time);
	tb_reset_n = 1'b1;
	#(1000);
	$display("%t DUT D-PHY is Out of Reset.\n",$time);
	if (PHY_MODE == "SOFT_DPHY") begin
	    sync_rst_i = 1'b0;
		$display("%t Waiting 1ns to Simulate PLL Lock...\n",$time);
		#(1000);
		$display("%t PLL is Locked!\n",$time);
		pll_lock_i = 1'b1;
	end else begin
	    preset_n = 1'b1;
		rx_soft_rst_n = 1'b1;
		rx_soft_shutdown_n = 1'b1;
	end
	$display("%t Waiting for PHY Ready...\n",$time);
	@(posedge ready_o);
	$display("%t PHY is Ready!\n",$time);
	$display("%t DUT Controller is Out of Reset.\n",$time);
	fork
	    begin
		    @(posedge clk_byte_tb);
			reset_fr_n_i = 1'b1;
		end
		begin
		    @(posedge axis_vid_clk_i);
			axis_vid_rstn_i = 1'b1;
		end
	join
	if (RX_TYPE == "DSI2") begin
	    $display("%t Activating DSI-2 PHY Model.\n",$time);
		phy_active = 1'b1;
		@(negedge phy_active);
	    $display("%t DSI-2 PHY Model Transmission Complete.\n",$time);
	end else begin
	    $display("%t Activating CSI-2 PHY Model\n",$time);
		phy_active = 1'b1;
		@(negedge phy_active);
	    $display("%t CSI-2 PHY Model Transmission Complete.\n",$time);
	end
	#(10000);
	$fclose(f);
	data_checker;
	$display("%t TEST FINISH\n",$time);
	$finish;
end

// Received Data from DUT
always @(posedge axis_vid_clk_i) begin
	if (axis_vid_rstn_i & axis_vid_tready_i & axis_vid_tvalid_o) begin
	    if (RX_TYPE == "DSI2") begin
		    if (RGB888_ENABLED == "ON")
			    axis_data_dsi_rgb888;
			else if (RGB565_ENABLED == "ON")
			    axis_data_dsi_rgb565;
		end else begin
		    if (RGB888_ENABLED == "ON")
			    axis_data_csi_rgb888;
			else if (RGB565_ENABLED == "ON")
			    axis_data_csi_rgb565;
			else if (RAW10_ENABLED == "ON")
			    axis_data_csi_raw10;
			else if (RAW12_ENABLED == "ON")
			    axis_data_csi_raw12;
		end
	    axis_vid_tdata_r   <= axis_vid_tdata_o;
	    axis_vid_tdata_rr  <= axis_vid_tdata_r;
	    axis_vid_tdata_rrr <= axis_vid_tdata_rr;
		axis_vid_tdata_ctr <= axis_vid_tdata_ctr + 1'b1;
		num_pixels_ctr     <= (num_pixels_ctr >= NUM_PIXELS_ADJ) ? PIXELS_PER_CLOCK : (num_pixels_ctr + PIXELS_PER_CLOCK);
	end
end

assign num_pixels_mask = (num_pixels_ctr > NUM_PIXELS_ADJ) ? (num_pixels_ctr - NUM_PIXELS_ADJ) : 'd0;

//////////////////////////////////////////////////
// DUT Instantiation                            //
//////////////////////////////////////////////////
`include "dut_inst.v"

endmodule

`endif
