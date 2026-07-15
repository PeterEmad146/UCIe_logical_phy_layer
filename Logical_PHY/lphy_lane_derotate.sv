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


  // 2. Elaboration-Time Expected Pattern Generation
  
  // Using generate blocks evaluates these constants before simulation runs
  logic [7:0] exp_norm_b0 [NUM_LANES-1:0];
  logic [7:0] exp_norm_b1 [NUM_LANES-1:0];
  logic [7:0] exp_rev_b0 [NUM_LANES-1:0];
  logic [7:0] exp_rev_b1 [NUM_LANES-1:0];

  generate
    for (genvar i = 0; i < NUM_LANES; i++) begin: gen_exp_patterns
      wire [7:0] norm_id = i[7:0];
      wire [7:0] rev_id = (NUM_LANES - 1 - i);

      // Pattern: 0 1 0 1 Lane ID (LSB First) 0 1 0 1
      assign exp_norm_b0[i] = {norm_id[3:0], 4'b1010};
      assign exp_norm_b1[i] = {4'b1010, norm_id[7:4]};
      
      assign exp_rev_b0[i]  = {rev_id[3:0], 4'b1010};
      assign exp_rev_b1[i]  = {4'b1010, rev_id[7:4]};
    end
  endgenerate

  // 3. Per-Lane ID Reversal Detection (MBINIT.REVERSALMB)
  logic [7:0] internal_prev_byte [NUM_LANES-1:0];
  logic [7:0] internal_cycle_cnt;
  logic [6:0] interal_normal_hits [NUM_LANES-1:0];
  logic [6:0] internal_reversed_hits [NUM_LANES-1:0];

  // Combinatorial Majority Vote Tally
  logic [7:0] internal_total_normal;
  logic [7:0] internal_total_reversed;

  always_comb begin
    internal_total_normal = '0;
    internal_total_reversed = '0;
    for (int i = 0; i < NUM_LANES; i++) begin
      if (interal_normal_hits[i] >= 16) internal_total_normal = internal_total_normal + 1'b1;
      if (internal_reversed_hits[i] >= 16) internal_total_reversed = internal_total_reversed + 1'b1;
    end
  end
    
  always_ff @(posedge i_lphy_lane_derotate_clk or negedge i_lphy_lane_derotate_rst_n) begin
    if (!i_lphy_lane_derotate_rst_n) begin
      for (int i = 0; i < NUM_LANES; i++) begin
        internal_prev_byte[i] <= '0;
        interal_normal_hits[i] <= '0;
        internal_reversed_hits[i] <= '0;
      end
      internal_cycle_cnt <= '0;
      o_lphy_lane_derotate_reversal_detected <= 1'b0;
      o_lphy_lane_derotate_reversal_check_done <= 1'b0;
    end else begin
      o_lphy_lane_derotate_reversal_check_done <= 1'b0;   // Default
      
      if (i_lphy_lane_derotate_en_reversal_check && i_lphy_lane_derotate_rx_lane_valid) begin
        internal_cycle_cnt <= internal_cycle_cnt + 1'b1;

        for (int i = 0; i < NUM_LANES; i++) begin
          internal_prev_byte[i] <= i_lphy_lane_derotate_rx_lane_data_in[i];

          // Check for Normal ID
          if (internal_prev_byte[i] == exp_norm_b0[i] && i_lphy_lane_derotate_rx_lane_data_in[i] == exp_norm_b1[i]) begin
            if (interal_normal_hits[i] < 127) interal_normal_hits[i] <= interal_normal_hits[i] + 1'b1;
          end

          // Check for Reversed ID
          if (internal_prev_byte[i] == exp_rev_b0[i] && i_lphy_lane_derotate_rx_lane_data_in[i] == exp_rev_b1[i]) begin
            if (internal_reversed_hits[i] < 127) internal_reversed_hits[i] <= internal_reversed_hits[i] + 1'b1;
          end
        end

        // Evaluate results after 128 iterations (256 clock cycles)
        if (internal_cycle_cnt == 8'hFF) begin
          if (internal_total_reversed > internal_total_normal) begin
            o_lphy_lane_derotate_reversal_detected <= 1'b1;
          end else begin
            o_lphy_lane_derotate_reversal_detected <= 1'b0;
          end
          o_lphy_lane_derotate_reversal_check_done <= 1'b1;
        end
      end else if (!i_lphy_lane_derotate_en_reversal_check) begin
        internal_cycle_cnt <= '0;
        for (int i = 0; i < NUM_LANES; i++) begin
          interal_normal_hits [i] <= '0;
          internal_reversed_hits[i] <= '0;
        end
      end
    end
  end
endmodule
