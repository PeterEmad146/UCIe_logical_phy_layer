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

  // Postamble Counter (Tracks 8 clock cycles / 16 UI after Valid Drops)
  always_ff @(posedge i_lphy_clkgate_rx_clk or negedge i_lphy_clkgate_rx_rst_n) begin
    if (!i_lphy_clkgate_rx_rst_n) begin
      internal_postamble_cnt <= 4'd2;   // Start fully idle
    end else begin
      if (i_lphy_clkgate_rx_valid_in) begin
        internal_postamble_cnt <= 4'd0;
      end else if (internal_postamble_cnt < 4'd2) begin
        internal_postamble_cnt <= internal_postamble_cnt + 1'b1;
      end
    end
  end

  
  
endmodule
