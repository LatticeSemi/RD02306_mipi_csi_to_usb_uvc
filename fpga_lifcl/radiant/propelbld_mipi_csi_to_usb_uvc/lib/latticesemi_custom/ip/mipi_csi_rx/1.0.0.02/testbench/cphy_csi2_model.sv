//===========================================================================
// Filename: cphy_csi2_model.sv
// Copyright(c) 2025 Lattice Semiconductor Corporation. All rights reserved. 
//===========================================================================
`ifndef CPHY_CSI2_MODEL
`define CPHY_CSI2_MODEL

`timescale 1ps / 1ps

module cphy_csi2_model #(
    parameter NUM_RX_LANE = 3,
    parameter UI          = 286,
    parameter NUM_FRAMES  = 2,
    parameter NUM_PIXELS  = 1920,
    parameter NUM_LINES   = 8,
    parameter VID_DT      = 6'h3E,
    parameter BPP         = 24,
    parameter VC_ID       = 2'h0,
    parameter T_FRAME_GAP = 5000000,
    parameter T_INIT      = 100000,
    parameter T_LPX       = 60000,
    parameter T3_PREPARE  = 50000,
	parameter T3_PREAMBLE = 28*UI,
    parameter T3_POST     = 224*UI,
	parameter CSI_LS_LE   = "ON",
	parameter CSI_T_LPS   = 100000
) (
    input       tb_reset_n,
    inout [2:0] d_a_io,
    inout [2:0] d_b_io,
    inout [2:0] d_c_io
);

// Localparam
localparam     CSI_VACT_WC    = NUM_PIXELS * BPP / 8;
localparam int T3_PREAMBLE_UI = int'($ceil(T3_PREAMBLE/UI));
localparam int T3_POST_UI     = int'($ceil(T3_POST/UI));

// Signals
reg [2:0]  d_a_i;
reg [2:0]  d_b_i;
reg [2:0]  d_c_i;
reg        d_weak_0    = 1'b1;
reg        d_weak_1    = 1'b1;
reg        d_weak_2    = 1'b1;
reg [15:0] crc16;
reg [15:0] new_crc16;
reg        cphy_active = 1'b0;
reg [8:0]  packet_data []; // {sync,data[7:0]}

integer packet_pointer,packet_bytes,i,j,k,l;
integer f = $fopen("tb_expected_data.txt","w");

// Drive Strength
assign (pull0, pull1) d_a_io[0] = d_a_i[0];
assign (pull0, pull1) d_b_io[0] = d_b_i[0];
assign (pull0, pull1) d_c_io[0] = d_c_i[0];
assign (pull0, pull1) d_a_io[1] = d_a_i[1];
assign (pull0, pull1) d_b_io[1] = d_b_i[1];
assign (pull0, pull1) d_c_io[1] = d_c_i[1];
assign (pull0, pull1) d_a_io[2] = d_a_i[2];
assign (pull0, pull1) d_b_io[2] = d_b_i[2];
assign (pull0, pull1) d_c_io[2] = d_c_i[2];
assign                d_a_io[0] = (~d_weak_0) ? d_a_i[0] : 1'bz;
assign                d_b_io[0] = (~d_weak_0) ? d_b_i[0] : 1'bz;
assign                d_c_io[0] = (~d_weak_0) ? d_c_i[0] : 1'bz;
assign                d_a_io[1] = (~d_weak_1) ? d_a_i[1] : 1'bz;
assign                d_b_io[1] = (~d_weak_1) ? d_b_i[1] : 1'bz;
assign                d_c_io[1] = (~d_weak_1) ? d_c_i[1] : 1'bz;
assign                d_a_io[2] = (~d_weak_2) ? d_a_i[2] : 1'bz;
assign                d_b_io[2] = (~d_weak_2) ? d_b_i[2] : 1'bz;
assign                d_c_io[2] = (~d_weak_2) ? d_c_i[2] : 1'bz;

// Drive Single Symbol
task drive_symbol_lane0 (input [2:0] sym);
    reg [2:0] tmp;
	reg [2:0] out;
	#(1);
	tmp = {d_a_i[0],d_b_i[0],d_c_i[0]};
    #(UI-1);
	case (sym)
	    0:
		begin
		    if (tmp == 3'b100)
			    out = 3'b001;
			else if (tmp == 3'b011)
			    out = 3'b110;
			else if (tmp == 3'b010)
			    out = 3'b100;
			else if (tmp == 3'b101)
			    out = 3'b011;
			else if (tmp == 3'b001)
			    out = 3'b010;
			else if (tmp == 3'b110)
			    out = 3'b101;
		end
		
		1:
		begin
		    if (tmp == 3'b100)
			    out = 3'b110;
			else if (tmp == 3'b011)
			    out = 3'b001;
			else if (tmp == 3'b010)
			    out = 3'b011;
			else if (tmp == 3'b101)
			    out = 3'b100;
			else if (tmp == 3'b001)
			    out = 3'b101;
			else if (tmp == 3'b110)
			    out = 3'b010;
		end
		
		2:
		begin
		    if (tmp == 3'b100)
			    out = 3'b010;
			else if (tmp == 3'b011)
			    out = 3'b101;
			else if (tmp == 3'b010)
			    out = 3'b001;
			else if (tmp == 3'b101)
			    out = 3'b110;
			else if (tmp == 3'b001)
			    out = 3'b100;
			else if (tmp == 3'b110)
			    out = 3'b011;
		end
		
		3:
		begin
		    if (tmp == 3'b100)
			    out = 3'b101;
			else if (tmp == 3'b011)
			    out = 3'b010;
			else if (tmp == 3'b010)
			    out = 3'b110;
			else if (tmp == 3'b101)
			    out = 3'b001;
			else if (tmp == 3'b001)
			    out = 3'b011;
			else if (tmp == 3'b110)
			    out = 3'b100;
		end
		
		4:
		begin
		    if (tmp == 3'b100)
			    out = 3'b011;
			else if (tmp == 3'b011)
			    out = 3'b100;
			else if (tmp == 3'b010)
			    out = 3'b101;
			else if (tmp == 3'b101)
			    out = 3'b010;
			else if (tmp == 3'b001)
			    out = 3'b110;
			else if (tmp == 3'b110)
			    out = 3'b001;
		end
	endcase
	d_a_i[0] = out[2];
	d_b_i[0] = out[1];
	d_c_i[0] = out[0];
endtask

task drive_symbol_lane1 (input [2:0] sym);
    reg [2:0] tmp;
	reg [2:0] out;
	#(1);
	tmp = {d_a_i[1],d_b_i[1],d_c_i[1]};
    #(UI-1);
	case (sym)
	    0:
		begin
		    if (tmp == 3'b100)
			    out = 3'b001;
			else if (tmp == 3'b011)
			    out = 3'b110;
			else if (tmp == 3'b010)
			    out = 3'b100;
			else if (tmp == 3'b101)
			    out = 3'b011;
			else if (tmp == 3'b001)
			    out = 3'b010;
			else if (tmp == 3'b110)
			    out = 3'b101;
		end
		
		1:
		begin
		    if (tmp == 3'b100)
			    out = 3'b110;
			else if (tmp == 3'b011)
			    out = 3'b001;
			else if (tmp == 3'b010)
			    out = 3'b011;
			else if (tmp == 3'b101)
			    out = 3'b100;
			else if (tmp == 3'b001)
			    out = 3'b101;
			else if (tmp == 3'b110)
			    out = 3'b010;
		end
		
		2:
		begin
		    if (tmp == 3'b100)
			    out = 3'b010;
			else if (tmp == 3'b011)
			    out = 3'b101;
			else if (tmp == 3'b010)
			    out = 3'b001;
			else if (tmp == 3'b101)
			    out = 3'b110;
			else if (tmp == 3'b001)
			    out = 3'b100;
			else if (tmp == 3'b110)
			    out = 3'b011;
		end
		
		3:
		begin
		    if (tmp == 3'b100)
			    out = 3'b101;
			else if (tmp == 3'b011)
			    out = 3'b010;
			else if (tmp == 3'b010)
			    out = 3'b110;
			else if (tmp == 3'b101)
			    out = 3'b001;
			else if (tmp == 3'b001)
			    out = 3'b011;
			else if (tmp == 3'b110)
			    out = 3'b100;
		end
		
		4:
		begin
		    if (tmp == 3'b100)
			    out = 3'b011;
			else if (tmp == 3'b011)
			    out = 3'b100;
			else if (tmp == 3'b010)
			    out = 3'b101;
			else if (tmp == 3'b101)
			    out = 3'b010;
			else if (tmp == 3'b001)
			    out = 3'b110;
			else if (tmp == 3'b110)
			    out = 3'b001;
		end
	endcase
	d_a_i[1] = out[2];
	d_b_i[1] = out[1];
	d_c_i[1] = out[0];
endtask

task drive_symbol_lane2 (input [2:0] sym);
    reg [2:0] tmp;
	reg [2:0] out;
	#(1);
	tmp = {d_a_i[2],d_b_i[2],d_c_i[2]};
    #(UI-1);
	case (sym)
	    0:
		begin
		    if (tmp == 3'b100)
			    out = 3'b001;
			else if (tmp == 3'b011)
			    out = 3'b110;
			else if (tmp == 3'b010)
			    out = 3'b100;
			else if (tmp == 3'b101)
			    out = 3'b011;
			else if (tmp == 3'b001)
			    out = 3'b010;
			else if (tmp == 3'b110)
			    out = 3'b101;
		end
		
		1:
		begin
		    if (tmp == 3'b100)
			    out = 3'b110;
			else if (tmp == 3'b011)
			    out = 3'b001;
			else if (tmp == 3'b010)
			    out = 3'b011;
			else if (tmp == 3'b101)
			    out = 3'b100;
			else if (tmp == 3'b001)
			    out = 3'b101;
			else if (tmp == 3'b110)
			    out = 3'b010;
		end
		
		2:
		begin
		    if (tmp == 3'b100)
			    out = 3'b010;
			else if (tmp == 3'b011)
			    out = 3'b101;
			else if (tmp == 3'b010)
			    out = 3'b001;
			else if (tmp == 3'b101)
			    out = 3'b110;
			else if (tmp == 3'b001)
			    out = 3'b100;
			else if (tmp == 3'b110)
			    out = 3'b011;
		end
		
		3:
		begin
		    if (tmp == 3'b100)
			    out = 3'b101;
			else if (tmp == 3'b011)
			    out = 3'b010;
			else if (tmp == 3'b010)
			    out = 3'b110;
			else if (tmp == 3'b101)
			    out = 3'b001;
			else if (tmp == 3'b001)
			    out = 3'b011;
			else if (tmp == 3'b110)
			    out = 3'b100;
		end
		
		4:
		begin
		    if (tmp == 3'b100)
			    out = 3'b011;
			else if (tmp == 3'b011)
			    out = 3'b100;
			else if (tmp == 3'b010)
			    out = 3'b101;
			else if (tmp == 3'b101)
			    out = 3'b010;
			else if (tmp == 3'b001)
			    out = 3'b110;
			else if (tmp == 3'b110)
			    out = 3'b001;
		end
	endcase
	d_a_i[2] = out[2];
	d_b_i[2] = out[1];
	d_c_i[2] = out[0];
endtask

// Drive 7 Symbols
task drive_7symbols_lane0 (input [2:0] sym6, input [2:0] sym5, input [2:0] sym4, input [2:0] sym3, input [2:0] sym2, input [2:0] sym1, input [2:0] sym0);
    drive_symbol_lane0(sym0);
    drive_symbol_lane0(sym1);
    drive_symbol_lane0(sym2);
    drive_symbol_lane0(sym3);
    drive_symbol_lane0(sym4);
    drive_symbol_lane0(sym5);
    drive_symbol_lane0(sym6);
endtask

task drive_7symbols_lane1 (input [2:0] sym6, input [2:0] sym5, input [2:0] sym4, input [2:0] sym3, input [2:0] sym2, input [2:0] sym1, input [2:0] sym0);
    drive_symbol_lane1(sym0);
    drive_symbol_lane1(sym1);
    drive_symbol_lane1(sym2);
    drive_symbol_lane1(sym3);
    drive_symbol_lane1(sym4);
    drive_symbol_lane1(sym5);
    drive_symbol_lane1(sym6);
endtask

task drive_7symbols_lane2 (input [2:0] sym6, input [2:0] sym5, input [2:0] sym4, input [2:0] sym3, input [2:0] sym2, input [2:0] sym1, input [2:0] sym0);
    drive_symbol_lane2(sym0);
    drive_symbol_lane2(sym1);
    drive_symbol_lane2(sym2);
    drive_symbol_lane2(sym3);
    drive_symbol_lane2(sym4);
    drive_symbol_lane2(sym5);
    drive_symbol_lane2(sym6);
endtask

task drive_16bits_lane0 (input [15:0] data);
    reg       flip6,ro6,po6;
    reg       flip5,ro5,po5;
    reg       flip4,ro4,po4;
    reg       flip3,ro3,po3;
    reg       flip2,ro2,po2;
    reg       flip1,ro1,po1;
    reg       flip0,ro0,po0;
	reg [2:0] sym6,sym5,sym4,sym3,sym2,sym1,sym0;
	
	if (data <= 16'h3FFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[13];
		po6   = data[12];
		ro5   = data[11];
		po5   = data[10];
		ro4   = data[9];
		po4   = data[8];
		ro3   = data[7];
		po3   = data[6];
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'h4FFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 1;
		ro6   = data[11];
		po6   = data[10];
		ro5   = data[9];
		po5   = data[8];
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = data[3];
		po2   = data[2];
		ro1   = data[1];
		po1   = data[0];
		ro0   = 0;
		po0   = 0;
	end else if (data <= 16'h5FFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 1;
	    flip0 = 0;
		ro6   = data[11];
		po6   = data[10];
		ro5   = data[9];
		po5   = data[8];
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = data[3];
		po2   = data[2];
		ro1   = 0;
		po1   = 0;
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'h6FFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 1;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[11];
		po6   = data[10];
		ro5   = data[9];
		po5   = data[8];
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = 0;
		po2   = 0;
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'h7FFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 1;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[11];
		po6   = data[10];
		ro5   = data[9];
		po5   = data[8];
		ro4   = data[7];
		po4   = data[6];
		ro3   = 0;
		po3   = 0;
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'h8FFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 1;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[11];
		po6   = data[10];
		ro5   = data[9];
		po5   = data[8];
		ro4   = 0;
		po4   = 0;
		ro3   = data[7];
		po3   = data[6];
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'h9FFF) begin
	    flip6 = 0;
	    flip5 = 1;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[11];
		po6   = data[10];
		ro5   = 0;
		po5   = 0;
		ro4   = data[9];
		po4   = data[8];
		ro3   = data[7];
		po3   = data[6];
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hAFFF) begin
	    flip6 = 1;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = 0;
		po6   = 0;
		ro5   = data[11];
		po5   = data[10];
		ro4   = data[9];
		po4   = data[8];
		ro3   = data[7];
		po3   = data[6];
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hB3FF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 1;
	    flip0 = 1;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = data[5];
		po4   = data[4];
		ro3   = data[3];
		po3   = data[2];
		ro2   = data[1];
		po2   = data[0];
		ro1   = 0;
		po1   = 0;
		ro0   = 0;
		po0   = 0;
	end else if (data <= 16'hB7FF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 1;
	    flip1 = 0;
	    flip0 = 1;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = data[5];
		po4   = data[4];
		ro3   = data[3];
		po3   = data[2];
		ro2   = 0;
		po2   = 0;
		ro1   = data[1];
		po1   = data[0];
		ro0   = 0;
		po0   = 0;
	end else if (data <= 16'hBBFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 1;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 1;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = data[5];
		po4   = data[4];
		ro3   = 0;
		po3   = 0;
		ro2   = data[3];
		po2   = data[2];
		ro1   = data[1];
		po1   = data[0];
		ro0   = 0;
		po0   = 0;
	end else if (data <= 16'hBFFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 1;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 1;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = 0;
		po4   = 0;
		ro3   = data[5];
		po3   = data[4];
		ro2   = data[3];
		po2   = data[2];
		ro1   = data[1];
		po1   = data[0];
		ro0   = 0;
		po0   = 0;
	end else if (data <= 16'hC3FF) begin
	    flip6 = 0;
	    flip5 = 1;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 1;
		ro6   = data[9];
		po6   = data[8];
		ro5   = 0;
		po5   = 0;
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = data[3];
		po2   = data[2];
		ro1   = data[1];
		po1   = data[0];
		ro0   = 0;
		po0   = 0;
	end else if (data <= 16'hC7FF) begin
	    flip6 = 1;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 1;
		ro6   = 0;
		po6   = 0;
		ro5   = data[9];
		po5   = data[8];
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = data[3];
		po2   = data[2];
		ro1   = data[1];
		po1   = data[0];
		ro0   = 0;
		po0   = 0;
	end else if (data <= 16'hCBFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 1;
	    flip1 = 1;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = data[5];
		po4   = data[4];
		ro3   = data[3];
		po3   = data[2];
		ro2   = 0;
		po2   = 0;
		ro1   = 0;
		po1   = 0;
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hCFFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 1;
	    flip2 = 0;
	    flip1 = 1;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = data[5];
		po4   = data[4];
		ro3   = 0;
		po3   = 0;
		ro2   = data[3];
		po2   = data[2];
		ro1   = 0;
		po1   = 0;
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hD3FF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 1;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 1;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = 0;
		po4   = 0;
		ro3   = data[5];
		po3   = data[4];
		ro2   = data[3];
		po2   = data[2];
		ro1   = 0;
		po1   = 0;
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hD7FF) begin
	    flip6 = 0;
	    flip5 = 1;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 1;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = 0;
		po5   = 0;
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = data[3];
		po2   = data[2];
		ro1   = 0;
		po1   = 0;
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hDBFF) begin
	    flip6 = 1;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 1;
	    flip0 = 0;
		ro6   = 0;
		po6   = 0;
		ro5   = data[9];
		po5   = data[8];
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = data[3];
		po2   = data[2];
		ro1   = 0;
		po1   = 0;
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hDFFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 1;
	    flip2 = 1;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = data[5];
		po4   = data[4];
		ro3   = 0;
		po3   = 0;
		ro2   = 0;
		po2   = 0;
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hE3FF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 1;
	    flip3 = 0;
	    flip2 = 1;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = 0;
		po4   = 0;
		ro3   = data[5];
		po3   = data[4];
		ro2   = 0;
		po2   = 0;
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hE7FF) begin
	    flip6 = 0;
	    flip5 = 1;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 1;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = 0;
		po5   = 0;
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = 0;
		po2   = 0;
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hEBFF) begin
	    flip6 = 1;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 1;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = 0;
		po6   = 0;
		ro5   = data[9];
		po5   = data[8];
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = 0;
		po2   = 0;
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hEFFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 1;
	    flip3 = 1;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = 0;
		po4   = 0;
		ro3   = 0;
		po3   = 0;
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hF3FF) begin
	    flip6 = 0;
	    flip5 = 1;
	    flip4 = 0;
	    flip3 = 1;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = 0;
		po5   = 0;
		ro4   = data[7];
		po4   = data[6];
		ro3   = 0;
		po3   = 0;
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hF7FF) begin
	    flip6 = 1;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 1;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = 0;
		po6   = 0;
		ro5   = data[9];
		po5   = data[8];
		ro4   = data[7];
		po4   = data[6];
		ro3   = 0;
		po3   = 0;
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hFBFF) begin
	    flip6 = 0;
	    flip5 = 1;
	    flip4 = 1;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = 0;
		po5   = 0;
		ro4   = 0;
		po4   = 0;
		ro3   = data[7];
		po3   = data[6];
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	//end else if (data <= 16'hFFFF) begin
	end else begin
	    flip6 = 1;
	    flip5 = 0;
	    flip4 = 1;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = 0;
		po6   = 0;
		ro5   = data[9];
		po5   = data[8];
		ro4   = 0;
		po4   = 0;
		ro3   = data[7];
		po3   = data[6];
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end
	
	case ({flip6,ro6,po6})
	    3'b000  : sym6 = 0;
	    3'b001  : sym6 = 1;
	    3'b010  : sym6 = 2;
	    3'b011  : sym6 = 3;
	    default : sym6 = 4;
	endcase
	
	case ({flip5,ro5,po5})
	    3'b000  : sym5 = 0;
	    3'b001  : sym5 = 1;
	    3'b010  : sym5 = 2;
	    3'b011  : sym5 = 3;
	    default : sym5 = 4;
	endcase
	
	case ({flip4,ro4,po4})
	    3'b000  : sym4 = 0;
	    3'b001  : sym4 = 1;
	    3'b010  : sym4 = 2;
	    3'b011  : sym4 = 3;
	    default : sym4 = 4;
	endcase
	
	case ({flip3,ro3,po3})
	    3'b000  : sym3 = 0;
	    3'b001  : sym3 = 1;
	    3'b010  : sym3 = 2;
	    3'b011  : sym3 = 3;
	    default : sym3 = 4;
	endcase
	
	case ({flip2,ro2,po2})
	    3'b000  : sym2 = 0;
	    3'b001  : sym2 = 1;
	    3'b010  : sym2 = 2;
	    3'b011  : sym2 = 3;
	    default : sym2 = 4;
	endcase
	
	case ({flip1,ro1,po1})
	    3'b000  : sym1 = 0;
	    3'b001  : sym1 = 1;
	    3'b010  : sym1 = 2;
	    3'b011  : sym1 = 3;
	    default : sym1 = 4;
	endcase
	
	case ({flip0,ro0,po0})
	    3'b000  : sym0 = 0;
	    3'b001  : sym0 = 1;
	    3'b010  : sym0 = 2;
	    3'b011  : sym0 = 3;
	    default : sym0 = 4;
	endcase
	
	drive_7symbols_lane0(sym6,sym5,sym4,sym3,sym2,sym1,sym0);
endtask

task drive_16bits_lane1 (input [15:0] data);
    reg       flip6,ro6,po6;
    reg       flip5,ro5,po5;
    reg       flip4,ro4,po4;
    reg       flip3,ro3,po3;
    reg       flip2,ro2,po2;
    reg       flip1,ro1,po1;
    reg       flip0,ro0,po0;
	reg [2:0] sym6,sym5,sym4,sym3,sym2,sym1,sym0;
	
	if (data <= 16'h3FFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[13];
		po6   = data[12];
		ro5   = data[11];
		po5   = data[10];
		ro4   = data[9];
		po4   = data[8];
		ro3   = data[7];
		po3   = data[6];
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'h4FFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 1;
		ro6   = data[11];
		po6   = data[10];
		ro5   = data[9];
		po5   = data[8];
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = data[3];
		po2   = data[2];
		ro1   = data[1];
		po1   = data[0];
		ro0   = 0;
		po0   = 0;
	end else if (data <= 16'h5FFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 1;
	    flip0 = 0;
		ro6   = data[11];
		po6   = data[10];
		ro5   = data[9];
		po5   = data[8];
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = data[3];
		po2   = data[2];
		ro1   = 0;
		po1   = 0;
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'h6FFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 1;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[11];
		po6   = data[10];
		ro5   = data[9];
		po5   = data[8];
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = 0;
		po2   = 0;
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'h7FFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 1;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[11];
		po6   = data[10];
		ro5   = data[9];
		po5   = data[8];
		ro4   = data[7];
		po4   = data[6];
		ro3   = 0;
		po3   = 0;
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'h8FFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 1;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[11];
		po6   = data[10];
		ro5   = data[9];
		po5   = data[8];
		ro4   = 0;
		po4   = 0;
		ro3   = data[7];
		po3   = data[6];
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'h9FFF) begin
	    flip6 = 0;
	    flip5 = 1;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[11];
		po6   = data[10];
		ro5   = 0;
		po5   = 0;
		ro4   = data[9];
		po4   = data[8];
		ro3   = data[7];
		po3   = data[6];
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hAFFF) begin
	    flip6 = 1;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = 0;
		po6   = 0;
		ro5   = data[11];
		po5   = data[10];
		ro4   = data[9];
		po4   = data[8];
		ro3   = data[7];
		po3   = data[6];
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hB3FF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 1;
	    flip0 = 1;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = data[5];
		po4   = data[4];
		ro3   = data[3];
		po3   = data[2];
		ro2   = data[1];
		po2   = data[0];
		ro1   = 0;
		po1   = 0;
		ro0   = 0;
		po0   = 0;
	end else if (data <= 16'hB7FF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 1;
	    flip1 = 0;
	    flip0 = 1;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = data[5];
		po4   = data[4];
		ro3   = data[3];
		po3   = data[2];
		ro2   = 0;
		po2   = 0;
		ro1   = data[1];
		po1   = data[0];
		ro0   = 0;
		po0   = 0;
	end else if (data <= 16'hBBFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 1;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 1;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = data[5];
		po4   = data[4];
		ro3   = 0;
		po3   = 0;
		ro2   = data[3];
		po2   = data[2];
		ro1   = data[1];
		po1   = data[0];
		ro0   = 0;
		po0   = 0;
	end else if (data <= 16'hBFFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 1;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 1;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = 0;
		po4   = 0;
		ro3   = data[5];
		po3   = data[4];
		ro2   = data[3];
		po2   = data[2];
		ro1   = data[1];
		po1   = data[0];
		ro0   = 0;
		po0   = 0;
	end else if (data <= 16'hC3FF) begin
	    flip6 = 0;
	    flip5 = 1;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 1;
		ro6   = data[9];
		po6   = data[8];
		ro5   = 0;
		po5   = 0;
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = data[3];
		po2   = data[2];
		ro1   = data[1];
		po1   = data[0];
		ro0   = 0;
		po0   = 0;
	end else if (data <= 16'hC7FF) begin
	    flip6 = 1;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 1;
		ro6   = 0;
		po6   = 0;
		ro5   = data[9];
		po5   = data[8];
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = data[3];
		po2   = data[2];
		ro1   = data[1];
		po1   = data[0];
		ro0   = 0;
		po0   = 0;
	end else if (data <= 16'hCBFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 1;
	    flip1 = 1;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = data[5];
		po4   = data[4];
		ro3   = data[3];
		po3   = data[2];
		ro2   = 0;
		po2   = 0;
		ro1   = 0;
		po1   = 0;
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hCFFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 1;
	    flip2 = 0;
	    flip1 = 1;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = data[5];
		po4   = data[4];
		ro3   = 0;
		po3   = 0;
		ro2   = data[3];
		po2   = data[2];
		ro1   = 0;
		po1   = 0;
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hD3FF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 1;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 1;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = 0;
		po4   = 0;
		ro3   = data[5];
		po3   = data[4];
		ro2   = data[3];
		po2   = data[2];
		ro1   = 0;
		po1   = 0;
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hD7FF) begin
	    flip6 = 0;
	    flip5 = 1;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 1;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = 0;
		po5   = 0;
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = data[3];
		po2   = data[2];
		ro1   = 0;
		po1   = 0;
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hDBFF) begin
	    flip6 = 1;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 1;
	    flip0 = 0;
		ro6   = 0;
		po6   = 0;
		ro5   = data[9];
		po5   = data[8];
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = data[3];
		po2   = data[2];
		ro1   = 0;
		po1   = 0;
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hDFFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 1;
	    flip2 = 1;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = data[5];
		po4   = data[4];
		ro3   = 0;
		po3   = 0;
		ro2   = 0;
		po2   = 0;
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hE3FF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 1;
	    flip3 = 0;
	    flip2 = 1;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = 0;
		po4   = 0;
		ro3   = data[5];
		po3   = data[4];
		ro2   = 0;
		po2   = 0;
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hE7FF) begin
	    flip6 = 0;
	    flip5 = 1;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 1;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = 0;
		po5   = 0;
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = 0;
		po2   = 0;
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hEBFF) begin
	    flip6 = 1;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 1;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = 0;
		po6   = 0;
		ro5   = data[9];
		po5   = data[8];
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = 0;
		po2   = 0;
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hEFFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 1;
	    flip3 = 1;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = 0;
		po4   = 0;
		ro3   = 0;
		po3   = 0;
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hF3FF) begin
	    flip6 = 0;
	    flip5 = 1;
	    flip4 = 0;
	    flip3 = 1;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = 0;
		po5   = 0;
		ro4   = data[7];
		po4   = data[6];
		ro3   = 0;
		po3   = 0;
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hF7FF) begin
	    flip6 = 1;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 1;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = 0;
		po6   = 0;
		ro5   = data[9];
		po5   = data[8];
		ro4   = data[7];
		po4   = data[6];
		ro3   = 0;
		po3   = 0;
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hFBFF) begin
	    flip6 = 0;
	    flip5 = 1;
	    flip4 = 1;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = 0;
		po5   = 0;
		ro4   = 0;
		po4   = 0;
		ro3   = data[7];
		po3   = data[6];
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	//end else if (data <= 16'hFFFF) begin
	end else begin
	    flip6 = 1;
	    flip5 = 0;
	    flip4 = 1;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = 0;
		po6   = 0;
		ro5   = data[9];
		po5   = data[8];
		ro4   = 0;
		po4   = 0;
		ro3   = data[7];
		po3   = data[6];
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end
	
	case ({flip6,ro6,po6})
	    3'b000  : sym6 = 0;
	    3'b001  : sym6 = 1;
	    3'b010  : sym6 = 2;
	    3'b011  : sym6 = 3;
	    default : sym6 = 4;
	endcase
	
	case ({flip5,ro5,po5})
	    3'b000  : sym5 = 0;
	    3'b001  : sym5 = 1;
	    3'b010  : sym5 = 2;
	    3'b011  : sym5 = 3;
	    default : sym5 = 4;
	endcase
	
	case ({flip4,ro4,po4})
	    3'b000  : sym4 = 0;
	    3'b001  : sym4 = 1;
	    3'b010  : sym4 = 2;
	    3'b011  : sym4 = 3;
	    default : sym4 = 4;
	endcase
	
	case ({flip3,ro3,po3})
	    3'b000  : sym3 = 0;
	    3'b001  : sym3 = 1;
	    3'b010  : sym3 = 2;
	    3'b011  : sym3 = 3;
	    default : sym3 = 4;
	endcase
	
	case ({flip2,ro2,po2})
	    3'b000  : sym2 = 0;
	    3'b001  : sym2 = 1;
	    3'b010  : sym2 = 2;
	    3'b011  : sym2 = 3;
	    default : sym2 = 4;
	endcase
	
	case ({flip1,ro1,po1})
	    3'b000  : sym1 = 0;
	    3'b001  : sym1 = 1;
	    3'b010  : sym1 = 2;
	    3'b011  : sym1 = 3;
	    default : sym1 = 4;
	endcase
	
	case ({flip0,ro0,po0})
	    3'b000  : sym0 = 0;
	    3'b001  : sym0 = 1;
	    3'b010  : sym0 = 2;
	    3'b011  : sym0 = 3;
	    default : sym0 = 4;
	endcase
	
	drive_7symbols_lane1(sym6,sym5,sym4,sym3,sym2,sym1,sym0);
endtask

task drive_16bits_lane2 (input [15:0] data);
    reg       flip6,ro6,po6;
    reg       flip5,ro5,po5;
    reg       flip4,ro4,po4;
    reg       flip3,ro3,po3;
    reg       flip2,ro2,po2;
    reg       flip1,ro1,po1;
    reg       flip0,ro0,po0;
	reg [2:0] sym6,sym5,sym4,sym3,sym2,sym1,sym0;
	
	if (data <= 16'h3FFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[13];
		po6   = data[12];
		ro5   = data[11];
		po5   = data[10];
		ro4   = data[9];
		po4   = data[8];
		ro3   = data[7];
		po3   = data[6];
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'h4FFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 1;
		ro6   = data[11];
		po6   = data[10];
		ro5   = data[9];
		po5   = data[8];
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = data[3];
		po2   = data[2];
		ro1   = data[1];
		po1   = data[0];
		ro0   = 0;
		po0   = 0;
	end else if (data <= 16'h5FFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 1;
	    flip0 = 0;
		ro6   = data[11];
		po6   = data[10];
		ro5   = data[9];
		po5   = data[8];
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = data[3];
		po2   = data[2];
		ro1   = 0;
		po1   = 0;
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'h6FFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 1;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[11];
		po6   = data[10];
		ro5   = data[9];
		po5   = data[8];
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = 0;
		po2   = 0;
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'h7FFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 1;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[11];
		po6   = data[10];
		ro5   = data[9];
		po5   = data[8];
		ro4   = data[7];
		po4   = data[6];
		ro3   = 0;
		po3   = 0;
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'h8FFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 1;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[11];
		po6   = data[10];
		ro5   = data[9];
		po5   = data[8];
		ro4   = 0;
		po4   = 0;
		ro3   = data[7];
		po3   = data[6];
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'h9FFF) begin
	    flip6 = 0;
	    flip5 = 1;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[11];
		po6   = data[10];
		ro5   = 0;
		po5   = 0;
		ro4   = data[9];
		po4   = data[8];
		ro3   = data[7];
		po3   = data[6];
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hAFFF) begin
	    flip6 = 1;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = 0;
		po6   = 0;
		ro5   = data[11];
		po5   = data[10];
		ro4   = data[9];
		po4   = data[8];
		ro3   = data[7];
		po3   = data[6];
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hB3FF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 1;
	    flip0 = 1;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = data[5];
		po4   = data[4];
		ro3   = data[3];
		po3   = data[2];
		ro2   = data[1];
		po2   = data[0];
		ro1   = 0;
		po1   = 0;
		ro0   = 0;
		po0   = 0;
	end else if (data <= 16'hB7FF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 1;
	    flip1 = 0;
	    flip0 = 1;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = data[5];
		po4   = data[4];
		ro3   = data[3];
		po3   = data[2];
		ro2   = 0;
		po2   = 0;
		ro1   = data[1];
		po1   = data[0];
		ro0   = 0;
		po0   = 0;
	end else if (data <= 16'hBBFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 1;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 1;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = data[5];
		po4   = data[4];
		ro3   = 0;
		po3   = 0;
		ro2   = data[3];
		po2   = data[2];
		ro1   = data[1];
		po1   = data[0];
		ro0   = 0;
		po0   = 0;
	end else if (data <= 16'hBFFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 1;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 1;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = 0;
		po4   = 0;
		ro3   = data[5];
		po3   = data[4];
		ro2   = data[3];
		po2   = data[2];
		ro1   = data[1];
		po1   = data[0];
		ro0   = 0;
		po0   = 0;
	end else if (data <= 16'hC3FF) begin
	    flip6 = 0;
	    flip5 = 1;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 1;
		ro6   = data[9];
		po6   = data[8];
		ro5   = 0;
		po5   = 0;
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = data[3];
		po2   = data[2];
		ro1   = data[1];
		po1   = data[0];
		ro0   = 0;
		po0   = 0;
	end else if (data <= 16'hC7FF) begin
	    flip6 = 1;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 1;
		ro6   = 0;
		po6   = 0;
		ro5   = data[9];
		po5   = data[8];
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = data[3];
		po2   = data[2];
		ro1   = data[1];
		po1   = data[0];
		ro0   = 0;
		po0   = 0;
	end else if (data <= 16'hCBFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 1;
	    flip1 = 1;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = data[5];
		po4   = data[4];
		ro3   = data[3];
		po3   = data[2];
		ro2   = 0;
		po2   = 0;
		ro1   = 0;
		po1   = 0;
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hCFFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 1;
	    flip2 = 0;
	    flip1 = 1;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = data[5];
		po4   = data[4];
		ro3   = 0;
		po3   = 0;
		ro2   = data[3];
		po2   = data[2];
		ro1   = 0;
		po1   = 0;
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hD3FF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 1;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 1;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = 0;
		po4   = 0;
		ro3   = data[5];
		po3   = data[4];
		ro2   = data[3];
		po2   = data[2];
		ro1   = 0;
		po1   = 0;
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hD7FF) begin
	    flip6 = 0;
	    flip5 = 1;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 1;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = 0;
		po5   = 0;
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = data[3];
		po2   = data[2];
		ro1   = 0;
		po1   = 0;
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hDBFF) begin
	    flip6 = 1;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 1;
	    flip0 = 0;
		ro6   = 0;
		po6   = 0;
		ro5   = data[9];
		po5   = data[8];
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = data[3];
		po2   = data[2];
		ro1   = 0;
		po1   = 0;
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hDFFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 1;
	    flip2 = 1;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = data[5];
		po4   = data[4];
		ro3   = 0;
		po3   = 0;
		ro2   = 0;
		po2   = 0;
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hE3FF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 1;
	    flip3 = 0;
	    flip2 = 1;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = 0;
		po4   = 0;
		ro3   = data[5];
		po3   = data[4];
		ro2   = 0;
		po2   = 0;
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hE7FF) begin
	    flip6 = 0;
	    flip5 = 1;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 1;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = 0;
		po5   = 0;
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = 0;
		po2   = 0;
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hEBFF) begin
	    flip6 = 1;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 0;
	    flip2 = 1;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = 0;
		po6   = 0;
		ro5   = data[9];
		po5   = data[8];
		ro4   = data[7];
		po4   = data[6];
		ro3   = data[5];
		po3   = data[4];
		ro2   = 0;
		po2   = 0;
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hEFFF) begin
	    flip6 = 0;
	    flip5 = 0;
	    flip4 = 1;
	    flip3 = 1;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = data[7];
		po5   = data[6];
		ro4   = 0;
		po4   = 0;
		ro3   = 0;
		po3   = 0;
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hF3FF) begin
	    flip6 = 0;
	    flip5 = 1;
	    flip4 = 0;
	    flip3 = 1;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = 0;
		po5   = 0;
		ro4   = data[7];
		po4   = data[6];
		ro3   = 0;
		po3   = 0;
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hF7FF) begin
	    flip6 = 1;
	    flip5 = 0;
	    flip4 = 0;
	    flip3 = 1;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = 0;
		po6   = 0;
		ro5   = data[9];
		po5   = data[8];
		ro4   = data[7];
		po4   = data[6];
		ro3   = 0;
		po3   = 0;
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end else if (data <= 16'hFBFF) begin
	    flip6 = 0;
	    flip5 = 1;
	    flip4 = 1;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = data[9];
		po6   = data[8];
		ro5   = 0;
		po5   = 0;
		ro4   = 0;
		po4   = 0;
		ro3   = data[7];
		po3   = data[6];
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	//end else if (data <= 16'hFFFF) begin
	end else begin
	    flip6 = 1;
	    flip5 = 0;
	    flip4 = 1;
	    flip3 = 0;
	    flip2 = 0;
	    flip1 = 0;
	    flip0 = 0;
		ro6   = 0;
		po6   = 0;
		ro5   = data[9];
		po5   = data[8];
		ro4   = 0;
		po4   = 0;
		ro3   = data[7];
		po3   = data[6];
		ro2   = data[5];
		po2   = data[4];
		ro1   = data[3];
		po1   = data[2];
		ro0   = data[1];
		po0   = data[0];
	end
	
	case ({flip6,ro6,po6})
	    3'b000  : sym6 = 0;
	    3'b001  : sym6 = 1;
	    3'b010  : sym6 = 2;
	    3'b011  : sym6 = 3;
	    default : sym6 = 4;
	endcase
	
	case ({flip5,ro5,po5})
	    3'b000  : sym5 = 0;
	    3'b001  : sym5 = 1;
	    3'b010  : sym5 = 2;
	    3'b011  : sym5 = 3;
	    default : sym5 = 4;
	endcase
	
	case ({flip4,ro4,po4})
	    3'b000  : sym4 = 0;
	    3'b001  : sym4 = 1;
	    3'b010  : sym4 = 2;
	    3'b011  : sym4 = 3;
	    default : sym4 = 4;
	endcase
	
	case ({flip3,ro3,po3})
	    3'b000  : sym3 = 0;
	    3'b001  : sym3 = 1;
	    3'b010  : sym3 = 2;
	    3'b011  : sym3 = 3;
	    default : sym3 = 4;
	endcase
	
	case ({flip2,ro2,po2})
	    3'b000  : sym2 = 0;
	    3'b001  : sym2 = 1;
	    3'b010  : sym2 = 2;
	    3'b011  : sym2 = 3;
	    default : sym2 = 4;
	endcase
	
	case ({flip1,ro1,po1})
	    3'b000  : sym1 = 0;
	    3'b001  : sym1 = 1;
	    3'b010  : sym1 = 2;
	    3'b011  : sym1 = 3;
	    default : sym1 = 4;
	endcase
	
	case ({flip0,ro0,po0})
	    3'b000  : sym0 = 0;
	    3'b001  : sym0 = 1;
	    3'b010  : sym0 = 2;
	    3'b011  : sym0 = 3;
	    default : sym0 = 4;
	endcase
	
	drive_7symbols_lane2(sym6,sym5,sym4,sym3,sym2,sym1,sym0);
endtask

task compute_crc16_d8 (input [7:0] data_in);
    for (j = 0; j < 8; j = j + 1) begin
	    new_crc16     = crc16;
		new_crc16[15] = data_in[j] ^ new_crc16[0];
		new_crc16[10] = crc16[11]  ^ new_crc16[15];
		new_crc16[3]  = crc16[4]   ^ new_crc16[15];
		crc16         = crc16 >> 1;
		crc16[15]     = new_crc16[15];
		crc16[10]     = new_crc16[10];
		crc16[3]      = new_crc16[3];
	end
endtask

task gen_sp (input integer packet_pointer, input [5:0] sp_dt);
    integer current_pointer;
	
	current_pointer = packet_pointer;
	crc16 = 16'hFFFF;
	compute_crc16_d8(8'h00);
	compute_crc16_d8({VC_ID[1:0],sp_dt});
	compute_crc16_d8(8'h00);
	compute_crc16_d8(8'h00);
	
	for (i = 0; i < (NUM_RX_LANE*2); i = i + 1) begin
	    packet_data[current_pointer + i] = 9'h100;
	end
	
	current_pointer = current_pointer + (NUM_RX_LANE*2);
	
	for (i = 0; i < (NUM_RX_LANE*2); i = i + 2) begin
	    packet_data[current_pointer + i]     = {1'b0,8'h00};
	    packet_data[current_pointer + i + 1] = {1'b0,VC_ID[1:0],sp_dt};
	end
	
	current_pointer = current_pointer + (NUM_RX_LANE*2);
	
	for (i = 0; i < (NUM_RX_LANE*2); i = i + 2) begin
	    packet_data[current_pointer + i]     = {1'b0,8'h00};
	    packet_data[current_pointer + i + 1] = {1'b0,8'h00};
	end
	
	current_pointer = current_pointer + (NUM_RX_LANE*2);
	
	for (i = 0; i < (NUM_RX_LANE*2); i = i + 2) begin
	    packet_data[current_pointer + i]     = {1'b0,crc16[7:0]};
	    packet_data[current_pointer + i + 1] = {1'b0,crc16[15:8]};
	end
	
	current_pointer = current_pointer + (NUM_RX_LANE*2);
	
	for (i = 0; i < (NUM_RX_LANE*2); i = i + 1) begin
	    packet_data[current_pointer + i] = 9'h100;
	end
	
	current_pointer = current_pointer + (NUM_RX_LANE*2);
	
	for (i = 0; i < (NUM_RX_LANE*2); i = i + 2) begin
	    packet_data[current_pointer + i]     = {1'b0,8'h00};
	    packet_data[current_pointer + i + 1] = {1'b0,VC_ID[1:0],sp_dt};
	end
	
	current_pointer = current_pointer + (NUM_RX_LANE*2);
	
	for (i = 0; i < (NUM_RX_LANE*2); i = i + 2) begin
	    packet_data[current_pointer + i]     = {1'b0,8'h00};
	    packet_data[current_pointer + i + 1] = {1'b0,8'h00};
	end
	
	current_pointer = current_pointer + (NUM_RX_LANE*2);
	
	for (i = 0; i < (NUM_RX_LANE*2); i = i + 2) begin
	    packet_data[current_pointer + i]     = {1'b0,crc16[7:0]};
	    packet_data[current_pointer + i + 1] = {1'b0,crc16[15:8]};
	end
	
	current_pointer = current_pointer + (NUM_RX_LANE*2);
endtask

task gen_lp (input integer packet_pointer, input string mode, input [15:0] lp_wc);
    integer current_pointer;
	reg [7:0] current_data;
	reg [5:0] lp_dt;
	
	current_pointer = packet_pointer;
	lp_dt = (mode == "BLANKING") ? 6'h11 : VID_DT[5:0];
	crc16 = 16'hFFFF;
	compute_crc16_d8(8'h00);
	compute_crc16_d8({VC_ID[1:0],lp_dt});
	compute_crc16_d8(lp_wc[7:0]);
	compute_crc16_d8(lp_wc[15:8]);
	
	for (i = 0; i < (NUM_RX_LANE*2); i = i + 1) begin
	    packet_data[current_pointer + i] = 9'h100;
	end
	
	current_pointer = current_pointer + (NUM_RX_LANE*2);
	
	for (i = 0; i < (NUM_RX_LANE*2); i = i + 2) begin
	    packet_data[current_pointer + i]     = {1'b0,8'h00};
	    packet_data[current_pointer + i + 1] = {1'b0,VC_ID[1:0],lp_dt};
	end
	
	current_pointer = current_pointer + (NUM_RX_LANE*2);
	
	for (i = 0; i < (NUM_RX_LANE*2); i = i + 2) begin
	    packet_data[current_pointer + i]     = {1'b0,lp_wc[7:0]};
	    packet_data[current_pointer + i + 1] = {1'b0,lp_wc[15:8]};
	end
	
	current_pointer = current_pointer + (NUM_RX_LANE*2);
	
	for (i = 0; i < (NUM_RX_LANE*2); i = i + 2) begin
	    packet_data[current_pointer + i]     = {1'b0,crc16[7:0]};
	    packet_data[current_pointer + i + 1] = {1'b0,crc16[15:8]};
	end
	
	current_pointer = current_pointer + (NUM_RX_LANE*2);
	
	for (i = 0; i < (NUM_RX_LANE*2); i = i + 1) begin
	    packet_data[current_pointer + i] = 9'h100;
	end
	
	current_pointer = current_pointer + (NUM_RX_LANE*2);
	
	for (i = 0; i < (NUM_RX_LANE*2); i = i + 2) begin
	    packet_data[current_pointer + i]     = {1'b0,8'h00};
	    packet_data[current_pointer + i + 1] = {1'b0,VC_ID[1:0],lp_dt};
	end
	
	current_pointer = current_pointer + (NUM_RX_LANE*2);
	
	for (i = 0; i < (NUM_RX_LANE*2); i = i + 2) begin
	    packet_data[current_pointer + i]     = {1'b0,lp_wc[7:0]};
	    packet_data[current_pointer + i + 1] = {1'b0,lp_wc[15:8]};
	end
	
	current_pointer = current_pointer + (NUM_RX_LANE*2);
	
	for (i = 0; i < (NUM_RX_LANE*2); i = i + 2) begin
	    packet_data[current_pointer + i]     = {1'b0,crc16[7:0]};
	    packet_data[current_pointer + i + 1] = {1'b0,crc16[15:8]};
	end
	
	current_pointer = current_pointer + (NUM_RX_LANE*2);
	
	crc16 = 16'hFFFF;
	
	for (i = 0; i < lp_wc; i = i + 1) begin
	    if (mode == "BLANKING")
	        current_data = 8'h55;
	    else begin
	        current_data = $random;
	    	$fwrite(f,"%0x\n",current_data);
	    end
		compute_crc16_d8(current_data);
		packet_data[current_pointer] = {1'b0,current_data};
		current_pointer = current_pointer + 1;
	end
	
	packet_data[current_pointer] = {1'b0,crc16[7:0]};
	current_pointer = current_pointer + 1;
	packet_data[current_pointer] = {1'b0,crc16[15:8]};
	current_pointer = current_pointer + 1;
	
	// Filler
	if (lp_wc % 2) begin
	    packet_data[current_pointer] = 9'h000;
	    current_pointer = current_pointer + 1;
	end
endtask

task drive_packet();
    integer j,k,l;
	
    if (NUM_RX_LANE == 1) begin
	    // LP-01
	    d_a_i[0] = 1'b0;
		d_b_i[0] = 1'b0;
		d_c_i[0] = 1'b1;
	    #(T_LPX);
		// LP-00
	    d_a_i[0] = 1'b0;
		d_b_i[0] = 1'b0;
		d_c_i[0] = 1'b0;
		#(T3_PREPARE);
		// Initialize First Symbol +x
		d_weak_0 = 1'b0;
		d_a_i[0] = 1'b1;
		d_b_i[0] = 1'b0;
		d_c_i[0] = 1'b0;
		// T3_PREAMBLE
		for (j = 0; j < T3_PREAMBLE_UI; j = j + 1) begin
		    drive_symbol_lane0(3);
		end
		// SYNC + DATA
		for (j = 0; j < packet_bytes; j = j + 2) begin
		    if (packet_data[j][8])
			    drive_7symbols_lane0(3,4,4,4,4,4,3);
			else
			    drive_16bits_lane0({packet_data[j+1][7:0],packet_data[j][7:0]});
		end
		// T3_POST
		for (j = 0; j < T3_POST_UI; j = j + 1) begin
		    drive_symbol_lane0(4);
		end
		// LP-11
		d_weak_0 = 1'b1;
		d_a_i[0] = 1'b1;
		d_b_i[0] = 1'b1;
		d_c_i[0] = 1'b1;
	end else if (NUM_RX_LANE == 2) begin
	    // LP-01
	    d_a_i[1:0] = 2'b00;
		d_b_i[1:0] = 2'b00;
		d_c_i[1:0] = 2'b11;
	    #(T_LPX);
		// LP-00
	    d_a_i[1:0] = 2'b00;
		d_b_i[1:0] = 2'b00;
		d_c_i[1:0] = 2'b00;
		#(T3_PREPARE);
		// Initialize First Symbol +x
		d_weak_0   = 1'b0;
		d_weak_1   = 1'b0;
		d_a_i[1:0] = 2'b11;
		d_b_i[1:0] = 2'b00;
		d_c_i[1:0] = 2'b00;
		// T3_PREAMBLE
		for (j = 0; j < T3_PREAMBLE_UI; j = j + 1) begin
		    drive_symbol_lane0(3);
		    drive_symbol_lane1(3);
		end
		fork
		begin
		    // SYNC + DATA
		    for (j = 0; j < packet_bytes; j = j + 4) begin
		        if (packet_data[j][8])
		    	    drive_7symbols_lane0(3,4,4,4,4,4,3);
		    	else
		    	    drive_16bits_lane0({packet_data[j+1][7:0],packet_data[j][7:0]});
		    end
		    // T3_POST
		    for (j = 0; j < T3_POST_UI; j = j + 1) begin
		        drive_symbol_lane0(4);
		    end
		    // LP-11
		    d_weak_0 = 1'b1;
		    d_a_i[0] = 1'b1;
		    d_b_i[0] = 1'b1;
		    d_c_i[0] = 1'b1;
		end
		begin
		    // SYNC + DATA
		    for (k = 2; k < packet_bytes; k = k + 4) begin
		        if (packet_data[k][8])
		    	    drive_7symbols_lane1(3,4,4,4,4,4,3);
		    	else
		    	    drive_16bits_lane1({packet_data[k+1][7:0],packet_data[k][7:0]});
		    end
			// Filler
			if ((packet_bytes % 4) == 2)
			    drive_16bits_lane1(16'h0000);
		    // T3_POST
		    for (k = 0; k < T3_POST_UI; k = k + 1) begin
		        drive_symbol_lane1(4);
		    end
		    // LP-11
		    d_weak_1 = 1'b1;
		    d_a_i[1] = 1'b1;
		    d_b_i[1] = 1'b1;
		    d_c_i[1] = 1'b1;
		end
		join
	end else begin // NUM_RX_LANE == 3
	    // LP-01
	    d_a_i = 3'b000;
		d_b_i = 3'b000;
		d_c_i = 3'b111;
	    #(T_LPX);
		// LP-00
	    d_a_i = 3'b000;
		d_b_i = 3'b000;
		d_c_i = 3'b000;
		#(T3_PREPARE);
		// Initialize First Symbol +x
		d_weak_0 = 1'b0;
		d_weak_1 = 1'b0;
		d_weak_2 = 1'b0;
		d_a_i    = 3'b111;
		d_b_i    = 3'b000;
		d_c_i    = 3'b000;
		// T3_PREAMBLE
		for (j = 0; j < T3_PREAMBLE_UI; j = j + 1) begin
		    drive_symbol_lane0(3);
		    drive_symbol_lane1(3);
		    drive_symbol_lane2(3);
		end
		fork
		begin
		    // SYNC + DATA
		    for (j = 0; j < packet_bytes; j = j + 6) begin
		        if (packet_data[j][8])
		    	    drive_7symbols_lane0(3,4,4,4,4,4,3);
		    	else
		    	    drive_16bits_lane0({packet_data[j+1][7:0],packet_data[j][7:0]});
		    end
		    // T3_POST
		    for (j = 0; j < T3_POST_UI; j = j + 1) begin
		        drive_symbol_lane0(4);
		    end
		    // LP-11
		    d_weak_0 = 1'b1;
		    d_a_i[0] = 1'b1;
		    d_b_i[0] = 1'b1;
		    d_c_i[0] = 1'b1;
		end
		begin
		    // SYNC + DATA
		    for (k = 2; k < packet_bytes; k = k + 6) begin
		        if (packet_data[k][8])
		    	    drive_7symbols_lane1(3,4,4,4,4,4,3);
		    	else
		    	    drive_16bits_lane1({packet_data[k+1][7:0],packet_data[k][7:0]});
		    end
			// Filler
			if ((packet_bytes % 6) == 2)
			    drive_16bits_lane1(16'h0000);
		    // T3_POST
		    for (k = 0; k < T3_POST_UI; k = k + 1) begin
		        drive_symbol_lane1(4);
		    end
		    // LP-11
		    d_weak_1 = 1'b1;
		    d_a_i[1] = 1'b1;
		    d_b_i[1] = 1'b1;
		    d_c_i[1] = 1'b1;
		end
		begin
		    // SYNC + DATA
		    for (l = 4; l < packet_bytes; l = l + 6) begin
		        if (packet_data[l][8])
		    	    drive_7symbols_lane2(3,4,4,4,4,4,3);
		    	else
		    	    drive_16bits_lane2({packet_data[l+1][7:0],packet_data[l][7:0]});
		    end
			// Filler
			if (((packet_bytes % 6) == 2) || ((packet_bytes % 6) == 4))
			    drive_16bits_lane2(16'h0000);
		    // T3_POST
		    for (l = 0; l < T3_POST_UI; l = l + 1) begin
		        drive_symbol_lane2(4);
		    end
		    // LP-11
		    d_weak_2 = 1'b1;
		    d_a_i[2] = 1'b1;
		    d_b_i[2] = 1'b1;
		    d_c_i[2] = 1'b1;
		end
		join
	end
endtask

task drive_frame();
    // FS
	packet_pointer = 0;
	packet_bytes = (NUM_RX_LANE*2) + (NUM_RX_LANE*6) + (NUM_RX_LANE*2) + (NUM_RX_LANE*6);
    packet_data = new[packet_bytes];
	gen_sp(packet_pointer,6'h00);
	packet_pointer = packet_pointer + ((NUM_RX_LANE*2) + (NUM_RX_LANE*6) + (NUM_RX_LANE*2) + (NUM_RX_LANE*6));
	drive_packet;
	#(CSI_T_LPS);
	
	repeat (NUM_LINES) begin
	    // LS
	    if (CSI_LS_LE == "ON") begin
	        packet_pointer = 0;
	        packet_bytes = (NUM_RX_LANE*2) + (NUM_RX_LANE*6) + (NUM_RX_LANE*2) + (NUM_RX_LANE*6);
            packet_data = new[packet_bytes];
	        gen_sp(packet_pointer,6'h02);
	        packet_pointer = packet_pointer + ((NUM_RX_LANE*2) + (NUM_RX_LANE*6) + (NUM_RX_LANE*2) + (NUM_RX_LANE*6));
	        drive_packet;
	        #(CSI_T_LPS);
	    end
		
		// VACT
        packet_pointer = 0;
        packet_bytes = (NUM_RX_LANE*2) + (NUM_RX_LANE*6) + (NUM_RX_LANE*2) + (NUM_RX_LANE*6) + CSI_VACT_WC + (CSI_VACT_WC % 2) + 2;
        packet_data = new[packet_bytes];
        gen_lp(packet_pointer,"DATA",CSI_VACT_WC);
        packet_pointer = packet_pointer + ((NUM_RX_LANE*2) + (NUM_RX_LANE*6) + (NUM_RX_LANE*2) + (NUM_RX_LANE*6) + CSI_VACT_WC + (CSI_VACT_WC % 2) + 2);
        drive_packet;
        #(CSI_T_LPS);
		
	    // LE
	    if (CSI_LS_LE == "ON") begin
	        packet_pointer = 0;
	        packet_bytes = (NUM_RX_LANE*2) + (NUM_RX_LANE*6) + (NUM_RX_LANE*2) + (NUM_RX_LANE*6);
            packet_data = new[packet_bytes];
	        gen_sp(packet_pointer,6'h03);
	        packet_pointer = packet_pointer + ((NUM_RX_LANE*2) + (NUM_RX_LANE*6) + (NUM_RX_LANE*2) + (NUM_RX_LANE*6));
	        drive_packet;
	        #(CSI_T_LPS);
	    end
	end
	
	// FE
	packet_pointer = 0;
	packet_bytes = (NUM_RX_LANE*2) + (NUM_RX_LANE*6) + (NUM_RX_LANE*2) + (NUM_RX_LANE*6);
    packet_data = new[packet_bytes];
	gen_sp(packet_pointer,6'h01);
	packet_pointer = packet_pointer + ((NUM_RX_LANE*2) + (NUM_RX_LANE*6) + (NUM_RX_LANE*2) + (NUM_RX_LANE*6));
	drive_packet;
endtask

// Testbench
initial begin
    @(posedge tb_reset_n);
	$display("%0t CPHY Model Out of Reset, Start Driving LP-11\n",$realtime);
	d_a_i = 3'b111;
	d_b_i = 3'b111;
	d_c_i = 3'b111;
	if (~cphy_active) begin
	    $display("%0t Waiting for CPHY Active...\n",$realtime);
		@(posedge cphy_active);
		$display("%0t CPHY Active Asserted...\n",$realtime);
		$display("%0t Driving Data...\n",$realtime);
	end
	#(T_INIT);
	repeat (NUM_FRAMES) begin
	    drive_frame;
		#(T_FRAME_GAP);
	end
	$fclose(f);
	cphy_active = 0;
end

endmodule
`endif