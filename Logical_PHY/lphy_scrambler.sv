`timescale 1ns / 1ps

module lphy_scrambler(
    input logic i_lphy_scrambler_clk,
    input logic i_lphy_scrambler_rst_n,             // Active-Low reset
    input logic i_lphy_scrambler_enable,            // High when data is valid and needs scrambling
    input logic i_lphy_scrambler_load_seed,         // Load the initial per-lane seed
    input logic [22:0] i_lphy_scrambler_seed_in,    // Per-lane seed value
    input logic [7:0] i_lphy_scrambler_data_in,     // 8-bit payload from datapath
    output logic [7:0] i_lphy_scramber_data_out
);

  logic [22:0] internal_lfsr_reg;
  logic [22:0] internal_next_lfsr;
  logic [7:0] internal_scramble_key;

  // Combinatorial block to advance LFSR by 8 steps and generate an 8-bit key
  always_comb begin
    internal_next_lfsr = internal_lfsr_reg;
    for (int i = 0; i < 8; i++) begin
      // The output bit of the LFSR is the MSB (bit 22)
      internal_scramble_key[i] = internal_next_lfsr[22];

      // Advance the LFSR state by 1 step
      if (internal_next_lfsr[22]) begin
        internal_next_lfsr = (internal_next_lfsr << 1) ^ 23'h210125;
      end else begin
        internal_next_lfsr = (internal_next_lfsr << 1);
      end
    end
  end

  // Sequential block to update the LFSR register
  always_ff @(posedge i_lphy_scrambler_clk or negedge i_lphy_scrambler_rst_n) begin
    if (!i_lphy_scrambler_rst_n) begin
      internal_lfsr_reg <= 23'h1DBFBC;  // Default to Lane 0 Seed
    end else if (i_lphy_scrambler_load_seed) begin
      internal_lfsr_reg <= i_lphy_scrambler_seed_in;
    end else if (i_lphy_scrambler_enable) begin
      internal_lfsr_reg <= internal_next_lfsr;
    end
  end

  // XOR the input data with the generated 8-bit scramble key
  // If enable is low, we pass the data through unmodified
  assign i_lphy_scramber_data_out = i_lphy_scrambler_enable ? (i_lphy_scrambler_data_in ^ internal_scramble_key) : i_lphy_scrambler_data_in;

endmodule
