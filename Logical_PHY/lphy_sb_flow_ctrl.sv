`timescale 1ns/1ps

module lphy_sb_flow_ctrl #(
  parameter int LOCAL_CREDITS_INIT = 32             // Maximum 32 local credits per spec
)(
  input logic i_lphy_sb_flow_ctrl_clk,
  input logic i_lphy_sb_flow_ctrl_rst_n, 
  input logic i_lphy_sb_flow_ctrl_rdi_in_reset,     // High when RDI state is Reset

  // Request from Sideband Controller/Encoder
  input logic i_lphy_sb_flow_ctrl_req_valid, 
  input logic i_lphy_sb_flow_ctrl_is_reg_req,       // High for Register Access Request
  input logic i_lphy_sb_flow_ctrl_is_reg_cpl,       // High for Register Access Completion
  input logic i_lphy_sb_flow_ctrl_is_msg,           // High for Messages (with or without data)

  // Authorization Output
  output logic o_lphy_sb_flow_ctrl_tx_allowed,      // High if credits are available to send the requests
  
  // Credit Return Inputs
  input logic i_lphy_sb_flow_ctrl_local_crd_ret,    // From Local RDI (pl_cfg_crd)
  input logic i_lphy_sb_flow_ctrl_remote_crd_ret    // Extracted from received sideband header 'Cr' bit
);
  
  // Credit Counters
  // Local RDI Credits (Max 32)
  logic [5:0] internal_local_crd_count;

  // Remote E2E credits for Register Accesses (Initialized to 4)
  logic [2:0] internal_remote_crd_count;

  // Credit Consumption logic
  logic internal_consume_local;
  logic internal_consume_remote;

  
  
endmodule