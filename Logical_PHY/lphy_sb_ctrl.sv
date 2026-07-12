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

  // Internal Signals
  logic internal_tx_allowed;
  logic internal_seq_tx_ready;
  logic internal_fire_encoder;

  logic internal_enc_pkt_valid; 
  logic [63:0] internal_enc_pkt_header;
  logic [63:0] internal_enc_pkt_data; 
  logic internal_enc_pkt_has_data;

  logic internal_dec_pkt_valid;
  logic [63:0] internal_dec_pkt_header;
  logic [63:0] internal_dec_pkt_data;

  // Decode Opcode for Flow Control
  logic internal_is_reg_req, internal_is_reg_cpl, internal_is_msg;

  always_comb begin
    internal_is_reg_req = (i_lphy_sb_ctrl_tx_opcode == 5'b00000) ||
                          (i_lphy_sb_ctrl_tx_opcode == 5'b00001) ||
                          (i_lphy_sb_ctrl_tx_opcode == 5'b00100) ||
                          (i_lphy_sb_ctrl_tx_opcode == 5'b00101) ||
                          (i_lphy_sb_ctrl_tx_opcode == 5'b01000) ||
                          (i_lphy_sb_ctrl_tx_opcode == 5'b01001) ||
                          (i_lphy_sb_ctrl_tx_opcode == 5'b01100) ||
                          (i_lphy_sb_ctrl_tx_opcode == 5'b01101);
    
    internal_is_reg_cpl = (i_lphy_sb_ctrl_tx_opcode == 5'b10000) ||
                          (i_lphy_sb_ctrl_tx_opcode == 5'b10001) ||
                          (i_lphy_sb_ctrl_tx_opcode == 5'b11001);
    
    internal_is_msg = (i_lphy_sb_ctrl_tx_opcode == 5'b10010) ||
                      (i_lphy_sb_ctrl_tx_opcode == 5'b11011);
  end

  // 1. Flow Control
  lphy_sb_flow_ctrl #(.LOCAL_CREDITS_INIT(32)) fc_inst (
    .i_lphy_sb_flow_ctrl_clk(i_lphy_sb_ctrl_clk), 
    .i_lphy_sb_flow_ctrl_rst_n(i_lphy_sb_ctrl_rst_n), 
    .i_lphy_sb_flow_ctrl_rdi_in_reset(i_lphy_sb_ctrl_rdi_in_reset), 
    .i_lphy_sb_flow_ctrl_req_valid(i_lphy_sb_ctrl_tx_req_valid), 
    .i_lphy_sb_flow_ctrl_is_reg_req(internal_is_reg_req), 
    .i_lphy_sb_flow_ctrl_is_reg_cpl(internal_is_reg_cpl), 
    .i_lphy_sb_flow_ctrl_is_msg(internal_is_msg), 
    .o_lphy_sb_flow_ctrl_tx_allowed(internal_tx_allowed), 
    .i_lphy_sb_flow_ctrl_local_crd_ret(i_lphy_sb_ctrl_tx_local_crd_ret), 
    .i_lphy_sb_flow_ctrl_remote_crd_ret(o_lphy_sb_ctrl_rx_req_valid & o_lphy_sb_ctrl_rx_cr)
  );

  // 2. Packet Encoder
  assign internal_fire_encoder = i_lphy_sb_ctrl_tx_req_valid & internal_tx_allowed & internal_seq_tx_ready;
  assign o_lphy_sb_ctrl_tx_req_ready internal_tx_allowed & internal_seq_tx_ready;

  lphy_sb_pkt_enc enc_inst (
    .i_lphy_sb_pkt_enc_clk(i_lphy_sb_ctrl_clk),
    .i_lphy_sb_pkt_enc_rst_n(i_lphy_sb_ctrl_rst_n), 
    .i_lphy_sb_pkt_enc_req_valid(internal_fire_encoder), 
    .o_lphy_sb_pkt_enc_req_ready(), 
    .i_lphy_sb_pkt_enc_opcode(i_lphy_sb_ctrl_tx_opcode), 
    .i_lphy_sb_pkt_enc_srcid(i_lphy_sb_ctrl_tx_srcid), 
    .i_lphy_sb_pkt_enc_dstid(i_lphy_sb_ctrl_tx_dstid), 
    .i_lphy_sb_pkt_enc_ep(i_lphy_sb_ctrl_tx_ep), 
    .i_lphy_sb_pkt_enc_cr(i_lphy_sb_ctrl_tx_cr), 
    .i_lphy_sb_pkt_enc_payload_in(i_lphy_sb_ctrl_tx_payload), 
    .i_lphy_sb_pkt_enc_tag(i_lphy_sb_ctrl_tx_tag), 
    .i_lphy_sb_pkt_enc_be(i_lphy_sb_ctrl_tx_be), 
    .i_lphy_sb_pkt_enc_addr(i_lphy_sb_ctrl_tx_addr), 
    .i_lphy_sb_pkt_enc_cp_status(i_lphy_sb_ctrl_tx_cp_status), 
    .i_lphy_sb_pkt_enc_msgcode(i_lphy_sb_ctrl_tx_msgcode), 
    .i_lphy_sb_pkt_enc_msgsubcode(i_lphy_sb_ctrl_tx_msgsubcode), 
    .i_lphy_sb_pkt_enc_msginfo(i_lphy_sb_ctrl_tx_msginfo), 
    .o_lphy_sb_pkt_enc_pkt_valid(internal_enc_pkt_valid), 
    .o_lphy_sb_pkt_enc_pkt_header(internal_enc_pkt_header), 
    .o_lphy_sb_pkt_enc_pkt_data(internal_enc_pkt_data), 
    .o_lphy_sb_pkt_enc_pkt_has_data(internal_has_data)
  );

  // 3. TX Word Sequencer
  typedef enum logic {ST_TX_IDLE, ST_TX_DATA} tx_st_t;
  tx_st_t tx_state, tx_next_state;
  
  logic [63:0] internal_hold_tx_data;

  // State Register
  always_ff @(posedge i_lphy_sb_ctrl_clk or negedge i_lphy_sb_ctrl_rst_n) begin
    if (!i_lphy_sb_ctrl_rst_n) tx_state <= ST_TX_IDLE;
    else tx_state <= tx_next_state;
  end
  
  // Next State Logic
  always_comb begin
    tx_next_state = tx_state;
    case (tx_state)
      ST_TX_IDLE: begin
        // If a packet arrives and it has data, move to DATA state
        if (internal_enc_pkt_valid && internal_seq_tx_ready && internal_enc_pkt_has_data)
          tx_next_state = ST_TX_DATA;
      end

      ST_TX_DATA : begin
        // Once the AFE accepts the data payload, return to IDLE
        if (i_lphy_sb_ctrl_afe_tx_ready)
          tx_next_state = ST_TX_IDLE;
      end
    endcase
  end

  // Registered Outputs (Glitch-Free to AFE)
  always_ff @(posedge i_lphy_sb_ctrl_clk or negedge i_lphy_sb_ctrl_rst_n) begin
    if(!i_lphy_sb_ctrl_rst_n) begin
      o_lphy_sb_ctrl_afe_tx_valid <= 1'b0;
      o_lphy_sb_ctrl_afe_tx_data <= 64'h0;
      internal_seq_tx_ready <= 1'b1;
      internal_hold_tx_data <= 64'h0;
    end else begin
      case (tx_state)
        ST_TX_IDLE: begin
          if (internal_enc_pkt_valid && internal_seq_tx_ready) begin
            // Push Header to AFE
            o_lphy_sb_ctrl_afe_tx_valid <= 1'b1;
            o_lphy_sb_ctrl_afe_tx_data <= internal_enc_pkt_header;

            if (internal_enc_pkt_has_data) begin
              internal_hold_tx_data <= internal_enc_pkt_data;
              internal_seq_tx_ready <= 1'b0;
            end
          end else if (i_lphy_sb_ctrl_afe_tx_ready) begin
            // Clear valid if no new packet is pending
            o_lphy_sb_ctrl_afe_tx_valid <= 1'b0;
          end
        end
        
        ST_TX_DATA: begin
          if (i_lphy_sb_ctrl_afe_tx_ready) begin
            // Push Payload to AFE
            o_lphy_sb_ctrl_afe_tx_valid <= 1'b1;
            o_lphy_sb_ctrl_afe_tx_data <= internal_hold_tx_data;
            internal_seq_tx_read <= 1'b1;                           // Ready for next packet
          end
        end
      endcase
    end
  end


endmodule