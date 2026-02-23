// Wrapper module for PIPE and MAC
module ccfpga_physical_layer_wrapper #(
   parameter DATA_BYTES = 8,
   parameter PATTERN_WIDTH = 128,
   parameter DATA_WIDTH = DATA_BYTES*8
   )
   (
   input  wire                   i_Reset_n,      // Asyn. Reset
   input  wire  [DATA_WIDTH-1:0] i_TxData,       // Tx Data
   input  wire  [DATA_BYTES-1:0] i_TxDataK,      // Tx Data K

   output wire                   o_PCLK,         // Parallel Interface Clock
   output wire  [DATA_WIDTH-1:0] o_RxData,       // Rx Data
   output wire  [DATA_BYTES-1:0] o_RxDataK,      // Rx Data K
   output wire                   o_LinkUp        // Link Up Indicator
   );

   // Internal signals
   wire                   s_clk;
   wire  [DATA_WIDTH-1:0] s_rx_data;
   wire  [DATA_BYTES-1:0] s_rx_datak;
   wire                   s_rx_valid;
   wire                   s_phy_status;
   wire             [2:0] s_rx_status;
   wire                   s_rx_elec_idle;
   wire             [1:0] s_power_down;
   wire                   s_tx_detect_rx;
   wire                   s_tx_elec_idle;
   wire  [DATA_BYTES-1:0] s_tx_compliance;
   wire                   s_rx_polarity;
   wire  [DATA_WIDTH-1:0] s_tx_data;
   wire  [DATA_BYTES-1:0] s_tx_datak;

   // Assign outputs
   assign o_PCLK = s_clk;

   ccfpga_LTSSM_logic #(
      .DATA_BYTES          ( DATA_BYTES       ),
      .PATTERN_WIDTH       ( PATTERN_WIDTH    )
   ) mac_inst (
      .i_Reset_n           ( i_Reset_n        ),
      .i_PCLK              ( s_clk            ),
      .i_RxValid           ( s_rx_valid       ),
      .i_PhyStatus         ( s_phy_status     ),
      .i_RxStatus          ( s_rx_status      ),
      .i_RxElecIdle        ( s_rx_elec_idle   ),
      .i_RxData            ( s_rx_data        ),
      .i_RxDataK           ( s_rx_datak       ),
      .i_TxData            ( i_TxData         ),
      .i_TxDataK           ( i_TxDataK        ),

      .o_PowerDown         ( s_power_down     ),
      .o_TxDetectRx        ( s_tx_detect_rx   ),
      .o_TxElecIdle        ( s_tx_elec_idle   ),
      .o_TxCompliance      ( s_tx_compliance  ),
      .o_RxPolarity        ( s_rx_polarity    ),
      .o_TxData            ( s_tx_data        ),
      .o_TxDataK           ( s_tx_datak       ),
      .o_RxData            ( o_RxData         ),
      .o_RxDataK           ( o_RxDataK        ),
      .o_LinkUp            ( o_LinkUp         )
   );

   ccfpga_pipe_wrapper #(
      .DATA_BYTES          ( DATA_BYTES       )
   ) pipe_inst (
      .i_Reset_n           ( i_Reset_n        ),
      .i_PowerDown         ( s_power_down     ),
      .i_TxDetectRx        ( s_tx_detect_rx   ),
      .i_TxElecIdle        ( s_tx_elec_idle   ),
      .i_TxCompliance      ( s_tx_compliance  ),
      .i_RxPolarity        ( s_rx_polarity    ),
      .i_TxData            ( s_tx_data        ),
      .i_TxDataK           ( s_tx_datak       ),

      .o_PCLK              ( s_clk            ),
      .o_RxValid           ( s_rx_valid       ),
      .o_PhyStatus         ( s_phy_status     ),
      .o_RxStatus          ( s_rx_status      ),
      .o_RxElecIdle        ( s_rx_elec_idle   ),
      .o_RxData            ( s_rx_data        ),
      .o_RxDataK           ( s_rx_datak       )
   );

endmodule