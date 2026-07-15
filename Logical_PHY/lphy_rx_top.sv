`timescale 1ps/1ps

module lphy_rx_top #(
  parameter int NUM_LANES = 16
) (
  input logic i_lphy_rx_top_clk,
  input logic i_lphy_rx_top_rst_n,
  
  // Configuration
  input logic i_lphy_rx_top_free_run_mode, 

  // Control Signals from LTSSM
  input logic i_lphy_rx_top_en_reversal_check,
  output logic o_lphy_rx_top_reversal_detected,
  output logic o_lphy_rx_top_reversal_check_done, 
  output logic o_lphy_rx_top_framing_err, 

  output logic [63:0] o_lphy_rx_top_detected_lane_failures, 
  output logic o_lphy_rx_top_check_done,

  // Descrambling Control from LTSSM
  input logic i_lphy_rx_top_descrambler_en, 
  input logic i_lphy_rx_top_load_seed,
  input logic [22:0] i_lphy_rx_top_lane_seeds [63:0],

  // Repair Control from LTSSM
  input logic i_lphy_rx_top_repair_en, 
  input logic i_lphy_rx_top_en_lane_check,

  // Interface to D2D Adapter (RDI)
  output logic o_lphy_rx_top_pl_valid, 
  output logic [7:0] o_lphy_rx_top_pl_data [NUM_LANES-1:0], 
  output logic o_lphy_rx_top_credit_return, 
  output logic o_lphy_rx_top_rx_gated_clk, 

  // Parallel AFE Boundary (AFE Interface)
  input logic [7:0] i_lphy_rx_top_RXDATA [NUM_LANES-1:0], 
  input logic [7:0] i_lphy_rx_top_RXVLD, 
  input logic [7:0] i_lphy_rx_top_RXRD [3:0], 
  input logic i_lphy_rx_top_RXTRK,
  output logic o_lphy_rx_top_rx_en
);
    


endmodule
