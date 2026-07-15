`timescale 1ps/1ps

module lphy_valid_deframer(
  input logic i_lphy_valid_deframer_clk, 
  input logic i_lphy_valid_deframer_rst_n,

  // 8-bit Parallel Input from the Deserializer
  // (Bit 0 was received first on the wire)
  input logic [7:0] i_lphy_valid_deframer_valid_frame_in, 
  
  // Extracted Outputs
  output logic o_lphy_valid_deframer_lane_valid,    // High if data is valid for this 8-UI block
  output logic o_lphy_valid_deframer_credit_return, // High if a Retimer credit is released
  output logic o_lphy_valid_deframer_framing_err    // High if an illegal frame is received
);

  always_ff @(posedge i_lphy_valid_deframer_clk or negedge i_lphy_valid_deframer_rst_n) begin
    if (!i_lphy_valid_deframer_rst_n) begin
      o_lphy_valid_deframer_lane_valid <= 1'b0;
      o_lphy_valid_deframer_credit_return <= 1'b0;
      o_lphy_valid_deframer_framing_err <= 1'b0;
    end else begin
      // Default: no error
      o_lphy_valid_deframer_framing_err <= 1'b0;

      // Decode the 8-UI Valid frame (Table 17 of the UCIe spec)
      case (i_lphy_valid_deframer_valid_frame_in)
        8'b1111_1111: begin
          o_lphy_valid_deframer_lane_valid <= 1'b1;
          o_lphy_valid_deframer_credit_return <= 1'b1;
        end
        8'b0000_1111: begin
          // Asserts for the first 4 UI, de-asserts for the last 4 UI
          o_lphy_valid_deframer_lane_valid <= 1'b1;
          o_lphy_valid_deframer_credit_return <= 1'b0;
        end
        8'b1111_0000: begin
          // De-asserts for the first 4 UI, asserts for the last 4 UI
          o_lphy_valid_deframer_lane_valid <= 1'b0;
          o_lphy_valid_deframer_credit_return <= 1'b1;
        end
        8'b0000_0000: begin
          o_lphy_valid_deframer_lane_valid <= 1'b0;
          o_lphy_valid_deframer_credit_return <= 1'b0;
        end
        default: begin
          // Any other bit pattern implies a bit flip / channel error
          o_lphy_valid_deframer_lane_valid <= 1'b0;
          o_lphy_valid_deframer_credit_return <= 1'b0;
          o_lphy_valid_deframer_framing_err <= 1'b1;
        end
      endcase
    end
  end
endmodule