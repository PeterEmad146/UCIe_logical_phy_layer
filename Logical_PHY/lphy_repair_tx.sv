`timescale 1ps/1ps

module lphy_repair_tx (
  input logic [7:0] i_lphy_repair_tx_tx_logical_data [63:0], 
  input logic [63:0] i_lphy_repair_tx_lane_failed, 

  output logic [7:0] o_lphy_repair_tx_tx_physical_data [63:0],
  output logic [7:0] o_lphy_repair_tx_tx_redundant_data [3:0]
);

  // Group 1: Lower 32 Lanes
  logic [1:0] internal_fail_cnt_lower;
  logic [4:0] internal_f0_l, internal_f1_l;

  always_comb begin
    internal_fail_cnt_lower = 0;
    internal_f0_l = '0;
    internal_f1_l = '0;

    for (int i = 0; i < 32; i++) begin
      if(i_lphy_repair_tx_lane_failed[i]) begin
        if (internal_fail_cnt_lower == 0) internal_f0_l = i[4:0];
        else if (internal_fail_cnt_lower == 1) internal_f1_l = i[4:0];
        internal_fail_cnt_lower++;
      end
    end

    for (int i = 0; i < 32; i++)
      o_lphy_repair_tx_tx_physical_data[i] = i_lphy_repair_tx_tx_logical_data[i];

    // Initialize Group 1 redundant pins
    o_lphy_repair_tx_tx_redundant_data[0] = 8'h00;
    o_lphy_repair_tx_tx_redundant_data[1] = 8'h00;
    
    if (internal_fail_cnt_lower == 1) begin
      for (int i = 0; i < 32; i++) begin
        if (i < internal_f0_l)
          o_lphy_repair_tx_tx_physical_data[i] = i_lphy_repair_tx_tx_logical_data[i+1];
        else if (i == internal_f0_l)
          o_lphy_repair_tx_tx_physical_data[i] = 8'h00;
      end
      // ERROR FIX 1: Use specific index for pin 0 instead of whole array assignment
      o_lphy_repair_tx_tx_redundant_data[0] = i_lphy_repair_tx_tx_logical_data[0];
    end
    else if (internal_fail_cnt_lower == 2) begin
      for (int i = 0; i < 32; i++) begin
        if (i < internal_f0_l)
          o_lphy_repair_tx_tx_physical_data[i] = i_lphy_repair_tx_tx_logical_data[i+1];
        else if (i == internal_f0_l || i == internal_f1_l)
          o_lphy_repair_tx_tx_physical_data[i] = 8'h00;
        else if (i > internal_f1_l)
          o_lphy_repair_tx_tx_physical_data[i] = i_lphy_repair_tx_tx_logical_data[i-1];
      end
      // ERROR FIX 1: Indexing correct redundant pins (0 and 1)
      o_lphy_repair_tx_tx_redundant_data[0] = i_lphy_repair_tx_tx_logical_data[0];
      o_lphy_repair_tx_tx_redundant_data[1] = i_lphy_repair_tx_tx_logical_data[31];
    end
  end
  

  // Group 2: Upper 32 Lanes
  logic [1:0] internal_fail_cnt_upper;
  logic [5:0] internal_f0_u, internal_f1_u;

  always_comb begin
    internal_fail_cnt_upper = 0;
    internal_f0_u = '0;
    internal_f1_u = '0;

    for (int i = 32; i < 64; i++) begin
      if (i_lphy_repair_tx_lane_failed[i]) begin
        if (internal_fail_cnt_upper == 0) internal_f0_u = i[5:0];
        else if (internal_fail_cnt_upper == 1) internal_f1_u = i[5:0];
        internal_fail_cnt_upper++;
      end
    end

    for (int i = 32; i < 64; i++)
      o_lphy_repair_tx_tx_physical_data[i] = i_lphy_repair_tx_tx_logical_data[i];
    
    // Initialize Group 2 Redundant pins
    o_lphy_repair_tx_tx_redundant_data[2] = 8'h00;
    o_lphy_repair_tx_tx_redundant_data[3] = 8'h00;

    if (internal_fail_cnt_upper == 1) begin
      for (int i = 32; i < 64; i++) begin
        if (i < internal_f0_u)
          o_lphy_repair_tx_tx_physical_data[i] = i_lphy_repair_tx_tx_logical_data[i+1];
        else if (i == internal_f0_u)
          o_lphy_repair_tx_tx_physical_data[i] = 8'h00;
      end
      // Error Fix 2: Correct index [2] (tx_redundant_data only goes 0 to 3)
      o_lphy_repair_tx_tx_redundant_data[2] = i_lphy_repair_tx_tx_logical_data[32];
    end 

    else if (internal_fail_cnt_upper == 2) begin
      for (int i = 32; i < 64; i++) begin
        if (i < internal_f0_u)
          o_lphy_repair_tx_tx_physical_data[i] = i_lphy_repair_tx_tx_logical_data[i+1];
        else if (i == internal_f0_u || i == internal_f1_u)
          o_lphy_repair_tx_tx_physical_data[i] = 8'h00;
        else if (i > internal_f1_u)
          o_lphy_repair_tx_tx_physical_data[i] = i_lphy_repair_tx_tx_logical_data[i-1];
      end
      // Error Fix 2: Correct indices [2] and [3]
      o_lphy_repair_tx_tx_redundant_data[2] = i_lphy_repair_tx_tx_logical_data[32];
      o_lphy_repair_tx_tx_redundant_data[3] = i_lphy_repair_tx_tx_logical_data[63];
    end
  end
endmodule
