`timescale 1ps/1ps

module lphy_rx_top #(
  parameter int NUM_LANES = 16
) (
  input logic i_lphy_rx_top_clk,
  input logic i_lphy_rx_top_rst_n,
  
  // Configuration
  input logic i_lphy_rx_top_free_run_mode, 

  // Control Signals from LTSSM
  input logic i_lphy_rx_top_en_reversal_check,
  output logic o_lphy_rx_top_reversal_detected,
  output logic o_lphy_rx_top_reversal_check_done, 
  output logic o_lphy_rx_top_framing_err, 

  output logic [63:0] o_lphy_rx_top_detected_lane_failures, 
  output logic o_lphy_rx_top_check_done,

  // Descrambling Control from LTSSM
  input logic i_lphy_rx_top_descrambler_en, 
  input logic i_lphy_rx_top_load_seed,
  input logic [22:0] i_lphy_rx_top_lane_seeds [63:0],

  // Repair Control from LTSSM
  input logic i_lphy_rx_top_repair_en, 
  input logic i_lphy_rx_top_en_lane_check,

  // Interface to D2D Adapter (RDI)
  output logic o_lphy_rx_top_pl_valid, 
  output logic [7:0] o_lphy_rx_top_pl_data [NUM_LANES-1:0], 
  output logic o_lphy_rx_top_credit_return, 
  output logic o_lphy_rx_top_rx_gated_clk, 

  // Parallel AFE Boundary (AFE Interface)
  input logic [7:0] i_lphy_rx_top_RXDATA [NUM_LANES-1:0], 
  input logic [7:0] i_lphy_rx_top_RXVLD, 
  input logic [7:0] i_lphy_rx_top_RXRD [3:0], 
  input logic i_lphy_rx_top_RXTRK,
  output logic o_lphy_rx_top_rx_en
);
    
  // Power up AFE receivers automatically when out of reset
  assign o_lphy_rx_top_rx_en = 1'b1;

  // Internal Pipeline signals
  logic [7:0] internal_rx_lane_data_64 [63:0];
  logic [7:0] internal_rx_lane_data_NUM [NUM_LANES-1:0];
  logic [7:0] internal_rx_txrd_data_raw [3:0];
  logic [7:0] internal_rx_valid_frame;

  logic internal_lane_valid;
  logic internal_lane_valid_d1;
  logic internal_credit_return;

  // Pipeline Alignment: internal_rx_lane_data_NUM is latched once (AFE latch).
  // internal_lane_valid is latched twice (AFE latch + valid deframer FF). 
  // Delay internal_lane_valid by 1 more cycle so lane_id_detect sees aligned data + valid. 
  always_ff @(posedge o_lphy_rx_top_rx_gated_clk or negedge i_lphy_rx_top_rst_n) begin
    if (!i_lphy_rx_top_rst_n) internal_lane_valid_d1 <= 1'b0;
    else internal_lane_valid_d1 <= internal_lane_valid;
  end

  // 1. AFE Pipeline Latch
  always_ff @(posedge o_lphy_rx_top_rx_gated_clk or negedge i_lphy_rx_top_rst_n) begin
    if (!i_lphy_rx_top_rst_n) begin
      internal_rx_valid_frame <= 8'h00;
      for (int i = 0; i < 64; i++) internal_rx_lane_data_64[i] <= 8'h00;
      for (int i = 0; i < NUM_LANES; i++) internal_rx_lane_data_NUM[i] <= 8'h00;
      for (int i = 0; i < 4; i++) internal_rx_txrd_data_raw[i] <= 8'h00;
    end else begin
      internal_rx_valid_frame <= i_lphy_rx_top_RXVLD;

      // Latch exactly NUM_LANES for the normal datapath
      for (int i = 0; i < NUM_LANES; i++) begin
        internal_rx_lane_data_NUM[i] <= i_lphy_rx_top_RXDATA[i];
        internal_rx_lane_data_64[i] <= i_lphy_rx_top_RXDATA[i];
      end

      // Safely pad the upper lanes with 0 to prevent [VRFC 10-323] array crashes in Repair Mux
      for (int i = NUM_LANES; i < 64; i++) begin
        internal_rx_lane_data_64[i] <= 8'h00;
      end

      for (int i = 0; i < 4; i++) internal_rx_txrd_data_raw[i] <= i_lphy_rx_top_RXRD[i];
    end
  end

  // 2. Lane ID Detection
  logic [NUM_LANES-1:0] internal_lane_failed_narrow;

  lphy_lane_id_detect #(
    .NUM_LANES(NUM_LANES)
  ) lphy_id_detect_inst (
    .i_lphy_lane_id_detect_clk(i_lphy_rx_top_clk), 
    .i_lphy_lane_id_detect_rst_n(i_lphy_rx_top_rst_n), 
    .i_lphy_lane_id_detect_rx_lane_data_in(internal_rx_lane_data_NUM), 
    .i_lphy_lane_id_detect_rx_lane_valid(internal_lane_valid_d1),
    .i_lphy_lane_id_detect_en_lane_check(i_lphy_rx_top_en_lane_check), 
    .i_lphy_lane_id_detect_is_reversed(o_lphy_rx_top_reversal_detected), 
    .i_lphy_repair_rx_lane_failed(internal_lane_failed_narrow), 
    .i_lphy_lane_id_detect_en_lane_check_done(o_lphy_rx_top_check_done)
  );

  // Zero-extend to the full 64-bit output width; upper bits are hardwired to 0
  // (no redundant lanes failed above NUM_LANES in a correctly-configured link)
  assign o_lphy_rx_top_detected_lane_failures = {{(64-NUM_LANES){1'b0}}, internal_lane_failed_narrow};

  // 3. RX Repair Multiplexer
  logic [7:0] internal_rx_repaired_data_64 [63:0];
  logic [63:0] internal_rx_lane_failed_map;

  always_comb begin
    internal_rx_lane_failed_map = i_lphy_rx_top_repair_en ? o_lphy_rx_top_detected_lane_failures : 64'h0;
  end

  lphy_repair_rx rx_repair_inst (
    .i_lphy_repair_rx_physical_data(internal_rx_lane_data_64), 
    .i_lphy_repair_rx_redundant_data(internal_rx_txrd_data_raw), 
    .i_lphy_repair_rx_lane_failed(internal_rx_lane_failed_map), 
    .o_lphy_repair_rx_logical_data(internal_rx_repaired_data_64)
  );

  // 4. Pipeline Alignment Buffer
  logic [7:0] internal_rx_lane_data_d1 [NUM_LANES-1:0];

  always_ff @(posedge i_lphy_rx_top_clk or negedge i_lphy_rx_top_rst_n) begin
    if (!i_lphy_rx_top_rst_n) begin
      for (int i = 0; i < NUM_LANES; i++) internal_rx_lane_data_d1[i] <= 8'h00;
    end else begin
      for (int i = 0; i < NUM_LANES; i++) internal_rx_lane_data_d1[i] <= internal_rx_repaired_data_64[i];
    end
  end

  // 5. Valid Deframer
  lphy_valid_deframer valid_deframer_inst (
    .i_lphy_valid_deframer_clk(i_lphy_rx_top_clk),
    .i_lphy_valid_deframer_rst_n(i_lphy_rx_top_rst_n), 
    .i_lphy_valid_deframer_valid_frame_in(internal_rx_valid_frame), 
    .o_lphy_valid_deframer_lane_valid(internal_lane_valid), 
    .o_lphy_valid_deframer_credit_return(internal_credit_return), 
    .o_lphy_valid_deframer_framing_err(o_lphy_rx_top_framing_err)
  );

  logic pl_valid_reg;
  logic pl_credit_return_reg;

  always_ff @(posedge i_lphy_rx_top_clk or negedge i_lphy_rx_top_rst_n) begin
    if (!i_lphy_rx_top_rst_n) begin
      pl_valid_reg <= 1'b0;
      pl_credit_return_reg <= 1'b0;
    end else begin
      pl_valid_reg <= internal_lane_valid;
      pl_credit_return_reg <= internal_credit_return;
    end
  end

  assign o_lphy_rx_top_pl_valid = pl_valid_reg;
  assign o_lphy_rx_top_credit_return = pl_credit_return_reg;

  // 6. Lane Derotator & Deskew
  logic [7:0] internal_derotated_data [NUM_LANES-1:0];

  lphy_lane_derotate #(
    .NUM_LANES(NUM_LANES)
  ) lane_derotate_inst (
    .i_lphy_lane_derotate_clk(i_lphy_rx_top_clk), 
    .i_lphy_lane_derotate_rst_n(i_lphy_rx_top_rst_n), 
    .i_lphy_lane_derotate_rx_lane_data_in(internal_rx_lane_data_d1), 
    .i_lphy_lane_derotate_rx_lane_valid(internal_lane_valid), 
    .i_lphy_lane_derotate_en_reversal_check(i_lphy_rx_top_en_reversal_check),
    .o_lphy_lane_derotate_reversal_detected(o_lphy_rx_top_reversal_detected), 
    .o_lphy_lane_derotate_reversal_check_done(o_lphy_rx_top_reversal_check_done), 
    .o_lphy_lane_derotate_rx_lane_data_out(internal_derotated_data)
  );

  // 7. Descrambler Array
  genvar i;
  generate;
    for (i = 0; i < NUM_LANES; i++) begin: gen_descrambler
      lphy_descrambler descrambler_inst (
        .i_lphy_descrambler_clk(i_lphy_rx_top_clk), 
        .i_lphy_descrambler_rst_n(i_lphy_rx_top_rst_n), 
        .i_lphy_descrambler_enable(i_lphy_descrambler_enable & pl_valid_reg), 
        .i_lphy_descrambler_load_seed(i_lphy_rx_top_load_seed), 
        .i_lphy_descrambler_seed_in(i_lphy_rx_top_lane_seeds[i]), 
        .i_lphy_descrambler_data_in(internal_derotated_data[i]), 
        .o_lphy_descrambler_data_out(o_lphy_rx_top_pl_data[i])
      );
    end
  endgenerate

  // 8. RX Clock Gater
  lphy_clkgate_rx clkgate_rx_inst (
    .i_lphy_clkgate_rx_clk(i_lphy_rx_top_clk), 
    .i_lphy_clkgate_rx_rst_n(i_lphy_rx_top_rst_n), 
    .i_lphy_clkgate_rx_free_run_mode(i_lphy_rx_top_free_run_mode), 
    .i_lphy_clkgate_rx_valid_in(internal_lane_valid), 
    .o_lphy_clkgate_rx_gated_clk(o_lphy_rx_top_rx_gated_clk)
  );

endmodule
