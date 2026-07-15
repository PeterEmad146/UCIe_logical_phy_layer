`timescale 1ps/1ps

module lphy_repair_rx(
  // Physical Data from AFE
  input logic [7:0] i_lphy_repair_rx_physical_data [63:0], 
  input logic [7:0] i_lphy_repair_rx_redundant_data [3:0],

  // Failure Map from Data Repair Controller / Lane ID Detect
  input logic [63:0] i_lphy_repair_rx_lane_failed,    // 1: Physical Lane is broken

  // Logical Data to RX Top
  output logic [7:0] o_lphy_repair_rx_logical_data [63:0]
);
  
  // Group 1: Lower 32 Lanes (0 to 31) using RRD_P and RRD_P[5]
  logic [1:0] internal_fail_cnt_lower;
  logic [4:0] internal_f0_l, internal_f1_l;

  always_comb begin
    internal_fail_cnt_lower = 0;
    internal_f0_l = '0;
    internal_f1_l = '0;

    // Count failures and record their physical indices
    for (int i = 0; i < 32; i++) begin
      if (i_lphy_repair_rx_lane_failed[i]) begin
        if (internal_fail_cnt_lower == 0) internal_f0_l = i[4:0];
        else if (internal_fail_cnt_lower == 1) internal_f1_l = i[4:0];
        internal_fail_cnt_lower++;
      end
    end

    // Default 1:1 Mapping
    for (int i = 0; i < 32; i++) o_lphy_repair_rx_logical_data[i] = i_lphy_repair_rx_physical_data[i];

    if (internal_fail_cnt_lower == 1) begin
      // Single Failure: Reconstruct shift-right mapping 
      o_lphy_repair_rx_logical_data[0] = i_lphy_repair_rx_redundant_data[0];
      for (int i = 1; i <= 31; i++) begin
        if (i <= internal_f0_l)
          o_lphy_repair_rx_logical_data[i] = i_lphy_repair_rx_physical_data[i-1];
      end
    end

    else if (internal_fail_cnt_lower == 2) begin
      // Two Failures: Reconstruct split shift mapping
      o_lphy_repair_rx_logical_data[0] = i_lphy_repair_rx_redundant_data[0];
      o_lphy_repair_rx_logical_data[31] = i_lphy_repair_rx_redundant_data[1];

      for (int i = 1; i <= 30; i++) begin
        if (i <= internal_f0_l)
          o_lphy_repair_rx_logical_data[i] = i_lphy_repair_rx_physical_data[i-1];
        else if (i >= internal_f1_l) begin
          o_lphy_repair_rx_logical_data[i] = i_lphy_repair_rx_physical_data[i+1];
        end
      end
    end

    // Group 2: Upper 32 Lanes (32 to 63) using RRD_P[7] and RRD_P[8]
    logic [1:0] internal_fail_cnt_upper;
    logic [5:0] internal_f0_u, internal_f1_u;

    always_comb begin
      internal_fail_cnt_upper = 0;
      internal_f0_u = '0;
      internal_f1_u = '0;

      // Count failiures and record their physical indices
      for (int i = 32; i < 64; i++) begin
        if (i_lphy_repair_rx_lane_failed[i]) begin
          if (internal_fail_cnt_upper == 0) internal_f0_u = i[5:0];
          else if (internal_fail_cnt_upper == 1) internal_f1_u = i[5:0];
          internal_fail_cnt_upper++;
        end
      end

      // Default 1:1 mapping
      for (int i = 32; i < 64; i++) o_lphy_repair_rx_logical_data[i] = i_lphy_repair_rx_physical_data[i];

      if (internal_fail_cnt_upper == 1) begin
        // Single Failure: Reconstruct shift-right mapping
        o_lphy_repair_rx_logical_data[32] = i_lphy_repair_rx_redundant_data[2];
        for (int i = 33; i <= 63; i++) begin
          if (i <= internal_f0_u)
            o_lphy_repair_rx_logical_data[i] = i_lphy_repair_rx_physical_data[i-1];
        end
      end

      else if (internal_fail_cnt_upper == 2) begin
        // Two Failures: Reconstruct split shift mapping
        o_lphy_repair_rx_logical_data[32] = i_lphy_repair_rx_redundant_data[2];
        o_lphy_repair_rx_logical_data[63] = i_lphy_repair_rx_redundant_data[3];

        for (int i = 33; i <= 62; i++) begin
          if (i <= internal_f0_u)
            o_lphy_repair_rx_logical_data[i] = i_lphy_repair_rx_physical_data[i-1];
          else if (i >= internal_f1_u)
            o_lphy_repair_rx_logical_data[i] = i_lphy_repair_rx_physical_data[i+1];
        end
      end
    end
  end
endmodule