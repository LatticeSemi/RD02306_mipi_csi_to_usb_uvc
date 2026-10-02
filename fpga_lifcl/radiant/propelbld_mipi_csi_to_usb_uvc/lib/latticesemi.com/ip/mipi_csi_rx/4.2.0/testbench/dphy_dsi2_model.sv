//===========================================================================
// Filename: dphy_dsi2_model.sv
// Copyright(c) 2016 Lattice Semiconductor Corporation. All rights reserved. 
//===========================================================================
`ifndef DPHY_DSI2_MODEL
`define DPHY_DSI2_MODEL

`timescale 1ps / 1ps

module dphy_dsi2_model#(
   // Design parameters
   parameter   dphy_num_lane          = 4,            // number of dphy data lanes. 
   parameter   dphy_clk_period        = 1683,         // in ps, clock period of DPHY. 
   parameter   CLK_MODE               = "HS_LP",
   parameter   BURST_MODE             = "ONOFF",
   parameter   LP_BLANKING            = "ON",
   parameter   EOTP                   = "ON",
   parameter   sim_weak               = "ON",         // simulate weak pull-up/pull-down
   parameter   send_cal               = "ON",         // send calibration, for line rate > 1500Mbps
   parameter   send_alt_cal           = "ON",         // send alternate calibration, for line rate > 2500Mbps
   parameter   skewcal_ui             = 32768,        // in UI, skew calibration time should be min 2^15*UI, max 100us
   parameter   altcal_ui              = 32768,        // in UI, alternate skew calibration time should be min 2^15*UI, max 100us
   // Testbench parameters for video data     
   parameter   num_frames             = 1,            // number of frames
   parameter   num_pixels             = 1920,         // number of horizontal pixels
   parameter   num_lines              = 1080,         // number of video lines
   parameter   t_lpx                  = 68000,        // in ps, min of 50ns
   parameter   t_clk_prepare          = 51000,        // in ps, set between 38ns to 95ns
   parameter   t_clk_zero             = 252503,       // in ps, (clk_prepare + clk_zero minimum should be 300ns)
   parameter   t_clk_pre              = 10098,        // in ps, minimum of 8*UI
   parameter   t_clk_post             = 186225,       // in ps, minimum of 60ns+52*UI
   parameter   t_clk_trail            = 99297,        // in ps, minimum of 60ns
   parameter   t_hs_prepare           = 55000,        // in ps, set between 40ns+4*UI to max of 85ns+6*UI
   parameter   t_hs_zero              = 103543,       // in ps, hs_prepare + hs_zero minimum should be 145ns+10*UI
   parameter   t_hs_trail             = 63366,        // in ps, minimum should be 60ns+4*UI, max should be 105ns+12*UI
   parameter   t_init                 = 100000000,    // in ps, DPHY initialization requirement, min of 100us
   parameter   hsa_payload            = 16'h007A,     // used for Non-burst sync pulse, HSA 2-byte word count (number of bytes of payload, see MIPI DSI spec v1.1 figure 30)
   parameter   bllp_payload           = 16'h193A,     // used for HS_ONLY mode, BLLP 2-byte word count (number of bytes of payload, see MIPI DSI spec v1.1 figure 30)
   parameter   hbp_payload            = 16'h01AE,     // used for HS_ONLY mode and HS_LP Non-burst sync pulse. HBP 2-byte word count (number of bytes of payload, see MIPI DSI spec v1.1 figure 30)
   parameter   hfp_payload            = 16'h0100,     // used for HS_ONLY mode and HS_LP Non-burst sync pulse. HFP 2-byte word count (number of bytes of payload, see MIPI DSI spec v1.1 figure 30)
   parameter   lps_bllp_duration      = 9532513,      // in ps, used for HS_LP mode, this pertains to the LP-11 state duration for blanking
   parameter   lps_hbp_duration       = 800000,       // in ps, used for HS_LP Non-burst sync events and burst mode. This pertains to the LP-11 state duration for horizontal back porch
   parameter   lps_hfp_duration       = 500000,       // in ps, used for HS_LP Non-burst sync events and burst mode. This pertains to the LP-11 state duration for horizontal front porch
   parameter   lps_pkt_gap            = 800000,       // in ps, LP-11 state duration inserted BETWEEN packets when HS_TXN_MODE == "SINGLE_PKT"
   parameter   HS_TXN_MODE            = "MULTI_PKT",  // "MULTI_PKT" - many packets per HS burst (legacy). "SINGLE_PKT" - one content packet per HS transaction.
   parameter   virtual_channel        = 2'h0,         // virtual channel ID
   parameter   video_data_type        = 6'h3E,        // video data type DI. example: 6'h3E = RGB888 
   parameter   vsa_lines              = 5,            // number of VSA lines, see MIPI DSI spec v1.1 figure 30
   parameter   vbp_lines              = 36,           // number of VBP lines, see MIPI DSI spec v1.1 figure 30
   parameter   vfp_lines              = 4,            // number of VFP lines, see MIPI DSI spec v1.1 figure 30
   parameter   trail_glitch_enable    = 0,            // used to enable/disable transmission of glitches at the end of trail 
   parameter   trail_glitch_interval  = 1000,         // interval in ps, for the trail glitches 
   parameter   frame_gap              = 100000,       // interval in ps, for the trail glitches 
   parameter   debug_on               = 0,            // for enabling/disabling DPHY data debug messages
   parameter   passthrough_en         = "OFF",
   parameter   tlast_mode             = "PER_TXN", // "PER_TXN" | "PER_LPPKT" - MBSI expected TLAST behavior
   parameter   vc_alternate           = "OFF",     // "ON" = alternate VC per HS transaction for MBSI TUSER-alignment checking (VCX stays 0: disabled for DSI2; EoTP fixed VC=0)
   parameter   uvsi_en                = "OFF",
   parameter   BYTES_IN_PARALLEL      = 4
)(
   input  wire resetn,
   inout  clk_p_io,
   inout  clk_n_io,
   inout [3:0] d_p_io,
   inout [3:0] d_n_io,
   output wire  dsi_valid_o
);

localparam eotp_enable  = (EOTP == "ON") ? 1 : 0;
localparam vact_payload = (video_data_type == 6'h3E) ? num_pixels*3 :
                        /*(video_data_type == 6'h0E) ? num_pixels*2 :*/
						                               num_pixels*2;

reg clk_p_i;
reg clk_n_i;
reg clk_weak;
reg [3:0] d_p_i;
reg [3:0] d_n_i;
reg d_weak;

generate if (sim_weak == "ON") begin
   assign (pull0, pull1) clk_p_io = clk_p_i;
   assign (pull0, pull1) clk_n_io = clk_n_i;
   assign (pull0, pull1) d_p_io[0] = d_p_i[0];
   assign (pull0, pull1) d_n_io[0] = d_n_i[0];
   assign (pull0, pull1) d_p_io[1] = d_p_i[1];
   assign (pull0, pull1) d_n_io[1] = d_n_i[1];
   assign (pull0, pull1) d_p_io[2] = d_p_i[2];
   assign (pull0, pull1) d_n_io[2] = d_n_i[2];
   assign (pull0, pull1) d_p_io[3] = d_p_i[3];
   assign (pull0, pull1) d_n_io[3] = d_n_i[3];
   assign clk_p_io = (~clk_weak) ? clk_p_i : 1'bz;
   assign clk_n_io = (~clk_weak) ? clk_n_i : 1'bz;
   assign d_p_io = (~d_weak) ? d_p_i : 4'bzzzz;
   assign d_n_io = (~d_weak) ? d_n_i : 4'bzzzz;
end else begin
   assign clk_p_io = clk_p_i;
   assign clk_n_io = clk_n_i;
   assign d_p_io = d_p_i;
   assign d_n_io = d_n_i;
end
endgenerate

parameter short_pkt_byte = 4; //4 bytes
parameter hsa_byte = short_pkt_byte + hsa_payload + 2*(short_pkt_byte); // 4 byte DI, 8 byte checksum 
parameter hsa_total_byte = hsa_byte + ((vsa_lines-1)*hsa_byte) + hsa_byte + (vbp_lines*(hsa_byte)) + (num_lines*hsa_byte) + ((vfp_lines-1)*hsa_byte);
parameter hstart_total_byte = ((vsa_lines-1)*short_pkt_byte) + (vbp_lines*short_pkt_byte) + (num_lines*short_pkt_byte) + ((vfp_lines-1)*short_pkt_byte);
parameter hend_total_byte = ((vsa_lines-1)*short_pkt_byte) + short_pkt_byte + (vbp_lines*short_pkt_byte) + short_pkt_byte + (num_lines*short_pkt_byte) + ((vfp_lines-1)*short_pkt_byte);
parameter bllp_byte = short_pkt_byte + bllp_payload + 2*(short_pkt_byte); //4 byte DI, 8 byte checksum
parameter bllp_total_byte = (BURST_MODE == "ON")? ((vsa_lines-1)*bllp_byte) + bllp_byte + (vbp_lines*(bllp_byte)) + bllp_byte + ((vfp_lines-1)*bllp_byte) + (num_lines*bllp_byte) : 
                                                  ((vsa_lines-1)*bllp_byte) + bllp_byte + (vbp_lines*(bllp_byte)) + bllp_byte + ((vfp_lines-1)*bllp_byte) + (num_lines*bllp_byte);

parameter vstart_total_byte = short_pkt_byte;
parameter vend_total_byte = short_pkt_byte;
parameter hbp_byte = short_pkt_byte + hbp_payload + 2*(short_pkt_byte); // 4 byte DI, 8 byte checksum 
parameter hbp_total_byte = hbp_byte + ((num_lines-1)*hbp_byte);
parameter hfp_byte = short_pkt_byte + hfp_payload + 2*(short_pkt_byte); // 4 byte DI, 8 byte checksum 
parameter hfp_total_byte = num_lines*hfp_byte;
parameter eotp_total_byte = short_pkt_byte;
parameter vact_byte = short_pkt_byte + vact_payload + 2*(short_pkt_byte);
parameter vact_total_byte = num_lines*vact_byte;

parameter frame_total_byte = (BURST_MODE ==   "OFF" && EOTP ==  "ON")?  hstart_total_byte + bllp_total_byte + vstart_total_byte + hbp_total_byte + hfp_total_byte + vact_total_byte                                                                       : 
                             (BURST_MODE ==   "OFF" && EOTP == "OFF")?  hstart_total_byte + bllp_total_byte + vstart_total_byte + hbp_total_byte + hfp_total_byte + eotp_total_byte + vact_total_byte                                                     : 
                             (BURST_MODE ==   "ON"  && EOTP ==  "ON")?  hstart_total_byte + bllp_total_byte + vstart_total_byte + hbp_total_byte + hfp_total_byte + vact_total_byte                                                                       : 
                             (BURST_MODE ==   "OFF" && EOTP == "OFF")?  hstart_total_byte + bllp_total_byte + vstart_total_byte + hbp_total_byte + hfp_total_byte + eotp_total_byte + vact_total_byte                                                     : 
                             (BURST_MODE == "ONOFF" && EOTP ==  "ON")?  hsa_total_byte + hstart_total_byte + hend_total_byte + bllp_total_byte + vstart_total_byte + vend_total_byte + hbp_total_byte + hfp_total_byte + vact_total_byte                  : 
                             (BURST_MODE == "ONOFF" && EOTP == "OFF")?  hsa_total_byte + hstart_total_byte + hend_total_byte + bllp_total_byte + vstart_total_byte + vend_total_byte + hbp_total_byte + hfp_total_byte + eotp_total_byte + vact_total_byte: 1; 


reg dphy_active;
reg [7:0] hsync_start [3:0];
reg [7:0] hsync_end [3:0];
reg [7:0] vsync_start [3:0];
reg [7:0] vsync_end [3:0];
reg [7:0] eotp_packet [3:0];

reg [15:0] line_counter0_r;
reg [15:0] line_counter1_r;
reg [15:0] line_counter2_r;
reg [15:0] line_counter3_r;
reg [ 1:0] odd_depth;
reg        validator_r;
reg [8:0] dphy_frame [frame_total_byte-1:0];
reg [5:0] pt_meta [frame_total_byte-1:0]; // {sof, tlast, vc[1:0], vcx[1:0]}
reg       pt_eotp [frame_total_byte-1:0]; // 1 = EoTP short-packet byte (MBSI VC/VCX gating)
reg sof_pending_dsi;
initial sof_pending_dsi = 0;
// VC alternation counter (used only when vc_alternate=="ON"): advances once per HS transaction
// (at frame_idx==0) so all data/sync packets in a burst share one VC and consecutive bursts
// differ - spec-typical for DSI. EoTP stays fixed VC=0. Free-running across the stimulus.
reg [1:0] vc_alt_cnt;
initial vc_alt_cnt = 2'd0;
reg [7:0] alt_ecc_dsi;   // scratch for recomputed short-packet ECC when alternating

integer count, frame_total_bits;
integer num_lanes;
integer i, j, k, n, start_pos;
integer dp_extra_pads, dp_pad_j;
integer beat_j, beat_k;
reg     beat_has_tlast;

reg [7:0] short_pkt [0:3];
assign dsi_valid_o  = validator_r;
integer f;
initial f = $fopen("tb_expected_data.txt","w");
integer f_mask;
initial f_mask = (passthrough_en == "ON") ? $fopen("tb_expected_mask.txt","w") : 0;

integer blanking_wc, blanking_counter, pixel_wc;
reg [7:0] blanking_di, ecc, blanking_data;
reg [8:0] pixel_data, data0, data1, data2, data3;

reg trail0, trail1, trail2, trail3, trail0_ongoing, trail1_ongoing, trail2_ongoing, trail3_ongoing, trail0_end, trail1_end, trail2_end, trail3_end;
reg clk_en;
reg [15:0] cur_crc, chksum;
reg dphy_clk_start;

integer frame_num, frame_idx, frame_idx_e;
integer trail_glitch_count, g0, g1, g2, g3;
reg glitch_val0, glitch_val1, glitch_val2, glitch_val3;

reg [7:0] data_h [$]; // data holder

initial begin
   frame_total_bits = frame_total_byte*8;
   dphy_active = 0;
   clk_p_i = 0;
   clk_n_i = 1;
   d_p_i[0] = 0;
   d_n_i[0] = 1;
   d_p_i[1] = 0;
   d_n_i[1] = 1;
   d_p_i[2] = 0;
   d_n_i[2] = 1;
   d_p_i[3] = 0;
   d_n_i[3] = 1;
   dphy_clk_start = 0;
   data0 = 0;
   data1 = 0;
   data2 = 0;
   data3 = 0;
   clk_weak = 0;
   d_weak = 0;

   @(posedge resetn);
   $display("%0t After reset, start driving LP-11\n",$realtime);
   #181007;
   clk_weak = 1;
   d_weak = 1;
   drive_clk_LP(1,1);
   drive_data_LP(1,1);
   #t_init; //T-INIT requirement
   if(!dphy_active) begin
      $display("%0t Waiting for dphy active...\n",$realtime);
      @(posedge dphy_active);
      $display("%0t dphy active ASSERTED...\n",$realtime);
   end
   
   if (CLK_MODE == "HS_ONLY") begin//start driving DPHY clock
      drive_hs_clk_req;
      dphy_clk_start = 1;
	  if (send_cal == "ON") begin
	      $display("%0t Skew Calibration Started...\n",$realtime);
		  drive_skewcal;
	      $display("%0t Skew Calibration Completed.\n",$realtime);
		  #frame_gap;
	  end
	  if (send_alt_cal == "ON") begin
	      $display("%0t Alternate Skew Calibration Started...\n",$realtime);
		  drive_altcal;
	      $display("%0t Alternate Skew Calibration Completed.\n",$realtime);
		  #frame_gap;
	  end
      for(frame_num=0; frame_num<num_frames;frame_num=frame_num+1) begin
         $display("%0t FRAME #%0d started...\n",$realtime,frame_num+1);
         frame_idx = 0;
         
         if (LP_BLANKING == "ON") begin
          if (BURST_MODE == "OFF") begin
            drive_hs_lp_sync_evt_or_burst_mode;
          end
          else if (BURST_MODE == "ON") begin
            drive_hs_lp_sync_evt_or_burst_mode;
          end
          else if (BURST_MODE == "ONOFF") begin
            drive_hs_lp_sync_pulse;
          end
        end
        else if (LP_BLANKING == "OFF") begin
          drive_hs_only;
        end
        
         #frame_gap;
         $display("%0t FRAME #%0d ended...\n",$realtime,frame_num+1);
      end
    end
    else if (CLK_MODE == "HS_LP") begin 
	  if (send_cal == "ON") begin
	      $display("%0t Skew Calibration Started...\n",$realtime);
		  drive_skewcal;
	      $display("%0t Skew Calibration Completed.\n",$realtime);
		  #frame_gap;
	  end
	  if (send_alt_cal == "ON") begin
	      $display("%0t Alternate Skew Calibration Started...\n",$realtime);
		  drive_altcal;
	      $display("%0t Alternate Skew Calibration Completed.\n",$realtime);
		  #frame_gap;
	  end
      for(frame_num=0; frame_num<num_frames;frame_num=frame_num+1) begin
         $display("%0t FRAME #%0d started...\n",$realtime,frame_num+1);
         frame_idx = 0;
         if (LP_BLANKING == "ON") begin
          if (BURST_MODE == "OFF") begin
            drive_hs_lp_sync_evt_or_burst_mode;
          end
          else if (BURST_MODE == "ON") begin
            drive_hs_lp_sync_evt_or_burst_mode;
          end
          else if (BURST_MODE == "ONOFF") begin
            drive_hs_lp_sync_pulse;
          end
        end
        else if (LP_BLANKING == "OFF") begin
          drive_hs_only;
        end
         #frame_gap;
         $display("%0t FRAME #%0d ended...\n",$realtime,frame_num+1);
      end
    end
   $fclose(f);
   if (passthrough_en == "ON") $fclose(f_mask);
   #10;
   dphy_active = 0;
end

generate
  if (CLK_MODE == "HS_ONLY") begin 
    initial begin
      @(posedge dphy_clk_start);
      forever begin
          clk_p_i =~ clk_p_i;
          clk_n_i =~ clk_n_i;
          #(dphy_clk_period/2);
      end
    end
  end
endgenerate

initial begin
clk_en = 0;
trail0_end = 0;
trail1_end = 0;
trail2_end = 0;
trail3_end = 0;
blanking_di = 8'h19;
hsync_start [0] = 8'h21;
hsync_start [1] = 8'h00;
hsync_start [2] = 8'h00;
hsync_start [3] = 8'h12;
hsync_end [0] = 8'h31;
hsync_end [1] = 8'h00;
hsync_end [2] = 8'h00;
hsync_end [3] = 8'h01;
vsync_start [0] = 8'h01;
vsync_start [1] = 8'h00;
vsync_start [2] = 8'h00;
vsync_start [3] = 8'h07;
vsync_end [0] = 8'h11;
vsync_end [1] = 8'h00;
vsync_end [2] = 8'h00;
vsync_end [3] = 8'h14;
eotp_packet [0] = 8'h08;
eotp_packet [1] = 8'h0F;
eotp_packet [2] = 8'h0F;
eotp_packet [3] = 8'h01;
end

task drive_clk_LP(input p, input n);
begin
   clk_p_i = p;
   clk_n_i = n;
end
endtask

task drive_data_LP(input p, input n);
begin
   d_p_i[0] = p;
   d_n_i[0] = n;
   if(dphy_num_lane >= 2) begin
      d_p_i[1] = p;
      d_n_i[1] = n;
   end
   if(dphy_num_lane >= 3) begin
      d_p_i[2] = p;
      d_n_i[2] = n;
   end
   if(dphy_num_lane >= 4) begin
      d_p_i[3] = p;
      d_n_i[3] = n;
   end
end
endtask

task drive_hs_clk_req();
begin
   clk_weak = 1;
   drive_clk_LP(0,1);
   #t_lpx;
   clk_weak = 1;
   drive_clk_LP(0,0);
   #t_clk_prepare;
   clk_weak = 0;
   drive_clk_LP(0,1);
   #t_clk_zero;
end
endtask

task drive_hs_data_req();
begin
   d_weak = 1;
   drive_data_LP(0,1);
   #t_lpx;
   d_weak = 1;
   drive_data_LP(0,0);
   #t_hs_prepare;
   d_weak = 0;
   drive_data_LP(0,1);
   #t_hs_zero;
end
endtask

task drive_data_lane0(input dp);
begin
   d_p_i[0] = dp;
   d_n_i[0] =~ dp;
end
endtask

task drive_data_lane1(input dp);
begin
   d_p_i[1] = dp;
   d_n_i[1] =~ dp;
end
endtask

task drive_data_lane2(input dp);
begin
   d_p_i[2] = dp;
   d_n_i[2] =~ dp;
end
endtask

task drive_data_lane3(input dp);
begin
   d_p_i[3] = dp;
   d_n_i[3] =~ dp;
end
endtask

task drive_sot();
begin
   $display("%0t SoT started...\n",$realtime);
   @(posedge clk_p_i);
   #(dphy_clk_period/4);
   drive_data_LP(1,0);
   @(posedge clk_p_i);
   @(negedge clk_p_i);
   #(dphy_clk_period/4); 
   drive_data_LP(0,1);
   @(posedge clk_p_i);
   #(dphy_clk_period/4); 
   drive_data_LP(1,0);
   @(negedge clk_p_i);
   #(dphy_clk_period/4); 
   $display("%0t SoT ended...\n",$realtime);
end
endtask

task gen_short_packet(input [7:0] pkt_type);
begin
   reg [1:0] pt_vc;
   reg [1:0] pt_vcx;
   // MBSI VC alternation (per HS transaction): rewrite this packet's DI (VC field) and recompute
   // its ECC. The VC advances once per burst (frame_idx==0) so all data/sync packets in one HS
   // transaction share a single VC - spec-typical for DSI. EoTP (0x08) is excluded so it stays
   // fixed VC=0 and the DUT's exact-pattern detect (0x0F0F08) still matches. VCX stays 0 (disabled
   // for DSI2): get_ecc is 6-bit so recomputed ECC[7:6]=0 -> pt_vcx=0.
   if (vc_alternate == "ON" && pkt_type != 8'h08) begin
      if (frame_idx == 0) vc_alt_cnt = vc_alt_cnt + 2'd1;   // new VC at each HS-transaction start
      alt_ecc_dsi = 8'h00;
      case (pkt_type)
         8'h01 : begin vsync_start[0] = {vc_alt_cnt, pkt_type[5:0]}; get_ecc({vsync_start[2], vsync_start[1], vsync_start[0]}, alt_ecc_dsi); vsync_start[3] = alt_ecc_dsi; end
         8'h11 : begin vsync_end[0]   = {vc_alt_cnt, pkt_type[5:0]}; get_ecc({vsync_end[2],   vsync_end[1],   vsync_end[0]},   alt_ecc_dsi); vsync_end[3]   = alt_ecc_dsi; end
         8'h21 : begin hsync_start[0] = {vc_alt_cnt, pkt_type[5:0]}; get_ecc({hsync_start[2], hsync_start[1], hsync_start[0]}, alt_ecc_dsi); hsync_start[3] = alt_ecc_dsi; end
         8'h31 : begin hsync_end[0]   = {vc_alt_cnt, pkt_type[5:0]}; get_ecc({hsync_end[2],   hsync_end[1],   hsync_end[0]},   alt_ecc_dsi); hsync_end[3]   = alt_ecc_dsi; end
      endcase
   end
   // All short packets: sof=0, tlast=0 per DUT behavior
   case(pkt_type)
      8'h01 :  begin
         pt_vc  = vsync_start[0][7:6];
         pt_vcx = vsync_start[3][7:6];
         for(k=0; k < 4; k=k+1) begin
            dphy_frame[frame_idx] = vsync_start[k];
            pt_meta[frame_idx] = {1'b0, 1'b0, pt_vc, pt_vcx};
            pt_eotp[frame_idx] = 1'b0;
            frame_idx=frame_idx+1;
         end
         // VSS is the frame start — mark that the next long packet should assert SOF
         if (passthrough_en == "ON") sof_pending_dsi = 1;
      end
      8'h08 :  begin
         pt_vc  = eotp_packet[0][7:6];
         pt_vcx = eotp_packet[3][7:6];
         for(k=0; k < 4; k=k+1) begin
            dphy_frame[frame_idx] = eotp_packet[k];
            pt_meta[frame_idx] = {1'b0, 1'b0, pt_vc, pt_vcx};
            pt_eotp[frame_idx] = 1'b1;
            frame_idx=frame_idx+1;
         end
      end
      8'h11 : begin
         pt_vc  = vsync_end[0][7:6];
         pt_vcx = vsync_end[3][7:6];
         for(k=0; k < 4; k=k+1) begin
            dphy_frame[frame_idx] = vsync_end[k];
            pt_meta[frame_idx] = {1'b0, 1'b0, pt_vc, pt_vcx};
            pt_eotp[frame_idx] = 1'b0;
            frame_idx=frame_idx+1;
         end
      end
      8'h21 :  begin
         pt_vc  = hsync_start[0][7:6];
         pt_vcx = hsync_start[3][7:6];
         for(k=0; k < 4; k=k+1) begin
            dphy_frame[frame_idx] = hsync_start[k];
            pt_meta[frame_idx] = {1'b0, 1'b0, pt_vc, pt_vcx};
            pt_eotp[frame_idx] = 1'b0;
            frame_idx=frame_idx+1;
         end
      end
      8'h31 :  begin
         pt_vc  = hsync_end[0][7:6];
         pt_vcx = hsync_end[3][7:6];
         for(k=0; k < 4; k=k+1) begin
            dphy_frame[frame_idx] = hsync_end[k];
            pt_meta[frame_idx] = {1'b0, 1'b0, pt_vc, pt_vcx};
            pt_eotp[frame_idx] = 1'b0;
            frame_idx=frame_idx+1;
         end
      end
   endcase
end      
endtask

task drive_hs_only();
begin
  
  if (BURST_MODE == "OFF") begin
    drive_non_burst_sync_events;
  end
  else if (BURST_MODE == "ON") begin
    drive_burst_mode;
  end
  else if (BURST_MODE == "ONOFF") begin
    drive_non_burst_sync_pulse;
  end
  
  if (CLK_MODE == "HS_ONLY") begin
      #t_clk_pre;
      drive_hs_data_req;
      drive_sot;
      drive_dphy_packet;
      drive_hs_trail;
  end
  else if (CLK_MODE == "HS_LP") begin
    fork
      begin
         drive_hs_lp_clk;
      end
      begin
         @(posedge clk_en);
         #t_clk_pre;
         drive_hs_data_req;
         drive_sot;
         drive_dphy_packet;
         drive_hs_trail;
      end
    join
  end
end
endtask

task drive_non_burst_sync_pulse();
begin
   gen_short_packet(8'h01);
   gen_blanking_packet(hsa_payload);
   repeat(vsa_lines-1) begin
      gen_short_packet(8'h31);
      gen_blanking_packet(bllp_payload);
      gen_short_packet(8'h21);
      gen_blanking_packet(hsa_payload);
   end
   gen_short_packet(8'h31);
   gen_blanking_packet(bllp_payload);
   gen_short_packet(8'h11);
   gen_blanking_packet(hsa_payload);

   repeat(vbp_lines) begin
      gen_short_packet(8'h31);
      gen_blanking_packet(bllp_payload);
      gen_short_packet(8'h21);
      gen_blanking_packet(hsa_payload);
   end

   gen_short_packet(8'h31);
   gen_blanking_packet(hbp_payload);

   $display("%0t Total number of bytes of active pixels per line = %0d\n",$realtime,vact_payload);
   $display("%0t Total number of active lines = %0d\n",$realtime,num_lines);
   for(j=0; j < num_lines; j=j+1) begin
      if(debug_on)
         $display("Generate data for line %0d\n",j);
      gen_active_line;
      gen_blanking_packet(hfp_payload);
      gen_short_packet(8'h21);
      gen_blanking_packet(hsa_payload);
      gen_short_packet(8'h31);
      if(j == num_lines-1) begin
         gen_blanking_packet(bllp_payload);
      end
      else begin
         gen_blanking_packet(hbp_payload);
      end
   end
   repeat(vfp_lines-1) begin
      gen_short_packet(8'h21);
      gen_blanking_packet(hsa_payload);
      gen_short_packet(8'h31);
      gen_blanking_packet(bllp_payload);
   end
   if(eotp_enable) 
      gen_short_packet(8'h08);
end
endtask

task drive_non_burst_sync_events();
begin
   gen_short_packet(8'h01);
   repeat(vsa_lines-1) begin
      gen_blanking_packet(bllp_payload);
      gen_short_packet(8'h21);
   end
   gen_blanking_packet(bllp_payload);
   gen_short_packet(8'h21);

   repeat(vbp_lines) begin
      gen_blanking_packet(bllp_payload);
      gen_short_packet(8'h21);
   end

   gen_blanking_packet(hbp_payload);

   $display("%0t Total number of bytes of active pixels per line = %0d\n",$realtime,vact_payload);
   $display("%0t Total number of active lines = %0d\n",$realtime,num_lines);
   for(j=0; j < num_lines; j=j+1) begin
      if(debug_on)
         $display("Generate data for line %0d\n",j);
      gen_active_line;
      gen_blanking_packet(hfp_payload);
      gen_short_packet(8'h21);
      if(j == num_lines-1) begin
         gen_blanking_packet(bllp_payload);
      end
      else begin
         gen_blanking_packet(hbp_payload);
      end
   end
   repeat(vfp_lines-1) begin
      gen_short_packet(8'h21);
      gen_blanking_packet(bllp_payload);
   end
   if(eotp_enable) 
      gen_short_packet(8'h08);
end
endtask

task drive_hs_lp_clk();
begin
   drive_hs_clk_req;
   clk_en = 1;
   while (clk_en) begin
      clk_p_i = ~clk_p_i;
      clk_n_i = ~clk_n_i;
      #(dphy_clk_period/2);
   end

   // Trail HS-0
   clk_p_i = 0;
   clk_n_i = 1;
   #t_clk_trail;
   
   clk_weak = 1;
   // Clk-Stop
   clk_p_i = 1;
   clk_n_i = 1;
end
endtask

task drive_burst_mode();
begin
   gen_short_packet(8'h01);
   repeat(vsa_lines-1) begin
      gen_blanking_packet(bllp_payload);
      gen_short_packet(8'h21);
   end
   gen_blanking_packet(bllp_payload);
   gen_short_packet(8'h21);

   repeat(vbp_lines) begin
      gen_blanking_packet(bllp_payload);
      gen_short_packet(8'h21);
   end

   gen_blanking_packet(hbp_payload);

   $display("%0t Total number of bytes of active pixels per line = %0d\n",$realtime,vact_payload);
   $display("%0t Total number of active lines = %0d\n",$realtime,num_lines);
   for(j=0; j < num_lines; j=j+1) begin
      if(debug_on)
         $display("Generate data for line %0d\n",j);
      gen_active_line;
      gen_blanking_packet(bllp_payload);
      gen_blanking_packet(hfp_payload);
      gen_short_packet(8'h21);
      if(j == num_lines-1) begin
         gen_blanking_packet(bllp_payload);
      end
      else begin
         gen_blanking_packet(hbp_payload);
      end
   end
   repeat(vfp_lines-1) begin
      gen_short_packet(8'h21);
      gen_blanking_packet(bllp_payload);
   end
   if(eotp_enable) 
      gen_short_packet(8'h08);
end
endtask

// Emit whatever is currently accumulated in dphy_frame[]/pt_meta[] (0 .. frame_idx-1)
// as ONE HS burst: HS clock request (HS_LP mode) + data HS request + SoT +
// packet stream + trail. Factored out of drive_hs_lp_sync / drive_hs_lp_sync_pulse /
// drive_hs_lp_sync_evt_or_burst_mode so all callers share one burst implementation.
task emit_hs_burst();
begin
   fork
      begin
        if (CLK_MODE == "HS_LP") begin
           drive_hs_lp_clk;
        end
      end
      begin
        if (CLK_MODE == "HS_LP") begin
          @(posedge clk_en);
        end
         #t_clk_pre;
         drive_hs_data_req;
         drive_sot;
         drive_dphy_packet;
         drive_hs_trail;
      end
   join
end
endtask

// Append an EoTP short packet to the current buffer when EoTP is enabled.
// Single point of EoTP insertion so it is consistently parameter-driven and
// appended as the terminating packet of every HS burst (both modes).
task maybe_append_eotp();
begin
   if (eotp_enable)
      gen_short_packet(8'h08);
end
endtask

// SINGLE_PKT commit: terminate the current one-packet buffer with an optional
// EoTP, transmit it as its own HS transaction, drop to LP-11 for lp_gap, then
// reset the buffer for the next packet.
task commit_single_pkt(input integer lp_gap);
begin
   maybe_append_eotp;
   emit_hs_burst;
   #lp_gap;
   frame_idx = 0;
end
endtask

task drive_hs_lp_sync(input [7:0] pkt);
begin
   frame_idx = 0;
   if (HS_TXN_MODE == "SINGLE_PKT") begin
      // Each packet of this blanking line is its own HS transaction.
      case(pkt)
        8'h01 : gen_short_packet(8'h01);
        8'h11 : gen_short_packet(8'h11);
        8'h21 : gen_short_packet(8'h21);
      endcase
      commit_single_pkt(lps_pkt_gap);
      if (BURST_MODE == "ONOFF") begin
         gen_blanking_packet(hsa_payload);
         commit_single_pkt(lps_pkt_gap);
         gen_short_packet(8'h31);
         commit_single_pkt(lps_pkt_gap);
      end
   end
   else begin
      // MULTI_PKT (legacy): sync short + (ONOFF) HSA long + HSE short + optional
      // EoTP, all sent in one HS burst. gen_* only fill the buffer (no time
      // delays), so accumulating before emit_hs_burst is behavior-identical.
      case(pkt)
        8'h01 : gen_short_packet(8'h01);
        8'h11 : gen_short_packet(8'h11);
        8'h21 : gen_short_packet(8'h21);
      endcase

      if (BURST_MODE == "OFF") begin
      end else
      if (BURST_MODE == "ON") begin
      end else
      if (BURST_MODE == "ONOFF") begin
        gen_blanking_packet(hsa_payload);
        gen_short_packet(8'h31);
      end

      maybe_append_eotp;
      emit_hs_burst;
   end
end
endtask

task drive_hs_lp_sync_pulse();
begin
   drive_hs_lp_sync(8'h01);
   #lps_bllp_duration;
   repeat(vsa_lines-1) begin
      drive_hs_lp_sync(8'h21);
      #lps_bllp_duration;
   end
   drive_hs_lp_sync(8'h11);
   #lps_bllp_duration;

   repeat(vbp_lines-1) begin
      drive_hs_lp_sync(8'h21);
      #lps_bllp_duration;
   end

   $display("%0t Total number of bytes of active pixels per line = %0d\n",$realtime,vact_payload);
   $display("%0t Total number of active lines = %0d\n",$realtime,num_lines);
   frame_idx = 0;
   if (HS_TXN_MODE == "SINGLE_PKT") begin
      // Each content packet is its own HS transaction. commit_single_pkt
      // appends the optional EoTP, transmits the burst, drops to LP for
      // lps_pkt_gap, and resets the buffer.
      gen_short_packet(8'h21);     commit_single_pkt(lps_pkt_gap); // HSS
      gen_blanking_packet(hsa_payload); commit_single_pkt(lps_pkt_gap); // HSA
      gen_short_packet(8'h31);     commit_single_pkt(lps_pkt_gap); // HSE
      gen_blanking_packet(hbp_payload); commit_single_pkt(lps_pkt_gap); // HBP
      for(j=0; j < num_lines; j=j+1) begin
         if(debug_on)
            $display("Generate data for line %0d\n",j);
         gen_active_line;             commit_single_pkt(lps_pkt_gap);
         gen_blanking_packet(hfp_payload); commit_single_pkt(lps_pkt_gap); // HFP
         gen_short_packet(8'h21);     commit_single_pkt(lps_pkt_gap); // HSS
         gen_blanking_packet(hsa_payload); commit_single_pkt(lps_pkt_gap); // HSA
         gen_short_packet(8'h31);     commit_single_pkt(lps_pkt_gap); // HSE
         if(j != num_lines-1) begin
            gen_blanking_packet(hbp_payload); commit_single_pkt(lps_pkt_gap); // HBP
         end
      end
   end
   else begin
      // MULTI_PKT (legacy): accumulate the whole active region into one buffer
      // and transmit it as a single continuous HS burst. gen_* only fill the
      // buffer (no time delays), so pre-accumulation is behavior-identical.
      gen_short_packet(8'h21);
      gen_blanking_packet(hsa_payload);
      gen_short_packet(8'h31);
      gen_blanking_packet(hbp_payload);
      for(j=0; j < num_lines; j=j+1) begin
         if(debug_on)
            $display("Generate data for line %0d\n",j);
         gen_active_line;
         gen_blanking_packet(hfp_payload);
         gen_short_packet(8'h21);
         gen_blanking_packet(hsa_payload);
         gen_short_packet(8'h31);
         if(j == num_lines-1) begin
            // frame-end: terminate active burst with EoTP when enabled
            maybe_append_eotp;
         end
         else begin
            gen_blanking_packet(hbp_payload);
         end
      end
      //drive active lines
      emit_hs_burst;
   end
   #lps_bllp_duration;

   repeat(vfp_lines-1) begin
      drive_hs_lp_sync(8'h21);
      #lps_bllp_duration;
   end
end
endtask


task drive_hs_lp_sync_evt_or_burst_mode();
begin
   drive_hs_lp_sync(8'h01);
   #lps_bllp_duration;
   repeat(vsa_lines-1) begin
      drive_hs_lp_sync(8'h21);
      #lps_bllp_duration;
   end
    
    if (BURST_MODE == "OFF") begin
      drive_hs_lp_sync(8'h21);
    end else 
    if (BURST_MODE == "ON") begin
      drive_hs_lp_sync(8'h21);
    end else
    if (BURST_MODE == "ONOFF") begin
      drive_hs_lp_sync(8'h11);
    end
   
   #lps_bllp_duration;

   repeat(vbp_lines-1) begin
      drive_hs_lp_sync(8'h21);
      #lps_bllp_duration;
   end

   $display("%0t Total number of bytes of active pixels per line = %0d\n",$realtime,vact_payload);
   $display("%0t Total number of active lines = %0d\n",$realtime,num_lines);

   drive_hs_lp_sync(8'h21);

   #lps_hbp_duration;

   for(j=0; j < num_lines; j=j+1) begin
      if(debug_on)
         $display("Generate data for line %0d\n",j);
      frame_idx = 0;
      gen_active_line;
      // SINGLE_PKT: terminate this active-line HS transaction with EoTP when
      // enabled. MULTI_PKT keeps the original behavior (no per-line EoTP here).
      if (HS_TXN_MODE == "SINGLE_PKT")
         maybe_append_eotp;
      //drive active lines
      emit_hs_burst;

      #lps_hfp_duration;
      
      drive_hs_lp_sync(8'h21);
      if(j == num_lines-1) begin
         #lps_bllp_duration;
      end
      else begin
         #lps_hbp_duration;
      end
   end
   
   repeat(vfp_lines-1) begin
      drive_hs_lp_sync(8'h21);
      #lps_bllp_duration;
   end
end
endtask

task get_ecc (input [23:0] d, output [5:0] ecc_val);
begin
  ecc_val[0] = d[0]^d[1]^d[2]^d[4]^d[5]^d[7]^d[10]^d[11]^d[13]^d[16]^d[20]^d[21]^d[22]^d[23];
  ecc_val[1] = d[0]^d[1]^d[3]^d[4]^d[6]^d[8]^d[10]^d[12]^d[14]^d[17]^d[20]^d[21]^d[22]^d[23];
  ecc_val[2] = d[0]^d[2]^d[3]^d[5]^d[6]^d[9]^d[11]^d[12]^d[15]^d[18]^d[20]^d[21]^d[22];
  ecc_val[3] = d[1]^d[2]^d[3]^d[7]^d[8]^d[9]^d[13]^d[14]^d[15]^d[19]^d[20]^d[21]^d[23];
  ecc_val[4] = d[4]^d[5]^d[6]^d[7]^d[8]^d[9]^d[16]^d[17]^d[18]^d[19]^d[20]^d[22]^d[23];
  ecc_val[5] = d[10]^d[11]^d[12]^d[13]^d[14]^d[15]^d[16]^d[17]^d[18]^d[19]^d[21]^d[22]^d[23];
end
endtask

task compute_crc16(input [7:0] data_tmp);
begin
   for (n = 0; n < 8; n = n + 1) begin
     cur_crc = chksum;
     cur_crc[15] = data_tmp[n]^cur_crc[0];
     cur_crc[10] = cur_crc[11]^cur_crc[15];
     cur_crc[3]  = cur_crc[4]^cur_crc[15]; 
     chksum = chksum >> 1;
     chksum[15] = cur_crc[15];
     chksum[10] = cur_crc[10];
     chksum[3] = cur_crc[3];
   end
end
endtask

task gen_blanking_packet(input [31:0] blanking_payload);
begin
   reg [1:0] pt_vc;
   reg [1:0] pt_vcx;
   reg pt_sof;
   integer pkt_start_idx;
   integer total_pkt_bytes;
   integer last_beat_start;
   integer lb;

   blanking_data = 8'h55;
   blanking_wc = blanking_payload;
   blanking_counter = 0;
   ecc = 8'h00;

   // MBSI VC alternation (per HS transaction): set this blanking (long) packet's VC field
   // before the ECC compute. VC advances once per burst (frame_idx==0), so all packets in the
   // HS transaction share it. VCX stays 0.
   if (vc_alternate == "ON") begin
      if (frame_idx == 0) vc_alt_cnt = vc_alt_cnt + 2'd1;
      blanking_di[7:6] = vc_alt_cnt;
   end

   get_ecc({blanking_payload[15:8], blanking_payload[7:0], blanking_di},ecc);
   pt_vc  = blanking_di[7:6];
   pt_vcx = ecc[7:6];

   // Capture SOF for this long packet's header beat
   pt_sof = sof_pending_dsi;
   if (passthrough_en == "ON") sof_pending_dsi = 0;
   pkt_start_idx = frame_idx;

   // Header (4 bytes — all in same beat, share sof)
   dphy_frame[frame_idx] = blanking_di;
   pt_meta[frame_idx] = {pt_sof, 1'b0, pt_vc, pt_vcx};
   pt_eotp[frame_idx] = 1'b0;
   frame_idx = frame_idx + 1;
   dphy_frame[frame_idx] = blanking_payload[7:0];
   pt_meta[frame_idx] = {pt_sof, 1'b0, pt_vc, pt_vcx};
   pt_eotp[frame_idx] = 1'b0;
   frame_idx = frame_idx + 1;
   dphy_frame[frame_idx] = blanking_payload[15:8];
   pt_meta[frame_idx] = {pt_sof, 1'b0, pt_vc, pt_vcx};
   pt_eotp[frame_idx] = 1'b0;
   frame_idx = frame_idx + 1;
   dphy_frame[frame_idx] = ecc;
   pt_meta[frame_idx] = {pt_sof, 1'b0, pt_vc, pt_vcx};
   pt_eotp[frame_idx] = 1'b0;
   frame_idx = frame_idx + 1;

   chksum = 16'hFFFF;
   for(i = 1; i < blanking_wc+1; i=i+1) begin
      dphy_frame[frame_idx] = blanking_data;
      pt_meta[frame_idx] = {1'b0, 1'b0, pt_vc, pt_vcx};
      pt_eotp[frame_idx] = 1'b0;
      frame_idx = frame_idx + 1;
      compute_crc16(blanking_data); 
      blanking_counter = blanking_counter + 1;
      if(blanking_counter == 256) begin
         blanking_data = blanking_data+1;
         blanking_counter = 0;
      end
   end
   
   // CRC (tlast set in post-processing below)
   dphy_frame[frame_idx] = chksum[7:0];
   pt_meta[frame_idx] = {1'b0, 1'b0, pt_vc, pt_vcx};
   pt_eotp[frame_idx] = 1'b0;
   frame_idx = frame_idx + 1;
   dphy_frame[frame_idx] = chksum[15:8];
   pt_meta[frame_idx] = {1'b0, 1'b0, pt_vc, pt_vcx};
   pt_eotp[frame_idx] = 1'b0;
   frame_idx = frame_idx + 1;

   // Mark all bytes in the last beat with tlast=1 (passthrough mode only)
   if (passthrough_en == "ON") begin
      last_beat_start = (frame_idx - 1) - ((frame_idx - 1) % BYTES_IN_PARALLEL);
      for (lb = last_beat_start; lb < frame_idx; lb = lb + 1)
         pt_meta[lb] = {pt_meta[lb][5], 1'b1, pt_meta[lb][3:2], pt_meta[lb][1:0]};
   end
end
endtask

task gen_active_line();
begin
    reg [1:0] pt_vc;
    reg [1:0] pt_vcx;
    reg pt_sof;
    integer pkt_start_idx;
    integer total_pkt_bytes;
    integer last_beat_start;
    integer lb;
    reg [1:0] eff_vc;

    // MBSI VC alternation (per HS transaction): pick this active-line packet's VC. VC advances
    // once per burst (frame_idx==0), so all packets in the HS transaction share it. Used in the
    // DI byte, the ECC input and pt_vc so transmit and expected stay consistent. VCX stays 0.
    if (vc_alternate == "ON" && frame_idx == 0) vc_alt_cnt = vc_alt_cnt + 2'd1;
    eff_vc = (vc_alternate == "ON") ? vc_alt_cnt : virtual_channel[1:0];

    ecc = 8'h00;
    get_ecc({vact_payload[15:8], vact_payload[7:0], eff_vc, video_data_type},ecc);
    pt_vc  = eff_vc;
    pt_vcx = ecc[7:6];

    // Capture SOF for this long packet's header beat
    pt_sof = sof_pending_dsi;
    if (passthrough_en == "ON") sof_pending_dsi = 0;
    pkt_start_idx = frame_idx;

    // Header (4 bytes — all in same beat, share sof)
    dphy_frame[frame_idx] = {eff_vc, video_data_type};
    pt_meta[frame_idx] = {pt_sof, 1'b0, pt_vc, pt_vcx};
    pt_eotp[frame_idx] = 1'b0;
    frame_idx = frame_idx + 1;
    dphy_frame[frame_idx] = vact_payload[7:0];  
    pt_meta[frame_idx] = {pt_sof, 1'b0, pt_vc, pt_vcx};
    pt_eotp[frame_idx] = 1'b0;
    frame_idx = frame_idx + 1;
    dphy_frame[frame_idx] = vact_payload[15:8];  
    pt_meta[frame_idx] = {pt_sof, 1'b0, pt_vc, pt_vcx};
    pt_eotp[frame_idx] = 1'b0;
    frame_idx = frame_idx + 1;
    dphy_frame[frame_idx] = ecc;  
    pt_meta[frame_idx] = {pt_sof, 1'b0, pt_vc, pt_vcx};
    pt_eotp[frame_idx] = 1'b0;
    frame_idx = frame_idx + 1;

    pixel_wc = vact_payload; 
    chksum = 16'hFFFF; 
    for(i = 0; i < pixel_wc; i=i+1) begin 
       pixel_data = $random;
       dphy_frame[frame_idx] = {1, pixel_data[7:0]};
       pt_meta[frame_idx] = {1'b0, 1'b0, pt_vc, pt_vcx};
       pt_eotp[frame_idx] = 1'b0;
       frame_idx = frame_idx + 1;
       compute_crc16(pixel_data); 
    end

    // CRC (tlast set in post-processing below)
    dphy_frame[frame_idx] = chksum[7:0];
    pt_meta[frame_idx] = {1'b0, 1'b0, pt_vc, pt_vcx};
    pt_eotp[frame_idx] = 1'b0;
    frame_idx = frame_idx + 1;
    dphy_frame[frame_idx] = chksum[15:8];
    pt_meta[frame_idx] = {1'b0, 1'b0, pt_vc, pt_vcx};
    pt_eotp[frame_idx] = 1'b0;
    frame_idx = frame_idx + 1;

    // Mark all bytes in the last beat with tlast=1 (passthrough mode only)
    if (passthrough_en == "ON") begin
       last_beat_start = (frame_idx - 1) - ((frame_idx - 1) % BYTES_IN_PARALLEL);
       for (lb = last_beat_start; lb < frame_idx; lb = lb + 1)
          pt_meta[lb] = {pt_meta[lb][5], 1'b1, pt_meta[lb][3:2], pt_meta[lb][1:0]};
    end
end
endtask

task drive_hs_trail();
begin
 trail_glitch_count = 35/trail_glitch_interval;
 fork
  begin
    if(trail0 == 0) 
      drive_hs_trail0; 
  end
  begin
    if(trail1 == 0 && dphy_num_lane >= 2) 
      drive_hs_trail1; 
  end
  begin
    if(trail2 == 0 && dphy_num_lane >= 3) 
      drive_hs_trail2; 
  end
  begin
    if(trail3 == 0 && dphy_num_lane >= 4) 
      drive_hs_trail3;
  end
 join 
end
endtask

task drive_hs_trail0();
begin
  if(!trail0_ongoing) begin
     $display("%0t HS trail data lane0 started...",$realtime);
     trail0_ongoing = 1;
     drive_data_lane0(~d_p_i[0]); 
     #t_hs_trail;
     if(trail_glitch_enable == 1) begin
        drive_trail_glitch0;
     end
     d_weak = 1;
     d_p_i[0] = 1;
     d_n_i[0] = 1;
     $display("%0t HS trail data lane0 ended...",$realtime);
     trail0_end = 1;
  end
end
endtask

task drive_hs_trail1();
begin
  if(!trail1_ongoing) begin
     $display("%0t HS trail data lane1 started...",$realtime);
     trail1_ongoing = 1;
     drive_data_lane1(~d_p_i[1]); 
     #t_hs_trail;
     if(trail_glitch_enable == 1) begin
        drive_trail_glitch1;
     end
     d_weak = 1;
     d_p_i[1] = 1;
     d_n_i[1] = 1;
     $display("%0t HS trail data lane1 ended...",$realtime);
     trail1_end = 1;
  end
end
endtask

task drive_hs_trail2();
begin
  if(!trail2_ongoing) begin
     $display("%0t HS trail data lane2 started...",$realtime);
     trail2_ongoing = 1;
     drive_data_lane2(~d_p_i[2]); 
     #t_hs_trail;
     if(trail_glitch_enable == 1) begin
        drive_trail_glitch2;
     end
     d_weak = 1;
     d_p_i[2] = 1;
     d_n_i[2] = 1;
     $display("%0t HS trail data lane2 ended...",$realtime);
     trail2_end = 1;
  end
end
endtask

task drive_hs_trail3();
begin
  if(!trail3_ongoing) begin
     $display("%0t HS trail data lane3 started...",$realtime);
     trail3_ongoing = 1;
     drive_data_lane3(~d_p_i[3]); 
     #t_hs_trail;
     if(trail_glitch_enable == 1) begin
        drive_trail_glitch3;
     end
     d_weak = 1;
     d_p_i[3] = 1;
     d_n_i[3] = 1;
     $display("%0t HS trail data lane3 ended...",$realtime);
     trail3_end = 1;
  end
end
endtask

task drive_trail_glitch0();
begin
   $display("%0t Driving Trail glitches for Data Lane 0 started...",$realtime);
   for(g0 = 0; g0 < trail_glitch_count; g0=g0+1) begin
      glitch_val0 = $random;
      d_p_i[0] = glitch_val0;
      d_n_i[0] = ~glitch_val0;
      #trail_glitch_interval;
   end  
   $display("%0t Driving Trail glitches for Data Lane 0 ended...",$realtime);
end
endtask

task drive_trail_glitch1();
begin
   $display("%0t Driving Trail glitches for Data Lane 1 started...",$realtime);
   for(g1 = 0; g1 < trail_glitch_count; g1=g1+1) begin
      glitch_val1 = $random;
      d_p_i[1] = glitch_val1;
      d_n_i[1] = ~glitch_val1;
      #trail_glitch_interval;
   end  
   $display("%0t Driving Trail glitches for Data Lane 1 ended...",$realtime);
end
endtask

task drive_trail_glitch2();
begin
   $display("%0t Driving Trail glitches for Data Lane 2 started...",$realtime);
   for(g2 = 0; g2 < trail_glitch_count; g2=g2+1) begin
      glitch_val2 = $random;
      d_p_i[2] = glitch_val2;
      d_n_i[2] = ~glitch_val2;
      #trail_glitch_interval;
   end  
   $display("%0t Driving Trail glitches for Data Lane 2 ended...",$realtime);
end
endtask

task drive_trail_glitch3();
begin
   $display("%0t Driving Trail glitches for Data Lane 3 started...",$realtime);
   for(g3 = 0; g3 < trail_glitch_count; g3=g3+1) begin
      glitch_val3 = $random;
      d_p_i[3] = glitch_val3;
      d_n_i[3] = ~glitch_val3;
      #trail_glitch_interval;
   end  
   $display("%0t Driving Trail glitches for Data Lane 3 ended...",$realtime);
end
endtask


task drive_dphy_packet();
begin
   trail0 = 0;
   trail1 = 0;
   trail2 = 0;
   trail3 = 0;
   validator_r    = 0; 
   trail0_ongoing = 0;
   trail1_ongoing = 0;
   trail2_ongoing = 0;
   trail3_ongoing = 0;
   line_counter0_r  = (vact_payload / dphy_num_lane) + |odd_depth;
   line_counter1_r  = (vact_payload / dphy_num_lane) +  odd_depth[1];
   line_counter2_r  = (vact_payload / dphy_num_lane) + &odd_depth;
   line_counter3_r  = (vact_payload / dphy_num_lane);
   odd_depth        = (vact_payload % dphy_num_lane);
   start_pos = 0;
   // ------------------------------------------------------------------
   // PER_TXN TLAST rule: TLAST asserts only ONCE per HS transaction. In
   // this model the whole frame is sent as a single continuous HS burst,
   // so TLAST must land only on the end-beat of the LAST packet of the
   // frame (long -> last CRC byte; short/EoTP -> ECC byte). Clear the
   // per-long-packet tlast marks set by gen_blanking_packet/gen_active_line,
   // then set tlast on the final frame byte only; the beat-consistency pass
   // below spreads it across the whole final beat.
   // In PER_LPPKT (legacy) mode this block is skipped, leaving the per-long-
   // packet CRC-beat marks in place (TLAST on every long packet's CRC beat).
   // ------------------------------------------------------------------
   if (passthrough_en == "ON" && tlast_mode == "PER_TXN") begin
      for (beat_j = 0; beat_j < frame_idx; beat_j = beat_j + 1)
         pt_meta[beat_j] = {pt_meta[beat_j][5], 1'b0, pt_meta[beat_j][3:2], pt_meta[beat_j][1:0]};
      if (frame_idx > 0)
         pt_meta[frame_idx-1] = {pt_meta[frame_idx-1][5], 1'b1, pt_meta[frame_idx-1][3:2], pt_meta[frame_idx-1][1:0]};
   end
   // Beat-consistency pass: if any byte within a BYTES_IN_PARALLEL-wide beat
   // has tlast=1 (marks end of a long packet), all bytes in that beat must
   // also carry tlast=1. This is required when two packets share a beat in a
   // single continuous HS transaction — e.g., a Blanking packet whose CRC ends
   // mid-beat while the next short packet's header (HSE/HSS) starts in the
   // same beat. In that case gen_blanking_packet only sets tlast on its own
   // CRC bytes, leaving the short-packet header bytes with tlast=0 inside the
   // same beat, causing a checker mismatch.
   if (passthrough_en == "ON") begin
      for (beat_j = 0; beat_j < frame_idx; beat_j = beat_j + BYTES_IN_PARALLEL) begin
         beat_has_tlast = 0;
         for (beat_k = beat_j;
              beat_k < beat_j + BYTES_IN_PARALLEL && beat_k < frame_idx;
              beat_k = beat_k + 1)
            if (pt_meta[beat_k][4]) beat_has_tlast = 1;
         if (beat_has_tlast) begin
            for (beat_k = beat_j;
                 beat_k < beat_j + BYTES_IN_PARALLEL && beat_k < frame_idx;
                 beat_k = beat_k + 1)
               pt_meta[beat_k] = {pt_meta[beat_k][5], 1'b1,
                                  pt_meta[beat_k][3:2], pt_meta[beat_k][1:0]};
         end
      end
   end

   $display("##### %0t Transmit DPHY packets ongoing... #####",$realtime);
   while(start_pos < frame_idx) begin
      // lane0 always valid in the while loop
      if(start_pos < frame_idx) begin
         data0 = dphy_frame[start_pos];
         if (passthrough_en == "ON") begin
            $fwrite(f,"%04x\n", {pt_meta[start_pos][5], pt_meta[start_pos][4], pt_meta[start_pos][3:2], pt_meta[start_pos][1:0], data0[7:0]});
            $fwrite(f_mask, "%0d\n", pt_eotp[start_pos] ? 2 : 1);
         end else if (uvsi_en == "ON" && data0[8])
            $fwrite(f,"%0x\n",data0[7:0]);
         if (data0[8])
            data_h.push_front(data0[7:0]);
         if (frame_idx > vact_payload  && start_pos >= 4 && line_counter0_r != 0) begin
            line_counter0_r = line_counter0_r -1;  
            validator_r     = 1;  
         end        
         if(debug_on) begin
            $display("##### %0t DPHY DATA #####",$realtime);
            $display("data lane0: %h",data0);
         end
      end
      else begin
         trail0 = 1;
      end
      start_pos = start_pos+1;
      if(dphy_num_lane >= 2) begin
         if(start_pos < frame_idx) begin
            data1 = dphy_frame[start_pos];
            if (passthrough_en == "ON") begin
               $fwrite(f,"%04x\n", {pt_meta[start_pos][5], pt_meta[start_pos][4], pt_meta[start_pos][3:2], pt_meta[start_pos][1:0], data1[7:0]});
               $fwrite(f_mask, "%0d\n", pt_eotp[start_pos] ? 2 : 1);
            end else if (uvsi_en == "ON" && data1[8]) 
               $fwrite(f,"%0x\n",data1[7:0]);
            if (data1[8])
               data_h.push_front(data1[7:0]);
         if (frame_idx > vact_payload  && start_pos >= 4 && line_counter1_r != 0) begin
            line_counter1_r = line_counter1_r -1; 
         end
            if(debug_on) 
               $display("data lane1: %h",data1);
         end
         else begin
            trail1 = 1;
            // trail lane: same beat metadata as lane0, zero data — pad byte
            if (passthrough_en == "ON") begin
               $fwrite(f,"%04x\n", {pt_meta[start_pos-1][5], pt_meta[start_pos-1][4], pt_meta[start_pos-1][3:2], pt_meta[start_pos-1][1:0], 8'h00});
               $fwrite(f_mask, "0\n");
            end
         end
         start_pos = start_pos+1;
      end
      if(dphy_num_lane >= 3) begin
         if(start_pos < frame_idx) begin
            data2 = dphy_frame[start_pos];
            if (passthrough_en == "ON") begin
               $fwrite(f,"%04x\n", {pt_meta[start_pos][5], pt_meta[start_pos][4], pt_meta[start_pos][3:2], pt_meta[start_pos][1:0], data2[7:0]});
               $fwrite(f_mask, "%0d\n", pt_eotp[start_pos] ? 2 : 1);
            end else if (uvsi_en == "ON" && data2[8])
               $fwrite(f,"%0x\n",data2[7:0]);
            if (data2[8])
               data_h.push_front(data2);
         if (frame_idx > vact_payload  && start_pos >= 4 && line_counter2_r != 0) begin
            line_counter2_r = line_counter2_r -1; 
         end
            if(debug_on)
               $display("data lane2: %h ",data2);
         end
         else begin
            trail2 = 1;
            // trail lane: same beat metadata as lane0, zero data — pad byte
            if (passthrough_en == "ON") begin
               $fwrite(f,"%04x\n", {pt_meta[start_pos-2][5], pt_meta[start_pos-2][4], pt_meta[start_pos-2][3:2], pt_meta[start_pos-2][1:0], 8'h00});
               $fwrite(f_mask, "0\n");
            end
         end
         start_pos = start_pos+1;
      end
      if(dphy_num_lane >= 4) begin
         if(start_pos < frame_idx) begin
            data3 = dphy_frame[start_pos];
            if (passthrough_en == "ON") begin
               $fwrite(f,"%04x\n", {pt_meta[start_pos][5], pt_meta[start_pos][4], pt_meta[start_pos][3:2], pt_meta[start_pos][1:0], data3[7:0]});
               $fwrite(f_mask, "%0d\n", pt_eotp[start_pos] ? 2 : 1);
            end else if (uvsi_en == "ON" && data3[8])
               $fwrite(f,"%0x\n",data3[7:0]);
            if (data3[8])
               data_h.push_front(data3);
         if (frame_idx > vact_payload  && start_pos >= 4 && line_counter3_r != 0) begin
            line_counter3_r = line_counter3_r -1; 
         end
            if(debug_on)
               $display("data lane3: %h",data3);
         end
         else begin
            trail3 = 1;
            // trail lane: same beat metadata as lane0, zero data — pad byte
            if (passthrough_en == "ON") begin
               $fwrite(f,"%04x\n", {pt_meta[start_pos-3][5], pt_meta[start_pos-3][4], pt_meta[start_pos-3][3:2], pt_meta[start_pos-3][1:0], 8'h00});
               $fwrite(f_mask, "0\n");
            end
         end
         start_pos = start_pos+1;
      end
      for(i = 0; i < 8; i=i+1) begin
         if(trail0 == 0)
            drive_data_lane0(data0[i]);  
         if(trail1 == 0 && dphy_num_lane >= 2)
            drive_data_lane1(data1[i]);     
         if(trail2 == 0 && dphy_num_lane >= 3)
            drive_data_lane2(data2[i]);    
         if(trail3 == 0 && dphy_num_lane >= 4)
            drive_data_lane3(data3[i]);  
         if(!trail0 || !trail1 || !trail2 || !trail3)
            #(dphy_clk_period/2);
      end
   end
   $display("##### %0t Transmit DPHY packets DONE! #####",$realtime);

   // Append extra pad entries to align the expected file to BYTES_IN_PARALLEL boundaries.
   // The while loop writes ceil(frame_idx/dphy_num_lane)*dphy_num_lane entries; the DUT
   // outputs ceil(frame_idx/BYTES_IN_PARALLEL)*BYTES_IN_PARALLEL bytes. Add the difference.
   if (passthrough_en == "ON") begin
      dp_extra_pads = ((frame_idx + BYTES_IN_PARALLEL - 1) / BYTES_IN_PARALLEL) * BYTES_IN_PARALLEL
                    - ((frame_idx + dphy_num_lane - 1)     / dphy_num_lane)      * dphy_num_lane;
      for (dp_pad_j = 0; dp_pad_j < dp_extra_pads; dp_pad_j = dp_pad_j + 1) begin
         // Pad bytes belong to the last real beat, so they carry that beat's TLAST
         // (pt_meta[frame_idx-1][4]) rather than a hardcoded 1 - correct for both
         // PER_TXN (last beat tlast=1) and PER_LPPKT (tracks the per-packet mark).
         $fwrite(f,"%04x\n", {pt_meta[frame_idx-1][5], pt_meta[frame_idx-1][4], pt_meta[frame_idx-1][3:2], pt_meta[frame_idx-1][1:0], 8'h00});
         $fwrite(f_mask, "0\n");
      end
   end

end
endtask
initial begin
   validator_r      = 0;
   line_counter0_r  = 0;
   line_counter1_r  = 0;
   line_counter2_r  = 0;
   line_counter3_r  = 0;
   odd_depth        = 0;
end

always @(posedge trail0) 
   drive_hs_trail0;

always @(posedge trail1) 
   drive_hs_trail1;


always @(posedge trail2) 
   drive_hs_trail2;

always @(posedge trail3)
   drive_hs_trail3;


generate
  if (dphy_num_lane == 4) begin
    always @(posedge (trail0_end && trail1_end && trail2_end && trail3_end)) begin
      #t_clk_post;
      clk_en = 0;
      trail0_end = 0;
      trail1_end = 0;
      trail2_end = 0;
      trail3_end = 0;
    end
  end else
  if (dphy_num_lane == 3) begin
    always @(posedge (trail0_end && trail1_end && trail2_end)) begin
      #t_clk_post;
      clk_en = 0;
      trail0_end = 0;
      trail1_end = 0;
      trail2_end = 0;
      trail3_end = 0;
    end
  end else
  if (dphy_num_lane == 2) begin
    always @(posedge (trail0_end && trail1_end)) begin
      #t_clk_post;
      clk_en = 0;
      trail0_end = 0;
      trail1_end = 0;
      trail2_end = 0;
      trail3_end = 0;
    end
  end else
  if (dphy_num_lane == 1) begin
    always @(posedge (trail0_end)) begin
      #t_clk_post;
      clk_en = 0;
      trail0_end = 0;
      trail1_end = 0;
      trail2_end = 0;
      trail3_end = 0;
    end
  end
endgenerate

task drive_data_HS(input dp);
begin
    drive_data_lane0(dp);
	if (dphy_num_lane > 1) drive_data_lane1(dp);
	if (dphy_num_lane > 2) drive_data_lane2(dp);
	if (dphy_num_lane > 3) drive_data_lane3(dp);
end
endtask

task drive_skewcal();
begin
    automatic reg [3:0]  skewcal_sync_ctr =  4'd0;
	automatic reg [31:0] skewcal_ui_ctr   = 32'd0;
    if (CLK_MODE == "HS_ONLY") begin
	    #t_clk_pre;
		drive_hs_data_req;
		@(posedge clk_p_i);
		#(dphy_clk_period/4);
		drive_data_HS(1);
		while (~&skewcal_sync_ctr) begin
		    skewcal_sync_ctr = skewcal_sync_ctr + 1'b1;
			#(dphy_clk_period/2);
		end
		#(dphy_clk_period/2);
		drive_data_HS(0);
		while (skewcal_ui_ctr < (skewcal_ui - 1)) begin
		    skewcal_ui_ctr = skewcal_ui_ctr + 1'b1;
			#(dphy_clk_period/2);
			drive_data_HS(~d_p_i[0]);
		end
		#(dphy_clk_period/2);
		drive_data_HS(~d_p_i[0]);
		#t_hs_trail;
		d_weak = 1;
		drive_data_LP(1,1);
	end else if (CLK_MODE == "HS_LP") begin
	    fork
		    begin
			    drive_hs_lp_clk;
			end
	        begin
			    @(posedge clk_en);
	            #t_clk_pre;
		        drive_hs_data_req;
		        @(posedge clk_p_i);
		        #(dphy_clk_period/4);
		        drive_data_HS(1);
		        while (~&skewcal_sync_ctr) begin
		            skewcal_sync_ctr = skewcal_sync_ctr + 1'b1;
		        	#(dphy_clk_period/2);
		        end
		        #(dphy_clk_period/2);
		        drive_data_HS(0);
		        while (skewcal_ui_ctr < (skewcal_ui - 1)) begin
		            skewcal_ui_ctr = skewcal_ui_ctr + 1'b1;
		        	#(dphy_clk_period/2);
		        	drive_data_HS(~d_p_i[0]);
		        end
		        #(dphy_clk_period/2);
				drive_data_HS(~d_p_i[0]);
				#t_hs_trail;
		        d_weak = 1;
		        drive_data_LP(1,1);
				clk_en = 0;
		    end
		join
	end
end
endtask

task drive_altcal();
begin
    automatic reg [1:0]  altcal_sync1_ctr =  2'd0;
    automatic reg [1:0]  altcal_sync0_ctr =  2'd0;
	automatic reg [31:0] altcal_ui_ctr    = 32'd0;
	automatic reg [8:0]  prbs9_shift_reg  =  9'b011111111;
    if (CLK_MODE == "HS_ONLY") begin
	    #t_clk_pre;
		drive_hs_data_req;
		@(posedge clk_p_i);
		#(dphy_clk_period/4);
		drive_data_HS(1);
		while (~&altcal_sync1_ctr) begin
		    altcal_sync1_ctr = altcal_sync1_ctr + 1'b1;
			#(dphy_clk_period/2);
		end
		#(dphy_clk_period/2);
		drive_data_HS(0);
		while (~&altcal_sync0_ctr) begin
		    altcal_sync0_ctr = altcal_sync0_ctr + 1'b1;
			#(dphy_clk_period/2);
		end
		#(dphy_clk_period/2);
		drive_data_HS(prbs9_shift_reg[8]^prbs9_shift_reg[4]);
		while (altcal_ui_ctr < (altcal_ui - 1)) begin
		    altcal_ui_ctr   = altcal_ui_ctr + 1'b1;
			prbs9_shift_reg = {prbs9_shift_reg[7:0],(prbs9_shift_reg[8]^prbs9_shift_reg[4])};
			#(dphy_clk_period/2);
			drive_data_HS(prbs9_shift_reg[8]^prbs9_shift_reg[4]);
		end
		#(dphy_clk_period/2);
		drive_data_HS(~d_p_i[0]);
		#t_hs_trail;
		d_weak = 1;
		drive_data_LP(1,1);
		clk_en = 0;
	end else if (CLK_MODE == "HS_LP") begin
	    fork
		    begin
			    drive_hs_lp_clk;
			end
	        begin
			    @(posedge clk_en);
	            #t_clk_pre;
		        drive_hs_data_req;
		        @(posedge clk_p_i);
		        #(dphy_clk_period/4);
		        drive_data_HS(1);
		        while (~&altcal_sync1_ctr) begin
		            altcal_sync1_ctr = altcal_sync1_ctr + 1'b1;
		        	#(dphy_clk_period/2);
		        end
		        #(dphy_clk_period/2);
		        drive_data_HS(0);
		        while (~&altcal_sync0_ctr) begin
		            altcal_sync0_ctr = altcal_sync0_ctr + 1'b1;
		        	#(dphy_clk_period/2);
		        end
		        #(dphy_clk_period/2);
		        drive_data_HS(prbs9_shift_reg[8]^prbs9_shift_reg[4]);
		        while (altcal_ui_ctr < (altcal_ui - 1)) begin
		            altcal_ui_ctr   = altcal_ui_ctr + 1'b1;
		        	prbs9_shift_reg = {prbs9_shift_reg[7:0],(prbs9_shift_reg[8]^prbs9_shift_reg[4])};
		        	#(dphy_clk_period/2);
		        	drive_data_HS(prbs9_shift_reg[8]^prbs9_shift_reg[4]);
		        end
		        #(dphy_clk_period/2);
				drive_data_HS(~d_p_i[0]);
				#t_hs_trail;
		        d_weak = 1;
		        drive_data_LP(1,1);
				clk_en = 0;
		    end
		join
	end
end
endtask

endmodule
`endif