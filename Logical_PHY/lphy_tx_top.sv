`timescale 1ps/1ps

module lphy_tx_top #(
  parameter int NUM_LANES = 16
)(
  // Byte-rate clock: one cycle = 8 UIs = one byte per lane
  input logic i_lphy_tx_top_clk,
  input logic i_lphy_tx_top_rst_n,

  // Configuration
  input logic [1:0] i_lphy_tx_top_link_width,       // 2'b00: x16, 2'b01: x32, 2'b10: x64
  input logic i_lphy_tx_top_free_run_mode,          // 1: Clock never gates, 0: Dynamic clock gating enabled
  input logic i_lphy_tx_top_select_valtrain,        // 0: Send per-lane ID pattern (MBINIT/SBINIT), 1: Send VALTRAIN pattern (MBTRAIN ValTrain substates)
  input logic i_lphy_tx_top_txtrk_en,               // 1: TXTRK carries Phase-1 replica

  // Scrambling Control from LTSSM (MBINIT State)
  input logic i_lphy_tx_top_scrambler_en,           // High during MBTRAIN and ACTIVE
  input logic i_lphy_tx_top_load_seed,              // Pulled high to load initial seeds
  input logic [22:0] i_lphy_tx_top_lane_seeds,    

  // Repair Control from LTSSM (MBINIT state)
  input logic i_lphy_tx_top_repair_en,              // 1: Redundancy routing active
  input logic [63:0] i_lphy_tx_top_ext_lane_failed_map,

  input logic i_lphy_tx_top_tx_training_en,         // 2: Send training pattern, 0: Send adapter data

  // Interface from D2D Adapter (RDI)
  input logic i_lphy_tx_top_lp_valid, 
  input logic i_lphy_tx_top_lp_irdy,
  output logic o_lphy_tx_top_pl_trdy, 
  input logic [511:0] i_lphy_tx_top_lp_data, 
  input logic i_lphy_tx_top_credit_return,          // From Flow Control for Retimer E2E Credits

  // Parallel AFE Boundary (AFE Interface)
  output logic [7:0] o_lphy_tx_top_TXDATA [NUM_LANES-1:0],  // 8-bit Parallel data per lane
  output logic [7:0] o_lphy_tx_top_TXVLD,                   // 8-bit Parallel valid frame
  output logic [7:0] o_lphy_tx_top_TXRD [3:0],              // 8-bit Parallel redundant data

  // AFE Control Flags (Digital to Analog)
  output logic o_lphy_tx_top_tx_clock_en,                   // Tells AFE to drive forwarded clock (includes postamble)
  output logic o_lphy_tx_top_tx_track_en                    // Tells AFE to drive the track clock
);

  // Internal Signals
  logic [7:0] internal_mapped_lane_data [63:0];
  logic internal_mapped_lane_valid;
  logic [7:0] internal_tx_valid_frame;
  logic internal_gated_tx_clk_en;

  logic [7:0] internal_scrambled_lane_data [63:0];
  logic [7:0] internal_repaired_lane_data [63:0];
  logic [7:0] internal_repaired_txrd_data [3:0];

  // 1. Byte-to-lane mapper
  lphy_byte_lane_map byte_mapper_inst (
    .i_lphy_byte_lane_map_clk(i_lphy_tx_top_clk), 
    .i_lphy_byte_lane_map_rst_n(i_lphy_tx_top_rst_n), 
    .i_lphy_byte_lane_map_link_width(i_lphy_tx_top_link_width),
    .i_lphy_byte_lane_map_lp_valid(i_lphy_tx_top_lp_valid), 
    .i_lphy_byte_lane_map_lp_irdy(i_lphy_tx_top_lp_irdy), 
    .o_lphy_byte_lane_map_pl_trdy(o_lphy_tx_top_pl_trdy), 
    .i_lphy_byte_lane_map_lp_data(i_lphy_tx_top_lp_data), 
    .o_lphy_byte_lane_map_lane_valid(internal_mapped_lane_valid), 
    .o_lphy_byte_lane_map_lane_data(internal_mapped_lane_data)
  );

  // Pipeline Alignment Stage
  // The valid framer has 1 cycle of sequential latency. We must delay the
  // datapath and scrambler enable by 1 cycle to maintain exact alignment.
  logic [7:0] internal_mapped_lane_data_d1 [63:0];
  logic internal_mapped_lane_valid_d1;

  always_ff @(posedge i_lphy_tx_top_clk or negedge i_lphy_tx_top_rst_n) begin
    if (!i_lphy_tx_top_rst_n) begin
      internal_mapped_lane_valid_d1 <= 1'b0;
      for (int i = 0; i < 64; i++) internal_mapped_lane_data_d1[i] <= 8'h00;
    end else begin
      internal_mapped_lane_valid_d1 <= internal_mapped_lane_valid;
      for (int i = 0; i < 64; i++) internal_mapped_lane_data_d1[i] <= internal_mapped_lane_data[i];
    end
  end

  // 2. Valid Framer
  lphy_valid_framer valid_framer_inst (
    .i_lphy_valid_framer_clk(i_lphy_tx_top_clk), 
    .i_lphy_valid_framer_rst_n(i_lphy_tx_top_rst_n), 
    .i_lphy_valid_framer_lane_valid(internal_mapped_lane_valid), 
    .i_lphy_valid_framer_credit_return(i_lphy_tx_top_credit_return), 
    .o_lphy_valid_framer_valid_frame_out(internal_tx_valid_frame)
  );

  // Training Pattern Generator Array & Multiplexer
  // Each lane gets its own lphy_pattern_gen instance wired to its lane index. 
  // This ensures each lane transmits the correct per-lane-ID training pattern
  // as defined in UCIe spec Tables 23 & 24.
  // select_valtrain (from LTSSM) switches between:
  //    0 -> Per-Lane ID pattern (used during SBINIT / MBINIT calibration)
  //    1 -> VALTRAIN pattern    (used during MBTRAIN ValTrainCenter / ValTrainVref)
  logic [15:0] internal_training_pattern_out [NUM_LANES-1:0];
  logic [7:0] internal_pre_scramble_data [63:0];

  genvar pg;
  generate;
    for (pg = 0; pg < NUM_LANES; pg++) begin : gen_pattern_gens
      lphy_pattern_gen pattern_gen_inst (
        .i_lphy_pattern_gen_lane_id(8'(pg)),
        .i_lphy_pattern_gen_select_valtrain(i_lphy_tx_top_select_valtrain),
        .o_lphy_pattern_gen_pattern_out(internal_training_pattern_out[pg])
      );
    end
  endgenerate

  always_comb begin
    for (int j = 0; j < NUM_LANES; j++) begin
      if (i_lphy_tx_top_tx_training_en) begin
        // Lower byte of the 16-bit pattern is sent first (LSB-first per UCIe spec)
        internal_pre_scramble_data[j] = internal_training_pattern_out[j][7:0];
      end else begin
        internal_pre_scramble_data[j] = internal_mapped_lane_data[j];
      end
   end
    // Unused lanes (indices >= NUM_LANES up to 63) default to 0
    for (int j = NUM_LANES; j < 64; j++) begin
      internal_pre_scramble_data[j] = 8'h00;
    end
  end

  // 4. Scrambler Array
  genvar i;
  generate;
    for (i = 0; i < NUM_LANES; i++) begin: gen_scramblers
      lphy_scrambler scrambler_inst (
        .i_lphy_scrambler_clk(i_lphy_tx_top_clk), 
        .i_lphy_scrambler_rst_n(i_lphy_tx_top_rst_n), 
        .i_lphy_scrambler_enable(i_lphy_tx_top_scrambler_en & internal_mapped_lane_valid_d1),
        .i_lphy_scrambler_load_seed(i_lphy_tx_top_load_seed), 
        .i_lphy_scrambler_seed_in(i_lphy_tx_top_lane_seeds[i]),
        .i_lphy_scrambler_data_in(internal_pre_scramble_data[i]),
        .i_lphy_scramber_data_out(internal_scrambled_lane_data[i])
      );
    end
  endgenerate

  // 5. TX Repair Multiplexer
  logic [63:0] internal_tx_lane_failed_map;
  always_comb begin
    internal_tx_lane_failed_map = i_lphy_tx_top_repair_en ? i_lphy_tx_top_ext_lane_failed_map : 64'h0;
  end

  lphy_repair_tx tx_repair_inst (
    .i_lphy_repair_tx_tx_logical_data  (internal_scrambled_lane_data),
    .i_lphy_repair_tx_lane_failed      (internal_tx_lane_failed_map),
    .o_lphy_repair_tx_tx_physical_data (internal_repaired_lane_data),
    .o_lphy_repair_tx_tx_redundant_data(internal_repaired_txrd_data)
  );

  // 6. Pipeline to AFE 
  logic [3:0] internal_postamble_cnt;

  always_ff @(posedge i_lphy_tx_top_clk or negedge i_lphy_tx_top_rst_n) begin
    if (!i_lphy_tx_top_rst_n) begin
      o_lphy_tx_top_TXVLD <= 8'h00;
      for (int i = 0; i < NUM_LANES; i++) o_lphy_tx_top_TXDATA[i] <= 8'h00;
      for (int i = 0; i < 4; i++) o_lphy_tx_top_TXRD[i] <= 8'h00;

      o_lphy_tx_top_tx_clock_en <= 1'b0;
      o_lphy_tx_top_tx_track_en <= 1'b0;
      internal_postamble_cnt <= 4'd2; 
    end else begin
      o_lphy_tx_top_TXVLD <= internal_tx_valid_frame;
       for (int i = 0; i < NUM_LANES; i++) o_lphy_tx_top_TXDATA[i] <= internal_repaired_lane_data[i];
       for (int i = 0; i < 4; i++) o_lphy_tx_top_TXRD[i] <= internal_repaired_txrd_data[i] <= internal_repaired_txrd_data[i];

       o_lphy_tx_top_tx_track_en <= i_lphy_tx_top_txtrk_en;

       // Generate AFE Logical Envelop (with exactly 2 cycle postamble)
       if (internal_mapped_lane_valid_d1) begin
        internal_postamble_cnt <= 4'd0;
        o_lphy_tx_top_tx_clock_en <= 1'b1;
       end else if (internal_postamble_cnt < 4'd2) begin
        internal_postamble_cnt <= internal_postamble_cnt + 1'b1;
        o_lphy_tx_top_tx_clock_en <= 1'b1;
       end else begin
        o_lphy_tx_top_tx_clock_en <= i_lphy_tx_top_free_run_mode;
       end
    end
  end
endmodule
