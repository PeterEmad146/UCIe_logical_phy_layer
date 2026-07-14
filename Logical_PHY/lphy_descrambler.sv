`timescale 1ps/1ps

module lphy_descrambler (
  input logic i_lphy_descrambler_clk,
  input logic i_lphy_descrambler_rst_n, 
  input logic i_lphy_descrambler_enable, 
  input logic i_lphy_descrambler_load_seed, 
  input logic [22:0] i_lphy_descrambler_seed_in, 
  input logic [7:0] i_lphy_descrambler_data_in,     // Scrambled 8-bit payload
  output logic [7:0] o_lphy_descrambler_data_out 
);

  logic [22:0] internal_lfsr_reg;
  logic [22:0] internal_next_lfsr;
  logic [7:0] internal_descramble_key;

  always_comb begin
    internal_next_lfsr = internal_lfsr_reg;
    for (int i = 0 ; i < 8; i ++) begin
      internal_descramble_key[i] = internal_next_lfsr[22];
      if (internal_next_lfsr[22]) begin
        internal_next_lfsr = (internal_next_lfsr << 1) ^ 23'h210125;
      end else begin
        internal_next_lfsr = (internal_next_lfsr << 1);
      end
    end
  end

  always_ff @(posedge i_lphy_descrambler_clk or negedge i_lphy_descrambler_rst_n) begin
    if (!i_lphy_descrambler_rst_n) begin
      internal_lfsr_reg <= 23'h1DBFBC;
    end else if (i_lphy_descrambler_load_seed) begin
      internal_lfsr_reg <= i_lphy_descrambler_seed_in;
    end else if (i_lphy_descrambler_enable) begin
      internal_lfsr_reg <= internal_next_lfsr;
    end
  end

  // Descrambling is identically XORing the scrambled data with the same generated key
  assign o_lphy_descrambler_data_out = i_lphy_descrambler_enable ? (i_lphy_descrambler_data_in ^ internal_descramble_key) : i_lphy_descrambler_data_in;

endmodule
