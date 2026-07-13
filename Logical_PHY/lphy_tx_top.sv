`timescale 1ps/1ps

module lphy_tx_top #(
  parameter int NUM_LANES = 16
)(
  // Byte-rate clock: one cycle = 8 UIs = one byte per lane
  input logic i_lphy_tx_top_clk,
  input logic i_lphy_tx_top_rst_n,

  // Configuration
  input logic [1:0] i_lphy_tx_top_link_width,       // 2'b00: x16, 2'b01: x32, 2'b10: x64
  input logic i_lphy_tx_top_free_run_mode,          // 1: Clock never gates, 0: Dynamic clock gating enabled
  input logic i_lphy_tx_top_select_valtrain,        // 0: Send per-lane ID pattern (MBINIT/SBINIT), 1: Send VALTRAIN pattern (MBTRAIN ValTrain substates)
  input logic i_lphy_tx_top_txtrk_en,               // 1: TXTRK carries Phase-1 replica

  // Scrambling Control from LTSSM (MBINIT State)
  input logic i_lphy_tx_top_scrambler_en,           // High during MBTRAIN and ACTIVE
  input logic i_lphy_tx_top_load_seed,              // Pulled high to load initial seeds
  input logic [22:0] i_lphy_tx_top_lane_seeds,    

  // Repair Control from LTSSM (MBINIT state)
  input logic i_lphy_tx_top_repair_en,              // 1: Redundancy routing active
  input logic [63:0] i_lphy_tx_top_ext_lane_failed_map,

  input logic i_lphy_tx_top_tx_training_en,         // 2: Send training pattern, 0: Send adapter data

  // Interface from D2D Adapter (RDI)
  input logic i_lphy_tx_top_lp_valid, 
  input logic i_lphy_tx_top_lp_irdy,
  output logic o_lphy_tx_top_pl_trdy, 
  input logic [511:0] i_lphy_tx_top_lp_data, 
  input logic i_lphy_tx_top_credit_return,          // From Flow Control for Retimer E2E Credits

  // Parallel AFE Boundary (AFE Interface)
  output logic [7:0] o_lphy_tx_top_TXDATA [NUM_LANES-1:0],  // 8-bit Parallel data per lane
  output logic [7:0] o_lphy_tx_top_TXVLD,                   // 8-bit Parallel valid frame
  output logic [7:0] o_lphy_tx_top_TXRD [3:0],              // 8-bit Parallel redundant data

  // AFE Control Flags (Digital to Analog)
  output logic o_lphy_tx_top_tx_clock_en,                   // Tells AFE to drive forwarded clock (includes postamble)
  output logic o_lphy_tx_top_tx_track_en                    // Tells AFE to drive the track clock
);

  // Internal Signals
  logic [7:0] internal_mapped_lane_data [63:0];
  logic internal_mapped_lane_valid;
  logic [7:0] internal_tx_valid_frame;
  logic internal_gated_tx_clk_en;

  logic [7:0] internal_scrambled_lane_data [63:0];
  logic [7:0] internal_repaired_lane_data [63:0];
  logic [7:0] internal_repaired_txrd_data [3:0];

  

endmodule
