//==============================================================================
// Byte stream packet generator (BFM) for BYTE_STREAM_INTF_EN
//==============================================================================
// Drives axis_byte_tdata_i, axis_byte_tvalid_i, axis_byte_tlast_i, axis_byte_tuser_i
// per waveform: header (4B), payload (N bytes), footer (2B CRC); short packet (4B, 1 beat).
// BYTES_IN_PARALLEL = 4 (32-bit) or 8 (64-bit). 64-bit: header beat includes first 4 payload bytes.
// Clock: axis_vid_clk_i. Respects axis_byte_tready_o.
//
// CRC_INSERT_EN "ON": BFM sends dummy footer CRC (A5A5); DUT inserts newly calculated CRC.
// CRC_INSERT_EN "OFF": BFM sends computed CRC-16 over payload; DUT passes through unchanged.
//
// ECC_INSERT_EN "ON": BFM sends dummy header ECC (A5) and drives VC/VCX in tuser[5:2];
//                     DUT uses VC/VCX from tuser and recalculates ECC.
// ECC_INSERT_EN "OFF": BFM sends computed ECC; DUT passes through unchanged, ignores user VC/VCX.
//==============================================================================

module axi_byte_stream_pkt_gen #(
    parameter int BYTES_IN_PARALLEL     = 4,
    parameter int TUSER_WIDTH      = 78,
    parameter int TDATA_WIDTH     = BYTES_IN_PARALLEL * 8,
    parameter string CRC_INSERT_EN = "OFF",   // "ON" = send dummy CRC A5A5, DUT inserts; "OFF" = BFM sends CRC, DUT passthrough
    parameter string ECC_INSERT_EN = "OFF",  // "ON" = send dummy ECC A5, DUT recalculates; "OFF" = BFM sends ECC, DUT passthrough
    parameter string VCX_EN       = "ON",   // Must match DUT for correct ECC when ECC_INSERT_EN "OFF"
    parameter string PASSTHROUGH_MODE = "ON"    // "ON" = passthrough mode, "OFF" = packet generator mode
) (
    input  logic                     clk_i,
    input  logic                     rst_n_i,
    input  logic                     axis_byte_tready_o,

    output logic [TDATA_WIDTH-1:0]   axis_byte_tdata_i,
    output logic                     axis_byte_tvalid_i,
    output logic                     axis_byte_tlast_i,
    output logic [TUSER_WIDTH-1:0]   axis_byte_tuser_i
);

    // File handle for writing long-packet payload only (for comparison with rx_model); 0 = disabled
    integer tx_data_file = 0;
    // Packet count: incremented after each short or long packet is fully sent (handshake complete)
    integer packets_sent = 0;

    // Debug signals for waveform tracing of CRC calculation (add to wave: u_byte_stream_pkt_gen.dbg_*)
    logic [15:0] dbg_crc_calculated_r;   // Final CRC (after all payload bytes)
    logic [15:0] dbg_crc_send_r;        // What we send (crc or DUMMY_CRC)
    logic [15:0] dbg_crc_running_r;     // CRC after each payload beat (per-cycle)
    logic [63:0] dbg_crc_data_r;        // Payload data just CRC'd (P0 P1 P2 P3 ... in [7:0] [15:8] ...)
    logic [15:0] dbg_payload_bytes_r;   // WC for this packet
    logic [ 7:0] dbg_crc_byte_idx_r;    // Bytes CRC'd so far (0..payload_bytes)
    logic        dbg_crc_valid_r;

    // Set file handle to write long-packet payload (output to tb_expected_data.txt; one byte per line, no gap between packets)
    task set_tx_data_file(input integer f);
        tx_data_file = f;
    endtask

    // Write N payload bytes to file (n=1..8). One byte per line; no gap between packets.
    task automatic write_payload_bytes(input int n, input [7:0] b0, b1, b2, b3, b4=0, b5=0, b6=0, b7=0);
        if (tx_data_file == 0 || n < 1 || n > 8) return;
        case (n)
            1: $fwrite(tx_data_file, "%02h\n", b0);
            2: $fwrite(tx_data_file, "%02h\n%02h\n", b0, b1);
            3: $fwrite(tx_data_file, "%02h\n%02h\n%02h\n", b0, b1, b2);
            4: $fwrite(tx_data_file, "%02h\n%02h\n%02h\n%02h\n", b0, b1, b2, b3);
            5: $fwrite(tx_data_file, "%02h\n%02h\n%02h\n%02h\n%02h\n", b0, b1, b2, b3, b4);
            6: $fwrite(tx_data_file, "%02h\n%02h\n%02h\n%02h\n%02h\n%02h\n", b0, b1, b2, b3, b4, b5);
            7: $fwrite(tx_data_file, "%02h\n%02h\n%02h\n%02h\n%02h\n%02h\n%02h\n", b0, b1, b2, b3, b4, b5, b6);
            8: $fwrite(tx_data_file, "%02h\n%02h\n%02h\n%02h\n%02h\n%02h\n%02h\n%02h\n", b0, b1, b2, b3, b4, b5, b6, b7);
            default: ;
        endcase
    endtask

    // -------------------------------------------------------------------------
    // CRC-16 for long packet footer (CSI-2 style: CRC-16-CCITT, poly 0x1021)
    // CRC_INSERT_EN "ON" → send dummy A5A5, DUT recalculates. "OFF" → BFM sends computed CRC, DUT passthrough.
    // -------------------------------------------------------------------------
    function automatic [15:0] crc16_byte(input [15:0] crc_in, input [7:0] data);
        reg [15:0] crc;
        int i;
        crc = crc_in ^ {8'h0, data};
        for (i = 0; i < 8; i++)
            crc = crc[0] ? ((crc >> 1) ^ 16'h8408) : (crc >> 1);
        return crc;
    endfunction

    localparam logic [7:0]  DUMMY_ECC = 8'hA5;   // When ECC_INSERT_EN: DUT replaces with recalculated ECC
    localparam logic [15:0] DUMMY_CRC = 16'hA5A5; // When CRC_INSERT_EN: DUT replaces with recalculated CRC. OFF: BFM sends computed CRC, DUT passthrough.

    // Short packet data types (CSI-2/DSI)
    localparam logic [5:0] DT_FRAME_START = 6'h00;  // FS
    localparam logic [5:0] DT_FRAME_END   = 6'h01;  // FE
    localparam logic [5:0] DT_LINE_START  = 6'h02;  // LS
    localparam logic [5:0] DT_LINE_END    = 6'h03;  // LE
    // Long packet data types (active pixel)
    localparam logic [5:0] DT_RGB565     = 6'h22;  // 16 bpp
    localparam logic [5:0] DT_RGB888     = 6'h24;  // 24 bpp

    // ECC for header byte3: ECC_INSERT_EN "ON" → send dummy, DUT recalculates. "OFF" → BFM sends computed ECC, DUT passthrough.
    function automatic [7:0] ecc_byte(input [5:0] dt, input [1:0] vc, input [1:0] vcx, input [15:0] wc);
        reg [25:0] ph;
        reg [7:0]  ecc;
        if (ECC_INSERT_EN == "ON")
            return DUMMY_ECC;  // DUT uses tuser[5:2] VC/VCX and recalculates ECC
        // ECC_INSERT_EN OFF: BFM sends computed ECC; DUT passes through, ignores user VC/VCX
        if (VCX_EN == "ON") begin
            ph = {vcx, wc, vc, dt};
            ecc[7:6] = vcx;
            ecc[5]   = ph[10] ^ ph[11] ^ ph[12] ^ ph[13] ^ ph[14] ^ ph[15] ^ ph[16] ^ ph[17] ^
                       ph[18] ^ ph[19] ^ ph[21] ^ ph[22] ^ ph[23] ^ ph[24] ^ ph[25];
            ecc[4]   = ph[ 4] ^ ph[ 5] ^ ph[ 6] ^ ph[ 7] ^ ph[ 8] ^ ph[ 9] ^ ph[16] ^ ph[17] ^
                       ph[18] ^ ph[19] ^ ph[20] ^ ph[22] ^ ph[23] ^ ph[24] ^ ph[25];
            ecc[3]   = ph[ 1] ^ ph[ 2] ^ ph[ 3] ^ ph[ 7] ^ ph[ 8] ^ ph[ 9] ^ ph[13] ^ ph[14] ^
                       ph[15] ^ ph[19] ^ ph[20] ^ ph[21] ^ ph[23] ^ ph[24] ^ ph[25];
            ecc[2]   = ph[ 0] ^ ph[ 2] ^ ph[ 3] ^ ph[ 5] ^ ph[ 6] ^ ph[ 9] ^ ph[11] ^ ph[12] ^
                       ph[15] ^ ph[18] ^ ph[20] ^ ph[21] ^ ph[22] ^ ph[24] ^ ph[25];
            ecc[1]   = ph[ 0] ^ ph[ 1] ^ ph[ 3] ^ ph[ 4] ^ ph[ 6] ^ ph[ 8] ^ ph[10] ^ ph[12] ^
                       ph[14] ^ ph[17] ^ ph[20] ^ ph[21] ^ ph[22] ^ ph[23] ^ ph[25];
            ecc[0]   = ph[ 0] ^ ph[ 1] ^ ph[ 2] ^ ph[ 4] ^ ph[ 5] ^ ph[ 7] ^ ph[10] ^ ph[11] ^
                       ph[13] ^ ph[16] ^ ph[20] ^ ph[21] ^ ph[22] ^ ph[23] ^ ph[24];
            return ecc;
        end else begin
            ph = {wc, vc, dt};
            ecc[7:6] = vcx;
            ecc[5]   = ph[10] ^ ph[11] ^ ph[12] ^ ph[13] ^ ph[14] ^ ph[15] ^ ph[16] ^ ph[17] ^
                       ph[18] ^ ph[19] ^ ph[21] ^ ph[22] ^ ph[23];
            ecc[4]   = ph[ 4] ^ ph[ 5] ^ ph[ 6] ^ ph[ 7] ^ ph[ 8] ^ ph[ 9] ^ ph[16] ^ ph[17] ^
                       ph[18] ^ ph[19] ^ ph[20] ^ ph[22] ^ ph[23];
            ecc[3]   = ph[ 1] ^ ph[ 2] ^ ph[ 3] ^ ph[ 7] ^ ph[ 8] ^ ph[ 9] ^ ph[13] ^ ph[14] ^
                       ph[15] ^ ph[19] ^ ph[20] ^ ph[21] ^ ph[23];
            ecc[2]   = ph[ 0] ^ ph[ 2] ^ ph[ 3] ^ ph[ 5] ^ ph[ 6] ^ ph[ 9] ^ ph[11] ^ ph[12] ^
                       ph[15] ^ ph[18] ^ ph[20] ^ ph[21] ^ ph[22];
            ecc[1]   = ph[ 0] ^ ph[ 1] ^ ph[ 3] ^ ph[ 4] ^ ph[ 6] ^ ph[ 8] ^ ph[10] ^ ph[12] ^
                       ph[14] ^ ph[17] ^ ph[20] ^ ph[21] ^ ph[22] ^ ph[23];
            ecc[0]   = ph[ 0] ^ ph[ 1] ^ ph[ 2] ^ ph[ 4] ^ ph[ 5] ^ ph[ 7] ^ ph[10] ^ ph[11] ^
                       ph[13] ^ ph[16] ^ ph[20] ^ ph[21] ^ ph[22] ^ ph[23];
            return ecc;
        end
    endfunction

    // Drive idle (valid=0) for one cycle
    task automatic drive_idle();
        @(posedge clk_i);
        axis_byte_tvalid_i <= 1'b0;
        axis_byte_tlast_i  <= 1'b0;
        axis_byte_tdata_i  <= '0;
        axis_byte_tuser_i  <= '0;
        dbg_crc_valid_r    <= 1'b0;
    endtask

    // Drive one beat and hold until handshake (valid & ready). Wait for posedge before asserting so
    // outputs are clock-aligned. #0 yields so DUT updates tready before we sample.
    task automatic drive_beat(input [TDATA_WIDTH-1:0] tdata, input tlast, input [TUSER_WIDTH-1:0] tuser);
//        @(posedge clk_i);   // align to clock before asserting
        axis_byte_tdata_i  <= tdata;
        axis_byte_tvalid_i <= 1'b1;
        axis_byte_tlast_i  <= tlast;
        axis_byte_tuser_i  <= tuser;
        do begin
            @(posedge clk_i);
//            #0;   // yield so DUT updates tready before we sample
            if (!rst_n_i) begin
                axis_byte_tvalid_i <= 1'b0;
                axis_byte_tlast_i  <= 1'b0;
                axis_byte_tdata_i  <= '0;
                axis_byte_tuser_i  <= '0;
                return;
            end
        end while (!(axis_byte_tvalid_i && axis_byte_tready_o));
    endtask

    // Inter-packet gap: valid low for gap_cycles (0 to 255)
    task automatic inter_packet_gap(input int gap_cycles);
        int i;
        axis_byte_tvalid_i <= 1'b0;
        axis_byte_tlast_i  <= 1'b0;
        axis_byte_tdata_i  <= '0;
        axis_byte_tuser_i  <= '0;
        for (i = 0; i < gap_cycles; i++)
            @(posedge clk_i);
    endtask

    // Short packet: 1 beat, 4 bytes = byte0=data_id, byte1=data_lo, byte2=data_hi, byte3=ECC (CSI-2 order).
    // 64-bit: upper 32 bits zero-padded.
    task automatic drive_short_packet(input [1:0] vc, input [1:0] vcx, input [5:0] dt, input [7:0] d0, input [7:0] d1);
        reg [7:0] data_id, ecc;
        reg [TDATA_WIDTH-1:0] tdata;
        reg [TUSER_WIDTH-1:0] tuser;
        data_id = {vc, dt};
        ecc     = ecc_byte(dt, vc, vcx, 16'h0);
        if (BYTES_IN_PARALLEL == 4)
            tdata = {ecc, d1, d0, data_id};
        else
            tdata = {32'b0, ecc, d1, d0, data_id};  // 64-bit: zero-pad upper 32 bits
        tuser   = '0;
        tuser[0]   = 1'b0;
        tuser[3:2] = vc;   // DUT uses tuser VC/VCX for ECC when ECC_INSERT_EN ON
        tuser[5:4] = vcx;
        if (BYTES_IN_PARALLEL == 8) begin
            tuser[41:40] = vc;   // 64-bit: Header 2 VC2
            tuser[43:42] = vcx;   // 64-bit: Header 2 VCX2
        end
        drive_beat(tdata, 1'b1, tuser);
        packets_sent++;
    endtask

    // Long packet: header (4B) + payload (payload_bytes) + footer (2B CRC).
    // 32-bit: payload_bytes 32..94. 64-bit: header beat has first 4 payload bytes, payload_bytes 20..94.
    // (64-bit DUT byte stream packetizer has WC>=20 FSM constraint; WC<20 would hang.)
    task automatic drive_long_packet(input [1:0] vc, input [1:0] vcx, input [5:0] dt, input [15:0] payload_bytes);
        reg [15:0] crc;
        reg [15:0] crc_send;
        reg [15:0] crc_running;
        reg [7:0] payload_mem [0:93];
        int i, j, full_beats, last_bytes, remain;
        reg [TDATA_WIDTH-1:0] tdata;
        reg [TUSER_WIDTH-1:0] tuser;
        reg [15:0] wc;

        if (BYTES_IN_PARALLEL == 4) begin
            if (payload_bytes < 32 || payload_bytes > 94) begin
                $error("byte_stream_pkt_gen: payload_bytes must be 32..94 for 32-bit");
                dbg_crc_valid_r <= 1'b0;
                return;
            end
        end else begin
            if (payload_bytes < 20 || payload_bytes > 94) begin
                $error("byte_stream_pkt_gen: payload_bytes must be 20..94 for 64-bit");
                dbg_crc_valid_r <= 1'b0;
                return;
            end
        end
        wc = payload_bytes;

        for (i = 0; i < payload_bytes; i++)
            payload_mem[i] = 8'(i % 256);

        crc = 16'hFFFF;
        for (i = 0; i < payload_bytes; i++)
            crc = crc16_byte(crc, payload_mem[i]);
        crc_send = (CRC_INSERT_EN == "ON") ? DUMMY_CRC : crc;

        dbg_crc_calculated_r <= crc;
        dbg_crc_send_r       <= crc_send;
        dbg_payload_bytes_r  <= payload_bytes;
        dbg_crc_valid_r      <= 1'b1;

        crc_running = 16'hFFFF;
        dbg_crc_running_r <= crc_running;
        dbg_crc_byte_idx_r <= 8'd0;

        tuser = '0;
        tuser[0] = 1'b0;
        tuser[3:2] = vc;   // DUT uses tuser VC/VCX for ECC when ECC_INSERT_EN ON
        tuser[5:4] = vcx;
        if (BYTES_IN_PARALLEL == 8) begin
            tuser[41:40] = vc;   // 64-bit: Header 2 VC2
            tuser[43:42] = vcx;   // 64-bit: Header 2 VCX2
        end

        if (BYTES_IN_PARALLEL == 4) begin
            // --- 32-bit path ---
            tdata = {{vcx, ecc_byte(dt, vc, vcx, wc)[5:0]}, wc[15:8], wc[7:0], {vc, dt}};
            drive_beat(tdata, 1'b0, tuser);

            full_beats = payload_bytes / 4;
            last_bytes = payload_bytes % 4;

            for (i = 0; i < full_beats; i++) begin
                tdata = {payload_mem[i*4+3], payload_mem[i*4+2], payload_mem[i*4+1], payload_mem[i*4+0]};
                write_payload_bytes(4, payload_mem[i*4+0], payload_mem[i*4+1], payload_mem[i*4+2], payload_mem[i*4+3]);
                drive_beat(tdata, 1'b0, tuser);
                for (j = 0; j < 4; j++) crc_running = crc16_byte(crc_running, payload_mem[i*4+j]);
                dbg_crc_running_r <= crc_running;
                dbg_crc_data_r    <= {32'b0, payload_mem[i*4+3], payload_mem[i*4+2], payload_mem[i*4+1], payload_mem[i*4+0]};
                dbg_crc_byte_idx_r <= 8'(i*4 + 4);
            end

            if (last_bytes == 2) begin
                tdata = {crc_send[15:8], crc_send[7:0], payload_mem[full_beats*4+1], payload_mem[full_beats*4+0]};
                write_payload_bytes(2, payload_mem[full_beats*4+0], payload_mem[full_beats*4+1], 8'h0, 8'h0);
                drive_beat(tdata, 1'b1, tuser);
                for (j = 0; j < 2; j++) crc_running = crc16_byte(crc_running, payload_mem[full_beats*4+j]);
                dbg_crc_running_r <= crc_running;
                dbg_crc_data_r    <= {48'b0, payload_mem[full_beats*4+1], payload_mem[full_beats*4+0]};
                dbg_crc_byte_idx_r <= 8'(full_beats*4 + 2);
            end else if (last_bytes == 1) begin
                tdata = {8'h0, crc_send[15:8], crc_send[7:0], payload_mem[full_beats*4+0]};
                write_payload_bytes(1, payload_mem[full_beats*4+0], 8'h0, 8'h0, 8'h0);
                drive_beat(tdata, 1'b1, tuser);
                crc_running = crc16_byte(crc_running, payload_mem[full_beats*4+0]);
                dbg_crc_running_r <= crc_running;
                dbg_crc_data_r    <= {56'b0, payload_mem[full_beats*4+0]};
                dbg_crc_byte_idx_r <= 8'(full_beats*4 + 1);
            end else if (last_bytes == 3) begin
                tdata = {crc_send[7:0], payload_mem[full_beats*4+2], payload_mem[full_beats*4+1], payload_mem[full_beats*4+0]};
                write_payload_bytes(3, payload_mem[full_beats*4+0], payload_mem[full_beats*4+1], payload_mem[full_beats*4+2], 8'h0);
                drive_beat(tdata, 1'b0, tuser);
                for (j = 0; j < 3; j++) crc_running = crc16_byte(crc_running, payload_mem[full_beats*4+j]);
                dbg_crc_running_r <= crc_running;
                dbg_crc_data_r    <= {40'b0, payload_mem[full_beats*4+2], payload_mem[full_beats*4+1], payload_mem[full_beats*4+0]};
                dbg_crc_byte_idx_r <= 8'(full_beats*4 + 3);
                tdata = {24'h0, crc_send[15:8]};
                drive_beat(tdata, 1'b1, tuser);
            end else begin
                tdata = {16'h0, crc_send};
                drive_beat(tdata, 1'b1, tuser);
            end
        end else begin
            // --- 64-bit path: header beat = [DI, WC_L, WC_H, ECC, P0, P1, P2, P3] ---
            tdata = {payload_mem[3], payload_mem[2], payload_mem[1], payload_mem[0],
                     {vcx, ecc_byte(dt, vc, vcx, wc)[5:0]}, wc[15:8], wc[7:0], {vc, dt}};
            write_payload_bytes(4, payload_mem[0], payload_mem[1], payload_mem[2], payload_mem[3]);
            drive_beat(tdata, 1'b0, tuser);
            for (j = 0; j < 4; j++) crc_running = crc16_byte(crc_running, payload_mem[j]);
            dbg_crc_running_r <= crc_running;
            dbg_crc_data_r    <= {payload_mem[3], payload_mem[2], payload_mem[1], payload_mem[0], 32'b0};
            dbg_crc_byte_idx_r <= 8'd4;

            remain = payload_bytes - 4;
            full_beats = remain / 8;
            last_bytes = remain % 8;

            for (i = 0; i < full_beats; i++) begin
                tdata = {payload_mem[i*8+11], payload_mem[i*8+10], payload_mem[i*8+9], payload_mem[i*8+8],
                         payload_mem[i*8+7], payload_mem[i*8+6], payload_mem[i*8+5], payload_mem[i*8+4]};
                write_payload_bytes(8, payload_mem[i*8+4], payload_mem[i*8+5], payload_mem[i*8+6], payload_mem[i*8+7],
                                   payload_mem[i*8+8], payload_mem[i*8+9], payload_mem[i*8+10], payload_mem[i*8+11]);
                drive_beat(tdata, 1'b0, tuser);
                for (j = 0; j < 8; j++) crc_running = crc16_byte(crc_running, payload_mem[i*8+4+j]);
                dbg_crc_running_r <= crc_running;
                dbg_crc_data_r    <= {payload_mem[i*8+11], payload_mem[i*8+10], payload_mem[i*8+9], payload_mem[i*8+8],
                                      payload_mem[i*8+7], payload_mem[i*8+6], payload_mem[i*8+5], payload_mem[i*8+4]};
                dbg_crc_byte_idx_r <= 8'(4 + (i+1)*8);
            end

            // Footer: last_bytes (0-8) payload + 2 CRC
            if (last_bytes == 0) begin
                tdata = {48'h0, crc_send};
                drive_beat(tdata, 1'b1, tuser);
            end else if (last_bytes <= 6) begin
                // 1..6 payload + 2 CRC fits in one 8-byte beat: [P4..P(4+n-1), CRC_lo, CRC_hi]
                tdata = '0;
                for (i = 0; i < last_bytes; i++)
                    tdata[i*8 +: 8] = payload_mem[full_beats*8+4+i];
                tdata[last_bytes*8 +: 8] = crc_send[7:0];
                tdata[(last_bytes+1)*8 +: 8] = crc_send[15:8];
                case (last_bytes)
                    1: write_payload_bytes(1, payload_mem[full_beats*8+4], 8'h0, 8'h0, 8'h0);
                    2: write_payload_bytes(2, payload_mem[full_beats*8+4], payload_mem[full_beats*8+5], 8'h0, 8'h0);
                    3: write_payload_bytes(3, payload_mem[full_beats*8+4], payload_mem[full_beats*8+5], payload_mem[full_beats*8+6], 8'h0);
                    4: write_payload_bytes(4, payload_mem[full_beats*8+4], payload_mem[full_beats*8+5], payload_mem[full_beats*8+6], payload_mem[full_beats*8+7]);
                    5: write_payload_bytes(5, payload_mem[full_beats*8+4], payload_mem[full_beats*8+5], payload_mem[full_beats*8+6], payload_mem[full_beats*8+7], payload_mem[full_beats*8+8]);
                    6: write_payload_bytes(6, payload_mem[full_beats*8+4], payload_mem[full_beats*8+5], payload_mem[full_beats*8+6], payload_mem[full_beats*8+7], payload_mem[full_beats*8+8], payload_mem[full_beats*8+9]);
                    default: ;
                endcase
                drive_beat(tdata, 1'b1, tuser);
                for (j = 0; j < last_bytes; j++) crc_running = crc16_byte(crc_running, payload_mem[full_beats*8+4+j]);
                dbg_crc_running_r <= crc_running;
                case (last_bytes)
                    1: dbg_crc_data_r <= {56'b0, payload_mem[full_beats*8+4]};
                    2: dbg_crc_data_r <= {48'b0, payload_mem[full_beats*8+5], payload_mem[full_beats*8+4]};
                    3: dbg_crc_data_r <= {40'b0, payload_mem[full_beats*8+6], payload_mem[full_beats*8+5], payload_mem[full_beats*8+4]};
                    4: dbg_crc_data_r <= {32'b0, payload_mem[full_beats*8+7], payload_mem[full_beats*8+6], payload_mem[full_beats*8+5], payload_mem[full_beats*8+4]};
                    5: dbg_crc_data_r <= {24'b0, payload_mem[full_beats*8+8], payload_mem[full_beats*8+7], payload_mem[full_beats*8+6], payload_mem[full_beats*8+5], payload_mem[full_beats*8+4]};
                    6: dbg_crc_data_r <= {16'b0, payload_mem[full_beats*8+9], payload_mem[full_beats*8+8], payload_mem[full_beats*8+7], payload_mem[full_beats*8+6], payload_mem[full_beats*8+5], payload_mem[full_beats*8+4]};
                    default: dbg_crc_data_r <= 64'b0;
                endcase
                dbg_crc_byte_idx_r <= 8'(4 + full_beats*8 + last_bytes);
            end else if (last_bytes == 7) begin
                tdata = {crc_send[7:0], payload_mem[full_beats*8+10], payload_mem[full_beats*8+9], payload_mem[full_beats*8+8],
                         payload_mem[full_beats*8+7], payload_mem[full_beats*8+6], payload_mem[full_beats*8+5], payload_mem[full_beats*8+4]};
                write_payload_bytes(7, payload_mem[full_beats*8+4], payload_mem[full_beats*8+5], payload_mem[full_beats*8+6],
                                   payload_mem[full_beats*8+7], payload_mem[full_beats*8+8], payload_mem[full_beats*8+9], payload_mem[full_beats*8+10], 8'h0);
                drive_beat(tdata, 1'b0, tuser);
                for (j = 0; j < 7; j++) crc_running = crc16_byte(crc_running, payload_mem[full_beats*8+4+j]);
                dbg_crc_running_r <= crc_running;
                dbg_crc_data_r    <= {8'b0, payload_mem[full_beats*8+10], payload_mem[full_beats*8+9], payload_mem[full_beats*8+8],
                                      payload_mem[full_beats*8+7], payload_mem[full_beats*8+6], payload_mem[full_beats*8+5], payload_mem[full_beats*8+4]};
                dbg_crc_byte_idx_r <= 8'(4 + full_beats*8 + 7);
                tdata = {56'h0, crc_send[15:8]};
                drive_beat(tdata, 1'b1, tuser);
            end else begin
                tdata = {payload_mem[full_beats*8+11], payload_mem[full_beats*8+10], payload_mem[full_beats*8+9], payload_mem[full_beats*8+8],
                         payload_mem[full_beats*8+7], payload_mem[full_beats*8+6], payload_mem[full_beats*8+5], payload_mem[full_beats*8+4]};
                write_payload_bytes(8, payload_mem[full_beats*8+4], payload_mem[full_beats*8+5], payload_mem[full_beats*8+6], payload_mem[full_beats*8+7],
                                   payload_mem[full_beats*8+8], payload_mem[full_beats*8+9], payload_mem[full_beats*8+10], payload_mem[full_beats*8+11]);
                drive_beat(tdata, 1'b0, tuser);
                for (j = 0; j < 8; j++) crc_running = crc16_byte(crc_running, payload_mem[full_beats*8+4+j]);
                dbg_crc_running_r <= crc_running;
                dbg_crc_data_r    <= {payload_mem[full_beats*8+11], payload_mem[full_beats*8+10], payload_mem[full_beats*8+9], payload_mem[full_beats*8+8],
                                      payload_mem[full_beats*8+7], payload_mem[full_beats*8+6], payload_mem[full_beats*8+5], payload_mem[full_beats*8+4]};
                dbg_crc_byte_idx_r <= 8'(4 + full_beats*8 + 8);
                tdata = {48'h0, crc_send};
                drive_beat(tdata, 1'b1, tuser);
            end
        end
        packets_sent++;
    endtask

    // Run a sequence: list of packet types (0=short, 1=long) and optional payload size for long.
    // long_payload_sizes[] used for each long packet; 32-bit: 32..94, 64-bit: 20..94.
    task automatic run_sequence(
        input int packet_types[],      // 0=short, 1=long
        input int gap_cycles,          // 0 to 255
        input int long_payload_sizes[] // length = count of long packets; each 32..94
    );
        int i, k, pload;
        k = 0;
        for (i = 0; i < packet_types.size(); i++) begin
            inter_packet_gap(gap_cycles);
            if (packet_types[i] == 0)
                drive_short_packet(2'b10, 2'b0, 6'h00, 8'h00, 8'h00);  // VC=2, DT=0x00, data=0
            else begin
                pload = (k < long_payload_sizes.size()) ? long_payload_sizes[k] : (32 + (i % 3));
                if (BYTES_IN_PARALLEL == 4) begin
                    if (pload < 32) pload = 32;
                end else begin
                    if (pload < 20) pload = 20;
                end
                if (pload > 94) pload = 94;
                drive_long_packet(2'b10, 2'b0, 6'h2E, pload);  // VC=2, DT=0x2E (raw8), payload
                k++;
            end
        end
        inter_packet_gap(gap_cycles);
    endtask

    // Run 3-frame sequence: FS -> LS -> long (active pixel) -> LE -> FE per frame.
    // Short packets: FS=0x00, FE=0x01, LS=0x02, LE=0x03. Long: RGB565=0x22 or RGB888=0x24.
    // gap_cycles: 0 = back-to-back; 1..255 = idle cycles between packets.
    task automatic run_frame_sequence(
        input int num_frames,        // e.g. 3
        input int gap_cycles,        // 0 to 255 (0 = back-to-back)
        input [5:0] long_dt,         // DT_RGB565 (0x22) or DT_RGB888 (0x24)
        input [15:0] payload_bytes   // 32..94 (32-bit) or 20..94 (64-bit)
    );
        int f;
        if (BYTES_IN_PARALLEL == 4 && (payload_bytes < 32 || payload_bytes > 94)) begin
            $error("byte_stream_pkt_gen: run_frame_sequence payload_bytes must be 32..94 for 32-bit");
            return;
        end
        if (BYTES_IN_PARALLEL == 8 && (payload_bytes < 20 || payload_bytes > 94)) begin
            $error("byte_stream_pkt_gen: run_frame_sequence payload_bytes must be 20..94 for 64-bit");
            return;
        end
        for (f = 0; f < num_frames; f++) begin
            inter_packet_gap(gap_cycles);
            drive_short_packet(2'b00, 2'b0, DT_FRAME_START, 8'h00, 8'h00);  // Frame Start
            inter_packet_gap(gap_cycles);
            drive_short_packet(2'b00, 2'b0, DT_LINE_START, 8'h00, 8'h00);   // Line Start
            inter_packet_gap(gap_cycles);
            drive_long_packet(2'b00, 2'b0, long_dt, payload_bytes);         // Active pixel (RGB565 or RGB888)
            inter_packet_gap(gap_cycles);
            drive_short_packet(2'b00, 2'b0, DT_LINE_END, 8'h00, 8'h00);      // Line End
            inter_packet_gap(gap_cycles);
            drive_short_packet(2'b00, 2'b0, DT_FRAME_END, 8'h00, 8'h00);    // Frame End
        end
        inter_packet_gap(gap_cycles);
    endtask

    // Initial: drive idle out of reset
    initial begin
        axis_byte_tvalid_i = 1'b0;
        axis_byte_tlast_i  = 1'b0;
        axis_byte_tdata_i  = '0;
        axis_byte_tuser_i  = '0;
        dbg_crc_calculated_r = 0;
        dbg_crc_send_r       = 0;
        dbg_crc_running_r    = 0;
        dbg_crc_data_r       = 0;
        dbg_payload_bytes_r  = 0;
        dbg_crc_byte_idx_r   = 0;
        dbg_crc_valid_r      = 0;
        wait (rst_n_i);
        @(posedge clk_i);
    end

endmodule
