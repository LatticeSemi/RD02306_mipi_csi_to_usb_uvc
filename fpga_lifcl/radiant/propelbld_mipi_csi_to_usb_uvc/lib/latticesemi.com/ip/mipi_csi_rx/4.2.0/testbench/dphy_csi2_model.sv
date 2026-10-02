//===========================================================================
// Filename: dphy_csi2_model.sv
// Copyright(c) 2017 Lattice Semiconductor Corporation. All rights reserved. 
//===========================================================================
`ifndef DPHY_CSI2_MODEL
`define DPHY_CSI2_MODEL

`timescale 1ps / 1ps

module dphy_csi2_model#(
   parameter num_frames           = 2,
   parameter num_pixels           = 200,
   parameter num_lines            = 2,
   parameter active_dphy_lanes    = 4,
   parameter data_type            = 6'h2b,
   parameter RX_CLK_MODE          = "HS_ONLY",

   parameter dphy_clk_period      = 1683, 
   parameter t_lpx                = 68000,
   parameter t_clk_prepare        = 51000,
   parameter t_clk_zero           = 252503, 
   parameter t_clk_trail          = 62000,
   parameter t_clk_post           = 131000,
   parameter t_clk_pre            = 10000,

   parameter t_hs_prepare         = 55000,
   parameter t_hs_zero            = 103543, 
   parameter t_hs_trail           = 80000,
   parameter lps_gap              = 100000,
   parameter frame_gap            = 100000,
   parameter t_init               = 100000000,
   parameter dphy_ch              = 0,
   parameter dphy_vc              = 0,
   parameter LS_LE                = 0,
   parameter debug                = 0,
   parameter fixed_data           = 0,
   parameter sim_weak             = "ON", // simulate weak pull-up/pull-down
   parameter send_cal             = "ON", // send calibration, for line rate > 1500Mbps
   parameter send_alt_cal         = "ON", // send alternate calibration, for line rate > 2500Mbps
   parameter skewcal_ui           = 32768,
   parameter altcal_ui            = 32768,
   parameter passthrough_en       = "OFF",
   parameter tlast_mode           = "PER_TXN", // "PER_TXN" | "PER_LPPKT" - MBSI expected TLAST behavior
   parameter vc_alternate         = "OFF",     // "ON" = alternate VC and VCX per packet for MBSI TUSER-alignment checking (CSI2: VCX_ON=1)
   parameter uvsi_en              = "OFF",
   parameter BYTES_IN_PARALLEL    = 4
)(
   input refclk_i,
   input resetn,
   inout clk_p_io,
   inout clk_n_io,
   inout [3:0] d_p_io,
   inout [3:0] d_n_io,
   output wire csi_valid_o
);

localparam ls_le_en = (LS_LE == "ON") ? 1 : 0;

// CSI-2: 1 packet = 1 HS transaction, so short packets (FS/LS/FE/LE) assert TLAST
// in PER_TXN. In PER_LPPKT (legacy) short packets never assert TLAST.
localparam sp_tlast_bit = (tlast_mode == "PER_TXN") ? 1'b1 : 1'b0;

reg [15:0] num_pixels_corrected;
reg [15:0] vact_payload;
reg long_even_line_en;

initial begin
    if (data_type == 6'h24) begin // RGB888
	    vact_payload = num_pixels*3;
	    long_even_line_en = 0;
	end else if (data_type == 6'h22) begin // RGB565
	    vact_payload = num_pixels*2;
	    long_even_line_en = 0;
	end else if (data_type == 6'h2B) begin // RAW10
	    if ((num_pixels % 4) > 0) begin
		    $display("%t Number of Horizontal Pixels Must Be In Multiple Of 4 for RAW10\n", $time);
			num_pixels_corrected = num_pixels - (num_pixels % 4);
		    $display("%t Corrected Number of Horizontal Pixels from %0d to %0d\n", $time, num_pixels, num_pixels_corrected);
		end else begin
		    num_pixels_corrected = num_pixels;
		end
		vact_payload = num_pixels_corrected*10/8;
	    long_even_line_en = 0;
  /*end else if (data_type == 6'h2C) begin // RAW12*/
    end else begin
	    if ((num_pixels % 2) > 0) begin
		    $display("%t Number of Horizontal Pixels Must Be In Multiple Of 2 for RAW12\n", $time);
			num_pixels_corrected = num_pixels - (num_pixels % 2);
		    $display("%t Corrected Number of Horizontal Pixels from %0d to %0d\n", $time, num_pixels, num_pixels_corrected);
		end else begin
		    num_pixels_corrected = num_pixels;
		end
		vact_payload = num_pixels_corrected*12/8;
	    long_even_line_en = 0;
	end
end

wire clk_p_w, clk_n_w;
reg cont_clk_p_r, cont_clk_n_r;

integer d = 0;
reg clk_en, cont_clk_en;
reg [1:0]  vc;
reg [5:0]  dt;
reg [15:0] wc;
reg [15:0] word_count_odd_r;
reg [15:0] iterations_r;
reg [15:0] BPC;
reg [7:0]  ecc;
reg [15:0] chksum;
reg [15:0] cur_crc;
reg odd_even_line; 
reg long_even_line;
reg ls_le;
reg [15:0] lnum;

reg [1:0] fnum;

reg sof_pending;
initial sof_pending = 0;
reg [1:0] vcx;
// VC/VCX alternation (used only when vc_alternate=="ON"): 4-bit counter, VC=cnt[1:0] cycles
// every packet, VCX=cnt[3:2] cycles every 4 packets. VCX is overlaid into ECC byte[7:6],
// which the DUT reads as VCX under VCX_ON=1 (CSI2). Free-running across the stimulus.
reg [3:0] vc_alt_cnt;
initial vc_alt_cnt = 4'd0;
reg [1:0] vc_alt_vcx;

reg dphy_start;
reg dphy_active;

integer i,j,k,l,m,n;
integer n_data_last_beat, n_total_pads, n_extra_pads, bpc_ctr, pad_i;
reg     tlast_val;
integer f;                                 // File where write data transmitted from test
initial f = $fopen("tb_expected_data.txt","w"); // File where write data transmitted from test
integer f_mask;
initial f_mask = (passthrough_en == "ON") ? $fopen("tb_expected_mask.txt","w") : 0;
reg [7:0] data [3:0];

reg       validator_r;
initial   validator_r = 1'b0;

wire [7:0] data0;
wire [7:0] data1;
wire [7:0] data2;
wire [7:0] data3;

reg [7:0] data_h [$];

clk_driver clk_drv();
bus_driver#(.ch(0),.dphy_clk(dphy_clk_period))bus_drv0(.clk_p_i(clk_p_w));
bus_driver#(.ch(1),.dphy_clk(dphy_clk_period))bus_drv1(.clk_p_i(clk_p_w));
bus_driver#(.ch(2),.dphy_clk(dphy_clk_period))bus_drv2(.clk_p_i(clk_p_w));
bus_driver#(.ch(3),.dphy_clk(dphy_clk_period))bus_drv3(.clk_p_i(clk_p_w));

assign clk_p_w = clk_drv.clk_p_i;
assign clk_n_w = clk_drv.clk_n_i;
assign csi_valid_o = validator_r;

reg clk_weak;
reg d_weak;
initial begin clk_weak = 1; d_weak = 1; end

generate if (sim_weak == "ON") begin
   assign (pull0, pull1) clk_p_io = (RX_CLK_MODE == "HS_LP")? clk_p_w : cont_clk_p_r; 
   assign (pull0, pull1) clk_n_io = (RX_CLK_MODE == "HS_LP")? clk_n_w : cont_clk_n_r;
   assign (pull0, pull1) d_p_io[0] = bus_drv0.do_p_i;
   assign (pull0, pull1) d_n_io[0] = bus_drv0.do_n_i;
   assign (pull0, pull1) d_p_io[1] = bus_drv1.do_p_i;
   assign (pull0, pull1) d_n_io[1] = bus_drv1.do_n_i;
   assign (pull0, pull1) d_p_io[2] = bus_drv2.do_p_i;
   assign (pull0, pull1) d_n_io[2] = bus_drv2.do_n_i;
   assign (pull0, pull1) d_p_io[3] = bus_drv3.do_p_i;
   assign (pull0, pull1) d_n_io[3] = bus_drv3.do_n_i;
   assign clk_p_io = (~clk_weak) ? ((RX_CLK_MODE == "HS_LP")? clk_p_w : cont_clk_p_r) : 1'bz; 
   assign clk_n_io = (~clk_weak) ? ((RX_CLK_MODE == "HS_LP")? clk_n_w : cont_clk_n_r) : 1'bz;
   assign d_p_io[0] = (~d_weak) ? bus_drv0.do_p_i : 1'bz;
   assign d_n_io[0] = (~d_weak) ? bus_drv0.do_n_i : 1'bz;
   assign d_p_io[1] = (~d_weak) ? bus_drv1.do_p_i : 1'bz;
   assign d_n_io[1] = (~d_weak) ? bus_drv1.do_n_i : 1'bz;
   assign d_p_io[2] = (~d_weak) ? bus_drv2.do_p_i : 1'bz;
   assign d_n_io[2] = (~d_weak) ? bus_drv2.do_n_i : 1'bz;
   assign d_p_io[3] = (~d_weak) ? bus_drv3.do_p_i : 1'bz;
   assign d_n_io[3] = (~d_weak) ? bus_drv3.do_n_i : 1'bz;
end else begin
   assign clk_p_io = (RX_CLK_MODE == "HS_LP")? clk_p_w : cont_clk_p_r; 
   assign clk_n_io = (RX_CLK_MODE == "HS_LP")? clk_n_w : cont_clk_n_r;
   assign d_p_io[0] = bus_drv0.do_p_i;
   assign d_n_io[0] = bus_drv0.do_n_i;
   assign d_p_io[1] = bus_drv1.do_p_i;
   assign d_n_io[1] = bus_drv1.do_n_i;
   assign d_p_io[2] = bus_drv2.do_p_i;
   assign d_n_io[2] = bus_drv2.do_n_i;
   assign d_p_io[3] = bus_drv3.do_p_i;
   assign d_n_io[3] = bus_drv3.do_n_i;
end
endgenerate

assign data0 = data[0];
assign data1 = data[1];
assign data2 = data[2];
assign data3 = data[3];

initial begin
      vc = dphy_vc;
      dt = data_type;
      wc = vact_payload - (active_dphy_lanes == 3)*2;
      iterations_r = 16'd0;
      fnum = 1;
      chksum = 16'hffff;
      dphy_active = 0;
      cont_clk_p_r = 1;
      cont_clk_n_r = 1;
      long_even_line = long_even_line_en;
      ls_le = ls_le_en;
      data[0]  = 0;
      data[1]  = 0;
      data[2]  = 0;
      data[3]  = 0;
      d = 0;
      $display("%t Word count = %0d\n", $time, vact_payload);
      @(posedge dphy_active);
      $display("%t DPHY [%0d] model activated\n", $time, dphy_ch);
      
      #(t_init);

      fork
         begin
            drive_cont_clk;
         end
         begin
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
            repeat (num_frames) begin
            // FS
            drive_fs;
      
            odd_even_line = 0; 
               //Drive data
               repeat (num_lines) begin
                  if (ls_le == 1) begin
                     #lps_gap;
                     drive_ls;
                  end
                  #lps_gap;
                  if (long_even_line == 1) begin
                     if (odd_even_line == 0) begin
                        wc = vact_payload;
                     end else
                     if (odd_even_line == 1) begin
                        wc = vact_payload*2;
                     end
                  end
                  drive_data;

                  if (ls_le == 1) begin
                     #lps_gap;
                     drive_le;
                  end
                  odd_even_line = ~odd_even_line;
               end
      
            //FE
            #lps_gap;
            drive_fe;
            #frame_gap;
            end
      
	    $fclose(f);
       if (passthrough_en == "ON") $fclose(f_mask);
	    #10;
            dphy_active = 0;
            cont_clk_en = 0;
         end
      join
end

initial begin
   clk_en = 0;
   cont_clk_en = 0;
end

task drive_cont_clk;
begin
   #1000;
   // HS-RQST
   if(debug == 1) begin
     $display("%t DPHY [%0d] CLK CONT : Driving HS-CLK-RQST", $time, dphy_ch);
   end
   cont_clk_p_r = 0;
   cont_clk_n_r = 1;
   #t_lpx;

   // HS-Prpr
   if(debug == 1) begin
     $display("%t DPHY [%0d] CLK CONT : Driving HS-Prpr", $time, dphy_ch);
   end
   cont_clk_p_r = 0;
   cont_clk_n_r = 0;
   #t_clk_prepare;

   // HS-Go
   if(debug == 1) begin
     $display("%t DPHY [%0d] CLK CONT : Driving HS-Go", $time, dphy_ch);
   end
   clk_weak = 0;
   cont_clk_p_r = 0;
   cont_clk_n_r = 1;
   #t_clk_zero;

   cont_clk_en = 1;
   if(debug == 1) begin
     $display("%t DPHY [%0d] CLK CONT : Driving HS-0/HS-1", $time, dphy_ch);
   end
   while (cont_clk_en) begin
      @(refclk_i);
      cont_clk_p_r = refclk_i;
      cont_clk_n_r = ~refclk_i;
   end

   // Trail HS-0
   if(debug == 1) begin
     $display("%t DPHY [%0d] CLK CONT : Driving CLK-Trail", $time, dphy_ch);
   end
   #t_clk_trail;

   // TX-Stop
   if(debug == 1) begin
     $display("%t DPHY [%0d] CLK CONT : Driving CLK-Stop", $time, dphy_ch);
   end
   clk_weak = 1;
   clk_drv.drv_clk_st(1, 1);
end
endtask

task drive_clk;
begin 

   #1000;
   // HS-RQST
   if(debug == 1) begin
     $display("%t DPHY [%0d] CLK : Driving HS-CLK-RQST", $time, dphy_ch);
   end
   clk_drv.drv_clk_st(0, 1);
   #t_lpx;

   // HS-Prpr
   if(debug == 1) begin
     $display("%t DPHY [%0d] CLK : Driving HS-Prpr", $time, dphy_ch);
   end
   clk_drv.drv_clk_st(0, 0);
   #t_clk_prepare;

   // HS-Go
   if(debug == 1) begin
     $display("%t DPHY [%0d] CLK : Driving HS-Go", $time, dphy_ch);
   end
   if(RX_CLK_MODE == "HS_LP") begin
     clk_weak = 0;
   end
   clk_drv.drv_clk_st(0, 1);
   #t_clk_zero;

   clk_en = 1;
   if(debug == 1) begin
     $display("%t DPHY [%0d] CLK : Driving HS-0/HS-1", $time, dphy_ch);
   end
   while (clk_en) begin
      @(refclk_i);
      clk_drv.drv_clk_st(refclk_i, ~refclk_i);
   end

   // Trail HS-0
   if(debug == 1) begin
     $display("%t DPHY [%0d] CLK : Driving CLK-Trail", $time, dphy_ch);
   end
   #t_clk_trail;

   // TX-Stop
   if(debug == 1) begin
     $display("%t DPHY [%0d] CLK : Driving CLK-Stop", $time, dphy_ch);
   end
   if(RX_CLK_MODE == "HS_LP") begin
     clk_weak = 1;
   end
   clk_drv.drv_clk_st(1, 1);

end
endtask

task drive_fs;
begin
   fork
      begin
         drive_clk;
      end
      begin
         pre_data(0);

         // FS packet
         // MBSI VC alternation: pick this packet's VC (and VCX) before building DI/ECC.
         if (vc_alternate == "ON") begin vc = vc_alt_cnt[1:0]; vc_alt_vcx = vc_alt_cnt[3:2]; vc_alt_cnt = vc_alt_cnt + 4'd1; end
         data[0] = {vc, 6'h00};
         data[1] = fnum;
         data[2] = 8'h00;
         data[3] = 8'h00;
         get_ecc({data[2], data[1], data[0]}, data[3]);
         // MBSI VC alternation: overlay this packet's VCX into the ECC byte's [7:6] (reserved
         // bits carry VCX under VCX_ON=1) AND re-encode ECC[5:0] over the 26-bit {VCX,header}
         // so the DUT's vcx_on corrector sees syndrome==0 and passes VCX/WC through intact.
         if (vc_alternate == "ON") data[3] = ecc_with_vcx(data[3][5:0], vc_alt_vcx);
         vcx = data[3][7:6];

         $display("%t DPHY [%0d] DATA : Driving FS", $time, dphy_ch);
         if (active_dphy_lanes == 1) begin
            for (i = 0 ; i < 4 ; i = i + 1) begin
               bus_drv0.drive_datax(data[i]);
            end
         end else
         if (active_dphy_lanes == 2) begin
            for (i = 0 ; i < 4 ; i = i + 2) begin
            if(debug) begin
              $display("%t DPHY [%0d] DATA : Driving data[%0d] = %0x", $time, dphy_ch, i, data[i]);
              $display("%t DPHY [%0d] DATA : Driving data[%0d] = %0x", $time, dphy_ch, i+1, data[i+1]);
            end
               fork
                  bus_drv0.drive_datax(data[i]);
                  bus_drv1.drive_datax(data[i+1]);
               join
            end
         end else
         if (active_dphy_lanes == 3) begin // RTL don't supports 3 lane mode
            if(debug) begin
              $display("%t DPHY [%0d] DATA : Driving data[0] = %0x", $time, dphy_ch, data[0]);
              $display("%t DPHY [%0d] DATA : Driving data[0] = %0x", $time, dphy_ch, data[1]);
              $display("%t DPHY [%0d] DATA : Driving data[0] = %0x", $time, dphy_ch, data[2]);
            end
               fork
                  bus_drv0.drive_datax(data[0]);
                  bus_drv1.drive_datax(data[1]);
                  bus_drv2.drive_datax(data[2]);
               join
               fork
                  bus_drv0.drive_datax(data[3]);
                  bus_drv1.drv_trail;
                  bus_drv2.drv_trail;
               join
         end else
         if (active_dphy_lanes == 4) begin
            fork
               bus_drv0.drive_datax(data[0]);
               bus_drv1.drive_datax(data[1]);
               bus_drv2.drive_datax(data[2]);
               bus_drv3.drive_datax(data[3]);
            join
         end
         if (passthrough_en == "ON") begin
            for (i = 0; i < 4; i = i + 1) begin
               $fwrite(f,"%04x\n", {1'b0, sp_tlast_bit, vc, vcx, data[i]}); // short packet: TLAST per tlast_mode
               $fwrite(f_mask, "1\n");
            end
            sof_pending = 1;
            if (BYTES_IN_PARALLEL == 8) begin // Dummy bytes
               for (i = 0; i < 4; i = i + 1) begin
                  $fwrite(f,"%04x\n", {1'b0, sp_tlast_bit, vc, vcx, 8'h00}); // short-packet last-beat pad (masked): TLAST tracks the beat
                  $fwrite(f_mask, "0\n");
               end
            end
         end

           post_data;
         // reset line number
         lnum = 1;
      end
   join
end
endtask

task drive_ls;
begin
   fork
      begin
         drive_clk;
      end
      begin
         pre_data(0);

         // LS packet
         // MBSI VC alternation: pick this packet's VC (and VCX) before building DI/ECC.
         if (vc_alternate == "ON") begin vc = vc_alt_cnt[1:0]; vc_alt_vcx = vc_alt_cnt[3:2]; vc_alt_cnt = vc_alt_cnt + 4'd1; end
         data[0] = {vc, 6'h02};
         data[1] = lnum[7:0];
         data[2] = lnum[15:8];
         data[3] = 8'h00;
         get_ecc({data[2], data[1], data[0]}, data[3]);
         // MBSI VC alternation: overlay this packet's VCX into the ECC byte's [7:6] (reserved
         // bits carry VCX under VCX_ON=1) AND re-encode ECC[5:0] over the 26-bit {VCX,header}
         // so the DUT's vcx_on corrector sees syndrome==0 and passes VCX/WC through intact.
         if (vc_alternate == "ON") data[3] = ecc_with_vcx(data[3][5:0], vc_alt_vcx);
         vcx = data[3][7:6];

         $display("%t DPHY [%0d] DATA : Driving LS", $time, dphy_ch);
         if (active_dphy_lanes == 1) begin
            for (i = 0 ; i < 4 ; i = i + 1) begin
               bus_drv0.drive_datax(data[i]);
            end
         end else
         if (active_dphy_lanes == 2) begin
            for (i = 0 ; i < 4 ; i = i + 2) begin
            if(debug) begin
              $display("%t DPHY [%0d] DATA : Driving data[%0d] = %0x", $time, dphy_ch, i, data[i]);
              $display("%t DPHY [%0d] DATA : Driving data[%0d] = %0x", $time, dphy_ch, i+1, data[i+1]);
            end
               fork
                  bus_drv0.drive_datax(data[i]);
                  bus_drv1.drive_datax(data[i+1]);
               join
            end
         end 
         else if (active_dphy_lanes == 3) begin
            if(debug) begin
              $display("%t DPHY [%0d] DATA : Driving data[0] = %0x", $time, dphy_ch, data[0]);
              $display("%t DPHY [%0d] DATA : Driving data[0] = %0x", $time, dphy_ch, data[1]);
              $display("%t DPHY [%0d] DATA : Driving data[0] = %0x", $time, dphy_ch, data[2]);
            end
               fork
                  bus_drv0.drive_datax(data[0]);
                  bus_drv1.drive_datax(data[1]);
                  bus_drv2.drive_datax(data[2]);
               join
               fork
                  bus_drv0.drive_datax(data[3]);
                  bus_drv1.drv_trail;
                  bus_drv2.drv_trail;
               join
         end 
         else if (active_dphy_lanes == 4) begin
            fork
               bus_drv0.drive_datax(data[0]);
               bus_drv1.drive_datax(data[1]);
               bus_drv2.drive_datax(data[2]);
               bus_drv3.drive_datax(data[3]);
            join
         end
         if (passthrough_en == "ON") begin
            for (i = 0; i < 4; i = i + 1) begin
               $fwrite(f,"%04x\n", {1'b0, sp_tlast_bit, vc, vcx, data[i]}); // short packet: TLAST per tlast_mode
               $fwrite(f_mask, "1\n");
            end
            if (BYTES_IN_PARALLEL == 8) begin // Dummy bytes
               for (i = 0; i < 4; i = i + 1) begin
                  $fwrite(f,"%04x\n", {1'b0, sp_tlast_bit, vc, vcx, 8'h00}); // short-packet last-beat pad (masked): TLAST tracks the beat
                  $fwrite(f_mask, "0\n");
               end
            end
         end
           post_data;
      end
   join
end
endtask

task drive_fe;
begin
   fork
      begin
         drive_clk;
      end
      begin
         pre_data(0);

         // FE packet
         // MBSI VC alternation: pick this packet's VC (and VCX) before building DI/ECC.
         if (vc_alternate == "ON") begin vc = vc_alt_cnt[1:0]; vc_alt_vcx = vc_alt_cnt[3:2]; vc_alt_cnt = vc_alt_cnt + 4'd1; end
         data[0] = {vc, 6'h01};
         data[1] = fnum;
         data[2] = 8'h00;
         data[3] = 8'h00;
         get_ecc({data[2], data[1], data[0]}, data[3]);
         // MBSI VC alternation: overlay this packet's VCX into the ECC byte's [7:6] (reserved
         // bits carry VCX under VCX_ON=1) AND re-encode ECC[5:0] over the 26-bit {VCX,header}
         // so the DUT's vcx_on corrector sees syndrome==0 and passes VCX/WC through intact.
         if (vc_alternate == "ON") data[3] = ecc_with_vcx(data[3][5:0], vc_alt_vcx);
         vcx = data[3][7:6];

         $display("%t DPHY [%0d] DATA : Driving FE", $time, dphy_ch);
         if (active_dphy_lanes == 1) begin
            for (i = 0 ; i < 4 ; i = i + 1) begin
               bus_drv0.drive_datax(data[i]);
            end
         end else
         if (active_dphy_lanes == 2) begin
            for (i = 0 ; i < 4 ; i = i + 2) begin
               fork
                  bus_drv0.drive_datax(data[i]);
                  bus_drv1.drive_datax(data[i+1]);
               join
            end
         end else 
         if (active_dphy_lanes == 3) begin
               fork
                  bus_drv0.drive_datax(data[0]);
                  bus_drv1.drive_datax(data[1]);
                  bus_drv2.drive_datax(data[2]);
               join
               fork
                  bus_drv0.drive_datax(data[3]);
                  bus_drv1.drv_trail;
                  bus_drv2.drv_trail;
               join
         end else
         if (active_dphy_lanes == 4) begin
            fork
               bus_drv0.drive_datax(data[0]);
               bus_drv1.drive_datax(data[1]);
               bus_drv2.drive_datax(data[2]);
               bus_drv3.drive_datax(data[3]);
            join
         end
         if (passthrough_en == "ON") begin
            for (i = 0; i < 4; i = i + 1) begin
               $fwrite(f,"%04x\n", {1'b0, sp_tlast_bit, vc, vcx, data[i]}); // short packet: TLAST per tlast_mode
               $fwrite(f_mask, "1\n");
            end
            if (BYTES_IN_PARALLEL == 8) begin // Dummy bytes
               for (i = 0; i < 4; i = i + 1) begin
                  $fwrite(f,"%04x\n", {1'b0, sp_tlast_bit, vc, vcx, 8'h00}); // short-packet last-beat pad (masked): TLAST tracks the beat
                  $fwrite(f_mask, "0\n");
               end
            end
         end
         post_data;
         fnum = ~fnum;
      end
   join
end
endtask

task drive_le;
begin
   fork
      begin
         drive_clk;
      end
      begin
         pre_data(0);

         // LE packet
         // MBSI VC alternation: pick this packet's VC (and VCX) before building DI/ECC.
         if (vc_alternate == "ON") begin vc = vc_alt_cnt[1:0]; vc_alt_vcx = vc_alt_cnt[3:2]; vc_alt_cnt = vc_alt_cnt + 4'd1; end
         data[0] = {vc, 6'h03};
         data[1] = lnum[7:0];
         data[2] = lnum[15:0];
         data[3] = 8'h00;
         get_ecc({data[2], data[1], data[0]}, data[3]);
         // MBSI VC alternation: overlay this packet's VCX into the ECC byte's [7:6] (reserved
         // bits carry VCX under VCX_ON=1) AND re-encode ECC[5:0] over the 26-bit {VCX,header}
         // so the DUT's vcx_on corrector sees syndrome==0 and passes VCX/WC through intact.
         if (vc_alternate == "ON") data[3] = ecc_with_vcx(data[3][5:0], vc_alt_vcx);
         vcx = data[3][7:6];

         $display("%t DPHY [%0d] DATA : Driving LE", $time, dphy_ch);
         if (active_dphy_lanes == 1) begin
            for (i = 0 ; i < 4 ; i = i + 1) begin
               bus_drv0.drive_datax(data[i]);
            end
         end else
         if (active_dphy_lanes == 2) begin
            for (i = 0 ; i < 4 ; i = i + 2) begin
               fork
                  bus_drv0.drive_datax(data[i]);
                  bus_drv1.drive_datax(data[i+1]);
               join
            end
         end 
         else if (active_dphy_lanes == 3) begin
               fork
                  bus_drv0.drive_datax(data[0]);
                  bus_drv1.drive_datax(data[1]);
                  bus_drv2.drive_datax(data[2]);
               join
               fork
                  bus_drv0.drive_datax(data[3]);
                  bus_drv1.drv_trail;
                  bus_drv2.drv_trail;
               join
         end 
         else if (active_dphy_lanes == 4) begin
            fork
               bus_drv0.drive_datax(data[0]);
               bus_drv1.drive_datax(data[1]);
               bus_drv2.drive_datax(data[2]);
               bus_drv3.drive_datax(data[3]);
            join
         end
         if (passthrough_en == "ON") begin
            for (i = 0; i < 4; i = i + 1) begin
               $fwrite(f,"%04x\n", {1'b0, sp_tlast_bit, vc, vcx, data[i]}); // short packet: TLAST per tlast_mode
               $fwrite(f_mask, "1\n");
            end
            if (BYTES_IN_PARALLEL == 8) begin // Dummy bytes
               for (i = 0; i < 4; i = i + 1) begin
                  $fwrite(f,"%04x\n", {1'b0, sp_tlast_bit, vc, vcx, 8'h00}); // short-packet last-beat pad (masked): TLAST tracks the beat
                  $fwrite(f_mask, "0\n");
               end
            end
         end

           post_data;
         lnum = lnum + 1;
      end
   join

end
endtask

task drive_data;
begin
   word_count_odd_r = wc;
   n_data_last_beat = ((wc + 5) % BYTES_IN_PARALLEL == 0) ? 0 : (((wc + 5) % BYTES_IN_PARALLEL) - 1);
   // For BYTES_IN_PARALLEL=4: payload+CRC starts at byte 0 of each beat; use (wc+2)
   // For BYTES_IN_PARALLEL=8: first 4 bytes of payload+CRC are in header beat (bytes 4-7);
   //    remaining (wc-2) bytes start at byte 0 of beat 2; pad based on (wc-2)
   n_total_pads     = (BYTES_IN_PARALLEL == 8)
       ? (BYTES_IN_PARALLEL - ((wc - 2) % BYTES_IN_PARALLEL)) % BYTES_IN_PARALLEL
       : (BYTES_IN_PARALLEL - ((wc + 2) % BYTES_IN_PARALLEL)) % BYTES_IN_PARALLEL;
   bpc_ctr          = 0;
   fork
      begin
         drive_clk;
      end
      begin
         #t_clk_prepare;
         pre_data(0);
         validator_r = 1'd1;
         //drive header
         // MBSI VC alternation: pick this long packet's VC (and VCX) before building DI/ECC.
         if (vc_alternate == "ON") begin vc = vc_alt_cnt[1:0]; vc_alt_vcx = vc_alt_cnt[3:2]; vc_alt_cnt = vc_alt_cnt + 4'd1; end
         data[0] = {vc, dt};
         data[1] = {wc[7:0]};
         data[2] = {wc[15:8]};
         data[3] = 8'h00;
         get_ecc({data[2], data[1], data[0]}, data[3]);
         // MBSI VC alternation: overlay this packet's VCX into the ECC byte's [7:6] (reserved
         // bits carry VCX under VCX_ON=1) AND re-encode ECC[5:0] over the 26-bit {VCX,header}
         // so the DUT's vcx_on corrector sees syndrome==0 and passes VCX/WC through intact.
         if (vc_alternate == "ON") data[3] = ecc_with_vcx(data[3][5:0], vc_alt_vcx);
         vcx = data[3][7:6];

         if (active_dphy_lanes == 1) begin
            for (i = 0 ; i < 4 ; i = i + 1) begin
               bus_drv0.drive_datax(data[i]);
            end
         end
         else if (active_dphy_lanes == 2) begin
            for (i = 0 ; i < 4 ; i = i + 2) begin
               fork
                  bus_drv0.drive_datax(data[i]);
                  bus_drv1.drive_datax(data[i+1]);
               join
            end
         end
         else if (active_dphy_lanes == 3) begin
               fork
                  bus_drv0.drive_datax(data[0]);
                  bus_drv1.drive_datax(data[1]);
                  bus_drv2.drive_datax(data[2]);
               join
               data[0]        = $random;
               data[1]        = $random;
               fork
                  bus_drv0.drive_datax(data[3]);
                  bus_drv1.drive_datax(data[0]);
                  bus_drv2.drive_datax(data[1]);
               join
               if (uvsi_en == "ON")
                  $fwrite(f,"%0x\n%0x\n",data[0],data[1]);
         end
         else if (active_dphy_lanes == 4) begin
            fork
               bus_drv0.drive_datax(data[0]);
               bus_drv1.drive_datax(data[1]);
               bus_drv2.drive_datax(data[2]);
               bus_drv3.drive_datax(data[3]);
            join
         end
         if (passthrough_en == "ON") begin : hdr_write
            reg pt_sof;
            pt_sof = sof_pending;
            sof_pending = 0;
            for (i = 0; i < 4; i = i + 1) begin
               $fwrite(f,"%04x\n", {pt_sof, 1'b0, vc, vcx, data[i]});
               $fwrite(f_mask, "1\n");
            end
         end
         validator_r = 1'd0;
         // reset crc value
         chksum = 16'hffff;
      
         // temporary alternating data 8'h0 and 8'hFF
         data[0] = 0;
         data[1] = 0;
         data[2] = 0;
         data[3] = 0;
         // random data packet
         repeat (BPC) begin // use variable later
            bpc_ctr = bpc_ctr + 1;
            if (word_count_odd_r >= active_dphy_lanes) begin
               iterations_r = active_dphy_lanes;
               word_count_odd_r = word_count_odd_r - active_dphy_lanes;
            end
            else begin
               iterations_r = word_count_odd_r;
            end
            tlast_val = (passthrough_en == "ON" && n_data_last_beat > 0 && bpc_ctr > BPC - ((n_data_last_beat + active_dphy_lanes - 1) / active_dphy_lanes)) ? 1'b1 : 1'b0;
            for (i = 0; i < iterations_r; i = i + 1) begin
                if (fixed_data == 0) begin
                  data[i] = $random;
                end else
                begin
                  data[i] = ~data[i];
                end
                compute_crc16(data[i]);
            end

            $display("%t DPHY [%0d] Driving Data", $time, dphy_ch);
            if (active_dphy_lanes == 1) begin
               for (i = 0 ; i < active_dphy_lanes ; i = i + 1) begin
                  bus_drv0.drive_datax(data[i]);
	          data_h.push_front(data[i]);
               end
               if (passthrough_en == "ON") begin
                  $fwrite(f,"%04x\n", {1'b0, tlast_val, vc, vcx, data[0]});
                  $fwrite(f_mask, "1\n");
               end else if (uvsi_en == "ON")
                  $fwrite(f,"%0x\n",data[0]);
            end 
            else if (active_dphy_lanes == 2) begin
               if (iterations_r == active_dphy_lanes) begin
                  fork
                     bus_drv0.drive_datax(data[0]);
                     bus_drv1.drive_datax(data[1]);
	             data_h.push_front(data[0]);
	             data_h.push_front(data[1]);
                  join
                  if (passthrough_en == "ON") begin
                     $fwrite(f,"%04x\n%04x\n", {1'b0, tlast_val, vc, vcx, data[0]}, {1'b0, tlast_val, vc, vcx, data[1]});
                     $fwrite(f_mask, "1\n1\n");
                  end else if (uvsi_en == "ON")
                     $fwrite(f,"%0x\n%0x\n",data[0],data[1]);
               end
               else begin
                  fork
                     bus_drv0.drive_datax(data[0]);
                     bus_drv1.drive_datax(chksum[7:0]);
	             data_h.push_front(data[0]);
                  join
                  // last beat inline: [data0, CRC_lo] — CRC_hi handled in CRC section
                  if (passthrough_en == "ON") begin
                     $fwrite(f,"%04x\n%04x\n", {1'b0, tlast_val, vc, vcx, data[0]}, {1'b0, tlast_val, vc, vcx, chksum[7:0]});
                     $fwrite(f_mask, "1\n1\n");
                  end else if (uvsi_en == "ON")
                     $fwrite(f,"%0x\n",data[0]);
               end               
            end 
            else if (active_dphy_lanes == 3) begin
               if (iterations_r == active_dphy_lanes) begin
               fork
                  bus_drv0.drive_datax(data[0]);
                  bus_drv1.drive_datax(data[1]);
                  bus_drv2.drive_datax(data[2]);
	             data_h.push_front(data[0]);
	             data_h.push_front(data[1]);
	             data_h.push_front(data[2]);
               join
                  if (passthrough_en == "ON") begin
                     $fwrite(f,"%04x\n%04x\n%04x\n", {1'b0, tlast_val, vc, vcx, data[0]}, {1'b0, tlast_val, vc, vcx, data[1]}, {1'b0, tlast_val, vc, vcx, data[2]});
                     $fwrite(f_mask, "1\n1\n1\n");
                  end else if (uvsi_en == "ON")
                     $fwrite(f,"%0x\n%0x\n%0x\n",data[0],data[1],data[2]);
               end
               else if (iterations_r == (active_dphy_lanes - 1)) begin
                  fork
                     bus_drv0.drive_datax(data[0]);
                     bus_drv1.drive_datax(data[1]);
                     bus_drv2.drive_datax(chksum[7:0]);
	             data_h.push_front(data[0]);
	             data_h.push_front(data[1]);
                  join
                  // last beat inline: [data0, data1, CRC_lo] — CRC_hi in CRC section
                  if (passthrough_en == "ON") begin
                     $fwrite(f,"%04x\n%04x\n%04x\n", {1'b0, tlast_val, vc, vcx, data[0]}, {1'b0, tlast_val, vc, vcx, data[1]}, {1'b0, tlast_val, vc, vcx, chksum[7:0]});
                     $fwrite(f_mask, "1\n1\n1\n");
                  end else if (uvsi_en == "ON")
                     $fwrite(f,"%0x\n%0x\n",data[0],data[1]);
               end
               else if (iterations_r == (active_dphy_lanes - 2)) begin
                  fork
                     bus_drv0.drive_datax(data[0]);
                     bus_drv1.drive_datax(chksum[7:0]);
                     bus_drv2.drive_datax(chksum[15:8]);
	             data_h.push_front(data[0]);
                  join
                  // last beat inline: [data0, CRC_lo, CRC_hi] — all tlast=1, all valid
                  if (passthrough_en == "ON") begin
                     $fwrite(f,"%04x\n%04x\n%04x\n", {1'b0, 1'b1, vc, vcx, data[0]}, {1'b0, 1'b1, vc, vcx, chksum[7:0]}, {1'b0, 1'b1, vc, vcx, chksum[15:8]});
                     $fwrite(f_mask, "1\n1\n1\n");
                  end else if (uvsi_en == "ON")
                     $fwrite(f,"%0x\n",data[0]);
               end
            end
            else if (active_dphy_lanes == 4) begin
               if (iterations_r == active_dphy_lanes) begin
               fork
                  bus_drv0.drive_datax(data[0]);
                  bus_drv1.drive_datax(data[1]);
                  bus_drv2.drive_datax(data[2]);
                  bus_drv3.drive_datax(data[3]);
	             data_h.push_front(data[0]);
	             data_h.push_front(data[1]);
	             data_h.push_front(data[2]);
	             data_h.push_front(data[3]);
               join
                  if (passthrough_en == "ON") begin
                     $fwrite(f,"%04x\n%04x\n%04x\n%04x\n", {1'b0, tlast_val, vc, vcx, data[0]}, {1'b0, tlast_val, vc, vcx, data[1]}, {1'b0, tlast_val, vc, vcx, data[2]}, {1'b0, tlast_val, vc, vcx, data[3]});
                     $fwrite(f_mask, "1\n1\n1\n1\n");
                  end else if (uvsi_en == "ON")
                     $fwrite(f,"%0x\n%0x\n%0x\n%0x\n",data[0],data[1],data[2],data[3]);
               end
               else if (iterations_r == (active_dphy_lanes - 1)) begin
                  fork
                     bus_drv0.drive_datax(data[0]);
                     bus_drv1.drive_datax(data[1]);
                     bus_drv2.drive_datax(data[2]);
                     bus_drv3.drive_datax(chksum[7:0]);
	             data_h.push_front(data[0]);
	             data_h.push_front(data[1]);
	             data_h.push_front(data[2]);
                  join
                  // last beat inline: [data0, data1, data2, CRC_lo] — CRC_hi in CRC section
                  if (passthrough_en == "ON") begin
                     $fwrite(f,"%04x\n%04x\n%04x\n%04x\n", {1'b0, tlast_val, vc, vcx, data[0]}, {1'b0, tlast_val, vc, vcx, data[1]}, {1'b0, tlast_val, vc, vcx, data[2]}, {1'b0, tlast_val, vc, vcx, chksum[7:0]});
                     $fwrite(f_mask, "1\n1\n1\n1\n");
                  end else if (uvsi_en == "ON")
                     $fwrite(f,"%0x\n%0x\n%0x\n",data[0],data[1],data[2]);
               end
               else if (iterations_r == (active_dphy_lanes - 2)) begin
                  fork
                     bus_drv0.drive_datax(data[0]);
                     bus_drv1.drive_datax(data[1]);
                     bus_drv2.drive_datax(chksum[7:0]);
                     bus_drv3.drive_datax(chksum[15:8]);
	             data_h.push_front(data[0]);
	             data_h.push_front(data[1]);
                  join
                  // last beat inline: [data0, data1, CRC_lo, CRC_hi] — all tlast=1, all valid
                  if (passthrough_en == "ON") begin
                     $fwrite(f,"%04x\n%04x\n%04x\n%04x\n", {1'b0, 1'b1, vc, vcx, data[0]}, {1'b0, 1'b1, vc, vcx, data[1]}, {1'b0, 1'b1, vc, vcx, chksum[7:0]}, {1'b0, 1'b1, vc, vcx, chksum[15:8]});
                     $fwrite(f_mask, "1\n1\n1\n1\n");
                  end else if (uvsi_en == "ON")
                     $fwrite(f,"%0x\n%0x\n",data[0],data[1]);
               end
               else if (iterations_r == (active_dphy_lanes - 3)) begin
                  fork
                     bus_drv0.drive_datax(data[0]);
                     bus_drv1.drive_datax(chksum[7:0]);
                     bus_drv2.drive_datax(chksum[15:8]);
                     bus_drv3.drv_trail;
	             data_h.push_front(data[0]);
                  join
                  // last beat inline: [data0, CRC_lo, CRC_hi, trail] — trail=pad
                  if (passthrough_en == "ON") begin
                     $fwrite(f,"%04x\n%04x\n%04x\n%04x\n", {1'b0, 1'b1, vc, vcx, data[0]}, {1'b0, 1'b1, vc, vcx, chksum[7:0]}, {1'b0, 1'b1, vc, vcx, chksum[15:8]}, {1'b0, 1'b1, vc, vcx, 8'h00});
                     $fwrite(f_mask, "1\n1\n1\n0\n");
                  end else if (uvsi_en == "ON")
                     $fwrite(f,"%0x\n",data[0]);
               end                  
            end
         end

         // drive crc data until end of packet
         $display("%t DPHY [%0d] Driving CRC[15:8] = %0x; CRC[7:0] = %0x", $time, dphy_ch, chksum[15:8], chksum[7:0]);
         if (active_dphy_lanes == 1) begin
            bus_drv0.drive_datax(chksum[7:0]);
            bus_drv0.drive_datax(chksum[15:8]);
            // 1-lane: two separate 1-byte last beats, each with tlast=1
            if (passthrough_en == "ON") begin
               $fwrite(f,"%04x\n%04x\n", {1'b0, 1'b1, vc, vcx, chksum[7:0]}, {1'b0, 1'b1, vc, vcx, chksum[15:8]});
               $fwrite(f_mask, "1\n1\n");
               n_extra_pads = n_total_pads;
               for (pad_i = 0; pad_i < n_extra_pads; pad_i = pad_i + 1) begin
                  $fwrite(f,"%04x\n", {1'b0, 1'b1, vc, vcx, 8'h00});
                  $fwrite(f_mask, "0\n");
               end
            end
         end 
         else if (active_dphy_lanes == 2) begin
            if (iterations_r == active_dphy_lanes) begin
            fork
               bus_drv0.drive_datax(chksum[7:0]);
               bus_drv1.drive_datax(chksum[15:8]);
            join 
            end
            else begin
               fork
                  bus_drv0.drive_datax(chksum[15:8]);
                  bus_drv1.drv_trail;
               join
            end
            if (iterations_r == active_dphy_lanes) begin
               // last beat: [CRC_lo, CRC_hi] — both valid
               if (passthrough_en == "ON") begin
                  $fwrite(f,"%04x\n%04x\n", {1'b0, 1'b1, vc, vcx, chksum[7:0]}, {1'b0, 1'b1, vc, vcx, chksum[15:8]});
                  $fwrite(f_mask, "1\n1\n");
                  n_extra_pads = n_total_pads;
                  for (pad_i = 0; pad_i < n_extra_pads; pad_i = pad_i + 1) begin
                     $fwrite(f,"%04x\n", {1'b0, 1'b1, vc, vcx, 8'h00});
                     $fwrite(f_mask, "0\n");
                  end
               end
            end else begin
               // last beat: [CRC_hi, trail] — trail=pad
               if (passthrough_en == "ON") begin
                  $fwrite(f,"%04x\n%04x\n", {1'b0, 1'b1, vc, vcx, chksum[15:8]}, {1'b0, 1'b1, vc, vcx, 8'h00});
                  $fwrite(f_mask, "1\n0\n");
                  n_extra_pads = (n_total_pads > 1) ? n_total_pads - 1 : 0;
                  for (pad_i = 0; pad_i < n_extra_pads; pad_i = pad_i + 1) begin
                     $fwrite(f,"%04x\n", {1'b0, 1'b1, vc, vcx, 8'h00});
                     $fwrite(f_mask, "0\n");
                  end
               end
            end
         end 
         else if (active_dphy_lanes == 3) begin
            if (iterations_r == active_dphy_lanes) begin
               fork
                  bus_drv0.drive_datax(chksum[7:0]);
                  bus_drv1.drive_datax(chksum[15:8]);
                  bus_drv2.drv_trail;
               join
            end
            else if (iterations_r == (active_dphy_lanes -1)) begin
              fork
                 bus_drv0.drive_datax(chksum[15:8]);
                 bus_drv1.drv_trail;
                 bus_drv2.drv_trail;
              join 
            end 
            else begin
               fork
                  bus_drv0.drv_trail;
                  bus_drv1.drv_trail;
                  bus_drv2.drv_trail; 
               join
            end
            if (passthrough_en == "ON") begin
               if (iterations_r == active_dphy_lanes) begin
                  // last beat: [CRC_lo, CRC_hi, trail] — trail=pad
                  $fwrite(f,"%04x\n%04x\n%04x\n", {1'b0, 1'b1, vc, vcx, chksum[7:0]}, {1'b0, 1'b1, vc, vcx, chksum[15:8]}, {1'b0, 1'b1, vc, vcx, 8'h00});
                  $fwrite(f_mask, "1\n1\n0\n");
               end else if (iterations_r == (active_dphy_lanes - 1)) begin
                  // last beat: [CRC_hi, trail, trail] — all pad except CRC_hi
                  $fwrite(f,"%04x\n%04x\n%04x\n", {1'b0, 1'b1, vc, vcx, chksum[15:8]}, {1'b0, 1'b1, vc, vcx, 8'h00}, {1'b0, 1'b1, vc, vcx, 8'h00});
                  $fwrite(f_mask, "1\n0\n0\n");
               end
            end
         end
         else if (active_dphy_lanes == 4) begin
            if (iterations_r == active_dphy_lanes) begin
               fork
                  bus_drv0.drive_datax(chksum[7:0]);
                  bus_drv1.drive_datax(chksum[15:8]);
                  bus_drv2.drv_trail;
                  bus_drv3.drv_trail;
               join
            end
            else if (iterations_r == (active_dphy_lanes -1)) begin
               fork
                  bus_drv0.drive_datax(chksum[15:8]);
                  bus_drv1.drv_trail;
                  bus_drv2.drv_trail;
                  bus_drv3.drv_trail;
               join 
            end
            if (passthrough_en == "ON") begin
               if (iterations_r == active_dphy_lanes) begin
                  // last beat: [CRC_lo, CRC_hi, trail, trail] — trail bytes=pad
                  $fwrite(f,"%04x\n%04x\n%04x\n%04x\n", {1'b0, 1'b1, vc, vcx, chksum[7:0]}, {1'b0, 1'b1, vc, vcx, chksum[15:8]}, {1'b0, 1'b1, vc, vcx, 8'h00}, {1'b0, 1'b1, vc, vcx, 8'h00});
                  $fwrite(f_mask, "1\n1\n0\n0\n");
                  n_extra_pads = (n_total_pads > 2) ? n_total_pads - 2 : 0;
                  for (pad_i = 0; pad_i < n_extra_pads; pad_i = pad_i + 1) begin
                     $fwrite(f,"%04x\n", {1'b0, 1'b1, vc, vcx, 8'h00});
                     $fwrite(f_mask, "0\n");
                  end
               end else if (iterations_r == (active_dphy_lanes - 1)) begin
                  // last beat: [CRC_hi, trail, trail, trail] — trail bytes=pad
                  $fwrite(f,"%04x\n%04x\n%04x\n%04x\n", {1'b0, 1'b1, vc, vcx, chksum[15:8]}, {1'b0, 1'b1, vc, vcx, 8'h00}, {1'b0, 1'b1, vc, vcx, 8'h00}, {1'b0, 1'b1, vc, vcx, 8'h00});
                  $fwrite(f_mask, "1\n0\n0\n0\n");
                  n_extra_pads = (n_total_pads > 3) ? n_total_pads - 3 : 0;
                  for (pad_i = 0; pad_i < n_extra_pads; pad_i = pad_i + 1) begin
                     $fwrite(f,"%04x\n", {1'b0, 1'b1, vc, vcx, 8'h00});
                     $fwrite(f_mask, "0\n");
                  end
               end else begin
                  fork
                     bus_drv0.drv_trail;
                     bus_drv1.drv_trail;
                     bus_drv2.drv_trail;
                     bus_drv3.drv_trail;
                  join
                  // inline CRC case: extra pads beyond the lane-cycle trail entries
                  n_extra_pads = (n_total_pads > (active_dphy_lanes - iterations_r - 2)) ? n_total_pads - (active_dphy_lanes - iterations_r - 2) : 0;
                  for (pad_i = 0; pad_i < n_extra_pads; pad_i = pad_i + 1) begin
                     $fwrite(f,"%04x\n", {1'b0, 1'b1, vc, vcx, 8'h00});
                     $fwrite(f_mask, "0\n");
                  end
               end
            end
         end


         #t_hs_trail;

         // HS-Stop
         //@(clk_p_io);
		 d_weak = 1;
         fork
            bus_drv0.drv_stop;
            begin
               if (active_dphy_lanes == 2) begin
                  bus_drv1.drv_stop;
               end
            end
            begin
               if (active_dphy_lanes == 3) begin
                  bus_drv1.drv_stop;
                  bus_drv2.drv_stop;
               end
            end
            begin
               if (active_dphy_lanes == 4) begin
                  fork
                     bus_drv1.drv_stop;
                     bus_drv2.drv_stop;
                     bus_drv3.drv_stop;
                  join
               end
            end
         join

         #t_clk_post; // based from waveform
         clk_en = 0;

      
     end
   join
end
endtask

task compute_crc16(input [7:0] data);
begin
   for (n = 0; n < 8; n = n + 1) begin
     cur_crc = chksum;
     cur_crc[15] = data[n]^cur_crc[0];
     cur_crc[10] = cur_crc[11]^cur_crc[15];
     cur_crc[3]  = cur_crc[4]^cur_crc[15]; 
     chksum = chksum >> 1;
     chksum[15] = cur_crc[15];
     chksum[10] = cur_crc[10];
     chksum[3] = cur_crc[3];
   end
end
endtask

task pre_data(input [1:0] mode);
begin
   // mode 0: B8 - Normal Packet
   // mode 1: FFFF - Skew Calibration
   // mode 2: FF00 - Alternate Skew Calibration
   
   @(posedge clk_en);

   #t_clk_pre;

   // HS-RQST
   if(debug) begin
     $display("%t DPHY [%0d] DATA : Driving HS-RQST", $time, dphy_ch);
   end
    bus_drv0.drv_dat_st(0,1);
    if (active_dphy_lanes == 2) begin
    bus_drv1.drv_dat_st(0,1);
    end else
    if (active_dphy_lanes == 3) begin
    bus_drv1.drv_dat_st(0,1);
    bus_drv2.drv_dat_st(0,1);
    end else
    if (active_dphy_lanes == 4) begin
    bus_drv1.drv_dat_st(0,1);
    bus_drv2.drv_dat_st(0,1);
    bus_drv3.drv_dat_st(0,1);
    end
   #t_lpx;

   // HS-Prpr
   if(debug) begin
     $display("%t DPHY [%0d] DATA : Driving HS-Prpr", $time, dphy_ch);
   end
    bus_drv0.drv_dat_st(0,0);
    if (active_dphy_lanes == 2) begin
    bus_drv1.drv_dat_st(0,0);
    end else
    if (active_dphy_lanes == 3) begin
    bus_drv1.drv_dat_st(0,0);
    bus_drv2.drv_dat_st(0,0);
    end else
    if (active_dphy_lanes == 4) begin
    bus_drv1.drv_dat_st(0,0);
    bus_drv2.drv_dat_st(0,0);
    bus_drv3.drv_dat_st(0,0);
    end
   #t_hs_prepare;

   // HS-Go
   if(debug) begin
     $display("%t DPHY [%0d] CLK : Driving HS-Go", $time, dphy_ch);
   end
    d_weak = 0;
    bus_drv0.drv_dat_st(0,1);
    if (active_dphy_lanes == 2) begin
    bus_drv1.drv_dat_st(0,1);
    end else
    if (active_dphy_lanes == 3) begin
    bus_drv1.drv_dat_st(0,1);
    bus_drv2.drv_dat_st(0,1);
    end else
    if (active_dphy_lanes == 4) begin
    bus_drv1.drv_dat_st(0,1);
    bus_drv2.drv_dat_st(0,1);
    bus_drv3.drv_dat_st(0,1);
    end
   #t_hs_zero;

   //sync with clock
   @(posedge clk_p_io);
   
   if (mode == 0) begin
       // HS-Sync
       // generate data (B8)
       for (i = 0; i < active_dphy_lanes; i = i + 1) begin
           data[i] = 8'hB8;
       end
       
       if(debug) begin
         $display("%t DPHY [%0d] CLK : Driving SYNC Data", $time, dphy_ch);
       end
       if (active_dphy_lanes == 1) begin
           bus_drv0.drive_datax(data[0]);
       end else
       if (active_dphy_lanes == 2) begin
       fork
           bus_drv0.drive_datax(data[0]);
           bus_drv1.drive_datax(data[1]);
       join
       end else
       if (active_dphy_lanes == 3) begin
       fork
           bus_drv0.drive_datax(data[0]);
           bus_drv1.drive_datax(data[1]);
           bus_drv2.drive_datax(data[2]);
       join
       end else
       if (active_dphy_lanes == 4) begin
         fork
             bus_drv0.drive_datax(data[0]);
             bus_drv1.drive_datax(data[1]);
             bus_drv2.drive_datax(data[2]);
             bus_drv3.drive_datax(data[3]);
         join
       end
   end else if (mode == 1) begin
       // Skew Calibration
       // generate data (FFFF)
	   for (j = 0; j <= 1; j = j + 1) begin
           for (i = 0; i < active_dphy_lanes; i = i + 1) begin
               data[i] = 8'hFF;
           end
           
           if(debug) begin
             $display("%t DPHY [%0d] CLK : Driving SKEW CALIBRATION Data", $time, dphy_ch);
           end
           if (active_dphy_lanes == 1) begin
               bus_drv0.drive_datax(data[0]);
           end else
           if (active_dphy_lanes == 2) begin
           fork
               bus_drv0.drive_datax(data[0]);
               bus_drv1.drive_datax(data[1]);
           join
           end else
           if (active_dphy_lanes == 3) begin
           fork
               bus_drv0.drive_datax(data[0]);
               bus_drv1.drive_datax(data[1]);
               bus_drv2.drive_datax(data[2]);
           join
           end else
           if (active_dphy_lanes == 4) begin
             fork
                 bus_drv0.drive_datax(data[0]);
                 bus_drv1.drive_datax(data[1]);
                 bus_drv2.drive_datax(data[2]);
                 bus_drv3.drive_datax(data[3]);
             join
           end
	   end
   end else if (mode == 2) begin
       // Alternate Calibration
       // generate data (0F)
       for (i = 0; i < active_dphy_lanes; i = i + 1) begin
           data[i] = 8'h0F;
       end
       
       if(debug) begin
         $display("%t DPHY [%0d] CLK : Driving ALTERNATE CALIBRATION Data", $time, dphy_ch);
       end
       if (active_dphy_lanes == 1) begin
           bus_drv0.drive_datax(data[0]);
       end else
       if (active_dphy_lanes == 2) begin
       fork
           bus_drv0.drive_datax(data[0]);
           bus_drv1.drive_datax(data[1]);
       join
       end else
       if (active_dphy_lanes == 3) begin
       fork
           bus_drv0.drive_datax(data[0]);
           bus_drv1.drive_datax(data[1]);
           bus_drv2.drive_datax(data[2]);
       join
       end else
       if (active_dphy_lanes == 4) begin
         fork
             bus_drv0.drive_datax(data[0]);
             bus_drv1.drive_datax(data[1]);
             bus_drv2.drive_datax(data[2]);
             bus_drv3.drive_datax(data[3]);
         join
       end
   end
end
endtask

task drive_trail;
begin
   if(debug) begin
     $display("%t DPHY [%0d] DATA : Driving HS-Trail", $time, dphy_ch);
   end
   #t_hs_trail;

   // HS-Stop
   if(debug) begin
     $display("%t DPHY [%0d] DATA : Driving HS-Stop", $time, dphy_ch);
   end
   d_weak = 1;
   fork
         bus_drv0.drv_stop;
         begin
             if (active_dphy_lanes == 2) begin
                 bus_drv1.drv_stop;
             end 
         end
         begin
             if (active_dphy_lanes == 3) begin
                 bus_drv1.drv_stop;
                 bus_drv2.drv_stop;
             end 
         end
         begin
             if (active_dphy_lanes == 4) begin
                fork
                    bus_drv1.drv_stop;
                    bus_drv2.drv_stop;
                    bus_drv3.drv_stop;
                join
             end
         end
   join

         #t_clk_post; // based from waveform
         clk_en = 0;

end
endtask

task post_data;
begin
   // HS-Trail
   if(debug) begin
     $display("%t DPHY [%0d] DATA : Driving HS-Trail", $time, dphy_ch);
   end
   fork
         bus_drv0.drv_trail;
         begin
            if (active_dphy_lanes == 2) begin
               bus_drv1.drv_trail;
            end
         end
         begin
            if (active_dphy_lanes == 3) begin
               bus_drv1.drv_trail;
               bus_drv2.drv_trail;
            end
         end
         begin
            if (active_dphy_lanes == 4) begin
               fork
                   bus_drv1.drv_trail;
                   bus_drv2.drv_trail;
                   bus_drv3.drv_trail;
               join
            end
         end
   join
   #t_hs_trail;

   // HS-Stop
   if(debug) begin
     $display("%t DPHY [%0d] DATA : Driving HS-Stop", $time, dphy_ch);
   end
   d_weak = 1;
   fork
         bus_drv0.drv_stop;
         begin
             if (active_dphy_lanes == 2) begin
                 bus_drv1.drv_stop;
             end 
         end
         begin
             if (active_dphy_lanes == 3) begin
                 bus_drv1.drv_stop;
                 bus_drv2.drv_stop;
             end 
         end
         begin
             if (active_dphy_lanes == 4) begin
                fork
                    bus_drv1.drv_stop;
                    bus_drv2.drv_stop;
                    bus_drv3.drv_stop;
                join
             end
         end
   join

         #t_clk_post; // based from waveform
         clk_en = 0;
end
endtask

always @(wc) begin
   BPC = (wc % active_dphy_lanes == 0)? (wc)/active_dphy_lanes : (wc)/active_dphy_lanes + 1;
end
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

// Build the 8-bit CSI-2 ECC byte for a VCX-bearing packet: {VCX[1:0], ECC[5:0]} where the
// 6-bit ECC is computed over the full 26-bit header {VCX, WC_H, WC_L, DI} (CSI-2 spec, VCX
// enabled). This is the 24-bit ECC (ecc24, from get_ecc) with the two VCX bits (ph[25:24])
// folded into the parity per the DUT's 26-bit syndrome matrix (rtl/common/lscc_ecc_check.v):
//   bit0 += vcx[0]; bit1 += vcx[1]; bits[5:2] += (vcx[0]^vcx[1]).
// Without this fold, a nonzero VCX leaves a stale 24-bit ECC, so a vcx_on receiver computes a
// nonzero syndrome and error-"corrects" the header (corrupting VCX and, for vcx=3, the word
// count). Folding it makes syndrome==0 so VCX and WC pass through intact.
function [7:0] ecc_with_vcx (input [5:0] ecc24, input [1:0] vcx);
  reg [5:0] e;
begin
  e[0] = ecc24[0] ^ vcx[0];
  e[1] = ecc24[1] ^ vcx[1];
  e[2] = ecc24[2] ^ vcx[0] ^ vcx[1];
  e[3] = ecc24[3] ^ vcx[0] ^ vcx[1];
  e[4] = ecc24[4] ^ vcx[0] ^ vcx[1];
  e[5] = ecc24[5] ^ vcx[0] ^ vcx[1];
  ecc_with_vcx = {vcx, e};
end
endfunction

task drive_data_HS(input dp);
begin
    bus_drv0.drv_dat_st(dp,~dp);
	if (active_dphy_lanes > 1) bus_drv1.drv_dat_st(dp,~dp);
	if (active_dphy_lanes > 2) bus_drv2.drv_dat_st(dp,~dp);
	if (active_dphy_lanes > 3) bus_drv3.drv_dat_st(dp,~dp);
end
endtask

task drive_skewcal();
begin
	automatic reg [31:0] skewcal_ui_ctr = 32'd0;
	fork
	    begin
		    drive_clk;
		end
	    begin
		    pre_data(1);
	        #(dphy_clk_period/2);
	        drive_data_HS(0);
	        while (skewcal_ui_ctr < (skewcal_ui - 1)) begin
	            skewcal_ui_ctr = skewcal_ui_ctr + 1'b1;
	        	#(dphy_clk_period/2);
	        	drive_data_HS(~bus_drv0.do_p_i);
	        end
	        #(dphy_clk_period/2);
			post_data;
	    end
	join
end
endtask

task drive_altcal();
begin
	automatic reg [31:0] altcal_ui_ctr   = 32'd0;
	automatic reg [8:0]  prbs9_shift_reg =  9'b011111111;
	fork
	    begin
		    drive_clk;
		end
	    begin
		    pre_data(2);
	        #(dphy_clk_period/2);
	        drive_data_HS(prbs9_shift_reg[8]^prbs9_shift_reg[4]);
	        while (altcal_ui_ctr < (altcal_ui - 1)) begin
	            altcal_ui_ctr   = altcal_ui_ctr + 1'b1;
				prbs9_shift_reg = {prbs9_shift_reg[7:0],(prbs9_shift_reg[8]^prbs9_shift_reg[4])};
	        	#(dphy_clk_period/2);
	        	drive_data_HS(prbs9_shift_reg[8]^prbs9_shift_reg[4]);
	        end
	        #(dphy_clk_period/2);
			post_data;
	    end
	join
end
endtask

endmodule
`endif
