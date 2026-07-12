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

  always_comb begin
    internal_consume_local = 1'b0;
    internal_consume_remote = 1'b0;

    if(i_lphy_sb_flow_ctrl_req_valid && o_lphy_sb_flow_ctrl_tx_allowed) begin
      // The Transmitter must not check for credits before sending Register Access Completions
      if (i_lphy_sb_flow_ctrl_is_reg_req) begin
        internal_consume_local = 1'b1;
        internal_consume_remote = 1'b1;
      end else if (i_lphy_sb_flow_ctrl_is_msg) begin
        internal_consume_local = 1'b1;
      end
    end
  end

  // Authorization logic
  always_comb begin
    if (i_lphy_sb_flow_ctrl_is_reg_cpl) begin
      // Completions must always sink and do not require credits
      o_lphy_sb_flow_ctrl_tx_allowed = 1'b0;
    end else if (i_lphy_sb_flow_ctrl_is_reg_req) begin
      // Needs both local RDI space and Remote E2E space
      o_lphy_sb_flow_ctrl_tx_allowed = (internal_local_crd_count > 0) && (internal_remote_crd_count > 0);
    end else if (i_lphy_sb_flow_ctrl_is_msg) begin
      // Only needs local RDI space
      o_lphy_sb_flow_ctrl_tx_allowed = (internal_local_crd_count > 0);
    end else begin
      o_lphy_sb_flow_ctrl_tx_allowed = 1'b0;
    end
  end

  // Sequential Counter Updates
  always_ff @(posedge i_lphy_sb_flow_ctrl_clk or negedge i_lphy_sb_flow_ctrl_rst_n) begin
    if(!i_lphy_sb_flow_ctrl_rst_n) begin
      internal_local_crd_count <= LOCAL_CREDITS_INIT[5:0];
      internal_remote_crd_count <= 3'd4;
    end else if (i_lphy_sb_flow_ctrl_rdi_in_reset) begin
      // The Adapter credit counters for register access request transmission
      // are initialized to 4 whenever RDI is in Reset state. 
      internal_local_crd_count <= LOCAL_CREDITS_INIT[5:0];
      internal_remote_crd_count <= 3'd4;
    end else begin
      // Local Credit Update
      if (internal_consume_local && !i_lphy_sb_flow_ctrl_local_crd_ret)
        internal_local_crd_count <= internal_local_crd_count - 1'b1;
      else if (!internal_consume_local && i_lphy_sb_flow_ctrl_local_crd_ret 
               && (internal_local_crd_count < LOCAL_CREDITS_INIT[5:0]))
        internal_local_crd_count <= internal_local_crd_count + 1'b1;
      // Remote Credit Update
      if (internal_consume_remote && !i_lphy_sb_flow_ctrl_remote_crd_ret)
        internal_remote_crd_count <= internal_remote_crd_count - 1'b1;
      else if (!internal_consume_remote && i_lphy_sb_flow_ctrl_remote_crd_ret 
               && (internal_remote_crd_count < 3'd4))
        internal_remote_crd_count <= internal_remote_crd_count + 1'b1;
    end
  end
endmodule
