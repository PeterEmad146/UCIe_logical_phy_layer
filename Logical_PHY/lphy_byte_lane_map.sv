`timescale 1ps/1ps

module lphy_byte_lane_map (
  input logic i_lphy_byte_lane_map_clk,
  input logic i_lphy_byte_lane_map_rst_n, 

  // Configuration
  input logic [1:0] i_lphy_byte_lane_map_link_width,    // 2'b00: x16, 2'b01: x32, 2'b10: x64

  // Interface from D2D Adapter (64 Bytes per transfer)
  input logic i_lphy_byte_lane_map_lp_valid, 
  input logic i_lphy_byte_lane_map_lp_irdy, 
  output logic o_lphy_byte_lane_map_pl_trdy, 
  input logic [511:0] i_lphy_byte_lane_map_lp_data, 

  // Output to Physical Lanes (up to 64 active lanes, 1 Byte per lane)
  output logic o_lphy_byte_lane_map_lane_valid,
  output logic [7:0] o_lphy_byte_lane_map_lane_data [63:0]
);

  logic [511:0] internal_buffer;
  logic [2:0] internal_chunk_cnt;
  logic internal_busy;

  // The PHY is ready to accept a new 64-byte payload chunck when it's not busy multiplexing
  assign o_lphy_byte_lane_map_pl_trdy = !internal_busy;

  always_ff @(posedge i_lphy_byte_lane_map_clk or negedge i_lphy_byte_lane_map_rst_n) begin
    if (!i_lphy_byte_lane_map_rst_n) begin
      internal_buffer <= '0;
      internal_chunk_cnt <= '0;
      internal_busy <= 1'b0;
      o_lphy_byte_lane_map_lane_valid <= 1'b0;
      for (int i = 0; i < 64; i++)
        o_lphy_byte_lane_map_lane_data[i] <= '0;
    end else begin
      // 1. Phase 0: New Data Acceptance
      if (!internal_busy && i_lphy_byte_lane_map_lp_valid && o_lphy_byte_lane_map_pl_trdy && i_lphy_byte_lane_map_lp_irdy) begin
        o_lphy_byte_lane_map_lane_valid <= 1'b1;
        internal_buffer <= i_lphy_byte_lane_map_lp_data;    // Capture full payload

        case (i_lphy_byte_lane_map_link_width)
          2'b10: begin    // x64
            for (int i = 0; i < 64; i++) o_lphy_byte_lane_map_lane_data[i] <= i_lphy_byte_lane_map_lp_data [i*8 +: 8];
            internal_busy <= 1'b0;
          end
          2'b01: begin    // x32
            for (int i = 0; i < 32; i++) o_lphy_byte_lane_map_lane_data[i] <= i_lphy_byte_lane_map_lp_data[i*8 +: 8];
            internal_busy <= 1'b1;
            internal_chunk_cnt <= 1;            
          end
          default: begin  // x16
            for (int i = 0; i < 16; i++) o_lphy_byte_lane_map_lane_data[i] <=  i_lphy_byte_lane_map_lp_data[i*8 +: 8];
            internal_busy <= 1'b1;
            internal_chunk_cnt <= 1;
          end
        endcase
      end

      // 2. PHASES 1-3: Sequential Mapping
      else if (internal_busy) begin
        o_lphy_byte_lane_map_lane_valid <= 1'b1;
        if (i_lphy_byte_lane_map_link_width == 2'b01) begin   // x32 Finish
          for (int i = 0; i < 32; i++) o_lphy_byte_lane_map_lane_data[i] <= internal_buffer[(i+32)*8 +: 8];
          internal_busy <= 1'b0;
        end else begin                                        // x16 Continue
          for (int i = 0; i < 16; i++) o_lphy_byte_lane_map_lane_data[i] <= internal_buffer[(i + internal_chunk_cnt*16)*8 +: 8];
          if (internal_chunk_cnt == 3) internal_busy <= 1'b0;
          else internal_chunk_cnt <= internal_chunk_cnt + 1;
        end
      end

      // 3. IDLE: Just clear valid, don't wipe the data lanes (optional for power, good for debug)
      else begin
        o_lphy_byte_lane_map_lane_valid <= 1'b0;
      end
    end
  end
endmodule
