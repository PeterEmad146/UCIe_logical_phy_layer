`timescale 1ns/1ps

module lphy_sb_crc (
  // TX Sideband Parity Generation
  input logic [63:0] i_lphy_sb_crc_tx_header_in,        // 64-bit Header (Phase 0 and Phase 1)
  input logic [63:0] i_lphy_sb_crc_tx_data_in,          // 64-bit Data Payload (Phase 2 and Phase 3)
  input logic i_lphy_sb_crc_tx_has_data,                // High if the Packet type includes a data payload

  // Header with Bit 63 (DP) and Bit 62 (CP) correctly populated
  output logic [63:0] o_lphy_sb_crc_tx_header_out, 

  // RX Sideband Parity Checking
  input logic [63:0] i_lphy_sb_crc_rx_header_in, 
  input logic [63:0] i_lphy_sb_crc_rx_data_in, 
  input logic [63:0] i_lphy_sb_crc_rx_has_data,

  // Error flags (Should be routed to fatal UIE escalation logic)
  output logic o_lphy_sb_crc_rx_cp_err,                 // High if Control Parity mismatch
  output logic o_lphy_sb_crc_rx_dp_err                  // High if Data Parity mismatch
);

  // TX Logic
  logic internal_tx_cp_gen;
  logic internal_tx_dp_gen;

  // Data Parity is the even parity of all bits in the data payload
  // If there is not data payload, this bit is set to 0b. 
  assign internal_tx_dp_gen = i_lphy_sb_crc_tx_has_data ? ^i_lphy_sb_crc_tx_data_in : 1'b0;

  // Control Parity is the even parity of all the header bits excluding DP (and CP itself)
  // Bits [61:0] represent the header excluding CP (Bit 62) and DP (Bit 63).
  assign internal_tx_cp_gen = ^i_lphy_sb_crc_tx_header_in[61:0];

  // Assemble the final header for transmission
  assign o_lphy_sb_crc_tx_header_out = {internal_tx_dp_gen, internal_tx_cp_gen, i_lphy_sb_crc_tx_header_in[61:0]};


endmodule