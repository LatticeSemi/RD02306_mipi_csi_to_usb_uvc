//===========================================================================
// Filename: tb_top.sv
// Copyright(c) 2025 Lattice Semiconductor Corporation. All rights reserved. 
//===========================================================================

// TB Files
`include "bus_driver.sv"
`include "clk_driver.sv"
`include "dphy_csi2_model.sv"
`include "dphy_dsi2_model.sv"
`include "cphy_csi2_model.sv"
`include "cphy_dsi2_model.sv"
`include "rx_model.sv"
`include "axi_byte_stream_pkt_gen.sv"

`timescale 1 ps / 1 fs

`ifndef TB_TOP
`define TB_TOP

module tb_top();

    // IP Configurations - DO NOT EDIT
    `include "dut_params.v"
    

    // Signals
    logic                               CLK_GSR             = 1'b0;
    logic                               USER_GSR            = 1'b1;
    logic                               GSROUT;
                
    logic                               dphy_clk            = 1'b0;
    logic                               byte_clk_tb         = 1'b0;
    logic                               tb_reset_n          = 1'b0;
    wire                                clk_p_io;
    wire                                clk_n_io;
    wire    [NUM_LANE-1:0]              d_p_io;
    wire    [NUM_LANE-1:0]              d_n_io;
    wire    [NUM_LANE-1:0]              d_a_io;
    wire    [NUM_LANE-1:0]              d_b_io;
    wire    [NUM_LANE-1:0]              d_c_io;
    logic                               phy_active          = 1'b0;

    logic                               fr_clk_i;
    logic                               byte_clk_o;
    logic                               fr_rst_n_i          = 1'b0;
    logic                               axis_vid_clk_i      = 1'b0;
    logic                               axis_vid_rst_n_i    = 1'b0;

    logic                               ref_clk_i           = 1'b0;
    logic                               ref_rst_n_i         = 1'b0;
    logic                               pll_clkop_i         = 1'b1;
    logic                               pll_clkos_i         = 1'b1;
    logic                               tinit_done_o;

    // K1
    logic                               pclk                = 1'b0;
    logic                               preset_n            = 1'b0;
    logic                               rx_soft_rst_n       = 1'b0;
    logic                               rx_soft_shutdown_n  = 1'b0;
    logic                               refclk_p            = 1'b0;
    logic                               refclk_n            = 1'b1;
    
    logic                               eclk_ready_i        = 1'b0;
    logic                               eclk_reset_i        = 1'b0;
    logic                               ddr_sync_busy       = 1'b0;
    logic                               eclk_syncclk_i;
    logic                               byte_clk_i;
    logic                               eclk_reset_o;
    logic                               eclk_syncclk_o;
    logic                               eclk_ready_o;
    
    logic                               pll_clkop_x2        = 1'b0;
    logic                               pll_clkop_x4        = 1'b0;

    
    generate
    if (DIR_TYPE == "RX") begin : RX_TB
        localparam TB_BPP                   = (RGB888_ENABLED == "ON") ? 24 :
                                              (RGB565_ENABLED == "ON") ? 16 :
                                              (RAW10_ENABLED  == "ON") ? 10 :
                                              (RAW12_ENABLED  == "ON") ? 12 : 12;
        localparam SYNCCLK_PERIOD           = 1000000/SYNCCLK_MHZ;
        localparam PHY_CLK_PERIOD           = $ceil(2000000/LINE_RATE); 
        localparam UI                       = $ceil(PHY_CLK_PERIOD/2);
        localparam CLK_FR_PERIOD            = (PHY_MODE == "HARD_CPHY") ? (PHY_CLK_PERIOD*PHY_DATA_WIDTH/2*7/16) : (PHY_CLK_PERIOD*PHY_DATA_WIDTH/2);
        localparam CLK_FR_PERIOD_ADJ        = (CLK_FR_PERIOD <= 16667) ? CLK_FR_PERIOD : 16667;
        localparam AXIS_CLK_CALC            = CLK_FR_PERIOD_ADJ*TB_BPP*PIXELS_PER_CLOCK/NUM_LANE/PHY_DATA_WIDTH;
        localparam AXIS_CLK_PERIOD          = (AXIS_CLK_CALC > CLK_FR_PERIOD_ADJ) ? CLK_FR_PERIOD_ADJ : AXIS_CLK_CALC;
        localparam PCLK_PERIOD              = 10000;
        localparam SOFT_DPHY_CLK_MODE       = CLK_MODE;
        localparam SIM_WEAK                 = (PHY_MODE == "SOFT_DPHY") ? "OFF" : "ON";
        localparam SEND_CAL                 = (LINE_RATE > 1500) ? "ON" : "OFF";
        localparam SEND_ALT_CAL             = (LINE_RATE > 2500) ? "ON" : "OFF";
        localparam VID_DT                   = (APP_TYPE == "DSI2") ? ((RGB888_ENABLED == "ON") ? 6'h3E :
                                                                      (RGB565_ENABLED == "ON") ? 6'h0E : 6'h0E) :
                                                                     ((RGB888_ENABLED == "ON") ? 6'h24 :
                                                                      (RGB565_ENABLED == "ON") ? 6'h22 :
                                                                      (RAW10_ENABLED  == "ON") ? 6'h2B :
                                                                      (RAW12_ENABLED  == "ON") ? 6'h2C : 6'h2C);

        // User Configurable Parameters
        localparam NUM_FRAMES               = 2;                                                    // Number of Frames
        localparam NUM_PIXELS               = 1920;                                                 // Number of Horizontal Pixels, In Multiple of 4 for RAW10, In Multiple of 2 for RAW12
        localparam NUM_LINES                = 8;                                                    // Number of Vertical Lines
        localparam VC_ID                    = 2'h0;                                                 // Virtual Channel ID
        localparam TB_T_FRAME_GAP           = 5000000;                                              // In Picoseconds. Delay Duration Between Frames.
        localparam TB_T_INIT                = 100000;                                               // In Picoseconds.
        localparam TB_T_LPX                 = 60000;                                                // In Picoseconds. (T_LPX >= 50ns)
        // DPHY Specific                                                                           
        localparam HARD_DPHY_CLK_MODE       = CLK_MODE;                                             // "HS_ONLY" - Continuous Clocking, "HS_LP" - Non-Continuous Clocking
        localparam TB_T_CLK_PREPARE         = 50000;                                                // In Picoseconds. (38ns <= TB_T_CLK_PREPARE <= 95ns). For SOFT_DPHY, LP State Period Must Be >= Free Running Clock Period (Min 20MHz, 50ns).
        localparam TB_T_CLK_ZERO            = 300000-TB_T_CLK_PREPARE;                              // In Picoseconds. ((TB_T_CLK_PREPARE + TB_T_CLK_ZERO) >= 300ns)
        localparam TB_T_CLK_PRE             = 8*UI;                                                 // In Picoseconds. (TB_T_CLK_PRE >= (8*UI))
        localparam TB_T_CLK_POST            = (60000+(208*UI))*1.1;                                 // In Picoseconds. For SOFT_DPHY, (TB_T_CLK_POST >= (60ns+(52*UI))). For HARD_DPHY, (TB_T_CLK_POST >= ((60ns+(208*UI))*1.1)).
        localparam TB_T_CLK_TRAIL           = 60000;                                                // In Picoseconds. (TB_T_CLK_TRAIL >= 60ns)
        localparam TB_T_HS_PREPARE          = 50000+(4*UI);                                         // In Picoseconds. ((40ns+(4*UI)) <= TB_T_HS_PREPARE <= (85ns+(6*UI))). For SOFT_DPHY, LP State Period Must Be >= Free Running Clock Period (Min 20MHz, 50ns).
        localparam TB_T_HS_ZERO             = (145000+(10*UI)+(8*SYNCCLK_PERIOD))-TB_T_HS_PREPARE;  // In Picoseconds. ((T_HS_PREPARE+T_HS_ZERO) >= (145ns+(10*UI)+(8*SYNCCLK_PERIOD))). For HARD_DPHY, SYNCCLK_PERIOD is 0.
        localparam TB_T_HS_TRAIL            = 60000+(4*UI);                                         // In Picoseconds. ((60ns+(4*UI)) <= TB_T_HS_TRAIL <= (105ns+(12*UI)))
        localparam TB_T_SKEWCAL             = 32768*UI;                                             // In Picoseconds. ((2^15*UI) <= TB_T_SKEWCAL <= 100us)
        localparam TB_T_ALTCAL              = 32768*UI;                                             // In Picoseconds. ((2^15*UI) <= TB_T_SKEWCAL <= 100us)
        // CPHY Specifc
        localparam TB_T3_PREPARE            = 50000;                                                // In Picoseconds. (38ns <= TB_T3_PREPARE <= 95ns).
        localparam TB_T3_PREBEGIN           = 21*UI;                                                // In Picoseconds. ((7*UI) <= TB_T3_PREBEGIN <= (448*UI)). ((TB_T3_PREPARE + TB_T3_PREBEGIN + TB_T3_PREEND) >= (112.5ns + (5*UI))).
        localparam TB_T3_POST               = 266*UI;                                               // In Picoseconds. (TB_T3_POST >= (266*UI)). In Multiple of 7 UI.
        // DSI Specific
        localparam DSI_TIMING_FORMAT        = "ONOFF";                                              // "ONOFF" - Non-Burst Sync Pulse, "OFF" - Non-Burst Sync Event, "ON" - Burst
        localparam DSI_BLANKING             = "ON";                                                 // "ON" - Send Blanking Packet, "OFF" - Skip Blanking Packet (Not Applicable for HARD_CPHY - Always ON).
        localparam DSI_EOTP                 = "ON";                                                 // "ON" - Send EOTp, "OFF" - Skip EOTp (Not Applicable for HARD_CPHY - Always OFF), 
        localparam DSI_VSA_LINES            = 5;                                                    // Number of Vertical Sync Active Lines.
        localparam DSI_VBP_LINES            = 36;                                                   // Number of Vertical Back Porch Lines.
        localparam DSI_VFP_LINES            = 4;                                                    // Number of Vertical Front Porch Lines.
        localparam DSI_HSA_WC               = 16'h0084;                                             // Horizontal Sync Active Blanking Packet Word Count. For Non-Burst Sync Pulse Mode.
        localparam DSI_BLLP_WC              = 16'h193A;                                             // BLLP Period Blanking Packet Word Count. For Continuous Clocking Mode.
        localparam DSI_HBP_WC               = 16'h01AC;                                             // Horizontal Back Porch Blanking Packet Word Count. For Continuous Clocking Mode and Non-Burst Sync Pulse Mode.
        localparam DSI_HFP_WC               = 16'h0102;                                             // Horizontal Front Porch Blanking Packet Word Count. For Continuous Clocking Mode and Non-Burst Sync Pulse Mode.
        localparam DSI_T_BLLP               = 2470000;                                              // In Picoseconds. BLLP Period Delay Duration. For Non-Continuous Clocking Mode.
        localparam DSI_T_HBP                = 800000;                                               // In Picoseconds. Horizontal Back Porch Delay Duration. For Non-Continuous Clocking Non-Burst Sync Event Mode and Burst Mode.
        localparam DSI_T_HFP                = 500000;                                               // In Picoseconds. Horizontal Front Porch Delay Duration. For Non-Continuous Clocking Non-Burst Sync Event Mode and Burst Mode.
        localparam DSI_HS_TXN_MODE          = "MULTI_PKT";                                          // "MULTI_PKT" - many packets per HS transaction (legacy). "SINGLE_PKT" - one content packet per HS transaction.
        localparam DSI_T_PKT_GAP            = DSI_T_HBP;                                            // In Picoseconds. LP-11 duration inserted between packets when DSI_HS_TXN_MODE == "SINGLE_PKT".
        // CSI Specific
        localparam CSI_LS_LE                = "ON";                                                 // "ON" - Send Line Start + Line End, "OFF" - Skip Line Start + Line End
        localparam CSI_T_LPS                = 100000;                                               // In Picoseconds. Delay Duration Between Packets.

        // Testbench Parameters - DO NOT EDIT
        localparam NUM_PIXELS_ADJ           = (RAW10_ENABLED  == "ON") ? (NUM_PIXELS - (NUM_PIXELS % 4)) :
                                              (RAW12_ENABLED  == "ON") ? (NUM_PIXELS - (NUM_PIXELS % 2)) : NUM_PIXELS;
        localparam int TB_SKEWCAL_UI        = int'($ceil(TB_T_SKEWCAL/UI));
        localparam TB_SKEWCAL_UI_ADJ        = TB_SKEWCAL_UI - (TB_SKEWCAL_UI%8);
        localparam int TB_ALTCAL_UI         = int'($ceil(TB_T_ALTCAL /UI));
        localparam TB_ALTCAL_UI_ADJ         = TB_ALTCAL_UI  - (TB_ALTCAL_UI %8);
        localparam TB_T3_PREEND             = 7*UI;
        localparam TB_T3_PREAMBLE           = ((TB_T3_PREPARE + TB_T3_PREBEGIN + TB_T3_PREEND) >= (112500 + (5*UI))) ? (TB_T3_PREBEGIN + TB_T3_PREEND) : (112500 + (5*UI));

        localparam PT_EN           = (BYTE_STREAM_INTF_EN == "ON" && PASSTHROUGH_MODE_EN == "ON") ? "ON" : "OFF";
        localparam PT_SOF_CHECK_EN = "OFF";  // "ON" to check SOF bit in passthrough mode, "OFF" to ignore it
        localparam EOTP_VC_COMP    = "ON";   // "ON" = compare VC/VCX on EoTP bytes (current behavior); "OFF" = ignore VC/VCX on EoTP bytes only
        localparam PT_MISMATCH_VERBOSE = "ON";  // "ON" to print mismatch details (line, expected, received), "OFF" for summary only
        localparam PT_TLAST_MODE   = MBSI_TLAST_MODE;  // "PER_TXN" | "PER_LPPKT" - from generated dut_params.v; must match DUT RX_MBSI_TLAST_MODE
        // MBSI VC/VCX alternation (RX only): "OFF" (default) = fixed VC_ID, current behavior.
        // "ON" = alternate VC per packet (and VCX on CSI2) so a per-beat compare can catch any
        // TDATA-vs-TUSER misalignment on the byte-stream interface. RX-scoped by construction:
        // these models are only instantiated under DIR_TYPE=="RX". The effective enable passed
        // to the models is additionally gated to PT_EN=="ON" (byte-stream passthrough / MBSI):
        // the UVSI/video path writes VC-agnostic expected pixels and the DUT filters to a single
        // VC_ID, so VC alternation there starves/scrambles the video path (invalid scenario).
        localparam MBSI_VC_ALT_EN  = "OFF";

        logic                               axis_vid_tready_i  = 1'b1;
        logic                               axis_vid_tvalid_o;
        logic   [TDATA_WIDTH-1:0]           axis_vid_tdata_o;
        logic   [1:0]                       axis_vid_tuser_o;
        logic                               axis_vid_tlast_o;

        logic                               axis_byte_tready_i = 1'b1;
        logic                               axis_byte_tvalid_o;
        logic   [BYTES_IN_PARALLEL*8-1:0]   axis_byte_tdata_o;
        logic   [77:0]                      axis_byte_tuser_o;
        logic                               axis_byte_tlast_o;
        
        logic   [TDATA_WIDTH-1:0]           axis_vid_tdata_r   =  'd0;
        logic   [TDATA_WIDTH-1:0]           axis_vid_tdata_rr  =  'd0;
        logic   [TDATA_WIDTH-1:0]           axis_vid_tdata_rrr =  'd0;
        logic   [1:0]                       axis_vid_tdata_ctr = 2'd0;
        logic   [31:0]                      num_pixels_ctr     = PIXELS_PER_CLOCK;
        logic   [3:0]                       num_pixels_mask;
		
		// AXI4-Lite CSR Interface signals
        logic                                    s_axi_aclk_i        = 1'b0;
        logic                                    s_axi_aresetn_i     = 1'b0;
        logic   [AXI4L_ADDR_WIDTH-1:0]           s_axi_awaddr_i      = {AXI4L_ADDR_WIDTH{1'b0}};
        logic   [2:0]                            s_axi_awprot_i      = 3'b000;
        logic                                    s_axi_awvalid_i     = 1'b0;
        wire                                     s_axi_awready_o;
        logic   [AXI4L_DATA_WIDTH-1:0]           s_axi_wdata_i       = {AXI4L_DATA_WIDTH{1'b0}};
        logic   [(AXI4L_DATA_WIDTH/8)-1:0]       s_axi_wstrb_i       = {(AXI4L_DATA_WIDTH/8){1'b0}};
        logic                                    s_axi_wvalid_i      = 1'b0;
        wire                                     s_axi_wready_o;
        wire    [1:0]                            s_axi_bresp_o;
        wire                                     s_axi_bvalid_o;
        logic                                    s_axi_bready_i      = 1'b0;
        logic   [AXI4L_ADDR_WIDTH-1:0]           s_axi_araddr_i      = {AXI4L_ADDR_WIDTH{1'b0}};
        logic   [2:0]                            s_axi_arprot_i      = 3'b000;
        logic                                    s_axi_arvalid_i     = 1'b0;
        wire                                     s_axi_arready_o;
        wire    [AXI4L_DATA_WIDTH-1:0]           s_axi_rdata_o;
        wire    [1:0]                            s_axi_rresp_o;
        wire                                     s_axi_rvalid_o;
        logic                                    s_axi_rready_i      = 1'b0;
        
        initial begin
            fork
                begin forever #(PHY_CLK_PERIOD/2)     dphy_clk        <= ~dphy_clk;         end
                begin forever #(CLK_FR_PERIOD_ADJ/2)  byte_clk_tb     <= ~byte_clk_tb;      end
                begin forever #(AXIS_CLK_PERIOD/2)    axis_vid_clk_i  <= ~axis_vid_clk_i;   end
                begin forever #(500000/SYNCCLK_MHZ)   ref_clk_i       <= ~ref_clk_i;        end
                begin forever #(PCLK_PERIOD/2)        pclk            <= ~pclk;             end // K1 Specific
                begin forever #(500000/PLL_REF_CLK)   refclk_p        <= ~refclk_p;         end // K1 Specific
                begin forever #(500000/PLL_REF_CLK)   refclk_n        <= ~refclk_n;         end // K1 Specific
				begin forever #(5000)                 s_axi_aclk_i    <= ~s_axi_aclk_i;     end // AXI4-Lite Clock 
            join
        end
        assign fr_clk_i = ((CLK_MODE == "HS_ONLY") && (CLK_FR_PERIOD <= 16667)) ? byte_clk_o : byte_clk_tb;
        
        // File Processing
        integer f = $fopen("tb_received_data.txt","w");

        // Tasks
        // Data Checker
        task data_checker();
            integer tb_expected_data;
            integer tb_received_data;
            integer expected_data_scan;
            integer received_data_scan;
            reg [13:0] expected_data_value;
            reg [13:0] received_data_value;
            automatic reg [31:0] data_matched_ctr    = 32'd0;
            automatic reg [31:0] data_mismatched_ctr = 32'd0;
            tb_expected_data = $fopen("tb_expected_data.txt","r");
            if (tb_expected_data == 0) begin
                $display("%t TEST FAILED! FAILED TO OPEN tb_expected_data.txt\n", $time);
                $finish;
            end
            tb_received_data = $fopen("tb_received_data.txt","r");
            if (tb_received_data == 0) begin
                $display("%t TEST FAILED! FAILED TO OPEN tb_received_data.txt\n", $time);
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
                    $display("%t TEST FAILED! DATA MISMATCH FOUND!\n", $time);
                else
                    $display("%t SIMULATION PASSED!\n", $time);
            end
            else if (expected_data_scan & !received_data_scan)
                $display("%t TEST FAILED! TESTBENCH RECEIVED LESS DATA THAN EXPECTED!\n", $time);
            else if (!expected_data_scan & received_data_scan)
                $display("%t TEST FAILED! TESTBENCH RECEIVED MORE DATA THAN EXPECTED!\n", $time);
            $display("%t DATA MATCHED: %0d, DATA MISMATCHED: %0d\n", $time,data_matched_ctr,data_mismatched_ctr);
            $fclose(tb_expected_data);
            $fclose(tb_received_data);
        endtask

        task passthrough_capture();
            integer i;
            reg [13:0] capture_val;
            for (i = 0; i < BYTES_IN_PARALLEL; i = i + 1) begin
                capture_val = {axis_byte_tuser_o[0],         // sof
                               axis_byte_tlast_o,             // tlast
                               axis_byte_tuser_o[3:2],        // vc
                               axis_byte_tuser_o[5:4],        // vcx
                               axis_byte_tdata_o[i*8 +: 8]}; // data
                $fwrite(f,"%04x\n", capture_val);
            end
        endtask

        task data_checker_pt();
            integer tb_expected_data;
            integer tb_received_data;
            integer tb_mask;
            integer expected_data_scan;
            integer received_data_scan;
            integer mask_scan;
            reg [13:0] expected_data_value;
            reg [13:0] received_data_value;
            reg [13:0] expected_cmp;
            reg [13:0] received_cmp;
            reg [3:0]  mask_value;   // 0 = skip (pad), 1 = compare, 2 = EoTP byte
            automatic reg [31:0] line_ctr             = 32'd0;
            automatic reg [31:0] data_matched_ctr    = 32'd0;
            automatic reg [31:0] data_mismatched_ctr = 32'd0;

            tb_expected_data = $fopen("tb_expected_data.txt","r");
            tb_received_data = $fopen("tb_received_data.txt","r");
            tb_mask          = $fopen("tb_expected_mask.txt","r");

            if (tb_expected_data == 0 || tb_received_data == 0 || tb_mask == 0) begin
                $display("%t TEST FAILED! FAILED TO OPEN comparison files\n", $time);
                $finish;
            end

            while (!$feof(tb_expected_data) && !$feof(tb_received_data)) begin
                expected_data_scan = $fscanf(tb_expected_data, "%h\n", expected_data_value);
                received_data_scan = $fscanf(tb_received_data, "%h\n", received_data_value);
                mask_scan          = $fscanf(tb_mask,          "%h\n", mask_value);
                line_ctr           = line_ctr + 1;
                if (mask_value) begin
                    expected_cmp = (PT_SOF_CHECK_EN == "OFF") ? {1'b0, expected_data_value[12:0]}
                                                               : expected_data_value;
                    received_cmp = received_data_value;
                    // EoTP VC/VCX gating (mask code 2): ignore VC (bits 11:10) and
                    // VCX (bits 9:8) on both sides. Never taken when EOTP_VC_COMP=="ON"
                    // -> identical to prior behavior.
                    if (mask_value == 4'h2 && EOTP_VC_COMP == "OFF") begin
                        expected_cmp[11:8] = 4'h0;
                        received_cmp[11:8] = 4'h0;
                    end
                    if (expected_cmp == received_cmp)
                        data_matched_ctr    = data_matched_ctr + 1;
                    else begin
                        data_mismatched_ctr = data_mismatched_ctr + 1;
                       if (PT_MISMATCH_VERBOSE == "ON")
                             $display("%t MISMATCH at line %0d: expected=%04x received=%04x\n",
                             $time, line_ctr, expected_cmp, received_cmp);
                    end
                end
            end
            if ((data_matched_ctr + data_mismatched_ctr) == 0)
                // Guard against a false pass: if no beats were compared (empty/short/malformed
                // mask or data files, e.g. a broken tb_expected_mask.txt) the mismatch counter
                // stays 0 and the run must NOT be reported as passing.
                $display("%t TEST FAILED! NO BEATS COMPARED (empty or malformed mask/data)!\n", $time);
            else if (data_mismatched_ctr != 0)
                $display("%t TEST FAILED! DATA MISMATCH FOUND!\n", $time);
            else
                $display("%t SIMULATION PASSED!\n", $time);
            $display("%t DATA MATCHED: %0d, DATA MISMATCHED: %0d\n", $time,
                     data_matched_ctr, data_mismatched_ctr);
            $fclose(tb_expected_data);
            $fclose(tb_received_data);
            $fclose(tb_mask);
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
            end
            else if (PIXELS_PER_CLOCK == 8) begin
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
            end
            else if (PIXELS_PER_CLOCK == 4) begin
                $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(0*16))+:8]); // P0[9:2]
                $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(1*16))+:8]); // P1[9:2]
                $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(2*16))+:8]); // P2[9:2]
                $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(3*16))+:8]); // P3[9:2]
                $fwrite(f,"%0x\n",{axis_vid_tdata_o[(3*16)+:2],axis_vid_tdata_o[(2*16)+:2],axis_vid_tdata_o[(1*16)+:2],axis_vid_tdata_o[(0*16)+:2]}); // P3[1:0],P2[1:0],P1[1:0],P0[1:0]
            end
            else if (PIXELS_PER_CLOCK == 2) begin
                if (axis_vid_tdata_ctr % 2 == 1) begin
                $fwrite(f,"%0x\n",axis_vid_tdata_r[(2+(0*16))+:8]);
                $fwrite(f,"%0x\n",axis_vid_tdata_r[(2+(1*16))+:8]);
                $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(0*16))+:8]);
                $fwrite(f,"%0x\n",axis_vid_tdata_o[(2+(1*16))+:8]);
                $fwrite(f,"%0x\n",{axis_vid_tdata_o[(1*16)+:2],axis_vid_tdata_o[(0*16)+:2],axis_vid_tdata_r[(1*16)+:2],axis_vid_tdata_r[(0*16)+:2]});
                end
          /*end else if (PIXELS_PER_CLOCK == 1) begin*/
            end
            else begin
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
            end
            else if (PIXELS_PER_CLOCK == 4) begin
                $fwrite(f,"%0x\n",axis_vid_tdata_o[(4+(0*16))+:8]); // P8[11:4]
                $fwrite(f,"%0x\n",axis_vid_tdata_o[(4+(1*16))+:8]); // P9[11:4]
                $fwrite(f,"%0x\n",{axis_vid_tdata_o[(1*16)+:4],axis_vid_tdata_o[(0*16)+:4]}); // P9[3:0],P8[3:0]
                if (num_pixels_mask == 'd0) begin
                $fwrite(f,"%0x\n",axis_vid_tdata_o[(4+(2*16))+:8]); // P10[11:4]
                $fwrite(f,"%0x\n",axis_vid_tdata_o[(4+(3*16))+:8]); // P11[11:4]
                $fwrite(f,"%0x\n",{axis_vid_tdata_o[(3*16)+:4],axis_vid_tdata_o[(2*16)+:4]}); // P11[3:0],P10[3:0]
                end
            end
            else if (PIXELS_PER_CLOCK == 2) begin
                $fwrite(f,"%0x\n",axis_vid_tdata_o[(4+(0*16))+:8]);
                $fwrite(f,"%0x\n",axis_vid_tdata_o[(4+(1*16))+:8]);
                $fwrite(f,"%0x\n",{axis_vid_tdata_o[(1*16)+:4],axis_vid_tdata_o[(0*16)+:4]});
          /*end else if (PIXELS_PER_CLOCK == 1) begin*/
            end
            else begin
                if (axis_vid_tdata_ctr % 2 == 1) begin
                $fwrite(f,"%0x\n",axis_vid_tdata_r[(4+(0*16))+:8]); // P0[11:4]
                $fwrite(f,"%0x\n",axis_vid_tdata_o[(4+(0*16))+:8]); // P1[11:4]
                $fwrite(f,"%0x\n",{axis_vid_tdata_o[(0*16)+:4],axis_vid_tdata_r[(0*16)+:4]}); // P1[3:0],P0[3:0]
                end
            end
        endtask
		
		task axi4lite_signal_driver();
            $display("%t Starting AXI4-Lite signal driver task", $time);
            
            // Initialize all AXI4-Lite signals to safe defaults
            s_axi_aresetn_i = 1'b0;        // Start in reset
            s_axi_awvalid_i = 1'b0;        
            s_axi_awaddr_i = {AXI4L_ADDR_WIDTH{1'b0}};     
            s_axi_awprot_i = 3'b000;       
            s_axi_wvalid_i = 1'b0;         
            s_axi_wdata_i = {AXI4L_DATA_WIDTH{1'b0}};      
            s_axi_wstrb_i = {(AXI4L_DATA_WIDTH/8){1'b0}}; 
            s_axi_bready_i = 1'b0;         
            s_axi_arvalid_i = 1'b0;        
            s_axi_araddr_i = {AXI4L_ADDR_WIDTH{1'b0}};     
            s_axi_arprot_i = 3'b000;       
            s_axi_rready_i = 1'b0;         
            
            // Wait for system initialization, then release reset
            #10000;
            s_axi_aresetn_i = 1'b1;        // Release AXI4-Lite reset
            
            // Set ready signals high to accept responses
            s_axi_bready_i = 1'b1;         
            s_axi_rready_i = 1'b1;
            s_axi_wvalid_i = 1'b1;
            s_axi_arvalid_i = 1'b1;
            s_axi_rready_i = 1'b1;
            s_axi_awvalid_i = 1'b1;           
            
            $display("%t AXI4-Lite inputs set to static values", $time);
        endtask

        // Testbench
        initial begin
		
			// Start AXI4-Lite signal driver task
            fork
                axi4lite_signal_driver();
            join_none
			
            $display("%t TEST START\n", $time);
            if (VIDEO_STREAM_INTF_EN == "ON")
                $display("%t TESTBENCH MODE: Video/UVS stream - checking axis_vid_*\n", $time);
            else if (BYTE_STREAM_INTF_EN == "ON" && PASSTHROUGH_MODE_EN == "ON")
                $display("%t TESTBENCH MODE: Byte streaming passthrough - checking axis_byte_*\n", $time);
            else
                $display("%t TESTBENCH MODE: Byte streaming (non-passthrough) - no capture block active\n", $time);
            #(TB_T_INIT);
            $display("%t Testbench is Out of Reset.\n", $time);
            tb_reset_n = 1'b1;
            #(1000);
            //$display("%t DUT D-PHY is Out of Reset.\n", $time);
            if (PHY_MODE == "SOFT_DPHY") begin
                ref_rst_n_i = 1'b1; 
                fr_rst_n_i = 1'b1;
            end
            else begin
                preset_n = 1'b1;
                ref_rst_n_i = 1'b1; 
                fr_rst_n_i = 1'b1;
                //rx_soft_rst_n = 1'b1;
                //rx_soft_shutdown_n = 1'b1;
            end
            #(10000);
            $display("%t DUT Controller is Out of Reset.\n", $time);
//            fork
//                begin
//                    @(posedge byte_clk_tb);
//                    fr_rst_n_i = 1'b1;
//                end
                begin
                    @(posedge axis_vid_clk_i);
                    axis_vid_rst_n_i = 1'b1;
                end
//            join
            if (APP_TYPE == "DSI2") begin
                $display("%t Activating DSI-2 PHY Model.\n", $time);
                phy_active = 1'b1;
                @(negedge phy_active);
                $display("%t DSI-2 PHY Model Transmission Complete.\n", $time);
            end
            else begin
                $display("%t Activating CSI-2 PHY Model\n", $time);
                phy_active = 1'b1;
                @(negedge phy_active);
                $display("%t CSI-2 PHY Model Transmission Complete.\n", $time);
            end
            #(10000);
            $fclose(f);
            if (PT_EN == "ON")
                data_checker_pt();
            else
                data_checker();
            $display("%t TEST FINISH\n", $time);
            $finish;
        end

        // Received Data from DUT
        if (VIDEO_STREAM_INTF_EN == "ON") begin
            always @(posedge axis_vid_clk_i) begin
                if (axis_vid_rst_n_i & axis_vid_tready_i & axis_vid_tvalid_o) begin
                    if (APP_TYPE == "DSI2") begin
                        if (RGB888_ENABLED == "ON")
                            axis_data_dsi_rgb888;
                        else if (RGB565_ENABLED == "ON")
                            axis_data_dsi_rgb565;
                    end
                    else begin
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
        end
        else if (BYTE_STREAM_INTF_EN == "ON" && PASSTHROUGH_MODE_EN == "ON") begin
            always @(posedge fr_clk_i) begin
                if (fr_rst_n_i & axis_byte_tready_i & axis_byte_tvalid_o) begin
                    passthrough_capture();
                end
            end
        end

        assign num_pixels_mask = (num_pixels_ctr > NUM_PIXELS_ADJ) ? (num_pixels_ctr - NUM_PIXELS_ADJ) : 'd0;

       
        if (APP_TYPE == "DSI2") begin : GEN_DSI2_MODEL
            if (PHY_MODE == "HARD_CPHY") begin : CPHY_MODEL
                cphy_dsi2_model #(
                    .NUM_RX_LANE            (NUM_LANE),
                    .UI                     (UI),
                    .NUM_FRAMES             (NUM_FRAMES),
                    .NUM_PIXELS             (NUM_PIXELS_ADJ),
                    .NUM_LINES              (NUM_LINES),
                    .VID_DT                 (VID_DT),
                    .BPP                    (TB_BPP),
                    .VC_ID                  (VC_ID),
                    .T_FRAME_GAP            (TB_T_FRAME_GAP),
                    .T_INIT                 (TB_T_INIT),
                    .T_LPX                  (TB_T_LPX),
                    .TB_T3_PREPARE          (TB_T3_PREPARE),
                    .TB_T3_PREAMBLE         (TB_T3_PREAMBLE),
                    .TB_T3_POST             (TB_T3_POST),
                    .DSI_TIMING_FORMAT      (DSI_TIMING_FORMAT),
                    .DSI_VSA_LINES          (DSI_VSA_LINES),
                    .DSI_VBP_LINES          (DSI_VBP_LINES),
                    .DSI_VFP_LINES          (DSI_VFP_LINES),
                    .DSI_HSA_WC             (DSI_HSA_WC),
                    .DSI_BLLP_WC            (DSI_BLLP_WC),
                    .DSI_HBP_WC             (DSI_HBP_WC),
                    .DSI_HFP_WC             (DSI_HFP_WC),
                    .DSI_T_BLLP             (DSI_T_BLLP),
                    .DSI_T_HBP              (DSI_T_HBP),
                    .DSI_T_HFP              (DSI_T_HFP)
                ) cphy_dsi2_model_inst (
                    .tb_reset_n             (tb_reset_n),
                    .d_a_io                 (d_a_io),
                    .d_b_io                 (d_b_io),
                    .d_c_io                 (d_c_io)
                );
                
                initial begin
                    @(posedge phy_active);
                    GEN_DSI2_MODEL.CPHY_MODEL.cphy_dsi2_model_inst.cphy_active = 1;
                    @(negedge GEN_DSI2_MODEL.CPHY_MODEL.cphy_dsi2_model_inst.cphy_active);
                    phy_active = 1'b0;
                end
            end
            else begin : DPHY_MODEL
                dphy_dsi2_model #(
                    .dphy_num_lane          (NUM_LANE),
                    .dphy_clk_period        (PHY_CLK_PERIOD),
                    .CLK_MODE               (CLK_MODE),
                    .BURST_MODE             (DSI_TIMING_FORMAT),
                    .LP_BLANKING            (DSI_BLANKING),
                    .EOTP                   (DSI_EOTP),
                    .sim_weak               (SIM_WEAK),
                    .send_cal               (SEND_CAL),
                    .send_alt_cal           (SEND_ALT_CAL),
                    .skewcal_ui             (TB_SKEWCAL_UI_ADJ),
                    .altcal_ui              (TB_ALTCAL_UI_ADJ),
                    .num_frames             (NUM_FRAMES),
                    .num_pixels             (NUM_PIXELS),
                    .num_lines              (NUM_LINES),
                    .t_lpx                  (TB_T_LPX),
                    .t_clk_prepare          (TB_T_CLK_PREPARE),
                    .t_clk_zero             (TB_T_CLK_ZERO),
                    .t_clk_pre              (TB_T_CLK_PRE),
                    .t_clk_post             (TB_T_CLK_POST),
                    .t_clk_trail            (TB_T_CLK_TRAIL),
                    .t_hs_prepare           (TB_T_HS_PREPARE),
                    .t_hs_zero              (TB_T_HS_ZERO),
                    .t_hs_trail             (TB_T_HS_TRAIL),
                    .t_init                 (TB_T_INIT),
                    .hsa_payload            (DSI_HSA_WC),
                    .bllp_payload           (DSI_BLLP_WC),
                    .hbp_payload            (DSI_HBP_WC),
                    .hfp_payload            (DSI_HFP_WC),
                    .lps_bllp_duration      (DSI_T_BLLP),
                    .lps_hbp_duration       (DSI_T_HBP),
                    .lps_hfp_duration       (DSI_T_HFP),
                    .lps_pkt_gap            (DSI_T_PKT_GAP),
                    .HS_TXN_MODE            (DSI_HS_TXN_MODE),
                    .virtual_channel        (VC_ID),
                    .video_data_type        (VID_DT),
                    .vsa_lines              (DSI_VSA_LINES),
                    .vbp_lines              (DSI_VBP_LINES),
                    .vfp_lines              (DSI_VFP_LINES),
                    .frame_gap              (TB_T_FRAME_GAP),
                    .passthrough_en         (PT_EN),
                    .tlast_mode             (PT_TLAST_MODE),
                    .vc_alternate           ((PT_EN == "ON") ? MBSI_VC_ALT_EN : "OFF"),
                    .uvsi_en                (VIDEO_STREAM_INTF_EN),
                    .BYTES_IN_PARALLEL      (BYTES_IN_PARALLEL)
                ) dphy_dsi2_model_inst (
                    .resetn                 (tb_reset_n),
                    .clk_p_io               (clk_p_io),
                    .clk_n_io               (clk_n_io),
                    .d_p_io                 (d_p_io),
                    .d_n_io                 (d_n_io)
                );
            
                initial begin
                    @(posedge phy_active);
                    GEN_DSI2_MODEL.DPHY_MODEL.dphy_dsi2_model_inst.dphy_active = 1;
                    @(negedge GEN_DSI2_MODEL.DPHY_MODEL.dphy_dsi2_model_inst.dphy_active);
                    phy_active = 1'b0;
                end
            end
        end
        else begin : GEN_CSI2_MODEL
            if (PHY_MODE == "HARD_CPHY") begin : CPHY_MODEL
                cphy_csi2_model #(
                    .NUM_RX_LANE            (NUM_LANE),
                    .UI                     (UI),
                    .NUM_FRAMES             (NUM_FRAMES),
                    .NUM_PIXELS             (NUM_PIXELS_ADJ),
                    .NUM_LINES              (NUM_LINES),
                    .VID_DT                 (VID_DT),
                    .BPP                    (TB_BPP),
                    .VC_ID                  (VC_ID),
                    .T_FRAME_GAP            (TB_T_FRAME_GAP),
                    .T_INIT                 (TB_T_INIT),
                    .T_LPX                  (TB_T_LPX),
                    .TB_T3_PREPARE          (TB_T3_PREPARE),
                    .TB_T3_PREAMBLE         (TB_T3_PREAMBLE),
                    .TB_T3_POST             (TB_T3_POST),
                    .CSI_LS_LE              (CSI_LS_LE),
                    .CSI_T_LPS              (CSI_T_LPS)
                ) cphy_csi2_model_inst (
                    .tb_reset_n             (tb_reset_n),
                    .d_a_io                 (d_a_io),
                    .d_b_io                 (d_b_io),
                    .d_c_io                 (d_c_io)
                );
                
                initial begin
                    @(posedge phy_active);
                    GEN_CSI2_MODEL.CPHY_MODEL.cphy_csi2_model_inst.cphy_active = 1;
                    @(negedge GEN_CSI2_MODEL.CPHY_MODEL.cphy_csi2_model_inst.cphy_active);
                    phy_active = 1'b0;
                end
            end
            else begin : DPHY_MODEL
                dphy_csi2_model #(
                    .num_frames             (NUM_FRAMES),
                    .num_pixels             (NUM_PIXELS),
                    .num_lines              (NUM_LINES),
                    .active_dphy_lanes      (NUM_LANE),
                    .data_type              (VID_DT),
                    .RX_CLK_MODE            (CLK_MODE),
                    .dphy_clk_period        (PHY_CLK_PERIOD),
                    .t_lpx                  (TB_T_LPX),
                    .t_clk_prepare          (TB_T_CLK_PREPARE),
                    .t_clk_zero             (TB_T_CLK_ZERO),
                    .t_clk_trail            (TB_T_CLK_TRAIL),
                    .t_clk_post             (TB_T_CLK_POST),
                    .t_clk_pre              (TB_T_CLK_PRE),
                    .t_hs_prepare           (TB_T_HS_PREPARE),
                    .t_hs_zero              (TB_T_HS_ZERO),
                    .t_hs_trail             (TB_T_HS_TRAIL),
                    .lps_gap                (CSI_T_LPS),
                    .frame_gap              (TB_T_FRAME_GAP),
                    .t_init                 (TB_T_INIT),
                    .dphy_vc                (VC_ID),
                    .LS_LE                  (CSI_LS_LE),
                    .sim_weak               (SIM_WEAK),
                    .send_cal               (SEND_CAL),
                    .send_alt_cal           (SEND_ALT_CAL),
                    .skewcal_ui             (TB_SKEWCAL_UI_ADJ),
                    .altcal_ui              (TB_ALTCAL_UI_ADJ),
                    .passthrough_en         (PT_EN),
                    .tlast_mode             (PT_TLAST_MODE),
                    .vc_alternate           ((PT_EN == "ON") ? MBSI_VC_ALT_EN : "OFF"),
                    .uvsi_en                (VIDEO_STREAM_INTF_EN),
                    .BYTES_IN_PARALLEL      (BYTES_IN_PARALLEL)
                ) dphy_csi2_model_inst (
                    .refclk_i               (dphy_clk),
                    .resetn                 (tb_reset_n),
                    .clk_p_io               (clk_p_io),
                    .clk_n_io               (clk_n_io),
                    .d_p_io                 (d_p_io),
                    .d_n_io                 (d_n_io)
                );
            
                initial begin
                    @(posedge phy_active);
                    GEN_CSI2_MODEL.DPHY_MODEL.dphy_csi2_model_inst.dphy_active = 1;
                    @(negedge GEN_CSI2_MODEL.DPHY_MODEL.dphy_csi2_model_inst.dphy_active);
                    phy_active = 1'b0;
                end
            end
        end
        
        // DUT Instantiation
        `include "dut_inst.v"
    end
    else if (DIR_TYPE == "TX") begin : TX_TB

        localparam TB_BPP                   = (RGB888_ENABLED == "ON") ? 24 :
                                              (RGB565_ENABLED == "ON") ? 16 :
                                              (RAW10_ENABLED  == "ON") ? 10 :
                                              (RAW12_ENABLED  == "ON") ? 12 : 12;

        // User Configurable Parameters
        localparam DEBUG_MODE               = 0;                        // Debug Mode: Turn on for debug printings
        localparam CRC_CHECK                = "ON";                     // CRC Check: Turn on to enable frame CRC value checking
        localparam NUM_FRAMES               = 3;                        // Number of Frames
        localparam NUM_PIXELS               = (BP_ENABLE  == "ON") ? ((H_ACTIVE_BYTES_TH*8)/TB_BPP) : 320;	// Number of Pixels - Must not exceed Line Buffer FIFO depth
        localparam NUM_LINES                = LINE_CNT;                 // Number of Vertical Lines - Configured through IP GUI
        
        // Engineering Parameter - DO NOT MODIFY
        localparam BLANKING_EN          	= (BP_ENABLE  == "ON") ? "ON" : "OFF";	// Blanking Check: Turn on to enable horizontal/vertical blanking period checking
        localparam R_LANE_GBPS              = LINE_RATE/1000;			            // Lane rate
		localparam IMG_WIDTH                = (BP_ENABLE  == "ON") ? (NUM_PIXELS*NUM_LANE) : NUM_PIXELS;	// Image Width: Same as number of pixels when blanking feature is disabled
        localparam IMG_HEIGHT               = NUM_LINES;	                        // Image Height: Same as number of lines
        localparam NUM_DATA_LINE_THRESHOLD 	= (NUM_FRAMES*IMG_WIDTH*TB_BPP*NUM_LINES)/8;	// Number of Data Received at RX_MODEL
        // Byte stream: wall time after byte_stream_done_ev before closing RX logging (timescale 1ps)
        localparam time BYTE_STREAM_POST_DONE_PS = 5_000_000; // 5000 ns
        localparam NUM_PIXELS_MAX           = LINE_BUFFER_DEPTH * 256 / (COLORIMETRY < 2 ? 24 : 16);
        localparam int H_BLANKING           = (BP_ENABLE  == "ON") ? 0 : (NUM_PIXELS * 2.50);	// Horizontal Blanking: Horizontal blanking cycle for testbench stimulus generation
        localparam int V_BLANKING           = (BP_ENABLE  == "ON") ? 0 : (NUM_LINES  * 0.20);	// Vertical Blanking: Vertical blanking cycle for testbench stimulus generation
        localparam int H_BLANK_PX           = (H_BLANKING_BYTES_TH*8)/TB_BPP;	// Horizontal Blanking: Horizontal blanking cycle for RX model blanking validation
        localparam int V_BLANK_LN           = VBLANKING_LINE_CNT;	// Vertical Blanking: Vertical blanking cycle for RX model blanking validation
        localparam TOTAL_WIDTH              = IMG_WIDTH  + H_BLANKING;  // Total Image Width: Image Width + Horizontal Blanking
        localparam TOTAL_HEIGHT             = IMG_HEIGHT + V_BLANKING;  // Total Image Height: Image Height + Vertical Blanking
        
        initial begin: power_up_check
            #10ps;
            fork
                begin: max_pixel_check
                    if (NUM_PIXELS > NUM_PIXELS_MAX) begin
                        $display("%t TEST HALTED! Image pixel exceeded Line Buffering depth. Please reconfigure NUM_PIXELS or increase the IP's Line Buffering FIFO Depth option in the IP GUI.", $time);
                        $finish;
                    end
                end
            join_none
        end

        
        // Engineering Parameter - DO NOT MODIFY
        localparam TDATA_PIXEL_SIZE         = TDATA_WIDTH / PIXELS_PER_CLOCK;
        localparam PLL_CLK_PERIOD           = (PHY_MODE == "SOFT_DPHY") ? (1_000_000 / (LINE_RATE / 2.0)) : (1_000_000 / LINE_RATE);
        localparam REF_CLK_PERIOD           = 1_000_000 / SYNCCLK_MHZ;
        localparam PIX_CLK_PERIOD_MAX       = 5_000;
        localparam PIX_CLK_PERIOD_CALC      = 1_000_000 / ((LINE_RATE * NUM_LANE) / (PIXELS_PER_CLOCK * PIX_WIDTH));
        localparam PIX_CLK_PERIOD           = (PIX_CLK_PERIOD_CALC > PIX_CLK_PERIOD_MAX) ? PIX_CLK_PERIOD_CALC : PIX_CLK_PERIOD_MAX;
        localparam AXI4L_CLK_PERIOD         = 1_000_000 / 60;

        integer frame_count                 = 0;
        string color_format                 = (COLORIMETRY == 0) ? "RGB 888" :
                                              (COLORIMETRY == 1) ? "RGB 565" :
                                              (COLORIMETRY == 2) ? "RAW 10"  :
                                              (COLORIMETRY == 3) ? "RAW 12"  : "RGB 888";

        // AXI Stream interface
        logic                               axis_vid_tready_o;
        logic                               axis_vid_tvalid_i   = 1'b0;;
        logic   [TDATA_WIDTH-1:0]           axis_vid_tdata_i    = {TDATA_WIDTH{1'b0}};
        logic   [1:0]                       axis_vid_tuser_i    = 2'b00;;
        logic                               axis_vid_tlast_i    = 1'b0;;

        event byte_stream_ready_ev, byte_stream_done_ev;
        // Byte-stream interface (always declared; driven by BFM when BYTE_STREAM_INTF_EN else tied idle)
        logic                               axis_byte_tvalid_i;
        logic                               axis_byte_tlast_i;
        logic [(BYTES_IN_PARALLEL*8)-1:0]   axis_byte_tdata_i;
        logic [77:0]                        axis_byte_tuser_i;
        logic                               axis_byte_tready_o;

        // AXI4-Lite interface
        logic                               s_axi_aclk_i       = 1'b1;
        logic                               s_axi_aresetn_i    = 1'b0;
        logic   [AXI4L_ADDR_WIDTH-1:0]      s_axi_awaddr_i     = {AXI4L_ADDR_WIDTH{1'b0}};
        logic   [2:0]                       s_axi_awprot_i     = 3'b000;
        logic                               s_axi_awvalid_i    = 1'b0;
        logic                               s_axi_awready_o;
        logic   [AXI4L_DATA_WIDTH-1:0]      s_axi_wdata_i      = {AXI4L_DATA_WIDTH{1'b0}};
        logic   [(AXI4L_DATA_WIDTH/8)-1:0]  s_axi_wstrb_i      = {(AXI4L_DATA_WIDTH/8){1'b0}};
        logic                               s_axi_wvalid_i     = 1'b0;
        logic                               s_axi_wready_o;
        logic   [1:0]                       s_axi_bresp_o;
        logic                               s_axi_bvalid_o;
        logic                               s_axi_bready_i     = 1'b0;
        logic   [AXI4L_ADDR_WIDTH-1:0]      s_axi_araddr_i     = {AXI4L_ADDR_WIDTH{1'b0}};
        logic   [2:0]                       s_axi_arprot_i     = 3'b000;
        logic                               s_axi_arvalid_i    = 1'b0;
        logic                               s_axi_arready_o;
        logic   [AXI4L_DATA_WIDTH-1:0]      s_axi_rdata_o;
        logic   [1:0]                       s_axi_rresp_o;
        logic                               s_axi_rvalid_o;
        logic                               s_axi_rready_i     = 1'b0;
        
        // File handle for payload data capture
        integer                             payload_file;
        string                              payload_filename;


        // Tasks
        // Data Checker
        task data_checker ();
            integer tb_expected_data;
            integer tb_received_data;
            integer expected_data_scan;
            integer received_data_scan;
            reg [13:0] expected_data_value;
            reg [13:0] received_data_value;
            automatic reg [31:0] data_matched_ctr    = 32'd0;
            automatic reg [31:0] data_mismatched_ctr = 32'd0;
            tb_expected_data = $fopen("tb_expected_data.txt","r");
            if (tb_expected_data == 0) begin
                $display("%t TEST FAILED! FAILED TO OPEN tb_expected_data.txt\n", $time);
                $finish;
            end
            tb_received_data = $fopen("tb_received_data.txt","r");
            if (tb_received_data == 0) begin
                $display("%t TEST FAILED! FAILED TO OPEN tb_received_data.txt\n", $time);
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
                if (data_mismatched_ctr != 0) begin
                    rx_model.sim_failed = 1'b1;
                    $display("%t TEST FAILED! DATA MISMATCH FOUND!\n", $time);
                end
            end
            else if (expected_data_scan & !received_data_scan) begin
                rx_model.sim_failed = 1'b1;
                $display("%t TEST FAILED! TESTBENCH RECEIVED LESS DATA THAN EXPECTED!\n", $time);
            end
            else if (!expected_data_scan & received_data_scan) begin
                rx_model.sim_failed = 1'b1;
                $display("%t TEST FAILED! TESTBENCH RECEIVED MORE DATA THAN EXPECTED!\n", $time);
            end
            $display("%t DATA MATCHED: %0d, DATA MISMATCHED: %0d\n", $time,data_matched_ctr,data_mismatched_ctr);
            $fclose(tb_expected_data);
            $fclose(tb_received_data);
        endtask
        
        // AXI Stream Transmitter - Load and transmit frame
        task axi_stream_transmit ();
            @(posedge axis_vid_clk_i);
            $display("%t Starting AXI Stream Image Transmission.", $time);

            // Transmit frames
            repeat(NUM_FRAMES) begin
                transmit_frame();
                frame_count = frame_count + 1;
                $display("%t Frame %0d/%0d: %0d pixel x %0d line @ %s", $time, frame_count, NUM_FRAMES, IMG_WIDTH, IMG_HEIGHT, color_format);
            end
            
            #(10000);
            $display("%t AXI Stream Transmission Completed.", $time);
        endtask
        
        // Transmit Frame
        task transmit_frame ();
            bit     [6*8-1:0]   pixel_data[0:PIXELS_PER_CLOCK-1];
            bit                 valid_pixel;
            int                 y;  // Image height
            int                 vb;
            int                 xb; // Horizontal blanking
            int                 xf; // Horizontal frame/pixel
            int                 i;

            // Iterate image height + v_blanking
            for (y = 0; y < IMG_HEIGHT; y = y + 1) begin
                // Line h_blanking
                for (xb = 0; xb < H_BLANKING/PIXELS_PER_CLOCK; xb = xb + 1) begin
                    axis_vid_tvalid_i = 1'b0;
                    axis_vid_tlast_i = 1'b0;
                    @(posedge axis_vid_clk_i);
                end

                // Line active pixel
                for (xf = 0; xf < IMG_WIDTH/PIXELS_PER_CLOCK; xf = xf + 1) begin
                    for (i = 0; i < PIXELS_PER_CLOCK; i = i + 1) begin
                        if (COLORIMETRY == 0) begin
                            pixel_data[i] = $random;
                            axis_vid_tdata_i[TDATA_PIXEL_SIZE*i +: TDATA_PIXEL_SIZE] = pixel_data[i][PIX_WIDTH-1:0];
                        end
                        else if (COLORIMETRY == 1) begin
                            pixel_data[i] = $random;
                            axis_vid_tdata_i[(8*2) + TDATA_PIXEL_SIZE*i +: 8] = {pixel_data[i][11 +: 5], {3{1'b0}}};
                            axis_vid_tdata_i[(8*1) + TDATA_PIXEL_SIZE*i +: 8] = {pixel_data[i][ 5 +: 6], {2{1'b0}}};
                            axis_vid_tdata_i[(8*0) + TDATA_PIXEL_SIZE*i +: 8] = {pixel_data[i][ 0 +: 5], {3{1'b0}}};
                        end
                        else if (COLORIMETRY == 2) begin
                            pixel_data[i] = $random;
                            axis_vid_tdata_i[TDATA_PIXEL_SIZE*i +: TDATA_PIXEL_SIZE] = {{6{1'b0}}, pixel_data[i][0*10 +: 10]};
                        end
                        else if (COLORIMETRY == 3) begin
                            pixel_data[i] = $random;
                            axis_vid_tdata_i[TDATA_PIXEL_SIZE*i +: TDATA_PIXEL_SIZE] = {{4{1'b0}}, pixel_data[i][0*12 +: 12]};
                        end
                    end

                    axis_vid_tvalid_i = 1'b1;
                    axis_vid_tlast_i = (xf == IMG_WIDTH/PIXELS_PER_CLOCK - 1) ? 1'b1 : 1'b0;
                    axis_vid_tuser_i[0] = (xf == 0) && (y == 0);

                    #10ps;  // Prevent race

                    // Hold outgoing AXI-Stream content until tready asserted
                    wait (axis_vid_tready_o == 1'b1);
                    @(posedge axis_vid_clk_i);
                end
                
                // Going to next line
                axis_vid_tvalid_i = 1'b0;
                axis_vid_tlast_i = 1'b0;
            end

            // Line v_blanking
            for (vb = 0; vb < V_BLANKING; vb = vb + 1) begin
                axis_vid_tvalid_i = 1'b0;
                axis_vid_tlast_i = 1'b0;
                repeat (TOTAL_WIDTH/PIXELS_PER_CLOCK) begin
                    @(posedge axis_vid_clk_i);
                    #10ps;  // Prevent race
                end
            end

            // End of image
            @(posedge axis_vid_clk_i);
            axis_vid_tvalid_i = 1'b0;
            axis_vid_tlast_i = 1'b0;
        endtask // transmit_frame
        
        // Wait for simulation to complete (video: RX byte count; byte stream: settle time applied in main_test after byte_stream_done_ev)
        task wait_simulation_data ();
            if (VIDEO_STREAM_INTF_EN == "ON") begin
			    wait (rx_model.data_write_count == NUM_DATA_LINE_THRESHOLD);
			    #(10000);
            end else if (BYTE_STREAM_INTF_EN == "ON") begin
                // no-op: post-done delay is #(BYTE_STREAM_POST_DONE_PS) in main_test only
                #(300_000_000);
            end else begin
                #(10_000);
            end
            #(5_000_000);
        endtask

        // -------------------------------------------------------------------------
        // Byte stream packet generator (BFM) when BYTE_STREAM_INTF_EN
        // Clock: AXI-Stream Clock. Scenarios: back-to-back short/long, gap 0-255, payload 38-100 bytes.
        // -------------------------------------------------------------------------
        if (BYTE_STREAM_INTF_EN == "ON") begin : gen_axi_byte_bfm
            axi_byte_stream_pkt_gen #(
              .BYTES_IN_PARALLEL    (BYTES_IN_PARALLEL),
              .TUSER_WIDTH          (78),
              .TDATA_WIDTH          (BYTES_IN_PARALLEL*8),
              .CRC_INSERT_EN        (CRC_EN),
              .ECC_INSERT_EN        (ECC_EN),
              .VCX_EN               ("ON"),
              .PASSTHROUGH_MODE     (PASSTHROUGH_MODE_EN)
            ) u_axi_byte_stream_pkt_gen (
              .clk_i                (axis_vid_clk_i),
              .rst_n_i              (axis_vid_rst_n_i),
              .axis_byte_tready_o   (axis_byte_tready_o),
              .axis_byte_tdata_i    (axis_byte_tdata_i),
              .axis_byte_tvalid_i   (axis_byte_tvalid_i),
              .axis_byte_tlast_i    (axis_byte_tlast_i),
              .axis_byte_tuser_i    (axis_byte_tuser_i)
            );
            initial begin : byte_stream_stimulus
                int pt_short_short_short_long[];
                int pt_long_long[];
                int pt_long_short[];
                int pl_32_33_34[];
                int pl_38_39_40[];
                integer byte_stream_tx_file;
                @(byte_stream_ready_ev);
                repeat (100) @(posedge axis_vid_clk_i);
                $display("[%0t] Byte-stream BFM: tinit_done, starting packet sequence", $realtime);
                repeat (10) @(posedge axis_vid_clk_i);

                byte_stream_tx_file = $fopen("tb_expected_data.txt", "w");
                if (byte_stream_tx_file == 0) begin
                    $display("[%0t] ERROR: Could not open tb_expected_data.txt", $realtime);
                end else begin
                    u_axi_byte_stream_pkt_gen.set_tx_data_file(byte_stream_tx_file);
                end

                u_axi_byte_stream_pkt_gen.run_frame_sequence(3, 0, 6'h24, 40);
                repeat (50) @(posedge axis_vid_clk_i);
                u_axi_byte_stream_pkt_gen.run_frame_sequence(3, 5, 6'h22, 40);
                repeat (50) @(posedge axis_vid_clk_i);

                pt_short_short_short_long = '{0, 0, 0, 1};
                pl_32_33_34 = '{32};
                u_axi_byte_stream_pkt_gen.run_sequence(pt_short_short_short_long, 0, pl_32_33_34);
                repeat (50) @(posedge axis_vid_clk_i);

                pt_long_long = '{1, 1};
                pl_32_33_34 = '{34, 38};
                u_axi_byte_stream_pkt_gen.run_sequence(pt_long_long, 5, pl_32_33_34);
                repeat (50) @(posedge axis_vid_clk_i);

                pt_long_short = '{1, 0};
                pl_32_33_34 = '{94};
                u_axi_byte_stream_pkt_gen.run_sequence(pt_long_short, 10, pl_32_33_34);
                repeat (50) @(posedge axis_vid_clk_i);

                pt_short_short_short_long = '{0, 1};
                pl_38_39_40 = '{33};
                u_axi_byte_stream_pkt_gen.run_sequence(pt_short_short_short_long, 255, pl_38_39_40);

                pt_long_long = '{1, 1, 1, 1};
                pl_32_33_34 = '{32, 33, 34, 35};
                u_axi_byte_stream_pkt_gen.run_sequence(pt_long_long, 2, pl_32_33_34);

                u_axi_byte_stream_pkt_gen.set_tx_data_file(0);
                if (byte_stream_tx_file != 0) begin
                    $fclose(byte_stream_tx_file);
                    $display("[%0t] Byte stream TX data written to tb_expected_data.txt", $realtime);
                end
                $display("[%0t] Byte stream packet generator: sequence done.", $realtime);
                -> byte_stream_done_ev;
            end
        end


        rx_model #(
            .DEBUG_ENABLE       (DEBUG_MODE),       // Enable print message for debug  
            .NUM_LANE           (NUM_LANE),         // Number of D-PHY Lane
			.LS_LE_EN			(LS_LE_EN == "ON" ? 1 : 0),
            .CLK_MODE           (CLK_MODE == "HS_ONLY" ? "CONTINUOUS" : "NON_CONTINUOUS"),  // D-PHY Clocking Mode
			
            .CRC_CHECK          (CRC_CHECK),        // CRC Check
            .INTF_TYPE          (APP_TYPE),         // Application: CSI-2 / DSI-2
            .FRAME_CNT_EN       (BYTE_STREAM_INTF_EN == "ON" ? "OFF" : FRAME_CNT_ENABLE), // Enable Frame Counting
            .NUM_FRAMES         (BYTE_STREAM_INTF_EN == "ON" ? 0 : FRAME_CNT_MAX),    // Expected frame number when FRAME_CNT_ENABLE is turned ON
			.BLANKING_EN 		(BLANKING_EN),	// 
			.R_LANE_GBPS		(R_LANE_GBPS),		// 
			.H_ACTIVE 			(IMG_WIDTH),		// 
			.V_ACTIVE	 		(IMG_HEIGHT),		// 
			.H_BLANK_PX	 		(H_BLANK_PX),		// 
			.V_BLANK_LN	 		(V_BLANK_LN),		// 
			.BPP 				(TB_BPP),			// 
			.PIXELS_PER_CLOCK	(PIXELS_PER_CLOCK),
			
			.T_LPX				(T_LPX),
			.T_DATPREP			(T_DATPREP),
			.T_SKEWCAL_HSZERO	(T_SKEWCAL_HSZERO),
			.T_DAT_HSZERO		(T_DAT_HSZERO),
			.T_DATTRAIL			(T_DATTRAIL),
			.T_DATEXIT			(T_DATEXIT),
			.T_CLKPREP			(T_CLKPREP),
			.T_CLK_HSZERO		(T_CLK_HSZERO),
			.T_CLKPRE			(T_CLKPRE),
			.T_CLKPOST			(T_CLKPOST),
			.T_CLKTRAIL			(T_CLKTRAIL),
			.T_CLKEXIT			(T_CLKEXIT),
            .GEAR               (PHY_DATA_WIDTH)    // D-PHY Data Width
        ) rx_model (
            .reset_n_i          (tinit_done_o),     // Remain in reset untill tinit_done_o is asserted
            .c_p_i              (clk_p_io),
            .c_n_i              (clk_n_io),
            .d_p_i              (d_p_io),
            .d_n_i              (d_n_io) 
        );


        initial begin: clk_gen
            fork
                begin   forever #(PIX_CLK_PERIOD/2)     axis_vid_clk_i = ~axis_vid_clk_i;   end
                begin   forever #(REF_CLK_PERIOD/2)     ref_clk_i      = ~ref_clk_i;        end
                begin   forever #(AXI4L_CLK_PERIOD/2)   s_axi_aclk_i   = ~s_axi_aclk_i;     end
            join_none
        end
        
        initial begin: pll_gen
            fork
                begin   forever #(PLL_CLK_PERIOD/2) pll_clkop_i  = ~pll_clkop_i;        end
                begin   #(PLL_CLK_PERIOD/4);    // 90 degree phase shift
                        forever #(PLL_CLK_PERIOD/2) pll_clkos_i  = ~pll_clkos_i;        end
            join_none
        end

        always @(posedge pll_clkop_i) begin: pll_clkop_x2_derived
            pll_clkop_x2 <= ~pll_clkop_x2;
        end

        always @(posedge pll_clkop_x2) begin: pll_clkop_x4_derived
            pll_clkop_x4 <= ~pll_clkop_x4;
        end

        initial begin: ddr_init_sequence
            eclk_ready_i      = 1'd0;
            eclk_reset_i      = 1'd1;
            ddr_sync_busy     = 1'd0;
            #(20000);
            #(REF_CLK_PERIOD*2);
            ddr_sync_busy     = 1'd1;
            eclk_reset_i      = 1'd0;
            #(REF_CLK_PERIOD*4);
            eclk_reset_i      = 1'd1;
            #(REF_CLK_PERIOD*4);
            eclk_reset_i      = 1'd0;
            #(REF_CLK_PERIOD*4);
            ddr_sync_busy     = 1'd0;
            #(REF_CLK_PERIOD*8);
            eclk_ready_i      = 1'd1;
        end

        assign eclk_syncclk_i = ddr_sync_busy ? 1'b0 : pll_clkop_i;
        assign byte_clk_i = ddr_sync_busy ? 1'b0 : pll_clkop_x4;


        initial begin: main_test
            // Testbench Power-up and Initialization Sequence
            $display("%t TEST START\n", $time);
            #(10000);
            $display("%t Testbench is Out of Reset.\n", $time);
            tb_reset_n = 1'b1;
            #(1000);

            fork
                ref_rst_n_i = 1'b1;
                s_axi_aresetn_i = 1'b1;
                axis_vid_rst_n_i = 1'b1;
            join_none

            fork
                begin: tinit_check
                    $display("%t Waiting for PHY T-INIT done...\n", $time);
                    wait (tinit_done_o == 1'b1);
                    $display("%t PHY T-INIT Completed!\n", $time);
                end
            join
            
            $display("%t DUT Controller is Ready.\n", $time);
            $display("%t %s Rx Model is Active.\n", $time, APP_TYPE);
            
            if (VIDEO_STREAM_INTF_EN == "ON") begin
            axi_stream_transmit ();
            #(10000);
                    if (payload_file != 0) $fclose(payload_file);
            $display("%t Processing Rx Model Result...", $time);
            end else if (BYTE_STREAM_INTF_EN == "ON") begin
                -> byte_stream_ready_ev;
                @(byte_stream_done_ev);
                #(BYTE_STREAM_POST_DONE_PS);
                $display("%t Byte-stream BFM done; %0t ps settle after done_ev", $time, BYTE_STREAM_POST_DONE_PS);
            end
            #(10_000);
            if (payload_file != 0) $fclose(payload_file);
            wait_simulation_data ();
            
            rx_model.eotb = 1'b1;
            $display("%t CSI-2 Rx Model Data Reception Complete.\n", $time);

            #(10000);

            if (VIDEO_STREAM_INTF_EN == "ON" || BYTE_STREAM_INTF_EN == "ON") begin
            data_checker ();
            end

            if (rx_model.sim_failed) begin
                $display("%t SIMULATION FAILED", $time);
            end
            else begin
                $display("%t SIMULATION PASSED", $time);
            end
            $display("%t TEST FINISH\n", $time);
            $finish;
        end

        // Data Logger: video path only (byte-stream uses BFM to write tb_expected_data.txt)
        if (VIDEO_STREAM_INTF_EN == "ON") begin : gen_tb_expected_data
        initial begin: tb_expected_data
            // Raw 10
            bit [ 9:0] raw10_pix [0:3];
            bit [ 7:0] raw10_B0;
            bit [ 7:0] raw10_B1;
            bit [ 7:0] raw10_B2;
            bit [ 7:0] raw10_B3;
            bit [ 7:0] raw10_B4;
            
            // Raw 12
            bit [11:0] raw12_pix [0:1];
            bit [ 7:0] raw12_B0;
            bit [ 7:0] raw12_B1;
            bit [ 7:0] raw12_B2;
            
            int pix_count = 0;
            int base = ( (COLORIMETRY == 0) || (COLORIMETRY == 1) ) ? 24 :
                       ( (COLORIMETRY == 2) || (COLORIMETRY == 3) ) ? 16 : 24;

            payload_filename = $sformatf("tb_expected_data.txt");
            payload_file = $fopen(payload_filename, "w");
            
            if (payload_file == 0) begin
                $display("Error: Could not open payload file %s", payload_filename);
                $finish;
            end
            
            // Image pixel logging
            forever begin
                @(posedge axis_vid_clk_i);
                #10ps;  // Prevent race
                if (axis_vid_tready_o && axis_vid_tvalid_i) begin
                    if (COLORIMETRY == 0) begin
                        for (int p = 0; p < PIXELS_PER_CLOCK; p = p + 1) begin
                            $fwrite(payload_file, "%02h\n%02h\n%02h\n", axis_vid_tdata_i[7 + base*p -: 8], axis_vid_tdata_i[15 + base*p -: 8], axis_vid_tdata_i[23 + base*p -: 8]);
                            $fflush(payload_file);
                        end
                    end // rgb888
                    else if (COLORIMETRY == 1) begin
                        for (int p = 0; p < PIXELS_PER_CLOCK; p = p + 1) begin
                            $fwrite(payload_file, "%02h\n%02h\n", {axis_vid_tdata_i[12 + base*p -: 3], axis_vid_tdata_i[7 + base*p -: 5]}, {axis_vid_tdata_i[23 + base*p -: 5], axis_vid_tdata_i[15 + base*p -: 3]});
                            $fflush(payload_file);
                        end
                    end // rgb565
                    else if (COLORIMETRY == 2) begin
                        for (int p = 0; p < PIXELS_PER_CLOCK; p = p + 1) begin
                            raw10_pix[pix_count] = axis_vid_tdata_i[9 + base*p -: 10];
                            pix_count = pix_count + 1;
                            
                            if (pix_count == 4) begin
                                raw10_B0 = raw10_pix[0][9:2];
                                raw10_B1 = raw10_pix[1][9:2];
                                raw10_B2 = raw10_pix[2][9:2];
                                raw10_B3 = raw10_pix[3][9:2];
                                raw10_B4 = {raw10_pix[3][1:0], raw10_pix[2][1:0], raw10_pix[1][1:0], raw10_pix[0][1:0]};
                                $fwrite(payload_file, "%02h\n%02h\n%02h\n%02h\n%02h\n", raw10_B0, raw10_B1, raw10_B2, raw10_B3, raw10_B4);
                                $fflush(payload_file);
                                pix_count = 0;
                            end
                        end
                    end // raw10
                    else if (COLORIMETRY == 3) begin
                        for (int p = 0; p < PIXELS_PER_CLOCK; p = p + 1) begin
                            raw12_pix[pix_count] = axis_vid_tdata_i[11 + base*p -: 12];
                            pix_count = pix_count + 1;
                            
                            if (pix_count == 2) begin
                                raw12_B0 = raw12_pix[0][11:4];
                                raw12_B1 = raw12_pix[1][11:4];
                                raw12_B2 = {raw12_pix[1][3:0], raw12_pix[0][3:0]};
                                $fwrite(payload_file, "%02h\n%02h\n%02h\n", raw12_B0, raw12_B1, raw12_B2);
                                $fflush(payload_file);
                                pix_count = 0;
                            end
                        end
                    end // raw12
                    $fflush(payload_file);
                end
                end
            end
        end


        // DUT Instantiation
        `include "dut_inst.v"
    end
    endgenerate


    // GSR Clock Generation
    initial begin: gsr_gen
        fork
            begin forever #(5)  CLK_GSR <= ~CLK_GSR;    end
        join
    end

    // GSR
    GSR GSR_INST (
        .GSR_N      (USER_GSR),
        .CLK        (CLK_GSR)
    );


endmodule   // tb_top

`endif

