`timescale 1ps/1ps

module lphy_clkgate_rx(
  input logic i_lphy_clkgate_rx_clk, 
  input logic i_lphy_clkgate_rx_rst_n, 

  // Configuration
  input logic i_lphy_clkgate_rx_free_run_mode,    // 1: Clock never gates, 0: Dynamic clock gating enabled

  // Input from Valid Deframer
  input logic i_lphy_clkgate_rx_valid_in,         // High when data is actively being received

  // Gated Clock Output for internal RX logic and Adapter
  output logic o_lphy_clkgate_rx_gated_clk
);

  logic [3:0] internal_postamble_cnt;
  logic internal_clk_en;
  logic internal_clk_en_latched;

    
endmodule