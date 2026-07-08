`timescale 1ns/1ps

module lphy_sb_pkt_enc(
  
  input logic i_lphy_sb_pkt_enc_clk, 
  input logic i_lphy_sb_pkt_enc_rst_n, 

  // Handshake
  input logic i_lphy_sb_pkt_enc_req_valid, 
  output logic o_lphy_sb_pkt_enc_req_ready, 

  // Common Packet Fileds
  input logic [4:0] i_lphy_sb_pkt_enc_opcode,        // 5-bit opcode (Table 47)
  input logic [2:0] i_lphy_sb_pkt_enc_srcid,         // 3-bit source ID
  input logic [2:0] i_lphy_sb_pkt_enc_dstid,         // 3-bit Destination ID
  input logic i_lphy_sb_pkt_enc_ep,                  // Data Poison bit
  input logic i_lphy_sb_pkt_enc_cr,                  // Credit return bit
  input logic [63:0] i_lphy_sb_pkt_enc_payload_in,   // 64-bit Data Payload (if applicable)

  // Register Access Specific Fields
  input logic [4:0] i_lphy_sb_pkt_enc_tag,           // 5-bit Request Tag
  input logic [7:0] i_lphy_sb_pkt_enc_be,            // 8-bit Byte Enables
  input logic [23:0] i_lphy_sb_pkt_enc_addr,         // 24-bit Address (Requests only)
  input logic [2:0] i_lphy_sb_pkt_enc_cp_status,     // 3-bit Completion Status (Completions Only)

  // Message Specific Fields
  input logic [7:0] i_lphy_sb_pkt_enc_msgcode,       // 8-bit Message Code
  input logic [7:0] i_lphy_sb_pkt_enc_msgsubcode,    // 8-bit Message Subcode
  input logic [15:0] i_lphy_sb_pkt_enc_msginfo,      // 16-bit Message Info

  // Formatted Output to Sideband TX Serializer
  output logic o_lphy_sb_pkt_enc_pkt_valid, 
  output logic [63:0] o_lphy_sb_pkt_enc_pkt_header,
  output logic [63:0] o_lphy_sb_pkt_enc_pkt_data, 
  output logic o_lphy_sb_pkt_enc_pkt_has_data
);

  logic internal_is_reg_req;
  logic internal_is_reg_cpl;
  logic internal_is_msg;
  logic internal_has_data;
  logic [31:0] internal_phase0_reg;
  logic [31:0] internal_phase1_reg;
  logic [63:0] internal_raw_header;
  logic [63:0] internal_calc_header;

  // Decode Opcode to determine packet type and data presense (Table 47)
  always_comb begin
    internal_is_msg = (i_lphy_sb_pkt_enc_opcode == 5'b10010) || 
             (i_lphy_sb_pkt_enc_opcode == 5'b11011);

    internal_has_data = (i_lphy_sb_pkt_enc_opcode == 5'b00001) ||   // 32b Mem Write
               (i_lphy_sb_pkt_enc_opcode == 5'b00101) ||   // 32b Cfg Write
               (i_lphy_sb_pkt_enc_opcode == 5'b01001) ||   // 64b Mem Write
               (i_lphy_sb_pkt_enc_opcode == 5'b01101) ||   // 64b Cfg Write
               (i_lphy_sb_pkt_enc_opcode == 5'b10001) ||   // Cpl with 32b Data
               (i_lphy_sb_pkt_enc_opcode == 5'b11001) ||   // Cpl with 64b Data
               (i_lphy_sb_pkt_enc_opcode == 5'b11011) ||   // Message with 64b Data

    internal_is_reg_req = (i_lphy_sb_pkt_enc_opcode == 5'b00000) ||
                 (i_lphy_sb_pkt_enc_opcode == 5'b00001) ||
                 (i_lphy_sb_pkt_enc_opcode == 5'b00100) ||
                 (i_lphy_sb_pkt_enc_opcode == 5'b00101) ||
                 (i_lphy_sb_pkt_enc_opcode == 5'b01000) || 
                 (i_lphy_sb_pkt_enc_opcode == 5'b01001) ||
                 (i_lphy_sb_pkt_enc_opcode == 5'b01100) ||
                 (i_lphy_sb_pkt_enc_opcode == 5'b01101);
    
    internal_is_reg_cpl = (i_lphy_sb_pkt_enc_opcode == 5'b10000);
                 (i_lphy_sb_pkt_enc_opcode == 5'b10001);
                 (i_lphy_sb_pkt_enc_opcode == 5'b11001);
  end

  // Assemble the 64-bit Header (Phase 0 and Phase 1)
  always_comb begin
    if (internal_is_msg) begin
      // Message Format 
      // Phase 0: srcid [31:29], rsvd[28:22], msgcode[21:14], rsvd[13:5], opcode[4:0]
      internal_phase0_reg = {i_lphy_sb_pkt_enc_srcid, 7'h00, i_lphy_sb_pkt_enc_msgcode, 
                             9'h000, i_lphy_sb_pkt_enc_opcode};
      // Phase 1: dp[31], cp[30], rsvd[29:27], dstid[26:24], msginfo[23:8], msgsubcode[7:0]
      // Note: dp and cp are left 0 here; the will be calculated by the CRC block.
      internal_phase1_reg = {2'b00, 3'b000, i_lphy_sb_pkt_enc_dstid, i_lphy_sb_pkt_enc_msginfo,
                             i_lphy_sb_pkt_enc_msgsubcode};
    end else if (internal_is_reg_cpl) begin
      // Register Access Completions
      // Phase 0: srcid[31:28], rsvd[28:27], tag[26:22], be[21:14], rsvd[13:6], ep[5], opcode[4:0]
      internal_phase0_reg = {i_lphy_sb_pkt_enc_srcid, 2'b00, i_lphy_sb_pkt_enc_tag, i_lphy_sb_pkt_enc_be,
                             8'h00, i_lphy_sb_pkt_enc_ep, i_lphy_sb_pkt_enc_opcode};
      // Phase 1: dp[31], cp[30], cr[29], rsvd[28:27], dstid[26:24], rsvd[23:3], cp_status[2:0]
      internal_phase1_reg = {2'b00, i_lphy_sb_pkt_enc_cr, 2'b00, i_lphy_sb_pkt_enc_dstid,
                             21'b0, i_lphy_sb_pkt_enc_cp_status};
    end else begin
      // Register Access Requests
      // Phase 0: srcid[31:28], rsvd[28:27], tag[26:22], be[21:14], rsvd[13:6], ep[5], opcode[4:0]
      internal_phase0_reg = {i_lphy_sb_pkt_enc_srcid, 2'b00, i_lphy_sb_pkt_enc_tag, i_lphy_sb_pkt_enc_be,
                             8'h00, i_lphy_sb_pkt_enc_ep, i_lphy_sb_pkt_enc_opcode};
      // Phase 1: dp[31], cp[30], cr[29], rsvd[28:27], dstid[26:24], addr[23:0]
      internal_phase1_reg = {2'b00, i_lphy_sb_pkt_enc_cr, 2'b00, i_lphy_sb_pkt_enc_dstid,
                             i_lphy_sb_pkt_enc_addr};
    end  
    internal_raw_header = {internal_phase1_reg, internal_phase0_reg};
  end

  // Instantiate Phase 1 Parity Calculator
  lphy_sb_crc parity_calc (
    .i_lphy_sb_crc_tx_header_in(internal_raw_header), 
    .i_lphy_sb_crc_tx_data_in(i_lphy_sb_pkt_enc_payload_in),
    .i_lphy_sb_crc_tx_has_data(internal_has_data),
    .o_lphy_sb_crc_tx_header_out(internal_calc_header),
    .i_lphy_sb_crc_rx_header_in(64'h0),
    .i_lphy_sb_crc_rx_data_in(64'h0), 
    .i_lphy_sb_crc_rx_has_data(1'b0), 
    .o_lphy_sb_crc_rx_cp_err(), 
    .o_lphy_sb_crc_rx_dp_err()
  );

  

endmodule