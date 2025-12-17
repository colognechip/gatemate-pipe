//--------------------------------------------------------------------------
// Description: This module is the top module for the PHY/MAC
// - It instantiates the LTSSM FSM, Rx MAC, Tx counter, Timeout blocks,
// Data Sending modules, Scrambler and Descrambler
//==========================================================================

`timescale 1ns/100fs

module ccfpga_LTSSM_logic #(
   parameter DATA_BYTES = 8,
   parameter PATTERN_WIDTH = 128,
   parameter DATA_WIDTH = DATA_BYTES*8
   )
   (
   input wire                    i_Reset_n,      // Asynchronous Reset
   input wire                    i_PCLK,         // Parallel Interface Clock
   input wire                    i_RxValid,      // Received data is valid
   input wire                    i_PhyStatus,    // Physical Status
   input wire              [2:0] i_RxStatus,     // Receiver Status
   input wire                    i_RxElecIdle,   // Electrical Idle at Receiver
   input wire   [DATA_WIDTH-1:0] i_RxData,       // Rx Data
   input wire   [DATA_BYTES-1:0] i_RxDataK,      // Rx K Data
   input wire   [DATA_WIDTH-1:0] i_TxData,       // Tx Data
   input wire   [DATA_BYTES-1:0] i_TxDataK,      // Tx K Data

   output wire             [1:0] o_PowerDown,    // Power states
   output wire                   o_TxDetectRx,   // Receiver Detection (P1)/Loopback (P0)
   output wire                   o_TxElecIdle,   // Electrical Idle
   output wire  [DATA_BYTES-1:0] o_TxCompliance, // Compliance Pattern
   output wire                   o_RxPolarity,   // Received data polarity
   output reg   [DATA_WIDTH-1:0] o_TxData,       // Tx Data
   output reg   [DATA_BYTES-1:0] o_TxDataK,      // Tx K Data
   output wire  [DATA_WIDTH-1:0] o_RxData,       // Rx Data
   output wire  [DATA_BYTES-1:0] o_RxDataK,      // Rx K Data

   output wire                   o_LinkUp        // Link is on
   );
//-------------------------------------------------------------------------------------------------------------------------------
// Parameters
   // Define cycle time based on data width
   localparam CYCLE_TIME = DATA_BYTES == 8 ? 32 : DATA_BYTES == 4 ? 16 : DATA_BYTES == 2 ? 8 : DATA_BYTES == 1 ? 4 : 0; // in ns
//-------------------------------------------------------------------------------------------------------------------------------
   // Reset
   wire       reset = !i_Reset_n;
   // L0 flags
   wire       L0_enabled;           // L0 state
//-------------------------------------------------------------------------------------------------------------------------------
// Receiver side signals
   wire       s_rx_flag;                // Receiver flag
   wire       s_rx_flag_rst;            // Receiver flag Reset from FSM
   wire       s_rx_rst;                 // Receiver flag Reset
   wire       s_rx_OS_rst;              // Receiver OS flag Reset
   wire       s_rx_IDLE_rst;            // Receiver IDLE flag Reset
   wire       s_rx_flag_IDLE;           // Max count for received IDLE reached
   wire [7:0] expected_Link;            // Expected link number in Ordered Set
   wire [7:0] expected_Lane;            // Expected lane number in Ordered Set
   wire [7:0] expected_Ctrl;            // Expected control
   wire       s_link_detected_rst;      // Link Detected Reset from FSM
   wire       s_lane_detected_rst;      // Lane Detected Reset from FSM
   wire       link_detected;            // Link number detected
   wire       lane_detected;            // Lane number detected
   wire [3:0] rx_max_count;             // Max count for received Ordered Set
   wire       TS1_pattern_en;           // Enable TS1 pattern
   wire       TS2_pattern_en;           // Enable TS2 pattern
   wire       OS_detected;              // Receiver detects Ordered Set
   wire       OS_valid;                 // Received OS is valid
   wire       IDLE_detected;            // IDLE symbol detected
   wire       OS_rec_cfg_detected;      // Received OS with non-match Link/Lane in Recovery.RcvrCfg
   wire       s_rx_flag_OS;             // Max count for received Orderes Set reached
   wire       s_recovery_idle_rx_flag_rst;  // Recovery Idle Rx Reset flag (TS1 with PAD-Lane)
   wire       s_recovery_idle_rx_flag;      // Recovery Idle Rx flag (TS1 with PAD-Lane)
   wire       s_recovery_cfg_rx_flag_rst;   // Recovery Rcvrcfg Rx Reset flag (TS1 with non-matched Link/Lane)
   wire       s_recovery_cfg_rx_flag;       // Recovery Rcvrcfg Rx flag (TS1 with non-matched Link/Lane)
//-------------------------------------------------------------------------------------------------------------------------------
// Transmitter side signals
   wire       s_tx_flag;            // Transmitter flag
   wire       s_tx_flag_rst;        // Transmitter flag Reset from FSM
   wire       s_tx_OS_flag_rst;     // Transmitter flag reset
   wire       s_tx_IDLE_flag_rst;   // Transmitter IDLE flag reset
   wire       s_tx_flag_IDLE;       // Max count for transmitted IDLE reached
   wire [4:0] tx_max_count;         // Max count for transmitter
   wire       s_tx_flag_OS;         // Max count for transmitter reached
   wire       OS_type;              // Type of Ordered Set to be sent
   wire       s_polling_active_tx_flag;
   wire       s_polling_active_tx_flag_rst;
//-------------------------------------------------------------------------------------------------------------------------------
// Timeout signals
   wire s_clk_timeout_rst;    // Timeout reset
   wire s_OS_timeout_rst;     // Timeout reset
   wire [20:0] clk_max_count; // Max count for timeout
   wire s_timeout;            // Timeout flag
   wire s_timeout_clk;        // Timeout due to clock
   wire s_timeout_OS;         // Timeout due to received OS
   wire s_timeout_clk_en;     // Enable timeout due to clock
   wire s_timeout_OS_en;      // Enable timeout due to received OS
//-------------------------------------------------------------------------------------------------------------------------------
// FSM states
   wire [4:0] fsm_state;
//-------------------------------------------------------------------------------------------------------------------------------
// Sending triggers and signals
   wire       send_IDLE_trigger;   // Trigger to send IDLE
   wire       send_OS_trigger;     // Trigger to send OS
   wire       sending_OS;          // Sending OS flag
   wire       sending_data;        // Sending data flag
   wire       sending_SKP;         // Sending SKP flag
//-------------------------------------------------------------------------------------------------------------------------------
// Transmitted data signals
   wire [DATA_WIDTH-1:0] txdata_reg;
   wire [DATA_BYTES-1:0] txdatak_reg;
//-------------------------------------------------------------------------------------------------------------------------------
// Inversion Detection
   wire                  inversion_detected;
//-------------------------------------------------------------------------------------------------------------------------------
// Descrambler signals
   wire [DATA_WIDTH-1:0] descrambled_data;
   wire [DATA_BYTES-1:0] descrambled_data_k;
//-------------------------------------------------------------------------------------------------------------------------------
// Assignments
   wire idle_state = fsm_state == 5'b01001 || fsm_state == 5'b10101; // CONFIG_IDLE or RECOVERY.IDLE
   assign s_rx_OS_rst   = !idle_state ? s_rx_rst : 1'b1;             // Rx OS counting when not in IDLE state
   assign s_rx_IDLE_rst = idle_state  ? s_rx_rst : 1'b1;             // Rx IDLE counting when in IDLE state

   assign s_tx_OS_flag_rst   = !idle_state ? s_tx_flag_rst : 1'b1;   // Tx OS counting when not in IDLE state
   assign s_tx_IDLE_flag_rst = idle_state ? s_tx_flag_rst : 1'b1;    // Tx IDLE counting when in IDLE state
   assign o_PowerDown = fsm_state == 5'b00000 ? 2'b10 : fsm_state == 5'b00001 ? 2'b10 : 2'b00; // Power Down signal to SerDes
   assign o_LinkUp = fsm_state == 5'b01010 ? 1'b1 : fsm_state == 5'b01001 ? 1'b1 : 1'b0;       // Link Up enabled in L0 or CONFIG_IDLE
   assign s_rx_flag = ((s_rx_flag_OS && !idle_state) || (s_rx_flag_IDLE && idle_state));       // Rx flag
   assign s_tx_flag = (s_tx_flag_OS && !idle_state) || (s_tx_flag_IDLE && idle_state);         // Tx flag
   // Rx reset when:
   // - Link number detection in CONFIG_LINKWIDTH_START_LINKNUM state (substate of CONFIG_LINKWIDTH_START, waiting for link number)
   // - Lane number detection in CONFIG_LINKWIDTH_ACCEPT_LANENUM state (substate of CONFIG_LINKWIDTH_ACCEPT, waiting for lane number)
   // - Rx flag reset in other states
   // - Detection and Ordered Sets counting is only enabled when i_RxValid is high
   assign s_rx_rst  = ((fsm_state == 5'b10010) ? s_link_detected_rst :
                       (fsm_state == 5'b10011) ? s_lane_detected_rst : s_rx_flag_rst) || ~i_RxValid;

   // L0 enabled in L0 state
   assign L0_enabled   = fsm_state == 5'b01010 ? 1'b1 : 1'b0;
   // Invert Rx polarity
   assign o_RxPolarity = inversion_detected;
//-------------------------------------------------------------------------------------------------------------------------------
   // Count number of received Ordered Sets/IDLE data at each state
   assign rx_max_count = fsm_state == 5'b00010 ? 4'b1000 :
                         fsm_state == 5'b00011 ? 4'b1000 :
                         fsm_state == 5'b00100 ? 4'b0010 :
                         fsm_state == 5'b00101 ? 4'b0010 :
                         fsm_state == 5'b00110 ? 4'b0010 :
                         fsm_state == 5'b00111 ? 4'b0010 :
                         fsm_state == 5'b01000 ? 4'b1000 :
                         fsm_state == 5'b01001 ? 4'b1000 :
                         fsm_state == 5'b10010 ? 4'b0001 :
                         fsm_state == 5'b10011 ? 4'b0001 :
                         fsm_state == 5'b01011 ? 4'b1000 :
                         fsm_state == 5'b10100 ? 4'b1000 :
                         fsm_state == 5'b10101 ? 4'b1000 : 4'b1111;
   // TS1 Ordered Set pattern enable
   assign TS1_pattern_en = fsm_state == 5'b00010 ? 1'b1 :
                           fsm_state == 5'b00011 ? 1'b0 :
                           fsm_state == 5'b00100 ? 1'b1 :
                           fsm_state == 5'b00101 ? 1'b1 :
                           fsm_state == 5'b00110 ? 1'b1 :
                           fsm_state == 5'b00111 ? 1'b1 :
                           fsm_state == 5'b01000 ? 1'b0 :
                           fsm_state == 5'b01001 ? 1'b0 :
                           fsm_state == 5'b10010 ? 1'b1 :
                           fsm_state == 5'b10011 ? 1'b1 :
                           fsm_state == 5'b01011 ? 1'b1 :
                           fsm_state == 5'b10100 ? 1'b0 :
                           fsm_state == 5'b10101 ? 1'b0 : 1'b0;
   // TS2 Ordered Set pattern enable
   assign TS2_pattern_en = fsm_state == 5'b00010 ? 1'b1 :
                           fsm_state == 5'b00011 ? 1'b1 :
                           fsm_state == 5'b00100 ? 1'b0 :
                           fsm_state == 5'b00101 ? 1'b0 :
                           fsm_state == 5'b00110 ? 1'b0 :
                           fsm_state == 5'b00111 ? 1'b0 :
                           fsm_state == 5'b01000 ? 1'b1 :
                           fsm_state == 5'b01001 ? 1'b0 :
                           fsm_state == 5'b10010 ? 1'b0 :
                           fsm_state == 5'b10011 ? 1'b0 :
                           fsm_state == 5'b01011 ? 1'b1 :
                           fsm_state == 5'b10100 ? 1'b1 :
                           fsm_state == 5'b10101 ? 1'b0 : 1'b0;
   // Count number of transmitted Ordered Sets at each state
   assign tx_max_count   = fsm_state == 5'b00011 ? 5'b10000 :
                           fsm_state == 5'b01000 ? 5'b10000 :
                           fsm_state == 5'b01001 ? 5'b10000 :
                           fsm_state == 5'b10100 ? 5'b10000 : 5'b11111;
   // Type of Ordered Set to be sent at each state/ 0:TS1, 1:TS2
   assign OS_type        = fsm_state == 5'b00010 ? 1'b0 :
                           fsm_state == 5'b00011 ? 1'b1 :
                           fsm_state == 5'b00100 ? 1'b0 :
                           fsm_state == 5'b00101 ? 1'b0 :
                           fsm_state == 5'b00110 ? 1'b0 :
                           fsm_state == 5'b00111 ? 1'b0 :
                           fsm_state == 5'b01000 ? 1'b1 :
                           fsm_state == 5'b01011 ? 1'b0 :
                           fsm_state == 5'b10100 ? 1'b1 : 1'b0;
   // Max count for timeout at each state
   assign clk_max_count = fsm_state == 5'b00000 ? 12*1000000 / CYCLE_TIME : //12ms
                          fsm_state == 5'b00010 ? 24*1000000 / CYCLE_TIME : //24ms
                          fsm_state == 5'b00011 ? 48*1000000 / CYCLE_TIME : //48ms
                          fsm_state == 5'b00100 ? 24*1000000 / CYCLE_TIME : //24ms
                          fsm_state == 5'b00101 ?  2*1000000 / CYCLE_TIME : //2ms
                          fsm_state == 5'b00110 ?  2*1000000 / CYCLE_TIME : //2ms
                          fsm_state == 5'b01000 ?  2*1000000 / CYCLE_TIME : //2ms
                          fsm_state == 5'b01001 ?  2*1000000 / CYCLE_TIME : //2ms
                          fsm_state == 5'b01011 ? 24*1000000 / CYCLE_TIME : //24ms
                          fsm_state == 5'b10100 ? 48*1000000 / CYCLE_TIME : //48ms
                          fsm_state == 5'b10101 ?  2*1000000 / CYCLE_TIME : 2*1000000 / CYCLE_TIME; //2ms
//-------------------------------------------------------------------------------------------------------------------------------
// Timeout enable and timeout signal
   assign s_timeout_clk_en = fsm_state == 5'b00111 ? 1'b0 : 1'b1;
   assign s_timeout_OS_en  = (( fsm_state == 5'b00101 || fsm_state == 5'b00110 ) || fsm_state == 5'b00111) ? 1'b1 : 1'b0;
   assign s_timeout        = ( s_timeout_clk & s_timeout_clk_en) || ( s_timeout_OS & s_timeout_OS_en );
//-------------------------------------------------------------------------------------------------------------------------------
// ----- LTSSM -----
   ccfpga_LTSSM_fsm #(
      .DATA_BYTES     ( DATA_BYTES     )
   ) ccfpga_LTSSM_fsm_inst (
      .i_reset_n                    ( i_Reset_n      ),                // Asynchronous Reset
      .i_PCLK                       ( i_PCLK         ),                // Parallel Interface Clock
      .i_RxStatus                   ( i_RxStatus     ),                // Receiver Status
      .s_timeout                    ( s_timeout      ),                // Timeout flag
      .s_rx_flag                    ( s_rx_flag      ),                // Rx Flag
      .s_tx_flag                    ( s_tx_flag      ),                // Tx Flag
      .s_polling_active_tx_flag     ( s_polling_active_tx_flag ),      // Polling Active Tx Flag
      .s_recovery_cfg_rx_flag       ( s_recovery_cfg_rx_flag ),        // Recovery Rcvrcfg Rx Flag
      .s_recovery_idle_rx_flag      ( s_recovery_idle_rx_flag  ),      // Recovery Idle Rx Flag
      .i_RxElecIdle                 ( i_RxElecIdle   ),                // Electrical Idle at Receiver
      .link_detected                ( link_detected  ),                // Link Detected
      .lane_detected                ( lane_detected  ),                // Lane Detected

      .o_TxDetectRx                 ( o_TxDetectRx   ),                // Receiver Detection (P1)/Loopback (P0)
      .o_TxElecIdle                 ( o_TxElecIdle   ),                // Electrical Idle
      .o_TxCompliance               ( o_TxCompliance ),                // Compliance Pattern
      .o_send_OS_trigger            ( send_OS_trigger   ),             // Trigger the sending of OS
      .o_send_IDLE_trigger          ( send_IDLE_trigger ),             // Trigger the sending of IDLE
      .o_send_data_trigger          ( send_data_trigger ),             // Trigger the sending of data
      .o_fsm_state                  ( fsm_state         ),             // fsm status
      .s_clk_timeout_rst            ( s_clk_timeout_rst ),             // Clock Timeout Reset
      .s_OS_timeout_rst             ( s_OS_timeout_rst  ),             // OS Timeout Reset
      .s_rx_flag_rst                ( s_rx_flag_rst  ),                // Rx Flag Reset
      .s_tx_flag_rst                ( s_tx_flag_rst  ),                // Tx Flag Reset
      .s_polling_active_tx_flag_rst ( s_polling_active_tx_flag_rst ),  // Polling Active Tx Reset flag
      .s_recovery_cfg_rx_flag_rst   ( s_recovery_cfg_rx_flag_rst   ),  // Recovery Rcvrcfg Rx Reset flag
      .s_recovery_idle_rx_flag_rst  ( s_recovery_idle_rx_flag_rst  ),  // Recovery Idle Rx Reset flag
      .s_link_detected_rst          ( s_link_detected_rst          ),  // Link Detected Reset
      .s_lane_detected_rst          ( s_lane_detected_rst          )   // Lane Detected Reset
   );
//-------------------------------------------------------------------------------------------------------------------------------
// ----- Receiver of MAC layer -----
   ccfpga_rx_MAC #(
      .COUNT_WIDTH           ( 4                       ),
      .PATTERN_WIDTH         ( PATTERN_WIDTH           ),
      .DATA_BYTES            ( DATA_BYTES              )
   ) rx_MAC_inst (
      .clk                   ( i_PCLK                  ),
      .reset                 ( reset                   ),
      .fsm_state             ( fsm_state               ),

      .rx_data               ( descrambled_data        ),

      .OS_reset_flag         ( s_rx_OS_rst             ),
      .IDLE_reset_flag       ( s_rx_IDLE_rst           ),
      .timeout_reset_flag    ( s_OS_timeout_rst        ),
      .rec_cfg_reset_flag    ( s_recovery_cfg_rx_flag  ),
      .rec_idle_reset_flag   ( s_recovery_idle_rx_flag ),
      .TS1_pattern_en        ( TS1_pattern_en          ),
      .TS2_pattern_en        ( TS2_pattern_en          ),
      .max_count             ( rx_max_count            ),
      .L0_enabled            ( L0_enabled              ),

      .OS_valid              ( OS_valid                ),
      .OS_detected           ( OS_detected             ),
      .inversion_detected    ( inversion_detected      ),
      .OS_rec_cfg_detected   ( OS_rec_cfg_detected     ),
      .IDLE_detected         ( IDLE_detected           ),

      .OS_count_maxed        ( s_rx_flag_OS            ),
      .timeout_flag          ( s_timeout_OS            ),
      .IDLE_count_maxed      ( s_rx_flag_IDLE          ),
      .rec_cfg_count_maxed   ( s_recovery_cfg_rx_flag  ),
      .rec_idle_count_maxed  ( s_recovery_idle_rx_flag ),

      .expected_Link         ( expected_Link           ),
      .expected_Lane         ( expected_Lane           ),
      .expected_Ctrl         ( expected_Ctrl           ),
      .link_detected         ( link_detected           ),
      .lane_detected         ( lane_detected           ),

      .rx_data_DLL           ( o_RxData                ),
      .rx_dataK_DLL          ( o_RxDataK               )
   );
//-------------------------------------------------------------------------------------------------------------------------------
// ----- Transmitter of MAC layer -----
   ccfpga_tx_MAC #(
      .DATA_BYTES      ( DATA_BYTES        ),
      .PATTERN_WIDTH   ( PATTERN_WIDTH     )
   ) tx_MAC_inst (
      .clk                          ( i_PCLK                       ),
      .reset                        ( reset                        ),

      .tx_data                      ( i_TxData                     ),

      .s_tx_OS_flag_rst             ( s_tx_OS_flag_rst             ),
      .s_tx_IDLE_flag_rst           ( s_tx_IDLE_flag_rst           ),
      .s_polling_active_tx_flag_rst ( s_polling_active_tx_flag_rst ),

      .OS_valid                     ( OS_valid                     ),
      .OS_rec_cfg_detected          ( OS_rec_cfg_detected          ),
      .IDLE_detected                ( IDLE_detected                ),

      .send_OS_trigger              ( send_OS_trigger              ),
      .send_IDLE_trigger            ( send_IDLE_trigger            ),
      .OS_type                      ( OS_type                      ),
      .tx_max_count                 ( tx_max_count                 ),

      .expected_Link                ( expected_Link                ),
      .expected_Lane                ( expected_Lane                ),
      .expected_Ctrl                ( expected_Ctrl                ),

      .s_tx_flag_OS                 ( s_tx_flag_OS                 ),
      .s_tx_flag_IDLE               ( s_tx_flag_IDLE               ),
      .s_polling_active_tx_flag     ( s_polling_active_tx_flag     ),
      .sending_OS                   ( sending_OS                   ),
      .sending_data                 ( sending_data                 ),
      .sending_SKP                  ( sending_SKP                  ),

      .txdata_reg                   ( txdata_reg                   ),
      .txdatak_reg                  ( txdatak_reg                  )
   );
//-------------------------------------------------------------------------------------------------------------------------------
// ----- Clock count (Timeout) -----
   ccfpga_clk_counter # (
      .BIT_WIDTH        ( 21                 )
   ) timeout_counter_inst (
      .i_clk            ( i_PCLK             ),
      .i_reset          ( s_clk_timeout_rst  ),     // Asynchronous Reset
      .max_count        ( clk_max_count      ),     // Max Count
      .o_flag           ( s_timeout_clk      )      // Output Flag when Count reaches max count
   );
//-------------------------------------------------------------------------------------------------------------------------------
// ----- Scrambler -----
   wire                  scrambler_en;
   wire [DATA_BYTES-1:0] tx_char_is_training_sequence;
   wire [DATA_WIDTH-1:0] scrambled_data;
   wire [DATA_BYTES-1:0] scrambled_data_k;

   // Scrambled output data
   always @(posedge i_PCLK or posedge reset) begin
      if ( reset ) begin
         o_TxData  <= {DATA_WIDTH{1'b0}};
         o_TxDataK <= {DATA_BYTES{1'b0}};
      end else begin
         o_TxData  <= scrambled_data;
         o_TxDataK <= scrambled_data_k;
      end
   end

   // Scrambler instance
   ccfpga_scrambler #(
   .DATA_BYTES    ( DATA_BYTES                   )
   ) scrambler_inst (
   .clk           ( i_PCLK                       ),
   .reset         ( reset                        ),
   .scrambler_en  ( scrambler_en                 ),
   .data_in       ( txdata_reg                   ),
   .data_in_k     ( txdatak_reg                  ),
   .data_in_TS    ( tx_char_is_training_sequence ),

   .data_out      ( scrambled_data               ),
   .data_out_k    ( scrambled_data_k             )
   );

// ----- Descrambler -----
   wire                  descrambler_en;
   wire [DATA_BYTES-1:0] rx_char_is_training_sequence;

   reg  [DATA_WIDTH-1:0] rxdata_reg;
   reg  [DATA_BYTES-1:0] rxdatak_reg;

   // Capture input data
   always @(posedge i_PCLK or posedge reset) begin
      if ( reset ) begin
         rxdata_reg  <= {DATA_WIDTH{1'b0}};
         rxdatak_reg <= {DATA_BYTES{1'b0}};
      end else begin
         rxdata_reg  <= i_RxData;
         rxdatak_reg <= i_RxDataK;
      end
   end

   // Descrambler instance (for Rx data)
   ccfpga_scrambler #(
   .DATA_BYTES    ( DATA_BYTES                   )
   ) descrambler_inst (
   .clk           ( i_PCLK                       ),
   .reset         ( reset                        ),
   .scrambler_en  ( descrambler_en               ),
   .data_in       ( rxdata_reg                   ),
   .data_in_k     ( rxdatak_reg                  ),
   .data_in_TS    ( rx_char_is_training_sequence ),

   .data_out      ( descrambled_data             ),
   .data_out_k    ( descrambled_data_k           )
   );

   // TODO: Question: if we sending nothing, maybe waiting for data from upper layer
   // should the scrambler_en disabled?
   // Scrambler enabled when not directed in control bits and sending data/OS/SKP
   //assign scrambler_en = (sending_data | sending_OS | send_IDLE_trigger | sending_SKP) & ~expected_Ctrl[3];
   assign scrambler_en = (sending_data | sending_OS | sending_SKP) & ~expected_Ctrl[3];
   // Descrambler enabled when not directed in control bits
   assign descrambler_en = ~expected_Ctrl[3];
   // Training sequence indication for scrambler/descrambler
   assign tx_char_is_training_sequence = sending_OS ? {DATA_BYTES{1'b1}} : {DATA_BYTES{1'b0}};
   assign rx_char_is_training_sequence = (fsm_state == 5'b01010 | fsm_state == 5'b01001 | fsm_state == 5'b10110) ?
                                        {DATA_BYTES{1'b0}} : {DATA_BYTES{1'b1}};
//-------------------------------------------------------------------------------------------------------------------------------
endmodule