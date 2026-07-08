`timescale 1ns/1ps

module lphy_sb_pkt_dec (

  input logic i_lphy_sb_pkt_dec_clk, 
  input logic i_lphy_sb_pkt_dec_rst_n, 

  // Input from RX Deserializer
  input logic i_lphy_sb_pkt_dec_pkt_valid, 
  input logic [63:0] i_lphy_sb_pkt_dec_pkt_header,
  input logic [63:0] i_lphy_sb_pkt_dec_pkt_data, 

  // Common Decoded Fields
  output logic o_lphy_sb_pkt_dec_req_valid, 
  output logic [4:0] o_lphy_sb_pkt_dec_opcode, 
  output logic [2:0] o_lphy_sb_pkt_dec_srcid, 
  output logic [2:0] o_lphy_sb_pkt_dec_dstid,
  output logic o_lphy_sb_pkt_dec_ep, 
  output logic o_lphy_sb_pkt_dec_cr, 
  output logic [63:0] o_lphy_sb_pkt_dec_payload_out, 

  // Register Access Fileds
  output logic [4:0] o_lphy_sb_pkt_dec_tag, 
  output logic [7:0] o_lphy_sb_pkt_dec_be, 
  output logic [23:0] o_lphy_sb_pkt_dec_addr, 
  output logic [2:0] o_lphy_sb_pkt_dec_cp_status,

  // Message Specific Fields
  output logic [7:0] o_lphy_sb_pkt_dec_msgcode, 
  output logic [7:0] o_lphy_sb_pkt_dec_msgsubcode, 
  output logic [15:0] o_lphy_sb_pkt_dec_msginfo, 

  // Error Flags
  output logic o_lphy_sb_pkt_dec_parity_err
);


endmodule