`timescale 1ps/1ps

module lphy_lane_id_detect #(
  parameter int NUM_LANES = 64
)(
  input logic i_lphy_lane_id_detect_clk,
  input logic i_lphy_lane_id_detect_rst_n,

  // Data from RX Valid Deframer / Deserializer
  input logic [7:0] i_lphy_lane_id_detect_rx_lane_data_in [NUM_LANES-1:0], 
  input logic i_lphy_lane_id_detect_rx_lane_valid, 

  // Control Signals from LTSSM (MBINIT.REPAIRMB)
  input logic i_lphy_lane_id_detect_en_lane_check,
  input logic i_lphy_lane_id_detect_is_reversed,

  // Outputs to Data Repair Controller
  output logic [NUM_LANES-1:0] i_lphy_repair_rx_lane_failed,
  output logic i_lphy_lane_id_detect_en_lane_check_done
);

  // 1. Elaboriation-Time Expected Pattern Generation
  logic [7:0] internal_exp_norm_b0 [NUM_LANES-1:0];
  logic [7:0] internal_exp_norm_b1 [NUM_LANES-1:0];
  logic [7:0] internal_exp_rev_b0 [NUM_LANES-1:0];
  logic [7:0] internal_exp_rev_b1 [NUM_LANES-1:0];    

  generate
    for (genvar i = 0; i < NUM_LANES; i++) begin: gen_exp_patterns
      wire [7:0] internal_norm_id = i[7:0];
      wire [7:0] internal_rev_id = (NUM_LANES - 1 - i);

      // Pattern: 0 1 0 1 Lane ID (LSB First) 0 1 0 1
      // Sent over 2 bytes
      assign internal_exp_norm_b0[i] = {internal_norm_id[3:0], 4'b1010};
      assign internal_exp_norm_b1[i] = {4'b1010, internal_norm_id[7:4]};
      
      assign internal_exp_rev_b0[i] = {internal_rev_id[3:0], 4'b1010};
      assign internal_exp_rev_b1[i] = {4'b1010, internal_rev_id[7:4]};
    end
  endgenerate

  // 2. Detection & Consecutive Hit Logic
  logic [7:0] internal_prev_byte [NUM_LANES-1:0];
  logic [7:0] internal_cycle_cnt;

  // Counters to track the mandatory 16 consecutive hits
  logic [4:0] internal_consec_hits [NUM_LANES-1:0];
  logic internal_lane_passed [NUM_LANES-1:0];

  always_ff @(posedge i_lphy_lane_id_detect_clk or negedge i_lphy_lane_id_detect_rst_n) begin
    if (!i_lphy_lane_id_detect_rst_n) begin
      internal_prev_byte <= '{default: '0};
      internal_consec_hits <= '{default: '0};
      internal_lane_passed <= '{default: '0};
      i_lphy_repair_rx_lane_failed <= '0;
      internal_cycle_cnt <= '0;
      i_lphy_lane_id_detect_en_lane_check_done <= 1'b0;
    end else begin
      i_lphy_lane_id_detect_en_lane_check_done <= 1'b0;

      if (i_lphy_lane_id_detect_en_lane_check && i_lphy_lane_id_detect_rx_lane_valid) begin
        internal_cycle_cnt <= internal_cycle_cnt + 1'b1;
        
        for (int i = 0; i < NUM_LANES; i++) begin
          internal_prev_byte[i] <= i_lphy_lane_id_detect_rx_lane_data_in[i];

          if (internal_cycle_cnt[0] == 1'b1) begin
            logic match;
            if (i_lphy_lane_id_detect_is_reversed) begin
              match = (internal_prev_byte[i] == internal_exp_rev_b0[i] && i_lphy_lane_id_detect_rx_lane_data_in[i] == internal_exp_rev_b1[i]);
            end else begin
              match = (internal_prev_byte[i] == internal_exp_norm_b0[i] && i_lphy_lane_id_detect_rx_lane_data_in[i] == internal_exp_norm_b1[i]);
            end

            if (match) begin
              // Increment consecutive hits, capping at 16
              if (internal_consec_hits[i] < 5'd16) begin
                internal_consec_hits[i] <= internal_consec_hits[i] + 1'b1;
              end
              // If we hit the 16th consective match, flag the lane as passed
              if (internal_consec_hits[i] == 5'd15) begin
                internal_lane_passed[i] <= 1'b1;
              end
            end else begin
              internal_consec_hits[i] <= '0;
            end
          end
        end

        // Evaluate results after 128 iterations (256 clock cycles)
        if (internal_cycle_cnt == 8'hFF) begin
          for (int i = 0; i < NUM_LANES; i++) begin
            i_lphy_repair_rx_lane_failed[i] <= ~internal_lane_passed[i];
          end
          i_lphy_lane_id_detect_en_lane_check_done <= 1'b1;
        end
      end else if (!i_lphy_lane_id_detect_en_lane_check) begin
        // Clear state when not testing 
        internal_cycle_cnt <= '0;
        i_lphy_lane_id_detect_en_lane_check_done <= 1'b0;
        for (int i = 0; i < NUM_LANES; i++) begin
          internal_consec_hits[i] <= '0;
          internal_lane_passed[i] <= 1'b0;
          i_lphy_repair_rx_lane_failed[i] <= 1'b0;
        end
      end
    end
  end
endmodule
