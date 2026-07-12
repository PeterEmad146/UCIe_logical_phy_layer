`timescale 1ns/1ps

module lphy_valid_framer (
  input logic i_lphy_valid_framer_clk, 
  input logic i_lphy_valid_framer_rst_n, 

  // Inputs from TX Byte-to-Lane Mapper and Flow Control
  input logic i_lphy_valid_framer_lane_valid,       // High if data is currently being transmitted
  input logic i_lphy_valid_framer_credit_return,    // High if a Retimer credit needs to be released

  // 8-bit Parallel Output to the Serializer
  // (Bit 0 is transmitted first on the wire)
  output logic [7:0] o_lphy_valid_framer_valid_frame_out
);

  always_ff @(posedge i_lphy_valid_framer_clk or negedge i_lphy_valid_framer_rst_n) begin
    if (!i_lphy_valid_framer_rst_n) begin
      o_lphy_valid_framer_valid_frame_out <= 8'b0000_0000;
    end else begin
      // Implement Table 17: Valid Framing for retimers
      case ({i_lphy_valid_framer_credit_return, i_lphy_valid_framer_lane_valid})
        2'b11:  o_lphy_valid_framer_valid_frame_out <= 8'b1111_1111;    // Data Valid + 1 Credit
        2'b01:  o_lphy_valid_framer_valid_frame_out <= 8'b0000_1111;    // Data Valid + No Credit
        2'b10:  o_lphy_valid_framer_valid_frame_out <= 8'b1111_0000;    // No Data + 1 Credit
        2'b00:  o_lphy_valid_framer_valid_frame_out <= 8'b0000_0000;    // No Data + No Credit      
      endcase
    end
  end

endmodule
