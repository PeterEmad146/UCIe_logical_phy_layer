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

  logic is_reg_req;
  logic is_reg_cpl;
  logic is_msg;
  logic has_data;
  logic [31:0] phase0_reg;
  logic [31:0] phase1_reg;
  logic [63:0] raw_header;
  logic [63:0] calc_header;

  // Decode Opcode to determine packet type and data presense (Table 47)
  always_comb begin
    is_msg = (i_lphy_sb_pkt_enc_opcode == 5'b10010) || 
             (i_lphy_sb_pkt_enc_opcode == 5'b11011);

    has_data = (i_lphy_sb_pkt_enc_opcode == 5'b00001) ||   // 32b Mem Write
               (i_lphy_sb_pkt_enc_opcode == 5'b00101) ||   // 32b Cfg Write
               (i_lphy_sb_pkt_enc_opcode == 5'b01001) ||   // 64b Mem Write
               (i_lphy_sb_pkt_enc_opcode == 5'b01101) ||   // 64b Cfg Write
               (i_lphy_sb_pkt_enc_opcode == 5'b10001) ||   // Cpl with 32b Data
               (i_lphy_sb_pkt_enc_opcode == 5'b11001) ||   // Cpl with 64b Data
               (i_lphy_sb_pkt_enc_opcode == 5'b11011) ||   // Message with 64b Data

    is_reg_req = (i_lphy_sb_pkt_enc_opcode == 5'b00000) ||
                 (i_lphy_sb_pkt_enc_opcode == 5'b00001) ||
                 (i_lphy_sb_pkt_enc_opcode == 5'b00100) ||
                 (i_lphy_sb_pkt_enc_opcode == 5'b00101) ||
                 (i_lphy_sb_pkt_enc_opcode == 5'b01000) || 
                 (i_lphy_sb_pkt_enc_opcode == 5'b01001) ||
                 (i_lphy_sb_pkt_enc_opcode == 5'b01100) ||
                 (i_lphy_sb_pkt_enc_opcode == 5'b01101);
    
    is_reg_cpl = (i_lphy_sb_pkt_enc_opcode == 5'b10000);
                 (i_lphy_sb_pkt_enc_opcode == 5'b10001);
                 (i_lphy_sb_pkt_enc_opcode == 5'b11001);
  end

endmodule