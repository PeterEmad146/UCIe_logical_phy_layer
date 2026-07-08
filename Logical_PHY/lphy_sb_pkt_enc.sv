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

endmodule