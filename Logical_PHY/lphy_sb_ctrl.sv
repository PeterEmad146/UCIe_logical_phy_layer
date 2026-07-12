`timescale 1ns/1ps

module lphy_sb_ctrl (
  input logic i_lphy_sb_ctrl_clk,   // Local Downstread processing Clock (800 MHz)
  input logic i_lphy_sb_ctrl_rst_n,
  input logic i_lphy_sb_ctrl_rdi_in_reset,

  // Local TX Interface (from D2D Adapter)
  input logic i_lphy_sb_ctrl_tx_req_valid,
  output logic o_lphy_sb_ctrl_tx_req_ready, 
  input logic [4:0] i_lphy_sb_ctrl_tx_opcode, 
  input logic [2:0] i_lphy_sb_ctrl_tx_srcid, 
  input logic [2:0] i_lphy_sb_ctrl_tx_dstid, 
  input logic i_lphy_sb_ctrl_tx_ep, 
  input logic i_lphy_sb_ctrl_tx_cr, 
  input logic [63:0] i_lphy_sb_ctrl_tx_payload, 
  input logic [4:0] i_lphy_sb_ctrl_tx_tag,
  input logic [7:0] i_lphy_sb_ctrl_tx_be, 
  input logic [23:0] i_lphy_sb_ctrl_tx_addr,
  input logic [2:0] i_lphy_sb_ctrl_tx_cp_status, 
  input logic [7:0] i_lphy_sb_ctrl_tx_msgcode, 
  input logic [7:0] i_lphy_sb_ctrl_tx_msgsubcode,
  input logic [15:0] i_lphy_sb_ctrl_tx_msginfo,
  input logic i_lphy_sb_ctrl_tx_local_crd_ret, 

  // Local RX Interface (to D2D Adapter)
  output logic o_lphy_sb_ctrl_rx_req_valid, 
  output logic [4:0] o_lphy_sb_ctrl_rx_opcode, 
  output logic [2:0] o_lphy_sb_ctrl_rx_srcid, 
  output logic [2:0] o_lphy_sb_ctrl_rx_dstid,
  output logic o_lphy_sb_ctrl_rx_ep,
  output logic o_lphy_sb_ctrl_rx_cr, 
  output logic [63:0] o_lphy_sb_ctrl_rx_payload, 
  output logic [4:0] o_lphy_sb_ctrl_rx_tag, 
  output logic [7:0] o_lphy_sb_ctrl_rx_be, 
  output logic [23:0] o_lphy_sb_ctrl_rx_addr, 
  output logic [2:0] o_lphy_sb_ctrl_rx_cp_status, 
  output logic [7:0] o_lphy_sb_ctrl_rx_msgcode, 
  output logic [7:0] o_lphy_sb_ctrl_rx_msgsubcode,
  output logic [15:0] o_lphy_sb_ctrl_rx_msginfo, 
  output logic o_lphy_sb_ctrl_rx_parity_err, 

  // Parallel Sideband Interface (To/From AFE)
  output logic o_lphy_sb_ctrl_afe_tx_valid, 
  output logic [63:0] o_lphy_sb_ctrl_afe_tx_data,   // Sends Header, then Payload sequentially
  input logic i_lphy_sb_ctrl_afe_tx_ready,          // AFE asserts when ready to accept 64-bit chunk

  input logic i_lphy_sb_ctrl_afe_rx_valid, 
  input logic [63:0] i_lphy_sb_ctrl_afe_rx_data,    // Receives Header, then payload sequentially
  output logic o_lphy_sb_ctrl_afe_rx_en             // Enables Sideband RX in the AFE
);


endmodule