//===========================================================================
// Filename: rx_model.sv
// Copyright(c) 2025 Lattice Semiconductor Corporation. All rights reserved. 
//===========================================================================

`timescale 1ns/1ps

`ifndef RX_MODEL
`define RX_MODEL
module rx_model #(
    parameter               DEBUG_ENABLE            = 1'b0,  // Set to 1'b1 to enable debug, 1'b0 to disable //Debug control parameter - can be overridden during instantiation or compilation
    parameter               NUM_LANE                = 4,
    parameter               CLK_MODE                = "CONTINUOUS",
    parameter               HEADER_CHECK            = "OFF",
    parameter               EOTP_CHECK              = "OFF",
    parameter               CRC_CHECK               = "ON",
    parameter               ECC_CHECK               = "ON",
    parameter               INTF_TYPE               = "CSI2",
    parameter               FRAME_CNT_EN            = "ON",
    parameter               NUM_FRAMES              = 3,
    parameter               HS0_TIMEOUT             = 999999999,/// test
    parameter               DPHY_IP                 = "MIXEL",
    parameter               GEAR                    = 8,
    parameter               CIL_BYPASS              = "CIL_BYPASSED",
    parameter               BLANKING_EN             = "OFF",
    
    // -- Video Resolution --
    parameter integer       H_ACTIVE                = 1920,         // Active pixels per line
    parameter integer       V_ACTIVE                = 16,           // Active lines per frame
    parameter integer       H_BLANK_PX              = 0,            // Horizontal blanking pixels
    parameter integer       V_BLANK_LN              = 0,            // Vertical blanking lines
    parameter integer       BPP                     = 10,
    parameter integer       PIXELS_PER_CLOCK        = 1,
    // -- D-PHY Link Rate --
    parameter real          R_LANE_GBPS             = 0.912,      // Per-lane bit rate (Gbps)

    // -- Protocol Features --
    parameter bit           LS_LE_EN                = 1'b1,       // Line Start/Line End packets

    // -- D-PHY Timing 
    parameter integer       T_LPX                   = 10,
    parameter integer       T_DATPREP               = 8,
    parameter integer       T_SKEWCAL_HSZERO        = 19,
    parameter integer       T_DAT_HSZERO            = 22,
    parameter integer       T_DATTRAIL              = 18,
    parameter integer       T_DATEXIT               = 20,
    parameter integer       T_CLKPREP               = 8,
    parameter integer       T_CLK_HSZERO            = 51,
    parameter integer       T_CLKPRE                = 2,
    parameter integer       T_CLKPOST               = 19,
    parameter integer       T_CLKTRAIL              = 12,
    parameter integer       T_CLKEXIT               = 20,

    // -- Protocol Constants (fixed per CSI-2 spec) --
    parameter integer       PH_BYTES                = 4,             // Packet Header size
    parameter integer       CRC_BYTES               = 2,             // CRC size
    parameter integer       SP_BYTES                = 4,             // Short Packet size (FS/FE/LS/LE)

    // -- Blanking Analyze Bypass --
    parameter integer       BLANKING_SKIP_H         = 0,             // Number of initial H_BLANK analyze to bypass
    parameter integer       BLANKING_SKIP_V         = 0              // Number of initial V_BLANK analyze to bypass
) (
    input                   reset_n_i,      // Reset
    input                   c_p_i,          // Positive part of clock.
    input                   c_n_i,          // Negative part of clock.
    input   [NUM_LANE-1:0]  d_p_i,          // Positive part of data.
    input   [NUM_LANE-1:0]  d_n_i           // Negative part of data.
);

    ///////////////////////////////////////////////////////////////////////////////////////
    // Testbench Parameters - DO NOT EDIT
    localparam real BLANKING_TOLERANCE = 0.20;
    
    // -- Byte Clock --
    localparam real T_BC_NS         = GEAR / R_LANE_GBPS;              // ns per byte clock
    localparam real F_BC_HZ         = R_LANE_GBPS * 1e9 / GEAR;        // byte clock frequency
    
    localparam real T_LPX_NS            = T_LPX*T_BC_NS;        // LP-01 duration
    localparam real T_HS_PREPARE_NS     = T_DATPREP*T_BC_NS;    // HS-Prepare duration
    localparam real T_HS_ZERO_NS        = T_DAT_HSZERO*T_BC_NS; // HS-Zero duration
    localparam real T_HS_TRAIL_NS       = T_DATTRAIL*T_BC_NS;   // HS-Trail duration
    localparam real T_LP11_GAP_NS       = 0;                    // LP-11 dwell between bursts (protocol gap)
    
    // -- Pixel Domain --
    localparam integer H_BLANK_PX_RAW   = H_BLANK_PX*NUM_LANE;          // H_BLANK_PX is divided version based on NUM_LANE
    localparam integer H_TOTAL          = H_ACTIVE + H_BLANK_PX_RAW;    // total pixels per line
    localparam integer V_TOTAL          = V_ACTIVE + V_BLANK_LN;        // total lines per frame

    // -- Byte Clocks Per Lane --
    localparam integer BC_ACTIVE    = (H_ACTIVE * BPP) / (GEAR * NUM_LANE);  // active payload BC
    localparam integer PH_BC        = (PH_BYTES  + NUM_LANE - 1) / NUM_LANE;  // CEILING(4/N)
    localparam integer CRC_BC       = (CRC_BYTES + NUM_LANE - 1) / NUM_LANE;  // CEILING(2/N)
    localparam integer SP_BC        = (SP_BYTES  + NUM_LANE - 1) / NUM_LANE;  // CEILING(4/N)

    // -- D-PHY Transition Overhead (ns) --
    localparam real T_SOT_NS        = T_LPX_NS + T_HS_PREPARE_NS + T_HS_ZERO_NS;
    localparam real T_EOT_NS        = T_HS_TRAIL_NS;
    localparam real T_BURST_OH_NS   = T_SOT_NS + T_EOT_NS + T_LP11_GAP_NS;

    // ===============================================================
    //  For comparison: Ideal (no overhead) values
    // ===============================================================
    localparam integer  BC_LINE_IDEAL   = (H_TOTAL * BPP) / (GEAR * NUM_LANE);
    localparam integer  BC_FRAME_IDEAL  = BC_LINE_IDEAL * V_TOTAL;
    localparam real T_LINE_IDEAL_NS     = BC_LINE_IDEAL * T_BC_NS;
    localparam real T_FRAME_IDEAL_NS    = BC_FRAME_IDEAL * T_BC_NS;
    localparam real FPS_IDEAL           = F_BC_HZ / BC_FRAME_IDEAL;

    // ===============================================================
    //  Per-Burst Durations (in ns)
    // ===============================================================
    // Short packet burst: SoT + [4-byte SP data] + EoT
    localparam real T_SP_DATA_NS    = SP_BC * T_BC_NS;
    localparam real T_SP_BURST_NS   = T_SOT_NS + T_SP_DATA_NS + T_EOT_NS;

    // Long packet burst: SoT + [PH] + [payload] + [CRC] + EoT
    localparam real T_PH_NS         = PH_BC * T_BC_NS;
    localparam real T_PAYLOAD_NS    = BC_ACTIVE * T_BC_NS;
    localparam real T_CRC_NS        = CRC_BC * T_BC_NS;
    localparam real T_DATA_BURST_NS = T_SOT_NS + T_PH_NS + T_PAYLOAD_NS + T_CRC_NS + T_EOT_NS;

    // ===============================================================
    //  H-Blank Duration (in ns)
    // ===============================================================
    // H-blank in byte clocks (pixel-domain blanking mapped to BC)
    localparam integer BC_H_BLANK   = (H_BLANK_PX_RAW * BPP) / (GEAR * NUM_LANE);
    localparam real T_H_BLANK_NS    = BC_H_BLANK * T_BC_NS;
    
    localparam integer BC_H_TOTAL   = BC_ACTIVE+BC_H_BLANK;
    // ===============================================================
    //  Estimated Line Duration (FS->...->LE-> [H-blank] -> LS of next line)
    // ===============================================================
    //
    //  WITH LS/LE, one line period on the wire looks like:
    //
    //  /-LS burst-\  LP11  /---- Data burst ----\  LP11  /-LE burst-\   H-blank
    //  |SoT|SP|EoT|  gap   |SoT|PH|pixels|CRC|EoT|  gap  |SoT|SP|EoT|   (idle)
    //
    localparam real T_LINE_WITH_LSLE_NS =   T_SP_BURST_NS           // LS burst
                                            + T_LP11_GAP_NS         // LP-11 gap (LS -> Data)
                                            + T_DATA_BURST_NS       // Long packet burst (PH + pixels + CRC)
                                            + T_LP11_GAP_NS         // LP-11 gap (Data -> LE)
                                            + T_SP_BURST_NS         // LE burst
                                            + T_H_BLANK_NS;         // Horizontal blanking idle

    localparam real T_LINE_NO_LSLE_NS   =   T_DATA_BURST_NS          // Long packet burst only
                                            + T_H_BLANK_NS;          // Horizontal blanking idle

    localparam real T_LINE_NS           = LS_LE_EN ? T_LINE_WITH_LSLE_NS : T_LINE_NO_LSLE_NS;

    // ===============================================================
    //  Estimated Frame Duration
    // ===============================================================
    //
    //  Frame = FS + gap + [V_active lines] + gap + FE + V-blank
    //
    //  /-FS-\ LP11 /-Line 1-\ /-Line 2-\ ... /-Line N-\ LP11 /-FE-\  V-blank
    //

    localparam real T_V_BLANK_NS    = V_BLANK_LN * T_LINE_IDEAL_NS;
    localparam real T_FRAME_NS      =   T_SP_BURST_NS                // FS burst
                                        + T_LP11_GAP_NS              // gap (FS -> first line)
                                        + (V_ACTIVE * T_LINE_NS)     // all active lines (each includes H-blank)
                                        + T_LP11_GAP_NS              // gap (last LE -> FE)
                                        + T_SP_BURST_NS              // FE burst
                                        + T_V_BLANK_NS;              // vertical blanking

    localparam real ESTIMATED_FPS   =  (BLANKING_EN == "ON") ? (1e9/T_FRAME_NS) : 0.0;  // ns -> Hz

    ///////////////////////////////////////////////////////////////////////////////////////
    
    localparam [31:0] EOTP_VAL          = 32'h010F0F08;

    integer tx_output_data_file;
    integer write_file_timing;
    integer i;
    // Global variables for timing parameters
    time global_T_LPX;
    time global_HS_prepare;
    time global_HS_zero;
    time global_HS_trail;
    time global_UI;
    
    real global_HS_sum = 0;
    real global_T_LPX_expected = 0;
    real global_HS_prepare_min_expected = 0;
    real global_HS_prepare_max_expected = 0;
    real global_HS_sum_expected = 0;
    real global_HS_trail_expected = 0;

    integer global_failed_cases = 0;
    integer global_passed_cases = 0;

    integer global_EoTp_SP_failed_cases = 0;
    integer global_EoTp_SP_passed_cases = 0;

    integer global_EoTp_LP_failed_cases = 0;
    integer global_EoTp_LP_passed_cases = 0;

    integer global_CRC_failed_cases = 0;
    integer global_CRC_passed_cases = 0;

    integer global_SOT_failed_cases = 0;
    integer global_SOT_passed_cases = 0;

    integer global_EOT_bit_failed_cases = 0;
    integer global_EOT_bit_passed_cases = 0;

    integer global_ECC_failed_cases = 0;
    integer global_ECC_passed_cases = 0;

    integer global_FRAME_NUMBER_failed_cases = 0;
    integer global_FRAME_NUMBER_passed_cases = 0;

    integer global_Blanking_passed_cases = 0;
    integer global_Blanking_failed_cases = 0;

    integer timing_param_fail   = 0;
    integer data_write_count    = 0;

    reg                short_packet           =  1'd0;
    reg                eotb                   =  1'd0;            // Register used to close a file after TB top module request
    reg         [31:0] header_r               = 32'd0;
    reg         [ 1:0] virtual_channel_r       =  2'd0;
    reg         [ 5:0] data_type_r            =  6'd0;
    reg         [15:0] word_count_r           = 16'd0;
    reg         [ 5:0] ecc_calc               =  6'd0;
    reg         [ 7:0] ecc_r                  =  8'd0;
    reg [NUM_LANE-1:0] data_register_p_r      = {NUM_LANE{1'd0}}; // Register used to check trail bits
    reg [NUM_LANE-1:0] data_register_n_r      = {NUM_LANE{1'd0}}; // Register used to check trail bits
    reg         [15:0] frame_count_r          = 16'd0;
    reg         [15:0] line_count_r           = 16'd0;
    reg         [15:0] exp_frame_count_r      = 16'd0;
    reg         [15:0] exp_line_count_r       = 16'd0;
    reg         [15:0] packet_count_r         = 16'd1;
    // For CRC check
    reg         [15:0] calculated_crc_r       = 16'd0;
    reg                calculated_crc_valid_r =  1'd0;
    reg         [15:0] received_crc_r         = 16'd0;
    reg                received_crc_valid_r   =  1'd0;
    reg                sim_failed             =  1'd0;

    reg                clk_state_hs_lpn;
    // for eot bit check
    reg [         7:0] byte_data0_r,byte_data0_r1,byte_data0_r2;
    reg [         7:0] byte_data1_r,byte_data1_r1,byte_data1_r2;
    reg [         7:0] byte_data2_r,byte_data2_r1,byte_data2_r2;
    reg [         7:0] byte_data3_r,byte_data3_r1,byte_data3_r2;
    reg [        15:0] cil_bytes_header_0 = 16'd0;
    reg [        15:0] cil_bytes_header_1 = 16'd0;
    reg [        15:0] tmp_r;
    reg                eotp_check_start;
    reg                eotp_check_start1;
    reg                eotp_check_start2;
    reg                eotp_check_start3;
    reg                eotp_check_start4;
    reg                eotp_check_start5;
    reg [NUM_LANE-1:0] toggle_datap;
    reg [NUM_LANE-1:0] toggle_datan;
    reg                pass_fail_r;
    reg                header_decoded        =  1'd0;
    // Blanking analysis registers
    reg         [ 5:0] prev_data_type_r      =  6'd0;
    reg                prev_short_packet     =  1'd0;
    reg                frame_end_seen        =  1'd0;
    time               lp11_measured         =  0;
    integer            h_blank_count         =  0;
    integer            v_blank_count         =  0;
    integer            h_blank_pass          =  0;
    integer            h_blank_fail          =  0;
    integer            v_blank_pass          =  0;
    integer            v_blank_fail          =  0;
    integer            blanking_other_count  =  0;

    // Computed blanking thresholds (populated in initial block)
    real               h_total_bytes_th;
    real               h_active_bytes_th;
    real               h_blank_bytes;
    real               v_blank_lines_r;
    real               v_blank_bytes;
    real               byte_clk_period_ns;
    real               h_blank_time_ns;
    real               v_blank_time_ns;
    real               h_total_time_ns;
    real               blanking_tolerance;

    time               h_active_time_ns_measured    =  0;
    time               h_blank_time_ns_measured     =  0;
    time               v_blank_time_ns_measured     =  0;

    real               tolerance_minus_h_blank_time_ns;
    real               tolerance_plus_h_blank_time_ns;
    real               tolerance_minus_v_blank_time_ns;
    real               tolerance_plus_v_blank_time_ns;
    // Frame rate measurement
    real               frame_start_time_ns;
    real               prev_frame_start_time_ns;
    real               frame_period_ns;
    real               frame_rate_fps;
    real               frame_rate_min;
    real               frame_rate_max;
    real               frame_rate_sum;
    integer            frame_rate_count;
    reg                prev_frame_start_valid;

    // Line time measurement (LS-to-LS or image-data-to-image-data)
    real               line_start_time_ns;
    real               prev_line_start_time_ns;
    real               line_period_ns;
    real               line_period_min;
    real               line_period_max;
    real               line_period_sum;
    integer            line_period_count;
    reg                prev_line_start_valid;

    // Estimated line/frame timing derived from ESTIMATED_FPS parameter
    real               estimated_frame_period_ns;
    real               estimated_line_period_ns;
    integer            line_time_pass;
    integer            line_time_fail;
    integer            frame_time_pass;
    integer            frame_time_fail;
    // HS active data burst measurement (BC_active)
    real               hs_data_start_time;
    real               hs_data_end_time;
    real               hs_data_duration_ns;
    real               bc_active_measured;
    real               bc_active_estimated;
    real               bc_active_min;
    real               bc_active_max;
    real               bc_active_sum;
    integer            bc_active_count;
    integer            bc_active_pass;
    integer            bc_active_fail;

    always begin
        debug_display("Reset start");
        reset;                          // Reset
        header_decoded = 1'd0;
        debug_display("Reset done");

        debug_display("LP-11 Start start");
        wait4LPstart;                   // Check Timing parameters in data lines
        debug_display("LP Start done");

        debug_display("Sync word detection start");
        wait4B8;                        // Shifted data to detect B8 sync char
        debug_display("Sync word detection done");

        if (!wait4B8.sync_error) begin
            hs_data_start_time = $realtime;
            debug_display("Header read start");  
            readheader;                 // Reads header
            header_decoded = 1'd1;
            debug_display("Header read done");

            if (short_packet == 1'd0) begin     // For Long packet EoT checks in task below
                readbyte;                       // Reads payload data, footer and EoTp
            end
            else if (EOTP_CHECK == "ON") begin
                eotpcheck;                      // Checks EoTp after short packet
            end

            hs_data_end_time    = $realtime;
            hs_data_duration_ns = hs_data_end_time - hs_data_start_time;
            bc_active_measured  = hs_data_duration_ns / T_BC_NS;
            if (short_packet)
                bc_active_estimated = SP_BC * 1.0;
            else
                bc_active_estimated = (PH_BC + ((word_count_r + NUM_LANE - 1) / NUM_LANE) + CRC_BC) * 1.0;
        end

        debug_display("wait4LP11 start");  
        wait4LP11;                      // Check trail time in data line and wait for LP-11
        debug_display("wait4LP11 done");  
    end

    always begin
        crc_calc;
    end

    always @(posedge calculated_crc_valid_r or posedge received_crc_valid_r) begin
        if (calculated_crc_valid_r && received_crc_valid_r) begin
            #1;
            if (CRC_CHECK == "ON") begin
                if (calculated_crc_r == received_crc_r) begin
                    global_CRC_passed_cases = global_CRC_passed_cases + 1;
                end
                else begin
                    global_CRC_failed_cases = global_CRC_failed_cases + 1;
                end
            end
            #1;
            calculated_crc_valid_r = 1'd0;
            received_crc_valid_r   = 1'd0;
        end
    end
    
    // always_comb begin
        // if (BLANKING_EN == "ON") begin
                // if (h_blank_pass | v_blank_pass) begin
                    // global_Blanking_passed_cases = global_Blanking_passed_cases + 1;
                // end
                
                // if (h_blank_fail | v_blank_fail) begin
                    // global_Blanking_failed_cases = global_Blanking_failed_cases + 1;
                // end
        // end
    // end
    
    always begin
        data_register_p_r <= d_p_i;
        data_register_n_r <= d_n_i;
        wait4clk(1);
    end

    always begin
        while (!reset_n_i) begin
            #1;
        end
        @(posedge readbyte.in_process);
        wait4byteclk(((word_count_r)/NUM_LANE) + ((4/NUM_LANE)*(EOTP_CHECK == "ON")));
        eotp_check_start  = 1'd1;
        wait4byteclk(1);
        eotp_check_start1 = 1'd1;
        wait4byteclk(1);
        eotp_check_start2 = 1'd1;
        @(negedge wait4LP11.start);
        eotp_check_start  = 1'd0;
        eotp_check_start1 = 1'd0;
        eotp_check_start2 = 1'd0;
    end

    always begin
        @(posedge eotp_check_start);
        if (NUM_LANE == 4) begin
            if (word_count_r[1:0] == 2'd0) begin
                toggle_datap = {~data_register_p_r[3:2],2'bzz};
                toggle_datan = {~data_register_n_r[3:2],2'bzz};
                while (!eotp_check_start1 && !pass_fail_r) begin
                    if (d_p_i[3:2] == toggle_datap[3:2]) begin
                        // pass_fail_r = 0;
                    end
                    else begin
                        pass_fail_r = 1;
                    end
                    wait4clk(1);
                end
                toggle_datap = { data_register_p_r[3:2],~data_register_p_r[1:0]};
                toggle_datan = { data_register_n_r[3:2],~data_register_n_r[1:0]};
                while (!(d_p_i &  d_n_i)) begin
                    if (d_p_i[3:0] == toggle_datap[3:0] && !pass_fail_r) begin
                        // pass_fail_r = 0;
                    end
                    else begin
                        pass_fail_r = 1;
                    end 
                    wait4clk(1);
                end
            end
            else if (word_count_r[1:0] == 2'd1) begin
                toggle_datap = {~data_register_p_r[3],3'bzzz};
                toggle_datan = {~data_register_n_r[3],3'bzzz};
                while (!eotp_check_start1 && !pass_fail_r) begin
                    if (d_p_i[3] == toggle_datap[3]) begin
                        // pass_fail_r = 0;
                    end
                    else begin
                        pass_fail_r = 1;
                    end
                    wait4clk(1);
                end
                toggle_datap = { data_register_p_r[3],~data_register_p_r[2:0]};
                toggle_datan = { data_register_n_r[3],~data_register_n_r[2:0]};
                while (!(d_p_i &  d_n_i) && !pass_fail_r) begin
                    if (d_p_i[3:0] == toggle_datap[3:0]) begin
                        // pass_fail_r = 0;
                    end
                    else begin
                        pass_fail_r = 1;
                    end 
                    wait4clk(1);
                end
            end
            else if (word_count_r[1:0] == 2'd2) begin
                while (!eotp_check_start1) begin
                    wait4clk(1);
                end
                toggle_datap = { ~data_register_p_r[3:0]};
                toggle_datan = { ~data_register_n_r[3:0]};
                while (!(d_p_i &  d_n_i) && !pass_fail_r) begin
                    if (d_p_i[3:0] == toggle_datap[3:0]) begin
                        // pass_fail_r = 0;
                    end
                    else begin
                        pass_fail_r = 1;
                    end 
                    wait4clk(1);
                end
            end
            else if (word_count_r[1:0] == 2'd3) begin
                @(posedge eotp_check_start1);
                toggle_datap = {~data_register_p_r[3:1],1'bz};
                toggle_datan = {~data_register_n_r[3:1],1'bz};
                while (!eotp_check_start2 && !pass_fail_r) begin
                    if (d_p_i[3:1] == toggle_datap[3:1]) begin
                        pass_fail_r = 0;
                    end
                    else begin
                        pass_fail_r = 1;
                    end
                    wait4clk(1);
                end
                toggle_datap = { data_register_p_r[3:1],~data_register_p_r[0]};
                toggle_datan = { data_register_n_r[3:1],~data_register_n_r[0]};
                while (!(d_p_i &  d_n_i) && !pass_fail_r) begin
                    if (d_p_i[3:0] == toggle_datap[3:0]) begin
                        pass_fail_r = 0;
                    end
                    else begin
                        pass_fail_r = 1;
                    end 
                    wait4clk(1);
                end
            end
        end
        else if (NUM_LANE == 2) begin
            if (word_count_r[0] == 2'd0) begin
                @(posedge eotp_check_start1);
                toggle_datap = {~data_register_p_r[1:0]};
                toggle_datan = {~data_register_n_r[1:0]};
                while (!(d_p_i &  d_n_i) && !pass_fail_r) begin
                    if (d_p_i[1:0] == toggle_datap[1:0]) begin
                        // pass_fail_r = 0;
                    end
                    else begin
                        pass_fail_r = 1;
                    end 
                    wait4clk(1);
                end
            end
            else if (word_count_r[0] == 2'd1) begin
                @(posedge eotp_check_start1);
                toggle_datap = {~data_register_p_r[1],1'bx};
                toggle_datan = {~data_register_n_r[1],1'bx};
                while (!eotp_check_start2 && !pass_fail_r) begin
                    if (d_p_i[1] == toggle_datap[1]) begin
                        pass_fail_r = 0;
                    end
                    else begin
                        pass_fail_r = 1;
                    end
                    wait4clk(1);
                end
                toggle_datap = {data_register_p_r[1],~data_register_p_r[0]};
                toggle_datan = {data_register_n_r[1],~data_register_n_r[0]};
                while (!(d_p_i &  d_n_i) && !pass_fail_r) begin
                    if (d_p_i[1:0] == toggle_datap[1:0]) begin
                        pass_fail_r = 0;
                    end
                    else begin
                        pass_fail_r = 1;
                    end 
                    wait4clk(1);
                end
            end
        end
        else if (NUM_LANE == 1) begin
            @(posedge eotp_check_start2);
            toggle_datap = {~data_register_p_r[0]};
            toggle_datan = {~data_register_n_r[0]};
            while (!(d_p_i &  d_n_i) && !pass_fail_r) begin
                if (d_p_i[0] == toggle_datap[0]) begin
                    // pass_fail_r = 0;
                end
                else begin
                    pass_fail_r = 1;
                end 
                wait4clk(1);
            end
        end
        #1000;
        global_EOT_bit_passed_cases = global_EOT_bit_passed_cases + !pass_fail_r;
        global_EOT_bit_failed_cases = global_EOT_bit_failed_cases +  pass_fail_r;
        pass_fail_r                 = 1'd0;
        #1000;
    end

    initial begin
        eotpcheck_after_lp.in_process = 0; // Added to fix Modelsim issue
        readbyte.in_process = 0;
        readbyte.byte_count = 16'd0;
        readbyte.data       = {8*NUM_LANE{1'd0}};
        readbyte.byte1      = 0;
        readbyte.byte2      = 0;
        readbyte.byte3      = 0;
        readbyte.byte4      = 0;
        readbyte.byte1r     = 0;
        readbyte.byte2r     = 0;
        readbyte.byte3r     = 0;
        readbyte.byte4r     = 0;
        readbyte.crc_en     = 0;
        byte_data0_r        = 8'd0;
        byte_data1_r        = 8'd0;
        byte_data2_r        = 8'd0;
        byte_data3_r        = 8'd0;
        byte_data0_r1       = 8'd0;
        byte_data1_r1       = 8'd0;
        byte_data2_r1       = 8'd0;
        byte_data3_r1       = 8'd0;
        byte_data0_r2       = 8'd0;
        byte_data1_r2       = 8'd0;
        byte_data2_r2       = 8'd0;
        byte_data3_r2       = 8'd0;
        eotp_check_start    = 1'd0;
        eotp_check_start1   = 1'd0;
        eotp_check_start2   = 1'd0;
        eotp_check_start3   = 1'd0;
        eotp_check_start4   = 1'd0;
        eotp_check_start5   = 1'd0;
        pass_fail_r         = 1'd0;
        toggle_datap        = 'dz;
        toggle_datan        = 'dz;
        // Frame rate measurement init
        frame_start_time_ns      = 0.0;
        prev_frame_start_time_ns = 0.0;
        frame_period_ns          = 0.0;
        frame_rate_fps           = 0.0;
        frame_rate_min           = 1.0e30;
        frame_rate_max           = 0.0;
        frame_rate_sum           = 0.0;
        frame_rate_count         = 0;
        prev_frame_start_valid   = 1'b0;
        // Line time measurement init
        line_start_time_ns       = 0.0;
        prev_line_start_time_ns  = 0.0;
        line_period_ns           = 0.0;
        line_period_min          = 1.0e30;
        line_period_max          = 0.0;
        line_period_sum          = 0.0;
        line_period_count        = 0;
        prev_line_start_valid    = 1'b0;
        // Line/frame timing check counters
        line_time_pass           = 0;
        line_time_fail           = 0;
        frame_time_pass          = 0;
        frame_time_fail          = 0;
        // BC_active measurement init
        hs_data_start_time       = 0.0;
        hs_data_end_time         = 0.0;
        hs_data_duration_ns      = 0.0;
        bc_active_measured       = 0.0;
        bc_active_estimated       = 0.0;
        bc_active_min            = 1.0e30;
        bc_active_max            = 0.0;
        bc_active_sum            = 0.0;
        bc_active_count          = 0;
        bc_active_pass           = 0;
        bc_active_fail           = 0;
        
        if (BLANKING_EN == "ON") begin
            byte_clk_period_ns  = T_BC_NS;
            h_total_bytes_th    = BC_ACTIVE+BC_H_BLANK;
            h_active_bytes_th   = BC_ACTIVE;
            h_blank_bytes       = BC_H_BLANK;
            v_blank_lines_r     = V_BLANK_LN;
            v_blank_bytes       = v_blank_lines_r*h_total_bytes_th;
            h_total_time_ns     = T_LINE_NS;
            h_blank_time_ns     = T_H_BLANK_NS;
            v_blank_time_ns     = T_V_BLANK_NS;
            blanking_tolerance = BLANKING_TOLERANCE;
            $display("========================================");
            $display("[BLANKING CONFIG] BLANKING_EN  = ON");
            $display("[BLANKING CONFIG] BYTE_CLK_FREQ   = %.3f MHz", F_BC_HZ / 1.0e6);
            $display("[BLANKING CONFIG] H_TOTAL         = %0d pixels", H_TOTAL);
            $display("[BLANKING CONFIG] H_ACTIVE        = %0d pixels", H_ACTIVE);
            $display("[BLANKING CONFIG] V_TOTAL         = %0d lines",  V_TOTAL);
            $display("[BLANKING CONFIG] V_ACTIVE        = %0d lines",  V_ACTIVE);
            $display("[BLANKING CONFIG] BPP             = %0d bits",   BPP);
            $display("[BLANKING CONFIG] H_TOTAL_BYTES   = %.1f bytes", h_total_bytes_th);
            $display("[BLANKING CONFIG] H_ACTIVE_BYTES  = %.1f bytes", h_active_bytes_th);
            $display("[BLANKING CONFIG] H_BLANK_BYTES   = %.1f bytes", h_blank_bytes);
            $display("[BLANKING CONFIG] V_BLANK_LINES   = %.0f lines", v_blank_lines_r);
            $display("[BLANKING CONFIG] V_BLANK_BYTES   = %.1f bytes", v_blank_bytes);
            $display("[BLANKING CONFIG] Byte CLK Period = %.3f ns",    byte_clk_period_ns);
            $display("[BLANKING CONFIG] H_TOTAL_TIME    = %.1f ns",    h_total_time_ns);
            $display("[BLANKING CONFIG] H_BLANK_TIME    = %.1f ns",    h_blank_time_ns);
            $display("[BLANKING CONFIG] V_BLANK_TIME    = %.1f ns",    v_blank_time_ns);
            $display("========================================");
        end

        // Compute estimated line/frame timing from ESTIMATED_FPS parameter
        if (ESTIMATED_FPS > 0.0) begin
            // T_frame = 1 / FPS  (in ns)
            estimated_frame_period_ns = T_FRAME_NS;
            // T_line  = T_frame / V_TOTAL  (each frame has V_TOTAL lines total)
            // estimated_line_period_ns  = estimated_frame_period_ns / (1.0 * V_TOTAL);
            estimated_line_period_ns  = T_LINE_NS;
            $display("========================================");
            // $display("[TIMING CHECK CONFIG] ESTIMATED_FPS(with overhead)         = %.3f fps", ESTIMATED_FPS);
            // $display("[TIMING CHECK CONFIG] Estimated Frame Period(with overhead)    = %.1f ns (%.6f ms)", estimated_frame_period_ns, estimated_frame_period_ns / 1.0e6);
            // $display("[TIMING CHECK CONFIG] Estimated Line Period(with overhead) = %.1f ns (%.6f us)", estimated_line_period_ns, estimated_line_period_ns / 1.0e3);
            $fwrite(write_file_timing,"  Ideal Line Period(without overhead)  = %.3f us \n", T_LINE_IDEAL_NS / 1.0e3);
            $fwrite(write_file_timing,"  Ideal Frame Period(without overhead)  = %.3f ms (%.3f fps)\n", T_FRAME_IDEAL_NS / 1.0e6, FPS_IDEAL);
            $display("[TIMING CHECK CONFIG] V_TOTAL (lines/frame)   = %0d", V_TOTAL);
            // $display("[TIMING CHECK CONFIG] Tolerance               = +/-%.0f%%", blanking_tolerance * 100.0);
            $display("[TIMING CHECK CONFIG] LS_LE_EN                = %0d", LS_LE_EN);
            // $display("[TIMING CHECK CONFIG] BLANKING_SKIP_H         = %0d", BLANKING_SKIP_H);
            // $display("[TIMING CHECK CONFIG] BLANKING_SKIP_V         = %0d", BLANKING_SKIP_V);
            $display("========================================");
        end
        else begin
            estimated_frame_period_ns = 0.0;
            estimated_line_period_ns  = 0.0;
        end
        
        tx_output_data_file   = $fopen("tb_received_data.txt","w"); // file where writes DPHY_TX's output data
        write_file_timing     = $fopen("tb_rx_model_timing.txt","w"); // file where writes DPHY_TX's output data
        $fwrite(write_file_timing,"TIMING VALUES OF DATA LINES\n");
        $fwrite(write_file_timing,"START\n");
        @(posedge eotb);
        $fclose(tx_output_data_file);
        
        if (timing_param_fail == 0) begin
            $fwrite(write_file_timing,"ALL TIMING PARAMETERS PASS\n");
            $fflush(write_file_timing);
        end
        else begin
            $fwrite(write_file_timing,"%d PARAMETERS FAILED \n",timing_param_fail);
            $fflush(write_file_timing);
        end
        
        // Blanking analysis summary
        if (BLANKING_EN == "ON") begin
            $fwrite(write_file_timing,"\n");
            $fwrite(write_file_timing,"========================================\n");
            $fwrite(write_file_timing,"     BLANKING ANALYSIS SUMMARY\n");
            $fwrite(write_file_timing,"========================================\n");
            $fwrite(write_file_timing,"Configuration:\n");
            $fwrite(write_file_timing,"  Byte CLK Freq    = %.3f MHz\n", F_BC_HZ / 1.0e6);
            $fwrite(write_file_timing,"  H_TOTAL          = %0d pixels\n", H_TOTAL);
            $fwrite(write_file_timing,"  H_ACTIVE         = %0d pixels\n", H_ACTIVE);
            $fwrite(write_file_timing,"  V_TOTAL          = %0d lines\n",  V_TOTAL);
            $fwrite(write_file_timing,"  V_ACTIVE         = %0d lines\n",  V_ACTIVE);
            $fwrite(write_file_timing,"  LS_LE_EN         = %0d\n", LS_LE_EN);
            $fwrite(write_file_timing,"  BPP              = %0d bits\n",   BPP);
            $fwrite(write_file_timing,"  PIXELS_PER_CLOCK = %0d\n",   PIXELS_PER_CLOCK);
            
            $fwrite(write_file_timing,"Byte Clock Domain:\n");
            $fwrite(write_file_timing,"  H_TOTAL_BYTES_TH = %.1f bytes (BC_ACTIVE+BC_H_BLANK)\n",  BC_H_TOTAL);
            $fwrite(write_file_timing,"  H_ACTIVE_BYTES_TH= %.1f bytes BC_ACTIVE\n", BC_ACTIVE);
            $fwrite(write_file_timing,"  H_BLANK_BYTES    = %.1f bytes BC_H_BLANK\n", BC_H_BLANK);
            $fwrite(write_file_timing,"  V_BLANK_LINES    = %.0f lines V_BLANK_LINES\n", V_BLANK_LN);
            $fwrite(write_file_timing,"  V_BLANK_BYTES    = %.1f bytes (V_BLANK_LN * H_TOTAL_BYTES_TH)\n", V_BLANK_LN*BC_H_TOTAL);
            // $fwrite(write_file_timing,"Estimated Blanking Durations:\n");
            // $fwrite(write_file_timing,"  H_BLANK_TIME     = %.1f ns\n", T_H_BLANK_NS);
            // $fwrite(write_file_timing,"  V_BLANK_TIME     = %.1f ns\n", T_V_BLANK_NS);
            // $fwrite(write_file_timing,"Blanking Analyze Results:\n");
            // $fwrite(write_file_timing,"  BLANKING_SKIP_H  = %0d\n", BLANKING_SKIP_H);
            // $fwrite(write_file_timing,"  BLANKING_SKIP_V  = %0d\n", BLANKING_SKIP_V);
            // $fwrite(write_file_timing,"  H_BLANK periods  = %0d total (%0d pass, %0d info, %0d skipped)\n", h_blank_count, h_blank_pass, h_blank_fail, (h_blank_count > BLANKING_SKIP_H) ? BLANKING_SKIP_H : h_blank_count);
            // $fwrite(write_file_timing,"  V_BLANK periods  = %0d total (%0d pass, %0d info, %0d skipped)\n", v_blank_count, v_blank_pass, v_blank_fail, (v_blank_count > BLANKING_SKIP_V) ? BLANKING_SKIP_V : v_blank_count);
            // $fwrite(write_file_timing,"  Other LP-11      = %0d (protocol overhead)\n", blanking_other_count);
            $fwrite(write_file_timing,"========================================\n");
            $fflush(write_file_timing);
            $display("========================================");
            // $display("[BLANKING SUMMARY] H_BLANK: %0d total (%0d pass, %0d info, %0d skipped)", h_blank_count, h_blank_pass, h_blank_fail, (h_blank_count > BLANKING_SKIP_H) ? BLANKING_SKIP_H : h_blank_count);
            // $display("[BLANKING SUMMARY] V_BLANK: %0d total (%0d pass, %0d info, %0d skipped)", v_blank_count, v_blank_pass, v_blank_fail, (v_blank_count > BLANKING_SKIP_V) ? BLANKING_SKIP_V : v_blank_count);
            // $display("[BLANKING SUMMARY] Other:   %0d (protocol overhead)", blanking_other_count);
            $display("========================================");
        end

        // HS Active Data (BC_active) summary
        if (bc_active_count > 0) begin
            $fwrite(write_file_timing,"\n");
            $fwrite(write_file_timing,"========================================\n");
            $fwrite(write_file_timing,"     HS ACTIVE DATA (BC_ACTIVE) SUMMARY\n");
            $fwrite(write_file_timing,"========================================\n");
            // $fwrite(write_file_timing,"  Long Packets     = %0d\n", bc_active_count);
            $fwrite(write_file_timing,"  Avg Measured BC  = %.2f BC\n", bc_active_sum / bc_active_count);
            $fwrite(write_file_timing,"  Estimated BC     = %.1f BC (PH=%0d + Payload=%0d + CRC=%0d)\n", (PH_BC + BC_ACTIVE + CRC_BC) * 1.0, PH_BC, BC_ACTIVE, CRC_BC);
            $fwrite(write_file_timing,"  Estimated Time    = %.1f ns\n", (PH_BC + BC_ACTIVE + CRC_BC) * T_BC_NS);
            // $fwrite(write_file_timing,"  Min Measured BC  = %.2f BC\n", bc_active_min);
            // $fwrite(write_file_timing,"  Max Measured BC  = %.2f BC\n", bc_active_max);
            // $fwrite(write_file_timing,"  BC_active Check  = %0d pass, %0d fail\n", bc_active_pass, bc_active_fail);
            $fwrite(write_file_timing,"========================================\n");
            $fflush(write_file_timing);
            $display("========================================");
            $display("[BC_ACTIVE] Estimated=%.1f BC, Avg=%.2f BC, Min=%.2f, Max=%.2f (%0d long pkts)",
                     (PH_BC + BC_ACTIVE + CRC_BC) * 1.0, bc_active_sum / bc_active_count, bc_active_min, bc_active_max, bc_active_count);
            // $display("[BC_ACTIVE] %0d pass, %0d fail", bc_active_pass, bc_active_fail);
            $display("========================================");
        end

        // Frame rate and frame timing summary
        if (frame_rate_count > 0) begin
            $fwrite(write_file_timing,"\n");
            $fwrite(write_file_timing,"========================================\n");
            $fwrite(write_file_timing,"     FRAME RATE / FRAME TIMING SUMMARY\n");
            $fwrite(write_file_timing,"========================================\n");
            // $fwrite(write_file_timing,"  Frames Measured  = %0d\n", frame_rate_count);
            $fwrite(write_file_timing,"  Avg Frame Rate   = %.3f fps\n", frame_rate_sum / frame_rate_count);
            // $fwrite(write_file_timing,"  Min Frame Rate   = %.3f fps\n", frame_rate_min);
            // $fwrite(write_file_timing,"  Max Frame Rate   = %.3f fps\n", frame_rate_max);
            $fwrite(write_file_timing,"  Avg Frame Period = %.3f ms\n", (1.0e3 * frame_rate_count) / frame_rate_sum);
            $fflush(write_file_timing);
            if (ESTIMATED_FPS > 0.0) begin
                // $fwrite(write_file_timing,"  Estimated Frame Period(with overhead)  = %.3f ms (%.3f fps)\n", estimated_frame_period_ns / 1.0e6, ESTIMATED_FPS);
                $fwrite(write_file_timing,"  Ideal Frame Period(without overhead)  = %.3f ms (%.3f fps)\n", T_FRAME_IDEAL_NS / 1.0e6, FPS_IDEAL);
                // $fwrite(write_file_timing,"  Frame Time Check = %0d pass, %0d fail\n", frame_time_pass, frame_time_fail);
            end
            $fwrite(write_file_timing,"========================================\n");
            $fflush(write_file_timing);
            $display("========================================");
            $display("[FRAME RATE] Avg = %.3f fps, Min = %.3f fps, Max = %.3f fps", frame_rate_sum / frame_rate_count, frame_rate_min, frame_rate_max);
            if (ESTIMATED_FPS > 0.0)
                // $display("[FRAME TIME] %0d pass, %0d fail (estimated %.3f ms @ %.3f fps)", frame_time_pass, frame_time_fail, estimated_frame_period_ns / 1.0e6, ESTIMATED_FPS);
            $display("========================================");
        end
        else begin
            // $display("[FRAME RATE] No frame-to-frame intervals measured");
        end
        
        // Line timing summary
        if (line_period_count > 0) begin
            $fwrite(write_file_timing,"\n");
            $fwrite(write_file_timing,"========================================\n");
            $fwrite(write_file_timing,"     LINE TIMING SUMMARY\n");
            $fwrite(write_file_timing,"========================================\n");
            // $fwrite(write_file_timing,"  Lines Measured   = %0d\n", line_period_count);
            $fwrite(write_file_timing,"  Avg Line Period  = %.3f us\n", (line_period_sum / line_period_count) / 1.0e3);
            // $fwrite(write_file_timing,"  Min Line Period  = %.3f us\n", line_period_min / 1.0e3);
            // $fwrite(write_file_timing,"  Max Line Period  = %.3f us\n", line_period_max / 1.0e3);
            if (ESTIMATED_FPS > 0.0) begin
                // $fwrite(write_file_timing,"  Estimated Line Period(with overhead)  = %.3f us \n", estimated_line_period_ns / 1.0e3);
                $fwrite(write_file_timing,"  Ideal Line Period(without overhead)  = %.3f us \n", T_LINE_IDEAL_NS / 1.0e3);
                // $fwrite(write_file_timing,"  Line Time Check  = %0d pass, %0d fail\n", line_time_pass, line_time_fail);
            end
            $fwrite(write_file_timing,"========================================\n");
            $fflush(write_file_timing);
            $display("========================================");
            $display("[LINE TIME] Avg = %.3f us, Min = %.3f us, Max = %.3f us",
                     (line_period_sum / line_period_count) / 1.0e3, line_period_min / 1.0e3, line_period_max / 1.0e3);
            if (ESTIMATED_FPS > 0.0)
                // $display("[LINE TIME] %0d pass, %0d fail (estimated %.3f us)", line_time_pass, line_time_fail, estimated_line_period_ns / 1.0e3);
            $display("========================================");
        end
        $fclose(write_file_timing); 
    end
    
    // Enhanced debug display task with enable/disable control
    task debug_display(input string msg);
        begin
            if (DEBUG_ENABLE) begin
                $display("[%0t][RX MODEL DEBUG] %s", $realtime, msg);
            end
        end
    endtask

    // Enhanced debug display task with value - supports integer values
    task debug_display_val(input string msg, input int val);
        begin
            if (DEBUG_ENABLE) begin
                $display("[%0t][RX MODEL DEBUG] %s: %0d", $realtime, msg, val);  // Fixed format specifier
            end
        end
    endtask

    task wait4clk(input [15:0] cycle);
        begin
            repeat (cycle) begin
                @(c_p_i);
            end
        end
    endtask

    task wait4byteclk(input [15:0] cycle);
        begin
            repeat (cycle) begin
                wait4clk(8);
            end
        end
    endtask

    task wait4LPstart_Clock();
        reg LP11;
        reg LP01;
        reg LP00;
        reg HS0;
        begin
            LP11  = 0;
            LP01  = 0;
            LP00  = 0;
            HS0   = 0;

            while (!LP11) begin
                LP11 = c_p_i & c_n_i;
                #1;
            end
            while (!LP01) begin
                LP01 = !c_p_i & c_n_i;
                #1;
            end
            while (!LP00) begin
                LP00 = !c_p_i & !c_n_i;
                #1;
            end
            while (!HS0) begin
                HS0  = !c_p_i & c_n_i;
                #1;
            end
        end
    endtask

    task wait4LPstart();
        reg  start; // For debug
        reg  ZZZ;   // For debug
        time start_time;
        time time_start;
        time time_end;
        reg  LP11;
        reg  LP01;
        reg  LP00;
        reg  HS0;
        reg  tinit;
        reg  timout;
        reg  init;
        integer hs0_time;

        begin
            //INITIAL ASSIGN
            start       = 1;
            #1; // For test
            start_time  = $realtime;
            ZZZ         = 0;
            LP11        = 0;
            LP01        = 0;
            LP00        = 0;
            HS0         = 0;
            timout      = 0;
            hs0_time    = 0;
            init        = 0;
            //END
            ZZZ = 0;
            //END
            debug_display("Wait for new packet");  
            $fwrite(write_file_timing,"Wait for new packet\n");
            $fwrite(write_file_timing,"________________________________________\n");
            $fwrite(write_file_timing,"TIME %t\n",$realtime);
            //LP 11
            time_start  = $realtime;
            LP11        = 1;

            if (CLK_MODE == "NON_CONTINUOUS" && CIL_BYPASS == "CIL_BYPASSED") begin
                debug_display("NON_CONTINUOUS & CIL_BYPASSED - wait for clock start");  
                wait4LPstart_Clock();
                debug_display("wait4LPstart_Clock done");
            end

            debug_display_val("init", init);    
            while (!init) begin
                init = (d_p_i === {NUM_LANE{1'd1}} & d_n_i === {NUM_LANE{1'd1}});
                #1;
            end
            debug_display_val("init", init);

            while ((d_p_i === {NUM_LANE{1'd1}} & d_n_i === {NUM_LANE{1'd1}}) || (d_p_i === {NUM_LANE{1'dz}} & d_n_i === {NUM_LANE{1'dz}})) begin
                #1;
            end
            debug_display("LP11 0");
            LP11 = 0;
            debug_display_val("time_start", time_start);
            debug_display_val("time_end", time_end);
            time_end  = $realtime;
            lp11_measured = time_end - time_start;
            $fwrite(write_file_timing,"LP-11      = %t \n", lp11_measured);
            //END
            //LP 01
            time_start  = $realtime;
            LP01 = 1;
            while (d_p_i === {NUM_LANE{1'd0}} & d_n_i === {NUM_LANE{1'd1}}) begin
                #1;
            end
            LP01          = 0;
            time_end      = $realtime;
            global_T_LPX  = time_end-time_start;
            $fwrite(write_file_timing,"TLPX       = %t \n",global_T_LPX);
            //END
            //LP 00
            time_start  = $realtime;
            LP00 = 1;
            while (d_p_i === {NUM_LANE{1'd0}} & d_n_i === {NUM_LANE{1'd0}}) begin
                #1;
            end
            LP00              = 0;
            time_end          = $realtime;
            global_HS_prepare = time_end-time_start;
            $fwrite(write_file_timing,"HS-prepare = %t \n",global_HS_prepare);
            //END
            //HS 0
            time_start  = $realtime;
            HS0 = 1;
            while (d_p_i === {NUM_LANE{1'd0}} & d_n_i === {NUM_LANE{1'd1}} & !timout) begin
                #0.1;
                hs0_time = hs0_time + 0.1;
                timout=  (hs0_time > HS0_TIMEOUT);
            end
            HS0             = 0;
            time_end        = $realtime;
            global_HS_zero  = time_end-time_start;
            $fwrite(write_file_timing,"HS-0       = %t \n",global_HS_zero);
            //END
            start = 0;
            global_HS_sum = global_HS_zero + global_HS_prepare;
        end
    endtask

    task wait4LP11();
        reg                 start; // For debug
        reg                 LP11;
        reg                 print_1_time;
        reg [NUM_LANE-1:0]  toggled_bit_p;
        reg [NUM_LANE-1:0]  toggled_bit_n;
        time                trail_start;
        time                trail_end;

        begin
            start         = 1'd1;
            LP11          = 0;
            print_1_time  = 0;
            trail_start   = $realtime;
            while (!(d_p_i &  d_n_i)) begin
                #1;
            end
            trail_end                   = $realtime;
            global_HS_trail             = trail_end - trail_start;
            $fwrite(write_file_timing,"HS-Trail   = %t \n",global_HS_trail);
            start = 1'd0;
            check_tim_par();
            report_err();
        end
    endtask

    task check_tim_par();
        integer pass;
        integer fail;
        begin
            pass = 0;
            fail = 0;

            if (global_T_LPX >= global_T_LPX_expected) begin
                pass = pass + 1;
            end
            else begin
                fail = fail + 1;
                $fwrite(write_file_timing,"***ERROR*** TLPX is %t but must be minimum 50 \n",global_T_LPX);
                $fflush(write_file_timing);
                if (DEBUG_ENABLE) begin
                    $display("Errors TLPX fail  %d, %d", global_T_LPX, global_T_LPX_expected);
                    $stop;
                end
            end

            if (global_HS_prepare >= global_HS_prepare_min_expected) begin
                if (global_HS_prepare <= global_HS_prepare_max_expected) begin
                    pass = pass + 1;
                end
                else begin
                    $fwrite(write_file_timing,"***ERROR*** HS_prepare is %t but must be maximum %t \n",global_HS_prepare,global_HS_prepare_max_expected);
                    $fflush(write_file_timing);
                    fail = fail + 1;
                    if (DEBUG_ENABLE) begin
                        $display("Errors HS_prepare + HS_zero fail %d, %d", global_HS_prepare, global_HS_prepare_max_expected);
                        $stop;
                    end
                end
            end
            else begin
                $fwrite(write_file_timing,"***ERROR*** HS_prepare is %t but must be minimum %t \n",global_HS_prepare,global_HS_prepare_min_expected);
                $fflush(write_file_timing);
                // fail   = fail + 1;
                if (DEBUG_ENABLE) begin
                    // $display("Errors HS_prepare fail %d, %d", global_HS_prepare, global_HS_prepare_min_expected);
                    // $stop;
                end
            end

            if (global_HS_sum >= global_HS_sum_expected) begin
                pass   = pass + 1;
            end
            else begin
                $fwrite(write_file_timing,"***ERROR*** HS_prepare + HS_zero is %t but must be minimum %t \n",global_HS_sum,global_HS_sum_expected);
                $fflush(write_file_timing);
                fail = fail + 1;
                if (DEBUG_ENABLE) begin
                    $display("Errors HS_prepare + HS_zero fail %d, %d", global_HS_sum, global_HS_sum_expected);
                    $stop;
                end
            end

            if (global_HS_trail > global_HS_trail_expected) begin
                pass   = pass + 1;
            end
            else begin
                $fwrite(write_file_timing,"***ERROR*** HS_trail is %t but must be minimum %t \n",global_HS_trail,global_HS_trail_expected);
                $fflush(write_file_timing);
                fail = fail + 1;
                if (DEBUG_ENABLE) begin
                    $display("Errors HS_trail fail %d, %d", global_HS_trail, global_HS_trail_expected);
                    $stop;
                end
            end

            timing_param_fail = timing_param_fail + fail;
            global_passed_cases = global_passed_cases + pass;
            global_failed_cases = global_failed_cases + fail;
            $fwrite(write_file_timing,"TIME %t\n",$realtime);
            $fwrite(write_file_timing,"________________________________________\n");
            $fwrite(write_file_timing,"Packet received \n");
            $fflush(write_file_timing);
            
            if (header_decoded) begin
                if (short_packet)
                    $fwrite(write_file_timing,"Pkt Type   = SHORT PACKET\n");
                else
                $fwrite(write_file_timing,"Pkt Type   = LONG PACKET\n");
                $fwrite(write_file_timing,"Pkt #      = %0d\n", packet_count_r);
                $fwrite(write_file_timing,"Data Type  = 0x%02h (%0s)\n", data_type_r, get_data_type_name(data_type_r));
                $fwrite(write_file_timing,"Virt Chan  = %0d\n", virtual_channel_r);
                if (short_packet)
                    $fwrite(write_file_timing,"Data Field = 0x%04h\n", word_count_r);
                else
                    $fwrite(write_file_timing,"Word Count = %0d bytes\n", word_count_r);
                $fwrite(write_file_timing,"ECC        = 0x%02h", ecc_r);
                if (ecc_r == ecc_calc)
                    $fwrite(write_file_timing," (PASS)\n");
                else
                    $fwrite(write_file_timing," (FAIL)\n");
                $fflush(write_file_timing);
                packet_count_r = packet_count_r + 1;
                
                // Frame period / frame rate display and check for Frame Start packets
                if (prev_frame_start_valid && frame_rate_count > 0) begin
                    if ((INTF_TYPE == "CSI2" && data_type_r == 6'h00) ||
                        (INTF_TYPE == "DSI"  && data_type_r == 6'h01)) begin
                        $fwrite(write_file_timing,"Ideal Frame Period(no overhead)  = %.1f ns (%.3f fps)\n", T_FRAME_IDEAL_NS, FPS_IDEAL);
                        $fwrite(write_file_timing,"Measured Frame Per. = %.1f ns (%.6f ms)\n", frame_period_ns, frame_period_ns / 1.0e6);
                        $fwrite(write_file_timing,"Measured Frame Rate = %.3f fps\n", frame_rate_fps);
                        if (ESTIMATED_FPS > 0.0) begin
                            $fwrite(write_file_timing,"Frame Period Measured     = %.1f ns\n", frame_period_ns);
                            // $fwrite(write_file_timing,"Frame Period Estimated(with overhead)     = %.1f ns\n", estimated_frame_period_ns);
                            // $fwrite(write_file_timing,"Estimated   = %.1f ns (%.6f ms) @ %.3f fps\n", estimated_frame_period_ns, estimated_frame_period_ns / 1.0e6, ESTIMATED_FPS);
                            if (frame_period_ns >= estimated_frame_period_ns * (1.0 - blanking_tolerance) &&
                                frame_period_ns <= estimated_frame_period_ns * (1.0 + blanking_tolerance)) begin
                                // $fwrite(write_file_timing,"Frame Time = PASS (within +/-%.0f%%)\n", blanking_tolerance * 100.0);
                                // frame_time_pass = frame_time_pass + 1;
                            end
                            else begin
                                // $fwrite(write_file_timing,"Frame Time = FAIL (deviation: %.2f%%)\n", 100.0 * (frame_period_ns - estimated_frame_period_ns) / estimated_frame_period_ns);
                                // frame_time_fail = frame_time_fail + 1;
                            end
                        end
                    end
                end
                // Line period display and check for Line Start / ImageData packets
                if (prev_line_start_valid && line_period_count > 0) begin
                    if ((INTF_TYPE == "CSI2" && (( LS_LE_EN && data_type_r == 6'h02) ||
                                                (!LS_LE_EN && is_image_data_type(data_type_r)))) ||
                        (INTF_TYPE == "DSI"  && (( LS_LE_EN && data_type_r == 6'h21) ||
                                                (!LS_LE_EN && is_image_data_type(data_type_r))))) begin
                        $fwrite(write_file_timing,"Ideal Line Period(no overhead)  = %.1f ns\n", T_LINE_IDEAL_NS);
                        $fwrite(write_file_timing,"Measured Line Per.  = %.1f ns (%.6f us)\n", line_period_ns, line_period_ns / 1.0e3);
                        if (ESTIMATED_FPS > 0.0) begin
                            // $fwrite(write_file_timing,"Estimated   = %.1f ns (%.6f us) @ %0d lines/frame\n",estimated_line_period_ns, estimated_line_period_ns / 1.0e3, V_TOTAL);
                            $fwrite(write_file_timing,"Line Period Measured     = %.1f ns\n", line_period_ns);
                            // $fwrite(write_file_timing,"Line Period Estimated(with overhead)     = %.1f ns\n", estimated_line_period_ns);
                            if (line_period_ns >= estimated_line_period_ns * (1.0 - blanking_tolerance) &&
                                line_period_ns <= estimated_line_period_ns * (1.0 + blanking_tolerance)) begin
                                // $fwrite(write_file_timing,"Line Time  = PASS (within +/-%.0f%%)\n", blanking_tolerance * 100.0);
                                // line_time_pass = line_time_pass + 1;
                            end
                            else begin
                                // $fwrite(write_file_timing,"Line Time  = FAIL (deviation: %.2f%%)\n", 100.0 * (line_period_ns - estimated_line_period_ns) / estimated_line_period_ns);
                                // line_time_fail = line_time_fail + 1;
                            end
                        end
                    end
                end
                // Blanking period analysis
                if (BLANKING_EN == "ON") begin
                    $fwrite(write_file_timing,"--- Blanking Analysis ---\n");
                    $fwrite(write_file_timing,"LP-11 Measured     = %.1f ns\n", lp11_measured);
                    $fwrite(write_file_timing,"Prev Data Type     = 0x%02h (%0s)\n", prev_data_type_r, get_data_type_name(prev_data_type_r));
                    $fwrite(write_file_timing,"Curr Data Type     = 0x%02h (%0s)\n", data_type_r, get_data_type_name(data_type_r));
                    // Horizontal blanking detection based on LS_LE_EN
                    //   LS_LE_EN=1: LE(0x03) -> LS(0x02) transition
                    //   LS_LE_EN=0: ImageData -> ImageData transition
                    if (( LS_LE_EN && prev_data_type_r == 6'h03 && data_type_r == 6'h02) ||
                        (!LS_LE_EN && is_image_data_type(prev_data_type_r) && is_image_data_type(data_type_r))) begin
                        h_blank_count = h_blank_count + 1;
                        if (LS_LE_EN)
                            $fwrite(write_file_timing,"Blank Type         = HORIZONTAL BLANKING (#%0d) [LE -> LS]\n", h_blank_count);
                        else
                            $fwrite(write_file_timing,"Blank Type         = HORIZONTAL BLANKING (#%0d) [ImageData -> ImageData]\n", h_blank_count);
                        $fwrite(write_file_timing,"Estimated H_BLANK   = %.1f ns\n", h_blank_time_ns);
                        if (h_blank_count <= BLANKING_SKIP_H) begin
                            // $fwrite(write_file_timing,"H_BLANK Check      = SKIP (#%0d <= %0d bypass)\n", h_blank_count, BLANKING_SKIP_H);
                        end
                        else if (h_blank_time_ns != 0) begin
                            h_blank_time_ns_measured = lp11_measured;
                            tolerance_minus_h_blank_time_ns = h_blank_time_ns * (1.0 - blanking_tolerance);
                            tolerance_plus_h_blank_time_ns = h_blank_time_ns * (1.0 + blanking_tolerance);
                            if (lp11_measured >= tolerance_minus_h_blank_time_ns &&
                                lp11_measured <= tolerance_plus_h_blank_time_ns) begin
                                // $fwrite(write_file_timing,"H_BLANK Check      = PASS (within +/-%.0f%%)\n", blanking_tolerance * 100.0);
                                // h_blank_pass = h_blank_pass + 1;
                                if (lp11_measured > h_blank_time_ns) begin
                                    $fwrite(write_file_timing,"Actual measurement is larger than Estimated H_BLANK\n");
                                    $fwrite(write_file_timing,"Actual difference   = ( +/-%.0f%%)\n", (((lp11_measured-h_blank_time_ns)/h_blank_time_ns)*100.0)-100.0);
                                end else begin
                                        $fwrite(write_file_timing,"Actual measurement is lesser than Estimated H_BLANK\n");
                                        $fwrite(write_file_timing,"Actual difference   = ( +/-%.0f%%)\n", (((h_blank_time_ns-lp11_measured)/h_blank_time_ns)*100.0)-100.0);
                                    end
                            end
                            else begin
                                // $fwrite(write_file_timing,"H_BLANK Check      = Error: (measured vs estimated differ)\n");
                                if (lp11_measured > h_blank_time_ns) begin
                                    $fwrite(write_file_timing,"Actual measurement is larger than Estimated H_BLANK\n");
                                    $fwrite(write_file_timing,"Actual difference   = ( +/-%.0f%%)\n", (((lp11_measured-h_blank_time_ns)/h_blank_time_ns)*100.0)-100.0);
                                end else begin
                                        $fwrite(write_file_timing,"Actual measurement is lesser than Estimated H_BLANK\n");
                                        $fwrite(write_file_timing,"Actual difference   = ( +/-%.0f%%)\n", (((h_blank_time_ns-lp11_measured)/h_blank_time_ns)*100.0)-100.0);
                                    end
                                // h_blank_fail = h_blank_fail + 1;
                            end
                        end
                        // $fwrite(write_file_timing,"Tolerance minus H_BLANK   = %.1f ns\n", tolerance_minus_h_blank_time_ns);
                        // $fwrite(write_file_timing,"Tolerance plus H_BLANK   = %.1f ns\n", tolerance_plus_h_blank_time_ns);
                    end
                    else if ((prev_data_type_r == 6'h01 || data_type_r == 6'h00) && frame_end_seen) begin
                        v_blank_count = v_blank_count + 1;
                        $fwrite(write_file_timing,"Blank Type         = VERTICAL BLANKING (#%0d)\n", v_blank_count);
                        $fwrite(write_file_timing,"Estimated V_BLANK   = %.1f ns\n", v_blank_time_ns);
                        if (v_blank_count <= BLANKING_SKIP_V) begin
                            // $fwrite(write_file_timing,"V_BLANK Check      = SKIP (#%0d <= %0d bypass)\n", v_blank_count, BLANKING_SKIP_V);
                        end
                        else if (v_blank_time_ns != 0) begin
                            v_blank_time_ns_measured = lp11_measured;
                            tolerance_minus_v_blank_time_ns = v_blank_time_ns * (1.0 - blanking_tolerance);
                            tolerance_plus_v_blank_time_ns = v_blank_time_ns * (1.0 + blanking_tolerance);
                            if (lp11_measured >= tolerance_minus_v_blank_time_ns &&
                                lp11_measured <= tolerance_plus_v_blank_time_ns) begin
                                // $fwrite(write_file_timing,"V_BLANK Check      = PASS (within +/-%.0f%%)\n", blanking_tolerance * 100.0);
                                if (lp11_measured > v_blank_time_ns) begin
                                    $fwrite(write_file_timing,"Actual measurement is larger than Estimated V_BLANK\n");
                                    $fwrite(write_file_timing,"Actual difference   = ( +/-%.0f%%)\n", (((lp11_measured-v_blank_time_ns)/v_blank_time_ns)*100.0)-100.0);
                                end else begin
                                        $fwrite(write_file_timing,"Actual measurement is lesser than Estimated V_BLANK\n");
                                        $fwrite(write_file_timing,"Actual difference   = ( +/-%.0f%%)\n", (((v_blank_time_ns-lp11_measured)/v_blank_time_ns)*100.0)-100.0);
                                    end
                                // v_blank_pass = v_blank_pass + 1;
                            end
                            else begin
                                // $fwrite(write_file_timing,"V_BLANK Check      = Error: (measured vs estimated differ)\n");
                                if (lp11_measured > v_blank_time_ns) begin
                                    $fwrite(write_file_timing,"Actual measurement is larger than Estimated V_BLANK\n");
                                    $fwrite(write_file_timing,"Actual difference   = ( +/-%.0f%%)\n", (((lp11_measured-v_blank_time_ns)/v_blank_time_ns)*100.0)-100.0);
                                end else begin
                                    $fwrite(write_file_timing,"Actual measurement is lesser than Estimated V_BLANK\n");
                                        $fwrite(write_file_timing,"Actual difference   = ( +/-%.0f%%)\n", (((v_blank_time_ns-lp11_measured)/v_blank_time_ns)*100.0)-100.0);
                                    end
                                // v_blank_fail = v_blank_fail + 1;
                            end
                        end
                        // $fwrite(write_file_timing,"Tolerance minus V_BLANK   = %.1f ns\n", tolerance_minus_v_blank_time_ns);
                        // $fwrite(write_file_timing,"Tolerance plus V_BLANK   = %.1f ns\n", tolerance_plus_v_blank_time_ns);

                    end
                    else begin
                        blanking_other_count = blanking_other_count + 1;
                        $fwrite(write_file_timing,"Blank Type         = PROTOCOL OVERHEAD (#%0d)\n", blanking_other_count);
                    end
                    $fwrite(write_file_timing,"-------------------------\n");
                end
                // HS active data burst (BC_active) measurement
                if (hs_data_duration_ns > 0.0) begin
                    $fwrite(write_file_timing,"--- HS Active Data Measurement ---\n");
                    $fwrite(write_file_timing,"BC_active Estimated = %.1f BC", bc_active_estimated);
                    $fwrite(write_file_timing,"HS Data Duration   = %.1f ns\n", hs_data_duration_ns);
                    $fwrite(write_file_timing,"BC_active Measured = %.2f BC\n", bc_active_measured);
                    if (short_packet)
                        $fwrite(write_file_timing," (SP=%0d)\n", SP_BC);
                    else
                        $fwrite(write_file_timing," (PH=%0d + Payload=%0d + CRC=%0d)\n",
                                PH_BC, (word_count_r + NUM_LANE - 1) / NUM_LANE, CRC_BC);
                    if (bc_active_estimated > 0.0) begin
                        if (bc_active_measured >= bc_active_estimated * (1.0 - BLANKING_TOLERANCE) &&
                            bc_active_measured <= bc_active_estimated * (1.0 + BLANKING_TOLERANCE)) begin
                            // $fwrite(write_file_timing,"BC_active Check    = PASS (within +/-%.0f%%)\n", BLANKING_TOLERANCE * 100.0);
                            // bc_active_pass = bc_active_pass + 1;
                        end
                        else begin
                            // $fwrite(write_file_timing,"BC_active Check    = FAIL (deviation: %.2f%%)\n", 100.0 * (bc_active_measured - bc_active_estimated) / bc_active_estimated);
                            // bc_active_fail = bc_active_fail + 1;
                        end
                    end
                    if (!short_packet) begin
                        bc_active_count = bc_active_count + 1;
                        bc_active_sum   = bc_active_sum + bc_active_measured;
                        if (bc_active_measured < bc_active_min) bc_active_min = bc_active_measured;
                        if (bc_active_measured > bc_active_max) bc_active_max = bc_active_measured;
                    end
                    $fwrite(write_file_timing,"----------------------------------\n");
            $fflush(write_file_timing);
                end
                prev_data_type_r  = data_type_r;
                prev_short_packet = short_packet;
                if ((INTF_TYPE == "CSI2" && data_type_r == 6'h01) ||
                    (INTF_TYPE == "DSI"  && data_type_r == 6'h11))
                    frame_end_seen = 1'b1;
            end
            else begin
                $fwrite(write_file_timing,"Pkt Type   = UNKNOWN (sync error)\n");
                $fflush(write_file_timing);
            end
        end
    endtask

    task wait4B8();
        reg       in_process;

        reg       UI;
        real      UI_start;
        real      UI_end;
        real      ui_ps;

        reg [7:0] B8_r;
        reg       data_1_bit;
        reg       sync_error;

        begin
            in_process   = 1;
            sync_error   = 0;
            B8_r         = 8'h00;
            fork
                begin // B8 detecting
                    debug_display("B8 detection start");
                    while (B8_r != 8'hB8 & !sync_error) begin
                        wait4clk(1);

                        data_1_bit = d_p_i;
                        B8_r       = {data_1_bit,B8_r[7:1]};
                        if (!(B8_r == 8'h00 | B8_r == 8'h80 | B8_r == 8'hC0 | B8_r == 8'hE0 | B8_r == 8'h70 | B8_r == 8'hB8)) begin
                            sync_error = 1;
                            debug_display_val("B8_r", B8_r);
                            debug_display("Sync error detected");
                            global_SOT_failed_cases = global_SOT_failed_cases + 1;
                        end
                    end
                    if (!sync_error) begin
                        global_SOT_passed_cases = global_SOT_passed_cases + 1;
                    end
                    wait4clk(1);
                    debug_display("B8 detection done");
                end

                begin // Calculating UI
                    debug_display("UI calculation start");
                    wait4clk(2);
                    debug_display_val("UI_start", UI_start);
                    UI_start  = $realtime;
                    wait4clk(1);
                    UI_end    = $realtime;
                    debug_display_val("UI_end", UI_end);
                    global_UI = UI_end-UI_start;
                    $fwrite(write_file_timing,"UI         = %t \n",global_UI);
                    debug_display_val(" global_UI", global_UI);
                    ui_ps = global_UI * 1000.0; // Convert ns to ps
                    debug_display_val(" global_UI in ps", ui_ps);
                    global_T_LPX_expected           = 50;
                    global_HS_prepare_min_expected  = (40 + 4*global_UI);
                    global_HS_prepare_max_expected  = (85 + 6*global_UI);
                    global_HS_sum_expected          = (145 + 10*global_UI);
                    global_HS_trail_expected        = (60 + 4*global_UI);
                end
            join
            B8_r         = 8'd0;
            in_process   = 0;
        end
    endtask

    task readheader();
        reg in_process;
        begin
            in_process = 1;
            if (NUM_LANE == 3) begin
                for (i = 0; i <= 15; i = i + 1) begin
                    if (i <= 7) begin
                        header_r[ 0 + i] = d_p_i[0];
                        header_r[ 8 + i] = d_p_i[1];
                        header_r[16 + i] = d_p_i[2];
                    end
                    else begin
                        header_r[16 + i] = d_p_i[0];
                        cil_bytes_header_0[0 + i] = d_p_i[1];
                        cil_bytes_header_1[0 + i] = d_p_i[2];
                    end
                    wait4clk(1);
                end
            end
            else begin
                for (i = 0; i <= (32/NUM_LANE)-1; i = i + 1) begin
                    if (NUM_LANE == 4) begin
                        header_r[ 0 + i]   = d_p_i[0];
                        header_r[ 8 + i]   = d_p_i[1];
                        header_r[16 + i]   = d_p_i[2];
                        header_r[24 + i]   = d_p_i[3];
                        wait4clk(1);
                    end else
                    if (NUM_LANE == 2) begin
                        if (i <= 7) begin
                            header_r[ 0 + i] = d_p_i[0];
                            header_r[ 8 + i] = d_p_i[1];
                        end
                        else begin
                            header_r[ 8 + i] = d_p_i[0];
                            header_r[16 + i] = d_p_i[1];
                        end
                        wait4clk(1);
                    end else
                        if (NUM_LANE == 1) begin
                            header_r[ 0 + i]   = d_p_i[0];
                            wait4clk(1);
                        end
                    end
                end
            if (HEADER_CHECK == "ON") begin
                $display("%t VC  = %h\nDT  = %h\nWC  = %h\nECC = %h\n",$time,header_r[7:6],header_r[5:0],header_r[23:8],header_r[31:24]);
            end
            data_type_r            = header_r[ 5: 0];
            virtual_channel_r      = header_r[ 7: 6];
            word_count_r           = header_r[23: 8];
            ecc_r                  = header_r[31:24];

            compute_ecc(header_r[23:0],ecc_calc);
            if (ecc_r == ecc_calc) begin
                global_ECC_passed_cases = global_ECC_passed_cases + 1;
            end
            else begin
                global_ECC_failed_cases = global_ECC_failed_cases + 1;
            end

            short_packet = ( data_type_r == 6'h00 |
                             data_type_r == 6'h01 |
                             data_type_r == 6'h02 |
                             data_type_r == 6'h03 |
                             data_type_r == 6'h11 |
                             data_type_r == 6'h21 |
                             data_type_r == 6'h31 );
            // Received frame/line number and frame rate measurement
            if (INTF_TYPE == "CSI2") begin
                if (data_type_r == 6'h00) begin
                    frame_count_r = word_count_r;
                    
                    if (ESTIMATED_FPS > 0.0) begin
                        // Frame rate: measure FS-to-FS interval
                        frame_start_time_ns = $realtime;
                        if (prev_frame_start_valid) begin
                            frame_period_ns = frame_start_time_ns - prev_frame_start_time_ns;
                            if (frame_period_ns > 0.0) begin
                                frame_rate_fps   = 1.0e9 / frame_period_ns;
                                frame_rate_count = frame_rate_count + 1;
                                frame_rate_sum   = frame_rate_sum + frame_rate_fps;
                                if (frame_rate_fps < frame_rate_min) frame_rate_min = frame_rate_fps;
                                if (frame_rate_fps > frame_rate_max) frame_rate_max = frame_rate_fps;
                            end
                        end
                        prev_frame_start_time_ns = frame_start_time_ns;
                        prev_frame_start_valid   = 1'b1;
                    end 
                end
                else if (data_type_r == 6'h01) begin
                    frame_count_r = word_count_r;
                end
                else if (data_type_r == 6'h02) begin
                    line_count_r = word_count_r;
                    if (ESTIMATED_FPS > 0.0) begin
                        // Line time: measure LS-to-LS interval
                        line_start_time_ns = $realtime;
                        if (prev_line_start_valid) begin
                            line_period_ns = line_start_time_ns - prev_line_start_time_ns;
                            if (line_period_ns > 0.0) begin
                                line_period_count = line_period_count + 1;
                                line_period_sum   = line_period_sum + line_period_ns;
                                if (line_period_ns < line_period_min) line_period_min = line_period_ns;
                                if (line_period_ns > line_period_max) line_period_max = line_period_ns;
                            end
                        end
                        prev_line_start_time_ns = line_start_time_ns;
                        prev_line_start_valid   = 1'b1;
                    end
                end
                else if (data_type_r == 6'h03) begin
                    line_count_r = word_count_r;
                end
                // Line time for LS_LE_EN=0: measure ImageData-to-ImageData interval
                if (!LS_LE_EN && is_image_data_type(data_type_r)) begin
                
                    if (ESTIMATED_FPS > 0.0) begin
                        line_start_time_ns = $realtime;
                        if (prev_line_start_valid) begin
                            line_period_ns = line_start_time_ns - prev_line_start_time_ns;
                            if (line_period_ns > 0.0) begin
                                line_period_count = line_period_count + 1;
                                line_period_sum   = line_period_sum + line_period_ns;
                                if (line_period_ns < line_period_min) line_period_min = line_period_ns;
                                if (line_period_ns > line_period_max) line_period_max = line_period_ns;
                            end
                        end
                        prev_line_start_time_ns = line_start_time_ns;
                        prev_line_start_valid   = 1'b1;
                    end
                end
            end
            else if (INTF_TYPE == "DSI") begin
                if (data_type_r == 6'h01) begin
                    frame_count_r = word_count_r;
                    if (ESTIMATED_FPS > 0.0) begin
                        // Frame rate: measure V-Sync-Start-to-V-Sync-Start interval
                        frame_start_time_ns = $realtime;
                        if (prev_frame_start_valid) begin
                            frame_period_ns = frame_start_time_ns - prev_frame_start_time_ns;
                            if (frame_period_ns > 0.0) begin
                                frame_rate_fps   = 1.0e9 / frame_period_ns;
                                frame_rate_count = frame_rate_count + 1;
                                frame_rate_sum   = frame_rate_sum + frame_rate_fps;
                                if (frame_rate_fps < frame_rate_min) frame_rate_min = frame_rate_fps;
                                if (frame_rate_fps > frame_rate_max) frame_rate_max = frame_rate_fps;
                            end
                        end
                        prev_frame_start_time_ns = frame_start_time_ns;
                        prev_frame_start_valid   = 1'b1;
                    end
                end
                else if (data_type_r == 6'h11) begin
                    frame_count_r = word_count_r;
                end
                else if (data_type_r == 6'h21) begin
                    line_count_r = word_count_r;
                    
                    if (ESTIMATED_FPS > 0.0) begin
                        // Line time: measure HS-to-HS interval
                        line_start_time_ns = $realtime;
                        if (prev_line_start_valid) begin
                            line_period_ns = line_start_time_ns - prev_line_start_time_ns;
                            if (line_period_ns > 0.0) begin
                                line_period_count = line_period_count + 1;
                                line_period_sum   = line_period_sum + line_period_ns;
                                if (line_period_ns < line_period_min) line_period_min = line_period_ns;
                                if (line_period_ns > line_period_max) line_period_max = line_period_ns;
                            end
                        end
                        prev_line_start_time_ns = line_start_time_ns;
                        prev_line_start_valid   = 1'b1;
                    end
                end
                else if (data_type_r == 6'h31) begin
                    line_count_r = word_count_r;
                end
                // Line time for LS_LE_EN=0: measure ImageData-to-ImageData interval
                if (!LS_LE_EN && is_image_data_type(data_type_r)) begin
                
                    if (ESTIMATED_FPS > 0.0) begin
                        line_start_time_ns = $realtime;
                        if (prev_line_start_valid) begin
                            line_period_ns = line_start_time_ns - prev_line_start_time_ns;
                            if (line_period_ns > 0.0) begin
                                line_period_count = line_period_count + 1;
                                line_period_sum   = line_period_sum + line_period_ns;
                                if (line_period_ns < line_period_min) line_period_min = line_period_ns;
                                if (line_period_ns > line_period_max) line_period_max = line_period_ns;
                            end
                        end
                        prev_line_start_time_ns = line_start_time_ns;
                        prev_line_start_valid   = 1'b1;
                    end
                end
            end

            // Expected frame/line number
            if (data_type_r == 6'h00) begin 
                exp_frame_count_r = (exp_frame_count_r == NUM_FRAMES)? 16'h01 : exp_frame_count_r + 1;
            end
            else begin
                if (data_type_r == 6'h02) begin
                    exp_line_count_r = (exp_line_count_r ==   (NUM_FRAMES)*(V_ACTIVE+V_BLANK_LN))? 16'h01 : exp_line_count_r  + 1;
                end
            end

            if (FRAME_CNT_EN == "ON") begin
                if (exp_frame_count_r == frame_count_r) begin
                    // $display("%t Frame number PASS", $time);
                    global_FRAME_NUMBER_passed_cases = global_FRAME_NUMBER_passed_cases + 1;
                end
                else begin
                    // $display("%t Frame number FAIL", $time);
                    global_FRAME_NUMBER_failed_cases = global_FRAME_NUMBER_failed_cases + 1;
                end
            end
            in_process = 0;
        end
    endtask

    task readbyte();
        reg                  in_process;
        reg           [15:0] byte_count;
        reg [8*NUM_LANE-1:0] data;
        reg           [ 7:0] byte1, byte1r;
        reg           [ 7:0] byte2, byte2r;
        reg           [ 7:0] byte3, byte3r;
        reg           [ 7:0] byte4, byte4r;
        reg           [ 3:0] crc_en;

        begin
            in_process = 1;
            byte_count = 16'd0;
            data       = {8*NUM_LANE{1'd0}};
            byte1      = 0; byte1r     = 0;
            byte2      = 0; byte2r     = 0;
            byte3      = 0; byte3r     = 0;
            byte4      = 0; byte4r     = 0;
            crc_en     = 0;
            byte_count = 16'd0;
            if (NUM_LANE == 4) begin
                while ((byte_count != word_count_r) && ((word_count_r - byte_count) >= 4)) begin
                    for (i = 0; i <= 7; i = i + 1) begin
                        data[ 0 + i] = d_p_i[0];
                        data[ 8 + i] = d_p_i[1];
                        data[16 + i] = d_p_i[2];
                        data[24 + i] = d_p_i[3];
                        wait4clk(1);
                        crc_en = (i == 7)? 4'b1111 : crc_en;
                        crc_en = (i == 1)? 4'b0000 : crc_en;
                    end
                    $fwrite(tx_output_data_file,"%02h\n%02h\n%02h\n%02h\n",data[7:0],data[15:8],data[23:16],data[31:24]);
                    $fflush(tx_output_data_file);
                    $display("%t Data[0] : Receiving data = %02h\n", $time, data[ 7: 0]);
                    $display("%t Data[1] : Receiving data = %02h\n", $time, data[15: 8]);
                    $display("%t Data[2] : Receiving data = %02h\n", $time, data[23:16]);
                    $display("%t Data[3] : Receiving data = %02h\n", $time, data[31:24]);
                    data_write_count = data_write_count + 4;

                    byte_count     = byte_count + 4;
                    byte1r         = byte1;
                    byte2r         = byte2;
                    byte3r         = byte3;
                    byte4r         = byte4;
                    byte1          = data[ 7: 0];
                    byte2          = data[15: 8];
                    byte3          = data[23:16];
                    byte4          = data[31:24];
                end
                if (((word_count_r - byte_count) < 4)) begin
                    if ((word_count_r - byte_count) == 0) begin
                        if (EOTP_CHECK == "ON" | CRC_CHECK == "ON") begin
                            eotpcheck_after_lp(8'd0,8'd0,8'd0,3'b000);
                        end
                    end
                    else begin
                        for (i = 0; i <= 7; i = i + 1) begin
                            data[ 0 + i] = d_p_i[0];
                            data[ 8 + i] = d_p_i[1];
                            data[16 + i] = d_p_i[2];
                            data[24 + i] = d_p_i[3];
                            wait4clk(1);
                            crc_en = (i == 7)? (((word_count_r - byte_count) == 1)? 4'b0001 : ((word_count_r - byte_count) == 2)? 4'b0011 : 4'b0111) : crc_en;
                            crc_en = (i == 1)? 4'b0000 : crc_en;
                        end
                        byte1          = data[ 7: 0];
                        byte2          = data[15: 8];
                        byte3          = data[23:16];
                        byte4          = data[31:24];
                        case (word_count_r - byte_count)
                            16'd1: begin
                                $fwrite(tx_output_data_file,"%02h\n",data[7:0]);
                                $display("%t Data[0] : Receiving data = %02h\n", $time, data[ 7: 0]);
                                $fflush(tx_output_data_file);
                                data_write_count = data_write_count + 1;
                                if (EOTP_CHECK == "ON" | CRC_CHECK == "ON") begin
                                    eotpcheck_after_lp(data[15:8],data[23:16],data[31:24],3'b111);
                                end
                            end
                            16'd2: begin
                                $fwrite(tx_output_data_file,"%02h\n%02h\n",data[7:0],data[15:8]);
                                $fflush(tx_output_data_file);
                                $display("%t Data[0] : Receiving data = %02h\n", $time, data[ 7: 0]);
                                $display("%t Data[1] : Receiving data = %02h\n", $time, data[15: 8]);
                                data_write_count = data_write_count + 2;
                                if (EOTP_CHECK == "ON" | CRC_CHECK == "ON") begin
                                    eotpcheck_after_lp(data[23:16],data[31:24],8'd0,3'b110);
                                end
                            end
                            16'd3: begin
                                $fwrite(tx_output_data_file,"%02h\n%02h\n%02h\n",data[7:0],data[15:8],data[23:16]);
                                $fflush(tx_output_data_file);
                                $display("%t Data[0] : Receiving data = %02h\n", $time, data[ 7: 0]);
                                $display("%t Data[1] : Receiving data = %02h\n", $time, data[15: 8]);
                                $display("%t Data[2] : Receiving data = %02h\n", $time, data[23:16]);
                                data_write_count = data_write_count + 3;
                                if (EOTP_CHECK == "ON" | CRC_CHECK == "ON") begin
                                    eotpcheck_after_lp(data[31:24],8'd0,8'd0,3'b100);
                                end
                            end
                        endcase
                        byte_count     = byte_count + word_count_r - byte_count;
                        byte1          = data[ 7: 0];
                        byte2          = data[15: 8];
                        byte3          = data[23:16];
                        byte4          = data[31:24];
                    end
                end
            end
            else if (NUM_LANE == 3) begin
                if (CIL_BYPASS  != "CIL_BYPASSED") begin
                    $fwrite(tx_output_data_file,"%02h\n%02h\n",cil_bytes_header_0[15:8],cil_bytes_header_1[15:8]);
                    $fflush(tx_output_data_file);
                    byte_count = 16'd2;
                end
                else if (GEAR == 16 && CIL_BYPASS  == "CIL_BYPASSED") begin
                    wait4byteclk(1);
                end
                while ((byte_count != word_count_r) && ((word_count_r - byte_count) >= 3)) begin
                    for (i = 0; i <= 7; i = i + 1) begin
                        data[ 0 + i] = d_p_i[0];
                        data[ 8 + i] = d_p_i[1];
                        data[16 + i] = d_p_i[2];
                        wait4clk(1);
                        crc_en = (i == 7)? 4'b0111 : crc_en;
                        crc_en = (i == 1)? 4'b0000 : crc_en;
                    end
                    $fwrite(tx_output_data_file,"%02h\n%02h\n%02h\n",data[7:0],data[15:8],data[23:16]);
                    $fflush(tx_output_data_file);
                    $display("%t Data[0] : Receiving data = %02h\n", $time, data[ 7: 0]);
                    $display("%t Data[1] : Receiving data = %02h\n", $time, data[15: 8]);
                    $display("%t Data[2] : Receiving data = %02h\n", $time, data[23:16]);
                    data_write_count = data_write_count + 3;
                    byte_count     = byte_count + 3;
                    byte1          = data[ 7: 0];
                    byte2          = data[15: 8];
                    byte3          = data[23:16];
                end
                if (((word_count_r - byte_count) < 3)) begin
                    if ((word_count_r - byte_count) == 0) begin
                        if (EOTP_CHECK == "ON" | CRC_CHECK == "ON") begin
                            eotpcheck_after_lp(8'd0,8'd0,8'd0,3'b000);
                        end
                    end
                    else begin
                        for (i = 0; i <= 7; i = i + 1) begin
                            data[ 0 + i] = d_p_i[0];
                            data[ 8 + i] = d_p_i[1];
                            data[16 + i] = d_p_i[2];
                            wait4clk(1);
                            crc_en = (i == 7)? (((word_count_r - byte_count) == 1)? 4'b0001 : 4'b0011) : crc_en;
                            crc_en = (i == 1)? 4'b0000 : crc_en;
                        end
                        byte1          = data[ 7: 0];
                        byte2          = data[15: 8];
                        byte3          = data[23:16];
                        case(word_count_r - byte_count)
                            16'd1: begin
                                $fwrite(tx_output_data_file,"%02h\n",data[7:0]);
                                $fflush(tx_output_data_file);
                                $display("%t Data[0] : Receiving data = %02h\n", $time, data[ 7: 0]);
                                data_write_count = data_write_count + 1;
                                if (EOTP_CHECK == "ON" | CRC_CHECK == "ON") begin
                                    eotpcheck_after_lp(data[15:8],data[23:16],8'd0,3'b110);
                                end
                            end
                            16'd2: begin
                                $fwrite(tx_output_data_file,"%02h\n%02h\n",data[7:0],data[15:8]);
                                $fflush(tx_output_data_file);
                                $display("%t Data[0] : Receiving data = %02h\n", $time, data[ 7: 0]);
                                $display("%t Data[1] : Receiving data = %02h\n", $time, data[15: 8]);
                                data_write_count = data_write_count + 2;
                                if (EOTP_CHECK == "ON" | CRC_CHECK == "ON") begin
                                    eotpcheck_after_lp(data[23:16],8'd0,8'd0,3'b100);
                                end
                            end
                        endcase
                        byte_count     = byte_count + word_count_r - byte_count;
                        byte1          = data[ 7: 0];
                        byte2          = data[15: 8];
                        byte3          = data[23:16];
                    end
                end
            end
            else if (NUM_LANE == 2) begin
                byte3          = 8'hFF;
                byte4          = 8'hFF;
                while ((byte_count != word_count_r) && ((word_count_r - byte_count) >= 2)) begin
                    for (i = 0; i <= 7; i = i + 1) begin
                        data[ 0 + i] = d_p_i[0];
                        data[ 8 + i] = d_p_i[1];
                        wait4clk(1);
                        crc_en = (i == 7)? 4'b0011 : crc_en;
                        crc_en = (i == 1)? 4'b0000 : crc_en;
                    end
                    $fwrite(tx_output_data_file,"%02h\n%02h\n",data[7:0],data[15:8]);
                    $fflush(tx_output_data_file);
                    $display("%t Data[0] : Receiving data = %02h\n", $time, data[ 7: 0]);
                    $display("%t Data[1] : Receiving data = %02h\n", $time, data[15: 8]);
                    data_write_count = data_write_count + 2;
                    byte_count     = byte_count + 2;
                    byte1          = data[ 7: 0];
                    byte2          = data[15: 8];
                end

                if (((word_count_r - byte_count) == 1)) begin
                    for (i = 0; i <= 7; i = i + 1) begin
                        data[ 0 + i] = d_p_i[0];
                        data[ 8 + i] = d_p_i[1];
                        wait4clk(1);
                        crc_en = (i == 7)? 4'b0001 : crc_en;
                        crc_en = (i == 1)? 4'b0000 : crc_en;
                    end
                    case(word_count_r - byte_count)
                        16'd1: begin
                            $fwrite(tx_output_data_file,"%02h\n",data[7:0]);
                            $fflush(tx_output_data_file);
                            $display("%t Data[0] : Receiving data = %02h\n", $time, data[ 7: 0]);
                            data_write_count = data_write_count + 1;
                        end
                    endcase

                    byte_count     = byte_count + word_count_r - byte_count;
                    byte1          = data[ 7: 0];
                    byte2          = data[15: 8];

                    if (EOTP_CHECK == "ON" | CRC_CHECK == "ON") begin
                        eotpcheck_after_lp(byte2,8'd0,8'd0,3'b100);
                    end
                end
                else begin
                    if (EOTP_CHECK == "ON" | CRC_CHECK == "ON") begin
                        eotpcheck_after_lp(8'd0,8'd0,8'd0,3'b000);
                    end
                end
            end
            else if (NUM_LANE == 1) begin
                while ((byte_count != word_count_r)) begin
                    for (i = 0; i <= 7; i = i + 1) begin
                        data[ 0 + i] = d_p_i[0];
                        wait4clk(1);
                        crc_en = (i == 7)? 4'b0001 : crc_en;
                        crc_en = (i == 1)? 4'b0000 : crc_en;
                    end
                    $fwrite(tx_output_data_file,"%02h\n",data[7:0]);
                    $fflush(tx_output_data_file);
                    $display("%t Data[0] : Receiving data = %02h\n", $time, data[ 7: 0]);
                    data_write_count = data_write_count + 1;
                    byte_count     = byte_count + 1;
                    byte1          = data[ 7: 0];
                    byte2          = 8'hFF;
                    byte3          = 8'hFF;
                    byte4          = 8'hFF;
                end
                if (EOTP_CHECK == "ON" | CRC_CHECK == "ON") begin
                    eotpcheck_after_lp(8'd0,8'd0,8'd0,3'b000);
                end
            end
            in_process = 0;
        end
    endtask

    task eotpcheck();
        reg        in_process;
        integer    k;
        reg [31:0] EoTp;
        begin
            in_process = 1;
            EoTp       = 32'd0;
            if (NUM_LANE == 3) begin
                for (i = 0; i <= 15; i = i + 1) begin
                    if (i <= 7) begin
                        EoTp[ 0 + i] = d_p_i[0];
                        EoTp[ 8 + i] = d_p_i[1];
                        EoTp[16 + i] = d_p_i[2];
                    end
                    else begin
                        EoTp[16 + i] = d_p_i[0];
                    end
                    wait4clk(1);
                end  
            end
            else begin
                for (i = 0; i <= (32/NUM_LANE)-1; i = i + 1) begin
                    if (NUM_LANE == 4) begin
                        EoTp[ 0 + i]   = d_p_i[0];
                        EoTp[ 8 + i]   = d_p_i[1];
                        EoTp[16 + i]   = d_p_i[2];
                        EoTp[24 + i]   = d_p_i[3];
                        wait4clk(1);
                    end
                    else if (NUM_LANE == 2) begin
                        if (i <= 7) begin
                            EoTp[ 0 + i] = d_p_i[0];
                            EoTp[ 8 + i] = d_p_i[1];
                        end
                        else begin
                            EoTp[ 8 + i] = d_p_i[0];
                            EoTp[16 + i] = d_p_i[1];
                        end
                        wait4clk(1);
                    end
                    else if (NUM_LANE == 1) begin
                        EoTp[ 0 + i]   = d_p_i[0];
                        wait4clk(1);
                    end
                end
            end
            if (EoTp == EOTP_VAL) begin
                $display("EoTp received");
                global_EoTp_SP_passed_cases = global_EoTp_SP_passed_cases + 1;
            end
            else begin
                global_EoTp_SP_failed_cases = global_EoTp_SP_failed_cases + 1;
                for (k = 0; k < 32; k = k + 1) begin
                    if (EoTp[i] != EOTP_VAL[i]) begin
                        $display("EoTp bit %d is invalid",i);
                        #100;
                    end
                end
            end
            EoTp       = 32'd0;
            in_process = 0;
        end
    endtask

    // This task is additional task for task readbyte
    // Reads CRC and EoTp from data lines and check
    // Inputs is used for cases when payload and CRC and/or EoTp
    // received at the same time
    task eotpcheck_after_lp(
        input [7:0] crc_low,
        input [7:0] crc_high,
        input [7:0] eotp_low,
        input [2:0] valid
    );
        reg         in_process;
        reg [15:0]  crc;
        reg [31:0]  EoTp;
        
        begin
            in_process = 1'd1;
            crc        = 16'd0;
            EoTp       = 32'd0;
            
            if (NUM_LANE == 4) begin
                if (valid == 3'b000) begin // if word count is 4, 8,12 ...
                    for (i = 0; i <= 7; i = i + 1) begin
                        crc[ 0 + i]  = d_p_i[0];
                        crc[ 8 + i]  = d_p_i[1];
                        EoTp[ 0 + i] = d_p_i[2];
                        EoTp[ 8 + i] = d_p_i[3];
                        wait4clk(1);
                    end
                    if (EOTP_CHECK == "ON") begin
                        for (i = 0; i <= 7; i = i + 1) begin
                            EoTp[16 + i] = d_p_i[0];
                            EoTp[24 + i] = d_p_i[1];
                            wait4clk(1);
                        end
                    end
                end
                if (valid == 3'b100) begin // if word count is 7,11,15 ...
                    crc = crc_low;
                    for (i = 0; i <= 7; i = i + 1) begin
                        crc[ 8 + i]  = d_p_i[0];
                        EoTp[ 0 + i] = d_p_i[1];
                        EoTp[ 8 + i] = d_p_i[2];
                        EoTp[16 + i] = d_p_i[3];
                        wait4clk(1);
                    end
                    if (EOTP_CHECK == "ON") begin
                        for (i = 0; i <= 7; i = i + 1) begin
                            EoTp[24 + i] = d_p_i[0];
                            wait4clk(1);
                        end
                    end
                end else
                if (valid == 3'b110) begin // if word count is 6,10,14 ...
                    crc = {crc_high,crc_low};
                    received_crc_r = {crc_high,crc_low};
                    if (EOTP_CHECK == "ON") begin
                        for (i = 0; i <= 7; i = i + 1) begin
                            EoTp[ 0 + i] = d_p_i[0];
                            EoTp[ 8 + i] = d_p_i[1];
                            EoTp[16 + i] = d_p_i[2];
                            EoTp[24 + i] = d_p_i[3];
                            wait4clk(1);
                        end
                    end
                end
                else if (valid == 3'b111) begin // if word count is 5, 9,13 ...
                    crc  = {crc_high,crc_low};
                    EoTp = eotp_low;
                    if (EOTP_CHECK == "ON") begin
                        for (i = 0; i <= 7; i = i + 1) begin
                            EoTp[ 8 + i] = d_p_i[0];
                            EoTp[16 + i] = d_p_i[1];
                            EoTp[24 + i] = d_p_i[2];
                            wait4clk(1);
                        end
                    end
                end
            end

            if (NUM_LANE == 3) begin
                if (valid == 3'b000) begin // if word count is 3, 6, 9 ...
                    for (i = 0; i <= 7; i = i + 1) begin
                        crc[ 0 + i]  = d_p_i[0];
                        crc[ 8 + i]  = d_p_i[1];
                        EoTp[ 0 + i] = d_p_i[2];
                        wait4clk(1);
                    end
                    if (EOTP_CHECK == "ON") begin
                        for (i = 0; i <= 7; i = i + 1) begin
                            EoTp[ 8 + i] = d_p_i[0];
                            EoTp[16 + i] = d_p_i[1];
                            EoTp[24 + i] = d_p_i[2];
                            wait4clk(1);
                        end
                    end
                end
                if (valid == 3'b100) begin // if word count is 4, 7, 10 ...
                    crc = crc_low;
                    for (i = 0; i <= 7; i = i + 1) begin
                        crc[ 8 + i]  = d_p_i[0];
                        EoTp[ 0 + i] = d_p_i[1];
                        EoTp[ 8 + i] = d_p_i[2];
                        wait4clk(1);
                    end
                    if (EOTP_CHECK == "ON") begin
                        for (i = 0; i <= 7; i = i + 1) begin
                            EoTp[16 + i] = d_p_i[0];
                            EoTp[24 + i] = d_p_i[1];
                            wait4clk(1);
                        end
                    end
                end
                else if (valid == 3'b110) begin // if word count is 5, 8, 11 ...
                    crc = {crc_high,crc_low};
                    if (EOTP_CHECK == "ON") begin
                        for (i = 0; i <= 7; i = i + 1) begin
                            EoTp[ 0 + i] = d_p_i[0];
                            EoTp[ 8 + i] = d_p_i[1];
                            EoTp[16 + i] = d_p_i[2];
                            wait4clk(1);
                        end
                        for (i = 0; i <= 7; i = i + 1) begin
                            EoTp[24 + i] = d_p_i[0];
                            wait4clk(1);
                        end
                    end
                end
            end

            if (NUM_LANE == 2) begin
                if (valid == 3'b100) begin // Case when readbyte is already read crc[7:0] with last byte case when word count 1,3,5 ...
                    crc[7:0] = crc_low;
                    for (i = 0; i <= 7; i = i + 1) begin
                        crc[ 8 + i]  = d_p_i[0];
                        EoTp[ 0 + i] = d_p_i[1];
                        wait4clk(1);
                    end
                    if (EOTP_CHECK == "ON") begin
                        for (i = 0; i <= 7; i = i + 1) begin
                            EoTp[ 8 + i] = d_p_i[0];
                            EoTp[16 + i] = d_p_i[1];
                            wait4clk(1);
                        end
                        for (i = 0; i <= 7; i = i + 1) begin
                            EoTp[24 + i] = d_p_i[0];
                            wait4clk(1);
                        end
                    end
                end
                else begin
                    for (i = 0; i <= 7; i = i + 1) begin
                        crc[ 0 + i] = d_p_i[0];
                        crc[ 8 + i] = d_p_i[1];
                        wait4clk(1);
                    end
                    if (EOTP_CHECK == "ON") begin
                        for (i = 0; i <= 7; i = i + 1) begin
                            EoTp[ 0 + i] = d_p_i[0];
                            EoTp[ 8 + i] = d_p_i[1];
                            wait4clk(1);
                        end
                        for (i = 0; i <= 7; i = i + 1) begin
                            EoTp[16 + i] = d_p_i[0];
                            EoTp[24 + i] = d_p_i[1];
                            wait4clk(1);
                        end
                    end
                end
            end
            else if (NUM_LANE == 1) begin
                for (i = 0; i <= 15; i = i + 1) begin
                    crc[ 0 + i] = d_p_i[0];
                    wait4clk(1);
                end
                if (EOTP_CHECK == "ON") begin
                    for (i = 0; i <= 31; i = i + 1) begin
                        EoTp[ 0 + i] = d_p_i[0];
                        wait4clk(1);
                    end
                end
            end
            received_crc_r       = crc;
            received_crc_valid_r = 1'd1;

            if (EOTP_CHECK == "ON") begin
                if (EoTp == EOTP_VAL) begin
                    global_EoTp_LP_passed_cases = global_EoTp_LP_passed_cases + 1;
                end
                else begin
                    global_EoTp_LP_failed_cases = global_EoTp_LP_failed_cases + 1;
                end
            end
            // #1000;
            crc  = 16'd0;
            EoTp = 32'd0;
            in_process = 1'd0;
        end
    endtask

    task reset();
        reg wait4reset;
        
        begin
            #1;
            wait4reset = 1;
            while(!reset_n_i) begin
                #1;
            end
            wait4reset = 0;
        end
    endtask

    task crc_calc();
        reg                  in_process;
        reg [NUM_LANE*8-1:0] reverse_data;
        reg           [15:0] reverse_crc;
        reg           [15:0] rx_crc;
        
        integer              cycle_count;
        
        begin
            @(posedge readbyte.in_process);
            in_process            = 1;
            reverse_data          = {(NUM_LANE*8){1'd0}};
            reverse_crc           = 16'hFFFF;
            
            if (NUM_LANE == 1) begin
                cycle_count           = word_count_r/NUM_LANE;
            end
            else if (NUM_LANE == 2) begin
                cycle_count           = word_count_r/NUM_LANE + word_count_r[0];
            end
            else if (NUM_LANE == 3) begin
                cycle_count           = word_count_r/NUM_LANE + ((word_count_r % NUM_LANE) == 0) ? 0 : 1;
            end
            else if (NUM_LANE == 4) begin
                cycle_count           = word_count_r/NUM_LANE + |word_count_r[1:0];
            end
            
            repeat (cycle_count) begin
                @(posedge readbyte.crc_en[0]);
                if (NUM_LANE == 1) begin
                    reverse_data  = { readbyte.byte1[0],
                                      readbyte.byte1[1],
                                      readbyte.byte1[2],
                                      readbyte.byte1[3],
                                      readbyte.byte1[4],
                                      readbyte.byte1[5],
                                      readbyte.byte1[6],
                                      readbyte.byte1[7] };
                    reverse_crc   = nextCRC16_D8(reverse_data,reverse_crc);
                end
                else if (NUM_LANE == 2) begin
                    reverse_data  = { readbyte.byte1[0],readbyte.byte1[1],
                                      readbyte.byte1[2],readbyte.byte1[3],
                                      readbyte.byte1[4],readbyte.byte1[5],
                                      readbyte.byte1[6],readbyte.byte1[7],
                                      readbyte.byte2[0],readbyte.byte2[1],
                                      readbyte.byte2[2],readbyte.byte2[3],
                                      readbyte.byte2[4],readbyte.byte2[5],
                                      readbyte.byte2[6],readbyte.byte2[7] };
                    if (readbyte.crc_en == 4'b0011) begin
                        reverse_crc   = nextCRC16_D16(reverse_data,reverse_crc);
                    end
                    else if (readbyte.crc_en == 4'b0001) begin
                        reverse_crc   = nextCRC16_D8(reverse_data[15:8],reverse_crc);
                    end
                end
                else if (NUM_LANE == 3) begin
                    reverse_data  = { readbyte.byte1[0],readbyte.byte1[1],readbyte.byte1[2],readbyte.byte1[3],
                                      readbyte.byte1[4],readbyte.byte1[5],readbyte.byte1[6],readbyte.byte1[7],
                                      readbyte.byte2[0],readbyte.byte2[1],readbyte.byte2[2],readbyte.byte2[3],
                                      readbyte.byte2[4],readbyte.byte2[5],readbyte.byte2[6],readbyte.byte2[7],
                                      readbyte.byte3[0],readbyte.byte3[1],readbyte.byte3[2],readbyte.byte3[3],
                                      readbyte.byte3[4],readbyte.byte3[5],readbyte.byte3[6],readbyte.byte3[7] };
                    if (readbyte.crc_en == 4'b0111) begin
                        reverse_crc   = nextCRC16_D24(reverse_data,reverse_crc);
                    end
                    else if (readbyte.crc_en == 4'b0011) begin
                        reverse_crc   = nextCRC16_D16(reverse_data[23:8],reverse_crc);
                    end
                    else if (readbyte.crc_en == 4'b0001) begin
                        reverse_crc   = nextCRC16_D8(reverse_data[23:16],reverse_crc);
                    end
                end
                if (NUM_LANE == 4) begin
                    reverse_data  = { readbyte.byte1[0],readbyte.byte1[1],readbyte.byte1[2],readbyte.byte1[3],
                                      readbyte.byte1[4],readbyte.byte1[5],readbyte.byte1[6],readbyte.byte1[7],
                                      readbyte.byte2[0],readbyte.byte2[1],readbyte.byte2[2],readbyte.byte2[3],
                                      readbyte.byte2[4],readbyte.byte2[5],readbyte.byte2[6],readbyte.byte2[7],
                                      readbyte.byte3[0],readbyte.byte3[1],readbyte.byte3[2],readbyte.byte3[3],
                                      readbyte.byte3[4],readbyte.byte3[5],readbyte.byte3[6],readbyte.byte3[7],
                                      readbyte.byte4[0],readbyte.byte4[1],readbyte.byte4[2],readbyte.byte4[3],
                                      readbyte.byte4[4],readbyte.byte4[5],readbyte.byte4[6],readbyte.byte4[7] };
                    if (readbyte.crc_en == 4'b1111) begin
                        reverse_crc   = nextCRC16_D32(reverse_data,reverse_crc);
                    end
                    else if (readbyte.crc_en == 4'b0111) begin
                        reverse_crc   = nextCRC16_D24(reverse_data[31:8],reverse_crc);
                    end
                    else if (readbyte.crc_en == 4'b0011) begin
                        reverse_crc   = nextCRC16_D16(reverse_data[31:16],reverse_crc);
                    end
                    else if (readbyte.crc_en == 4'b0001) begin
                        reverse_crc   = nextCRC16_D8(reverse_data[31:24],reverse_crc);
                    end
                end
                // Current CRC
                rx_crc                = { reverse_crc[ 0],
                                          reverse_crc[ 1],
                                          reverse_crc[ 2],
                                          reverse_crc[ 3],
                                          reverse_crc[ 4],
                                          reverse_crc[ 5],
                                          reverse_crc[ 6],
                                          reverse_crc[ 7],
                                          reverse_crc[ 8],
                                          reverse_crc[ 9],
                                          reverse_crc[10],
                                          reverse_crc[11],
                                          reverse_crc[12],
                                          reverse_crc[13],
                                          reverse_crc[14],
                                          reverse_crc[15] };
            end
            calculated_crc_r       = rx_crc;
            calculated_crc_valid_r = 1'd1;
            in_process             = 0;
        end
    endtask

    task compute_ecc(
        input [23:0] d, output [5:0] ecc_val
    );
        begin
            ecc_val[0] = d[ 0] ^ d[ 1] ^ d[ 2] ^ d[ 4] ^ d[ 5] ^ d[ 7] ^ d[10] ^ d[11] ^ d[13] ^ d[16] ^ d[20] ^ d[21] ^ d[22] ^ d[23];
            ecc_val[1] = d[ 0] ^ d[ 1] ^ d[ 3] ^ d[ 4] ^ d[ 6] ^ d[ 8] ^ d[10] ^ d[12] ^ d[14] ^ d[17] ^ d[20] ^ d[21] ^ d[22] ^ d[23];
            ecc_val[2] = d[ 0] ^ d[ 2] ^ d[ 3] ^ d[ 5] ^ d[ 6] ^ d[ 9] ^ d[11] ^ d[12] ^ d[15] ^ d[18] ^ d[20] ^ d[21] ^ d[22];
            ecc_val[3] = d[ 1] ^ d[ 2] ^ d[ 3] ^ d[ 7] ^ d[ 8] ^ d[ 9] ^ d[13] ^ d[14] ^ d[15] ^ d[19] ^ d[20] ^ d[21] ^ d[23];
            ecc_val[4] = d[ 4] ^ d[ 5] ^ d[ 6] ^ d[ 7] ^ d[ 8] ^ d[ 9] ^ d[16] ^ d[17] ^ d[18] ^ d[19] ^ d[20] ^ d[22] ^ d[23];
            ecc_val[5] = d[10] ^ d[11] ^ d[12] ^ d[13] ^ d[14] ^ d[15] ^ d[16] ^ d[17] ^ d[18] ^ d[19] ^ d[21] ^ d[22] ^ d[23];
        end
    endtask

    task report_err(
    );
        begin
            if (global_failed_cases != 0 && timing_param_fail != 0) begin
                $display("%t Global FAIL", $time);
                $display("Errors timing_param_fail %d", timing_param_fail);
                $display("Errors global_failed_cases %d", global_failed_cases);
                sim_failed = 1'd1;
                // $stop;
            end
            
            if (CRC_CHECK == "ON") begin
                if (global_CRC_failed_cases != 0) begin
                    $display("%t CRC FAIL", $time);
                    $display("Errors ",global_CRC_failed_cases,"/",global_CRC_failed_cases + global_CRC_passed_cases);
                    sim_failed = 1'd1;
                    $stop;
                end
            end

            if (ECC_CHECK == "ON") begin
                if (global_ECC_failed_cases !=0) begin
                    $display("%t ECC FAIL", $time);
                    $display("ECC Errors ",global_ECC_failed_cases,"/",global_ECC_failed_cases + global_ECC_passed_cases);
                    sim_failed = 1'd1;
                    $stop;
                end
            end

            if (FRAME_CNT_EN == "ON") begin
                if (global_FRAME_NUMBER_failed_cases != 0) begin
                    $display("%t FRAME NUMBER INCREMENT FAIL", $time);
                    $display("Errors ",global_FRAME_NUMBER_failed_cases,"/",global_FRAME_NUMBER_failed_cases + global_FRAME_NUMBER_passed_cases);
                    sim_failed = 1'd1;
                    $stop;
                end
            end 

            // if (BLANKING_EN == "ON") begin
                // if (global_Blanking_failed_cases != 0) begin
                    // $display("%t Blanking FAIL", $time);
                    // $display("Errors ",global_Blanking_failed_cases,"/",global_Blanking_failed_cases);
                    // sim_failed = 1'd1;
                    // $stop;
                // end  
            // end  
        end
    endtask
    
    //------------------------------------------------------------------------------
    // Function Definition
    //------------------------------------------------------------------------------
    function [15:0] nextCRC16_D32;
        input [31:0] Data;
        input [15:0] crc_o;
        reg   [31:0] d;
        reg   [15:0] c;
        reg   [15:0] newcrc;
        
        begin
            d          = Data;
            c          = crc_o;

            newcrc[0]  = d[28] ^ d[27] ^ d[26] ^ d[22] ^ d[20] ^ d[19] ^ d[12] ^ d[11] ^
                         d[ 8] ^ d[ 4] ^ d[ 0] ^ c[ 3] ^ c[ 4] ^ c[ 6] ^ c[10] ^ c[11] ^
                         c[12];
            newcrc[1]  = d[29] ^ d[28] ^ d[27] ^ d[23] ^ d[21] ^ d[20] ^ d[13] ^ d[12] ^
                         d[ 9] ^ d[ 5] ^ d[ 1] ^ c[ 4] ^ c[ 5] ^ c[ 7] ^ c[11] ^ c[12] ^
                         c[13];
            newcrc[2]  = d[30] ^ d[29] ^ d[28] ^ d[24] ^ d[22] ^ d[21] ^ d[14] ^ d[13] ^
                         d[10] ^ d[ 6] ^ d[ 2] ^ c[ 5] ^ c[ 6] ^ c[ 8] ^ c[12] ^ c[13] ^
                         c[14];
            newcrc[3]  = d[31] ^ d[30] ^ d[29] ^ d[25] ^ d[23] ^ d[22] ^ d[15] ^ d[14] ^
                         d[11] ^ d[ 7] ^ d[ 3] ^ c[ 6] ^ c[ 7] ^ c[ 9] ^ c[13] ^ c[14] ^
                         c[15];
            newcrc[4]  = d[31] ^ d[30] ^ d[26] ^ d[24] ^ d[23] ^ d[16] ^ d[15] ^ d[12] ^
                         d[ 8] ^ d[ 4] ^ c[ 0] ^ c[ 7] ^ c[ 8] ^ c[10] ^ c[14] ^ c[15];
            newcrc[5]  = d[31] ^ d[28] ^ d[26] ^ d[25] ^ d[24] ^ d[22] ^ d[20] ^ d[19] ^
                         d[17] ^ d[16] ^ d[13] ^ d[12] ^ d[11] ^ d[ 9] ^ d[ 8] ^ d[ 5] ^
                         d[ 4] ^ d[ 0] ^ c[ 0] ^ c[ 1] ^ c[ 3] ^ c[ 4] ^ c[ 6] ^ c[ 8] ^
                         c[ 9] ^ c[10] ^ c[12] ^ c[15];
            newcrc[6]  = d[29] ^ d[27] ^ d[26] ^ d[25] ^ d[23] ^ d[21] ^ d[20] ^ d[18] ^
                         d[17] ^ d[14] ^ d[13] ^ d[12] ^ d[10] ^ d[ 9] ^ d[ 6] ^ d[ 5] ^
                         d[ 1] ^ c[ 1] ^ c[ 2] ^ c[ 4] ^ c[ 5] ^ c[ 7] ^ c[ 9] ^ c[10] ^
                         c[11] ^ c[13];
            newcrc[7]  = d[30] ^ d[28] ^ d[27] ^ d[26] ^ d[24] ^ d[22] ^ d[21] ^ d[19] ^
                         d[18] ^ d[15] ^ d[14] ^ d[13] ^ d[11] ^ d[10] ^ d[ 7] ^ d[ 6] ^
                         d[ 2] ^ c[ 2] ^ c[ 3] ^ c[ 5] ^ c[ 6] ^ c[ 8] ^ c[10] ^ c[11] ^
                         c[12] ^ c[14];
            newcrc[8]  = d[31] ^ d[29] ^ d[28] ^ d[27] ^ d[25] ^ d[23] ^ d[22] ^ d[20] ^
                         d[19] ^ d[16] ^ d[15] ^ d[14] ^ d[12] ^ d[11] ^ d[ 8] ^ d[ 7] ^
                         d[ 3] ^ c[ 0] ^ c[ 3] ^ c[ 4] ^ c[ 6] ^ c[ 7] ^ c[ 9] ^ c[11] ^
                         c[12] ^ c[13] ^ c[15];
            newcrc[9]  = d[30] ^ d[29] ^ d[28] ^ d[26] ^ d[24] ^ d[23] ^ d[21] ^ d[20] ^
                         d[17] ^ d[16] ^ d[15] ^ d[13] ^ d[12] ^ d[ 9] ^ d[ 8] ^ d[ 4] ^
                         c[ 0] ^ c[ 1] ^ c[ 4] ^ c[ 5] ^ c[ 7] ^ c[ 8] ^ c[10] ^ c[12] ^
                         c[13] ^ c[14];
            newcrc[10] = d[31] ^ d[30] ^ d[29] ^ d[27] ^ d[25] ^ d[24] ^ d[22] ^ d[21] ^
                         d[18] ^ d[17] ^ d[16] ^ d[14] ^ d[13] ^ d[10] ^ d[ 9] ^ d[ 5] ^
                         c[ 0] ^ c[ 1] ^ c[ 2] ^ c[ 5] ^ c[ 6] ^ c[ 8] ^ c[ 9] ^ c[11] ^
                         c[13] ^ c[14] ^ c[15];
            newcrc[11] = d[31] ^ d[30] ^ d[28] ^ d[26] ^ d[25] ^ d[23] ^ d[22] ^ d[19] ^
                         d[18] ^ d[17] ^ d[15] ^ d[14] ^ d[11] ^ d[10] ^ d[ 6] ^ c[ 1] ^
                         c[ 2] ^ c[ 3] ^ c[ 6] ^ c[ 7] ^ c[ 9] ^ c[10] ^ c[12] ^ c[14] ^
                         c[15];
            newcrc[12] = d[31] ^ d[29] ^ d[28] ^ d[24] ^ d[23] ^ d[22] ^ d[18] ^ d[16] ^
                         d[15] ^ d[ 8] ^ d[ 7] ^ d[ 4] ^ d[ 0] ^ c[ 0] ^ c[ 2] ^ c[ 6] ^
                         c[ 7] ^ c[ 8] ^ c[12] ^ c[13] ^ c[15];
            newcrc[13] = d[30] ^ d[29] ^ d[25] ^ d[24] ^ d[23] ^ d[19] ^ d[17] ^ d[16] ^
                         d[ 9] ^ d[ 8] ^ d[ 5] ^ d[ 1] ^ c[ 0] ^ c[ 1] ^ c[ 3] ^ c[ 7] ^
                         c[ 8] ^ c[ 9] ^ c[13] ^ c[14];
            newcrc[14] = d[31] ^ d[30] ^ d[26] ^ d[25] ^ d[24] ^ d[20] ^ d[18] ^ d[17] ^
                         d[10] ^ d[ 9] ^ d[ 6] ^ d[ 2] ^ c[ 1] ^ c[ 2] ^ c[ 4] ^ c[ 8] ^
                         c[ 9] ^ c[10] ^ c[14] ^ c[15];
            newcrc[15] = d[31] ^ d[27] ^ d[26] ^ d[25] ^ d[21] ^ d[19] ^ d[18] ^ d[11] ^
                         d[10] ^ d[ 7] ^ d[ 3] ^ c[ 2] ^ c[ 3] ^ c[ 5] ^ c[ 9] ^ c[10] ^
                         c[11] ^ c[15];
            nextCRC16_D32 = newcrc;
        end
    endfunction

    function [15:0] nextCRC16_D24;
        input [23:0] Data;
        input [15:0] crc;
        reg   [23:0] d;
        reg   [15:0] c;
        reg   [15:0] newcrc;
        
        begin
            d             = Data;
            c             = crc;
            
            newcrc[ 0]    = d[22] ^ d[20] ^ d[19] ^ d[12] ^ d[11] ^ d[ 8] ^ d[ 4] ^
                            d[ 0] ^ c[ 0] ^ c[ 3] ^ c[ 4] ^ c[11] ^ c[12] ^ c[14];
            newcrc[ 1]    = d[23] ^ d[21] ^ d[20] ^ d[13] ^ d[12] ^ d[ 9] ^ d[ 5] ^
                            d[ 1] ^ c[ 1] ^ c[ 4] ^ c[ 5] ^ c[12] ^ c[13] ^ c[15];
            newcrc[ 2]    = d[22] ^ d[21] ^ d[14] ^ d[13] ^ d[10] ^ d[ 6] ^ d[ 2] ^
                            c[ 2] ^ c[ 5] ^ c[ 6] ^ c[13] ^ c[14];
            newcrc[ 3]    = d[23] ^ d[22] ^ d[15] ^ d[14] ^ d[11] ^ d[ 7] ^ d[ 3] ^
                            c[ 3] ^ c[ 6] ^ c[ 7] ^ c[14] ^ c[15];
            newcrc[ 4]    = d[23] ^ d[16] ^ d[15] ^ d[12] ^ d[ 8] ^ d[ 4] ^ c[ 0] ^
                            c[ 4] ^ c[ 7] ^ c[ 8] ^ c[15];
            newcrc[ 5]    = d[22] ^ d[20] ^ d[19] ^ d[17] ^ d[16] ^ d[13] ^ d[12] ^
                            d[11] ^ d[ 9] ^ d[ 8] ^ d[ 5] ^ d[ 4] ^ d[ 0] ^ c[ 0] ^
                            c[ 1] ^ c[ 3] ^ c[ 4] ^ c[ 5] ^ c[ 8] ^ c[ 9] ^ c[11] ^
                            c[12] ^ c[14];
            newcrc[ 6]    = d[23] ^ d[21] ^ d[20] ^ d[18] ^ d[17] ^ d[14] ^ d[13] ^
                            d[12] ^ d[10] ^ d[ 9] ^ d[ 6] ^ d[ 5] ^ d[ 1] ^ c[ 1] ^
                            c[ 2] ^ c[ 4] ^ c[ 5] ^ c[ 6] ^ c[ 9] ^ c[10] ^ c[12] ^
                            c[13] ^ c[15];
            newcrc[ 7]    = d[22] ^ d[21] ^ d[19] ^ d[18] ^ d[15] ^ d[14] ^ d[13] ^
                            d[11] ^ d[10] ^ d[ 7] ^ d[ 6] ^ d[ 2] ^ c[ 2] ^ c[ 3] ^
                            c[ 5] ^ c[ 6] ^ c[ 7] ^ c[10] ^ c[11] ^ c[13] ^ c[14];
            newcrc[ 8]    = d[23] ^ d[22] ^ d[20] ^ d[19] ^ d[16] ^ d[15] ^ d[14] ^
                            d[12] ^ d[11] ^ d[ 8] ^ d[ 7] ^ d[ 3] ^ c[ 0] ^ c[ 3] ^
                            c[ 4] ^ c[ 6] ^ c[ 7] ^ c[ 8] ^ c[11] ^ c[12] ^ c[14] ^
                            c[15];
            newcrc[ 9]    = d[23] ^ d[21] ^ d[20] ^ d[17] ^ d[16] ^ d[15] ^ d[13] ^
                            d[12] ^ d[ 9] ^ d[ 8] ^ d[ 4] ^ c[ 0] ^ c[ 1] ^ c[ 4] ^
                            c[ 5] ^ c[ 7] ^ c[ 8] ^ c[ 9] ^ c[12] ^ c[13] ^ c[15];
            newcrc[10]    = d[22] ^ d[21] ^ d[18] ^ d[17] ^ d[16] ^ d[14] ^ d[13] ^
                            d[10] ^ d[ 9] ^ d[ 5] ^ c[ 1] ^ c[ 2] ^ c[ 5] ^ c[ 6] ^
                            c[ 8] ^ c[ 9] ^ c[10] ^ c[13] ^ c[14];
            newcrc[11]    = d[23] ^ d[22] ^ d[19] ^ d[18] ^ d[17] ^ d[15] ^ d[14] ^
                            d[11] ^ d[10] ^ d[ 6] ^ c[ 2] ^ c[ 3] ^ c[ 6] ^ c[ 7] ^
                            c[ 9] ^ c[10] ^ c[11] ^ c[14] ^ c[15];
            newcrc[12]    = d[23] ^ d[22] ^ d[18] ^ d[16] ^ d[15] ^ d[ 8] ^ d[ 7] ^
                            d[ 4] ^ d[ 0] ^ c[ 0] ^ c[ 7] ^ c[ 8] ^ c[10] ^ c[14] ^
                            c[15];
            newcrc[13]    = d[23] ^ d[19] ^ d[17] ^ d[16] ^ d[ 9] ^ d[ 8] ^ d[ 5] ^
                            d[ 1] ^ c[ 0] ^ c[ 1] ^ c[ 8] ^ c[ 9] ^ c[11] ^ c[15];
            newcrc[14]    = d[20] ^ d[18] ^ d[17] ^ d[10] ^ d[ 9] ^ d[ 6] ^ d[ 2] ^
                            c[ 1] ^ c[ 2] ^ c[ 9] ^ c[10] ^ c[12];
            newcrc[15]    = d[21] ^ d[19] ^ d[18] ^ d[11] ^ d[10] ^ d[ 7] ^ d[ 3] ^
                            c[ 2] ^ c[ 3] ^ c[10] ^ c[11] ^ c[13];
            nextCRC16_D24 = newcrc;
        end
    endfunction

    function [15:0] nextCRC16_D16;
        input [15:0] Data;
        input [15:0] crc_o;
        reg   [15:0] d;
        reg   [15:0] c;
        reg   [15:0] newcrc;
        
        begin
            d             = Data;
            c             = crc_o;
            
            newcrc[0]     = d[12] ^ d[11] ^ d[ 8] ^ d[ 4] ^ d[ 0] ^ c[ 0] ^ c[ 4] ^
                            c[ 8] ^ c[11] ^ c[12];
            newcrc[1]     = d[13] ^ d[12] ^ d[ 9] ^ d[ 5] ^ d[ 1] ^ c[ 1] ^ c[ 5] ^
                            c[ 9] ^ c[12] ^ c[13];
            newcrc[2]     = d[14] ^ d[13] ^ d[10] ^ d[ 6] ^ d[ 2] ^ c[ 2] ^ c[ 6] ^
                            c[10] ^ c[13] ^ c[14];
            newcrc[3]     = d[15] ^ d[14] ^ d[11] ^ d[ 7] ^ d[ 3] ^ c[ 3] ^ c[ 7] ^
                            c[11] ^ c[14] ^ c[15];
            newcrc[4]     = d[15] ^ d[12] ^ d[ 8] ^ d[ 4] ^ c[ 4] ^ c[ 8] ^ c[12] ^
                            c[15];
            newcrc[5]     = d[13] ^ d[12] ^ d[11] ^ d[ 9] ^ d[ 8] ^ d[ 5] ^ d[ 4] ^
                            d[ 0] ^ c[ 0] ^ c[ 4] ^ c[ 5] ^ c[ 8] ^ c[ 9] ^ c[11] ^
                            c[12] ^ c[13];
            newcrc[6]     = d[14] ^ d[13] ^ d[12] ^ d[10] ^ d[ 9] ^ d[ 6] ^ d[ 5] ^
                            d[ 1] ^ c[ 1] ^ c[ 5] ^ c[ 6] ^ c[ 9] ^ c[10] ^ c[12] ^
                            c[13] ^ c[14];
            newcrc[7]     = d[15] ^ d[14] ^ d[13] ^ d[11] ^ d[10] ^ d[ 7] ^ d[ 6] ^
                            d[ 2] ^ c[ 2] ^ c[ 6] ^ c[ 7] ^ c[10] ^ c[11] ^ c[13] ^
                            c[14] ^ c[15];
            newcrc[8]     = d[15] ^ d[14] ^ d[12] ^ d[11] ^ d[ 8] ^ d[ 7] ^ d[ 3] ^
                            c[ 3] ^ c[ 7] ^ c[ 8] ^ c[11] ^ c[12] ^ c[14] ^ c[15];
            newcrc[9]     = d[15] ^ d[13] ^ d[12] ^ d[ 9] ^ d[ 8] ^ d[ 4] ^ c[ 4] ^
                            c[ 8] ^ c[ 9] ^ c[12] ^ c[13] ^ c[15];
            newcrc[10]    = d[14] ^ d[13] ^ d[10] ^ d[ 9] ^ d[ 5] ^ c[ 5] ^ c[ 9] ^
                            c[10] ^ c[13] ^ c[14];
            newcrc[11]    = d[15] ^ d[14] ^ d[11] ^ d[10] ^ d[ 6] ^ c[ 6] ^ c[10] ^
                            c[11] ^ c[14] ^ c[15];
            newcrc[12]    = d[15] ^ d[ 8] ^ d[ 7] ^ d[ 4] ^ d[ 0] ^ c[ 0] ^ c[ 4] ^
                            c[ 7] ^ c[ 8] ^ c[15];
            newcrc[13]    = d[ 9] ^ d[ 8] ^ d[ 5] ^ d[ 1] ^ c[ 1] ^ c[ 5] ^ c[ 8] ^
                            c[ 9];
            newcrc[14]    = d[10] ^ d[ 9] ^ d[ 6] ^ d[ 2] ^ c[ 2] ^ c[ 6] ^ c[ 9] ^
                            c[10];
            newcrc[15]    = d[11] ^ d[10] ^ d[ 7] ^ d[ 3] ^ c[ 3] ^ c[ 7] ^ c[10] ^
                            c[11];
            nextCRC16_D16 = newcrc;
        end
    endfunction

    function [15:0] nextCRC16_D8;
        input [7:0]  Data;
        input [15:0] crc_o;
        reg   [7:0]  d;
        reg   [15:0] c;
        reg   [15:0] newcrc;

        begin
            d            = Data;
            c            = crc_o;
            newcrc[ 0]   = d[ 4] ^ d[ 0] ^ c[ 8] ^ c[12];
            newcrc[ 1]   = d[ 5] ^ d[ 1] ^ c[ 9] ^ c[13];
            newcrc[ 2]   = d[ 6] ^ d[ 2] ^ c[10] ^ c[14];
            newcrc[ 3]   = d[ 7] ^ d[ 3] ^ c[11] ^ c[15];
            newcrc[ 4]   = d[ 4] ^ c[12];
            newcrc[ 5]   = d[ 5] ^ d[ 4] ^ d[ 0] ^ c[ 8] ^ c[12] ^ c[13];
            newcrc[ 6]   = d[ 6] ^ d[ 5] ^ d[ 1] ^ c[ 9] ^ c[13] ^ c[14];
            newcrc[ 7]   = d[ 7] ^ d[ 6] ^ d[ 2] ^ c[10] ^ c[14] ^ c[15];
            newcrc[ 8]   = d[ 7] ^ d[ 3] ^ c[ 0] ^ c[11] ^ c[15];
            newcrc[ 9]   = d[ 4] ^ c[ 1] ^ c[12];
            newcrc[10]   = d[ 5] ^ c[ 2] ^ c[13];
            newcrc[11]   = d[ 6] ^ c[ 3] ^ c[14];
            newcrc[12]   = d[ 7] ^ d[ 4] ^ d[ 0] ^ c[ 4] ^ c[ 8] ^ c[12] ^ c[15];
            newcrc[13]   = d[ 5] ^ d[ 1] ^ c[ 5] ^ c[ 9] ^ c[13];
            newcrc[14]   = d[ 6] ^ d[ 2] ^ c[ 6] ^ c[10] ^ c[14];
            newcrc[15]   = d[ 7] ^ d[ 3] ^ c[ 7] ^ c[11] ^ c[15];
            nextCRC16_D8 = newcrc;
        end
    endfunction

    // Returns 1 if data_type corresponds to image pixel data (long packet)
    function is_image_data_type;
        input [5:0] dt;
        begin
            if (INTF_TYPE == "CSI2") begin
                is_image_data_type = (dt >= 6'h18 && dt <= 6'h2F);
            end
            else begin
                is_image_data_type = (dt == 6'h0C || dt == 6'h1C || dt == 6'h2C ||
                                      dt == 6'h0D || dt == 6'h1D || dt == 6'h2D || dt == 6'h3D ||
                                      dt == 6'h0E || dt == 6'h1E || dt == 6'h2E);
            end
        end
    endfunction

    // Decode MIPI CSI-2 / DSI data type to a human-readable name
    function [32*8-1:0] get_data_type_name;
        input [5:0] dt;
        begin
            if (INTF_TYPE == "CSI2") begin
                case (dt)
                    6'h00:   get_data_type_name = "FS  Frame Start";
                    6'h01:   get_data_type_name = "FE  Frame End";
                    6'h02:   get_data_type_name = "LS  Line Start";
                    6'h03:   get_data_type_name = "LE  Line End";
                    6'h04:   get_data_type_name = "Reserved 0x04";
                    6'h05:   get_data_type_name = "Reserved 0x05";
                    6'h06:   get_data_type_name = "Reserved 0x06";
                    6'h07:   get_data_type_name = "Reserved 0x07";
                    6'h08:   get_data_type_name = "Gen Short Pkt 1";
                    6'h09:   get_data_type_name = "Gen Short Pkt 2";
                    6'h0A:   get_data_type_name = "Gen Short Pkt 3";
                    6'h0B:   get_data_type_name = "Gen Short Pkt 4";
                    6'h0C:   get_data_type_name = "Gen Short Pkt 5";
                    6'h0D:   get_data_type_name = "Gen Short Pkt 6";
                    6'h0E:   get_data_type_name = "Gen Short Pkt 7";
                    6'h0F:   get_data_type_name = "Gen Short Pkt 8";
                    6'h10:   get_data_type_name = "Null";
                    6'h11:   get_data_type_name = "Blanking Data";
                    6'h12:   get_data_type_name = "Embedded 8-bit";
                    6'h18:   get_data_type_name = "YUV420 8-bit";
                    6'h19:   get_data_type_name = "YUV420 10-bit";
                    6'h1A:   get_data_type_name = "YUV420 Legacy";
                    6'h1C:   get_data_type_name = "YUV420 8b CSPS";
                    6'h1D:   get_data_type_name = "YUV420 10b CSPS";
                    6'h1E:   get_data_type_name = "YUV422 8-bit";
                    6'h1F:   get_data_type_name = "YUV422 10-bit";
                    6'h20:   get_data_type_name = "RGB444";
                    6'h21:   get_data_type_name = "RGB555";
                    6'h22:   get_data_type_name = "RGB565";
                    6'h23:   get_data_type_name = "RGB666";
                    6'h24:   get_data_type_name = "RGB888";
                    6'h28:   get_data_type_name = "RAW6";
                    6'h29:   get_data_type_name = "RAW7";
                    6'h2A:   get_data_type_name = "RAW8";
                    6'h2B:   get_data_type_name = "RAW10";
                    6'h2C:   get_data_type_name = "RAW12";
                    6'h2D:   get_data_type_name = "RAW14";
                    6'h2E:   get_data_type_name = "RAW16";
                    6'h2F:   get_data_type_name = "RAW20";
                    6'h30:   get_data_type_name = "User Defined 1";
                    6'h31:   get_data_type_name = "User Defined 2";
                    6'h32:   get_data_type_name = "User Defined 3";
                    6'h33:   get_data_type_name = "User Defined 4";
                    6'h34:   get_data_type_name = "User Defined 5";
                    6'h35:   get_data_type_name = "User Defined 6";
                    6'h36:   get_data_type_name = "User Defined 7";
                    6'h37:   get_data_type_name = "User Defined 8";
                    default: get_data_type_name = "Unknown CSI-2";
                endcase
            end
            else begin
                case (dt)
                    6'h01:   get_data_type_name = "V-Sync Start";
                    6'h11:   get_data_type_name = "V-Sync End";
                    6'h21:   get_data_type_name = "H-Sync Start";
                    6'h31:   get_data_type_name = "H-Sync End";
                    6'h08:   get_data_type_name = "EoTp";
                    6'h02:   get_data_type_name = "Color Mode Off";
                    6'h12:   get_data_type_name = "Color Mode On";
                    6'h22:   get_data_type_name = "Shut Down Periph";
                    6'h32:   get_data_type_name = "Turn On Periph";
                    6'h03:   get_data_type_name = "Gen Short Wr 0P";
                    6'h13:   get_data_type_name = "Gen Short Wr 1P";
                    6'h23:   get_data_type_name = "Gen Short Wr 2P";
                    6'h04:   get_data_type_name = "Gen Read 0 Param";
                    6'h14:   get_data_type_name = "Gen Read 1 Param";
                    6'h24:   get_data_type_name = "Gen Read 2 Param";
                    6'h05:   get_data_type_name = "DCS Short Wr 0P";
                    6'h15:   get_data_type_name = "DCS Short Wr 1P";
                    6'h06:   get_data_type_name = "DCS Read 0 Param";
                    6'h37:   get_data_type_name = "Set Max Ret Size";
                    6'h09:   get_data_type_name = "Null Packet";
                    6'h19:   get_data_type_name = "Blanking Packet";
                    6'h29:   get_data_type_name = "Gen Long Write";
                    6'h39:   get_data_type_name = "DCS Long Write";
                    6'h0C:   get_data_type_name = "Loosely Pk 20bYC";
                    6'h1C:   get_data_type_name = "Packed 24b YCbCr";
                    6'h2C:   get_data_type_name = "Packed 16b YCbCr";
                    6'h0D:   get_data_type_name = "Packed 30b RGB";
                    6'h1D:   get_data_type_name = "Packed 36b RGB";
                    6'h2D:   get_data_type_name = "Packed 12b YCbCr";
                    6'h3D:   get_data_type_name = "Packed 16b RGB";
                    6'h0E:   get_data_type_name = "Packed 18b RGB";
                    6'h1E:   get_data_type_name = "Loosely Pk 18bRG";
                    6'h2E:   get_data_type_name = "Packed 24b RGB";
                    default: get_data_type_name = "Unknown DSI";
                endcase
            end
        end
    endfunction

endmodule   // rx_model
`endif
