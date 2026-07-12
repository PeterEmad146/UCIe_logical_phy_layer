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


endmodule
