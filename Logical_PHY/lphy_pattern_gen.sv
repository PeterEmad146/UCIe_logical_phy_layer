`timescale 1ns/1ps

module lphy_pattern_gen (
  input logic [7:0] i_lphy_pattern_gen_lane_id,       // 8-bit Lane ID (from Table 18/19)
  input logic i_lphy_pattern_gen_select_valtrain,     // 0 = Per-Lane ID Pattern, 1 = VALTRAIN PATTERN
   output logic [15:0] o_lphy_pattern_gen_pattern_out  // 16-bit training pattern output
);

  logic [15:0] internal_lane_id_pattern;
  logic [15:0] internal_valtrain_pattern;

  // 1. Per-Lane ID Pattern (Table 23 & 24)
  // Format: 0 1 0 1 | Lane ID (LSB First) | 0 1 0 1
  // To transmit '0 1 0 1' LSB-first, bit 0=0, bit 1=1, bit 2=0, bit 3=1 -> 4-b1010
  assign internal_lane_id_pattern[3:0] = 4'b1010;
  assign internal_lane_id_pattern[11:4] = i_lphy_pattern_gen_lane_id;
  assign internal_lane_id_pattern[15:12] = 4'b1010;

  // 2. VALTRAIN Pattern
  // Format: Four 1's followed by Four 0's.
  // LSB-first: bits 0-3 are 1, bits 4-7 are 0 -> 8'b00001111 (8'h0F)
  // Duplicated across 16 bits -> 16'h0F0F
  assign internal_valtrain_pattern = 16'h0F0F;

  // Output Mux
  assign o_lphy_pattern_gen_pattern_out = i_lphy_pattern_gen_select_valtrain ? internal_valtrain_pattern : internal_lane_id_pattern;

endmodule