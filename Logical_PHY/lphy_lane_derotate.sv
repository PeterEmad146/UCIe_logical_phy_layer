`timescale 1ps/1ps

module lphy_lane_derotate #(
  parameter int NUM_LANES = 16
)(
  input logic i_lphy_lane_derotate_clk, 
  input logic i_lphy_lane_derotate_rst_n,

  // Data from RX Valid Deframer / Deserializer
  input logic [7:0] i_lphy_lane_derotate_rx_lane_data_in [NUM_LANES-1:0], 
  input logic i_lphy_lane_derotate_rx_lane_valid, 

  // Control Signals from LTSSM (MBINIT.REVERSALMB state)
  input logic i_lphy_lane_derotate_en_reversal_check,
  output logic o_lphy_lane_derotate_reversal_detected,    // 1: Reversed, 0: Normal
  output logic o_lphy_lane_derotate_reversal_check_done,  // Pulses high when 128-iteration check is complete

  // Deskewed and Aligned Data to RX Top
  output logic [7:0] o_lphy_lane_derotate_rx_lane_data_out [NUM_LANES-1:0]
);

  // 1. Deskew Buffer Logic
  always_ff @(posedge i_lphy_lane_derotate_clk or negedge i_lphy_lane_derotate_rst_n) begin
    if (!i_lphy_lane_derotate_rst_n) begin
      for (int i = 0; i < NUM_LANES; i++) begin
        o_lphy_lane_derotate_rx_lane_data_out[i] <= '0;
      end
    end else if (i_lphy_lane_derotate_rx_lane_valid) begin
      for (int i = 0; i < NUM_LANES; i++) begin
        if (o_lphy_lane_derotate_reversal_detected)
          o_lphy_lane_derotate_rx_lane_data_out[i] <= i_lphy_lane_derotate_rx_lane_data_in[NUM_LANES-1-i];
        else 
          o_lphy_lane_derotate_rx_lane_data_out[i] <= i_lphy_lane_derotate_rx_lane_data_in[i];
      end
    end
  end

  
    
endmodule
