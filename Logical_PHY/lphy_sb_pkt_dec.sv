`timescale 1ns/1ps

module lphy_sb_pkt_dec (

  input logic i_lphy_sb_pkt_dec_clk, 
  input logic i_lphy_sb_pkt_dec_rst_n, 

  // Input from RX Deserializer
  input logic i_lphy_sb_pkt_dec_pkt_valid, 
  input logic [63:0] i_lphy_sb_pkt_dec_pkt_header,
  input logic [63:0] i_lphy_sb_pkt_dec_pkt_data, 

  // Common Decoded Fields
  output logic o_lphy_sb_pkt_dec_req_valid, 
  output logic [4:0] o_lphy_sb_pkt_dec_opcode, 
  output logic [2:0] o_lphy_sb_pkt_dec_srcid, 
  output logic [2:0] o_lphy_sb_pkt_dec_dstid,
  output logic o_lphy_sb_pkt_dec_ep, 
  output logic o_lphy_sb_pkt_dec_cr, 
  output logic [63:0] o_lphy_sb_pkt_dec_payload_out, 

  // Register Access Fileds
  output logic [4:0] o_lphy_sb_pkt_dec_tag, 
  output logic [7:0] o_lphy_sb_pkt_dec_be, 
  output logic [23:0] o_lphy_sb_pkt_dec_addr, 
  output logic [2:0] o_lphy_sb_pkt_dec_cp_status,

  // Message Specific Fields
  output logic [7:0] o_lphy_sb_pkt_dec_msgcode, 
  output logic [7:0] o_lphy_sb_pkt_dec_msgsubcode, 
  output logic [15:0] o_lphy_sb_pkt_dec_msginfo, 

  // Error Flags
  output logic o_lphy_sb_pkt_dec_parity_err 
);

  // Internal signals for combinatorial decoding
  logic [31:0] internal_phase0_reg;
  logic [31:0] internal_phase1_reg;

  logic [4:0] internal_dec_opcode;
  logic internal_is_reg_req;
  logic internal_is_reg_cpl;
  logic internal_is_msg;
  logic internal_has_data;

  logic internal_rx_cp_err;
  logic internal_rx_dp_err;

  // Split Header into phases
  assign internal_phase1_reg = i_lphy_sb_pkt_dec_pkt_header[63:32];
  assign internal_phase0_reg = i_lphy_sb_pkt_dec_pkt_header[31:0];

  // Opcode is always at the same location of phase 0
  assign internal_dec_opcode = internal_phase0_reg[4:0];

  // Decode Opcode Groups
  always_comb begin
    internal_is_reg_req = (internal_dec_opcode == 5'b00000) ||
                          (internal_dec_opcode == 5'b00001) ||
                          (internal_dec_opcode == 5'b00100) ||
                          (internal_dec_opcode == 5'b00101) ||
                          (internal_dec_opcode == 5'b01000) ||
                          (internal_dec_opcode == 5'b01001) ||
                          (internal_dec_opcode == 5'b01100) ||
                          (internal_dec_opcode == 5'b01101);

    internal_is_reg_cpl = (internal_dec_opcode == 5'b10000) ||
                          (internal_dec_opcode == 5'b10001) ||
                          (internal_dec_opcode == 5'b11001);
    
    internal_is_msg = (internal_dec_opcode == 5'b10010) ||
                      (internal_dec_opcode == 5'b11011);
    
    internal_has_data = (internal_dec_opcode == 5'b00001) ||
                        (internal_dec_opcode == 5'b00101) ||
                        (internal_dec_opcode == 5'b01001) ||
                        (internal_dec_opcode == 5'b01101) ||
                        (internal_dec_opcode == 5'b10001) ||
                        (internal_dec_opcode == 5'b11001) ||
                        (internal_dec_opcode == 5'b11011);
  end

  // Instantiate Parity Checker
  lphy_sb_crc parity_checher (
    .i_lphy_sb_crc_tx_header_in(64'h0),
    .i_lphy_sb_crc_tx_data_in(64'h0),
    .i_lphy_sb_crc_tx_has_data(1'b0),
    .o_lphy_sb_crc_tx_header_out(),

    .i_lphy_sb_crc_rx_header_in(i_lphy_sb_pkt_dec_pkt_header), 
    .i_lphy_sb_crc_rx_data_in(i_lphy_sb_pkt_dec_pkt_data), 
    .i_lphy_sb_crc_rx_has_data(internal_has_data), 
    .o_lphy_sb_crc_rx_cp_err(internal_rx_cp_err), 
    .o_lphy_sb_crc_rx_dp_err(internal_rx_dp_err)
  );

  // Synchronous output assignment
  always_ff @(posedge i_lphy_sb_pkt_dec_clk or negedge i_lphy_sb_pkt_dec_rst_n) begin
  
    if(!i_lphy_sb_pkt_dec_rst_n) begin

      o_lphy_sb_pkt_dec_req_valid <= 1'b0;
      o_lphy_sb_pkt_dec_opcode <= 5'h0;
      o_lphy_sb_pkt_dec_srcid <= 3'h0;
      o_lphy_sb_pkt_dec_dstid <= 3'h0;
      o_lphy_sb_pkt_dec_ep <= 1'b0;
      o_lphy_sb_pkt_dec_cr <= 1'b0;
      o_lphy_sb_pkt_dec_payload_out <= 64'h0;
      o_lphy_sb_pkt_dec_tag <= 5'h0;
      o_lphy_sb_pkt_dec_be <= 8'h0;
      o_lphy_sb_pkt_dec_addr <= 24'h0;
      o_lphy_sb_pkt_dec_cp_status <= 3'h0;
      o_lphy_sb_pkt_dec_msgcode <= 8'h0;
      o_lphy_sb_pkt_dec_msgsubcode <= 8'h0;
      o_lphy_sb_pkt_dec_parity_err <= 1'b0;

    end else if (i_lphy_sb_pkt_dec_pkt_valid) begin
      
      o_lphy_sb_pkt_dec_req_valid <= 1'b1;
      o_lphy_sb_pkt_dec_opcode <= internal_dec_opcode;
      o_lphy_sb_pkt_dec_payload_out <= i_lphy_sb_pkt_dec_pkt_data;
      o_lphy_sb_pkt_dec_parity_err <= internal_rx_cp_err | internal_rx_dp_err;

      // Common decode for srcid
      srcid <= internal_phase0_reg[31:29];

      if(internal_is_msg) begin
        // Message Format
        o_lphy_sb_pkt_dec_dstid <= internal_phase1_reg[26:24];
        o_lphy_sb_pkt_dec_msgcode <= internal_phase0_reg[21:14];
        o_lphy_sb_pkt_dec_msginfo <= internal_phase1_reg[23:8];
        o_lphy_sb_pkt_dec_msgsubcode <= internal_phase1_reg[7:0];

        // Zero Out unused fields
        o_lphy_sb_pkt_dec_ep <= 0;
        o_lphy_sb_pkt_dec_cr <= 0;
        o_lphy_sb_pkt_dec_tag <= 0;
        o_lphy_sb_pkt_dec_be <= 0;
        o_lphy_sb_pkt_dec_addr <= 0;
        o_lphy_sb_pkt_dec_cp_status <= 0;

      end else if (internal_is_reg_cpl) begin
        // Register Access Completions
        o_lphy_sb_pkt_dec_dstid <= phase1[26:24];
        o_lphy_sb_pkt_dec_cr <= phase1[29];
        o_lphy_sb_pkt_dec_tag <= internal_phase0_reg[26:22];
        o_lphy_sb_pkt_dec_be <= internal_phase0_reg[21:14];
        o_lphy_sb_pkt_dec_ep <= internal_phase0_reg[5];
        o_lphy_sb_pkt_dec_cp_status <= internal_phase1_reg[2:0];

        // Zero Out unused fields
        o_lphy_sb_pkt_dec_addr <= 0;
        o_lphy_sb_pkt_dec_msgcode <= 0;
        o_lphy_sb_pkt_dec_msginfo <= 0;
        o_lphy_sb_pkt_dec_msgsubcode <= 0;
      end else begin
        // Register Access Requests
        o_lphy_sb_pkt_dec_dstid <= internal_phase1_reg[26:24];
        o_lphy_sb_pkt_dec_cr <= internal_phase1_reg[29];
        o_lphy_sb_pkt_dec_tag <= internal_phase0_reg[26:22];
        o_lphy_sb_pkt_dec_be <= internal_phase0_reg[21:14];
        o_lphy_sb_pkt_dec_ep <= internal_phase0_reg[5];
        o_lphy_sb_pkt_dec_addr <= internal_phase1_reg[23:0];

        // Zero out unused fields
        o_lphy_sb_pkt_dec_cp_status <= 0;
        o_lphy_sb_pkt_dec_msgcode <= 0;
        o_lphy_sb_pkt_dec_msginfo <= 0;
        o_lphy_sb_pkt_dec_msgsubcode <= 0;
      end
    end else begin
      o_lphy_sb_pkt_dec_req_valid <= 1'b0;
      o_lphy_sb_pkt_dec_parity_err <= 1'b0;
    end  

  end

endmodule