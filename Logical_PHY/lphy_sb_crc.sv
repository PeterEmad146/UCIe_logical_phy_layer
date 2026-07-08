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



endmodule