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

   output wire                   o_Reset_n,      // Asyn. Reset
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

   localparam CYCLE_TIME = DATA_BYTES == 8 ? 32 : DATA_BYTES == 4 ? 16 : DATA_BYTES == 2 ? 8 : DATA_BYTES == 1 ? 4 : 0; // in ns

   // Reset
   wire       reset = !i_Reset_n;

   // L0 flags
   wire       L0_enabled;           // L0 state

   // Rx
   wire       s_rx_flag_rst;        // Receiver flag Reset from FSM
   wire       s_rx_rst;             // Receiver flag Reset
   wire       s_rx_OS_rst;          // Receiver OS flag Reset
   wire       s_rx_IDLE_rst;        // Receiver IDLE flag Reset
   wire       s_rx_flag_IDLE;       // Max count for received IDLE reached
   reg  [7:0] expected_Link;        // Expected link number in Ordered Set
   reg  [7:0] expected_Lane;        // Expected lane number in Ordered Set
   reg  [7:0] expected_Ctrl;        // Expected control
   wire       s_link_detected_rst;  // Link Detected Reset from FSM
   wire       s_lane_detected_rst;  // Lane Detected Reset from FSM
   reg        link_detected;        // Link number detected
   reg        lane_detected;        // Lane number detected
   wire [3:0] rx_max_count;         // Max count for received Ordered Set
   wire       TS1_pattern_en;       // Enable TS1 pattern
   wire       TS2_pattern_en;       // Enable TS2 pattern
   wire       OS_detected;          // Receiver detects Ordered Set
   wire       OS_valid;             // Received OS is valid
   wire       s_rx_flag_OS;         // Max count for received Orderes Set reached
   wire [7:0] Link_number;          // Detected link number
   wire [7:0] Lane_number;          // Detected lane number
   wire [7:0] Control_bits;         // Detected control bits

   // Tx
   wire s_tx_flag_rst;        // Transmitter flag Reset from FSM
   wire s_tx_OS_flag_rst;     // Transmitter flag reset
   wire s_tx_IDLE_flag_rst;   // Transmitter IDLE flag reset
   wire s_tx_flag_IDLE;       // Max count for transmitted IDLE reached
   wire OS_sent;              // An OS is sent
   wire [4:0] tx_max_count;   // Max count for transmitter
   wire s_tx_flag_OS;         // Max count for transmitter reached
   wire OS_type;              // Type of Ordered Set to be sent
   wire s_polling_active_tx_flag;
   wire s_polling_active_tx_flag_rst;

   // Timeout
   wire s_clk_timeout_rst;    // Timeout reset
   wire s_OS_timeout_rst;     // Timeout reset
   wire [20:0] clk_max_count;  // Max count for timeout
   wire s_timeout;            // Timeout flag
   wire s_timeout_clk;        // Timeout due to clock
   wire s_timeout_OS;         // Timeout due to received OS
   wire s_timeout_clk_en;     // Enable timeout due to clock
   wire s_timeout_OS_en;      // Enable timeout due to received OS

   wire [4:0] fsm_state;
   wire IDLE_detected;        // IDLE symbol detected
   wire s_rx_flag;
   wire s_tx_flag;

   // Send data
   wire send_IDLE_trigger;
   wire send_OS_trigger;
   wire sending_OS;
   wire sending_data;
   wire sending_SKP;
   wire [DATA_WIDTH-1:0] txdata_OS;
   wire [DATA_BYTES-1:0] txdatak_OS;
   wire [DATA_WIDTH-1:0] txdata_IDLE;
   wire [DATA_BYTES-1:0] txdatak_IDLE;
   wire [DATA_WIDTH-1:0] txdata_DLL;
   wire [DATA_BYTES-1:0] txdatak_DLL;
   wire [DATA_WIDTH-1:0] txdata_SKP;
   wire [DATA_BYTES-1:0] txdatak_SKP;

   // Scrambler
   wire                  scrambler_en;
   wire [DATA_BYTES-1:0] tx_char_is_training_sequence;
   wire [DATA_WIDTH-1:0] scrambled_data;
   wire [DATA_BYTES-1:0] scrambled_data_k;

   reg  [DATA_WIDTH-1:0] txdata_reg;
   reg  [DATA_BYTES-1:0] txdatak_reg;

   // Descrambler
   wire                  descrambler_en;
   wire [DATA_BYTES-1:0] rx_char_is_training_sequence;
   wire [DATA_WIDTH-1:0] unscrambled_data;
   wire [DATA_BYTES-1:0] unscrambled_data_k;

   reg  [DATA_WIDTH-1:0] rxdata_reg;
   reg  [DATA_BYTES-1:0] rxdatak_reg;

   // Inversion Detection
   wire                  detect_inversion_en = fsm_state == 5'b00010; // Enable in POLLING_ACTIVE
   wire                  inversion_detected;

   // Assignments
   assign s_rx_OS_rst = fsm_state != 5'b01001 ? s_rx_rst : 1'b1;
   assign s_rx_IDLE_rst = fsm_state == 5'b01001 ? s_rx_rst : 1'b1;

   assign s_tx_OS_flag_rst = fsm_state != 5'b01001 ? s_tx_flag_rst : 1'b1;
   assign s_tx_IDLE_flag_rst = fsm_state == 5'b01001 ? s_tx_flag_rst : 1'b1;

   assign o_PowerDown = fsm_state == 5'b00000 ? 2'b10 : fsm_state == 5'b00001 ? 2'b10 : 2'b00; // Power Down for DETECT
   assign o_LinkUp = fsm_state == 5'b01010 ? 1'b1 : fsm_state == 5'b01001 ? 1'b1 : 1'b0; // Link Up for L0 or CONFIG_IDLE
   assign s_rx_flag = ((s_rx_flag_OS && (fsm_state != 5'b01001)) || (s_rx_flag_IDLE && (fsm_state == 5'b01001)));
   assign s_tx_flag = (s_tx_flag_OS && (fsm_state != 5'b01001)) || (s_tx_flag_IDLE && (fsm_state == 5'b01001));
   assign s_rx_rst  = ((fsm_state == 5'b10010) ? s_link_detected_rst : (fsm_state == 5'b10011) ? s_lane_detected_rst : s_rx_flag_rst) && i_RxValid; // TODO: i_RxValid = 1'b1 the whole time??

   // Rx
   assign L0_enabled   = fsm_state == 5'b01010 ? 1'b1 : 1'b0;
   assign o_RxPolarity = inversion_detected;

   assign rx_max_count = fsm_state == 5'b00010 ? 4'b1000 :
                         fsm_state == 5'b00011 ? 4'b1000 :
                         fsm_state == 5'b00100 ? 4'b0010 :
                         fsm_state == 5'b00101 ? 4'b0010 :
                         fsm_state == 5'b00110 ? 4'b0010 :
                         fsm_state == 5'b00111 ? 4'b0010 :
                         fsm_state == 5'b01000 ? 4'b1000 :
                         fsm_state == 5'b01001 ? 4'b1000 : 4'b1111;

   assign TS1_pattern_en = fsm_state == 5'b00010 ? 1'b1 :
                           fsm_state == 5'b00011 ? 1'b0 :
                           fsm_state == 5'b00100 ? 1'b1 :
                           fsm_state == 5'b00101 ? 1'b1 :
                           fsm_state == 5'b00110 ? 1'b1 :
                           fsm_state == 5'b00111 ? 1'b1 :
                           fsm_state == 5'b01000 ? 1'b0 :
                           fsm_state == 5'b01001 ? 1'b0 :
                           fsm_state == 5'b10010 ? 1'b1 :
                           fsm_state == 5'b10011 ? 1'b1 : 1'b0;

   assign TS2_pattern_en = fsm_state == 5'b00010 ? 1'b1 :
                           fsm_state == 5'b00011 ? 1'b1 :
                           fsm_state == 5'b00100 ? 1'b0 :
                           fsm_state == 5'b00101 ? 1'b0 :
                           fsm_state == 5'b00110 ? 1'b0 :
                           fsm_state == 5'b00111 ? 1'b0 :
                           fsm_state == 5'b01000 ? 1'b1 :
                           fsm_state == 5'b01001 ? 1'b0 :
                           fsm_state == 5'b10010 ? 1'b0 :
                           fsm_state == 5'b10011 ? 1'b0 : 1'b0;

   // Tx
   assign tx_max_count   = fsm_state == 5'b00011 ? 5'b10000 :
                           fsm_state == 5'b01000 ? 5'b10000 :
                           fsm_state == 5'b01001 ? 5'b10000 : 5'b11111;

   assign OS_type        = fsm_state == 5'b00010 ? 1'b0 :
                           fsm_state == 5'b00011 ? 1'b1 :
                           fsm_state == 5'b00100 ? 1'b0 :
                           fsm_state == 5'b00101 ? 1'b0 :
                           fsm_state == 5'b00110 ? 1'b0 :
                           fsm_state == 5'b00111 ? 1'b0 :
                           fsm_state == 5'b01000 ? 1'b1 : 1'b0;

   // Timeout
   assign clk_max_count = fsm_state == 5'b00000 ? 12*1000000 / CYCLE_TIME : //12ms
                          fsm_state == 5'b00010 ? 24*1000000 / CYCLE_TIME : //24ms
                          fsm_state == 5'b00011 ? 48*1000000 / CYCLE_TIME : //48ms
                          fsm_state == 5'b00100 ? 24*1000000 / CYCLE_TIME : //24ms
                          fsm_state == 5'b00101 ?  2*1000000 / CYCLE_TIME : //2ms
                          fsm_state == 5'b00110 ?  2*1000000 / CYCLE_TIME : //2ms
                          fsm_state == 5'b01000 ?  2*1000000 / CYCLE_TIME : //2ms
                          fsm_state == 5'b01001 ?  2*1000000 / CYCLE_TIME : 2*1000000 / CYCLE_TIME; //2ms

   assign s_timeout_clk_en = fsm_state == 5'b00111 ? 1'b0 : 1'b1;
   assign s_timeout_OS_en  = (( fsm_state == 5'b00101 || fsm_state == 5'b00110 ) || fsm_state == 5'b00111) ? 1'b1 : 1'b0;
   assign s_timeout        = ( s_timeout_clk & s_timeout_clk_en) || ( s_timeout_OS & s_timeout_OS_en );

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
      .s_clk_timeout_rst            ( s_clk_timeout_rst ),            // Clock Timeout Reset
      .s_OS_timeout_rst             ( s_OS_timeout_rst  ),            // OS Timeout Reset
      .s_rx_flag_rst                ( s_rx_flag_rst  ),                // Rx Flag Reset
      .s_tx_flag_rst                ( s_tx_flag_rst  ),                // Tx Flag Reset
      .s_polling_active_tx_flag_rst ( s_polling_active_tx_flag_rst ),  // Polling Active Tx Reset flag
      .s_link_detected_rst          ( s_link_detected_rst          ),  // Link Detected Reset
      .s_lane_detected_rst          ( s_lane_detected_rst          )   // Lane Detected Reset
   );
   // ------------------

   // Rx counter
   ccfpga_rx_MAC #(
      .COUNT_WIDTH        ( 4                 ),
      .PATTERN_WIDTH      ( PATTERN_WIDTH     ),
      .DATA_BYTES         ( DATA_BYTES        )
   ) rx_MAC_inst (
      .clk                ( i_PCLK            ),
      .reset              ( reset             ),
      .OS_reset_flag      ( s_rx_OS_rst       ),
      .IDLE_reset_flag    ( s_rx_IDLE_rst     ),
      .timeout_reset_flag ( s_OS_timeout_rst  ),

      .rx_data            ( unscrambled_data  ),
      .expected_Link      ( expected_Link     ),
      .expected_Lane      ( expected_Lane     ),
      .expected_Ctrl      ( expected_Ctrl     ),
      .max_count          ( rx_max_count      ),
      .TS1_pattern_en     ( TS1_pattern_en    ),
      .TS2_pattern_en     ( TS2_pattern_en    ),

      .L0_enabled         ( L0_enabled        ),

      .timeout_flag       ( s_timeout_OS      ),

      .OS_valid           ( OS_valid          ),
      .OS_detected        ( OS_detected       ),
      .OS_count_maxed     ( s_rx_flag_OS      ),
      .inversion_detected ( inversion_detected),
      .detected_Link      ( Link_number       ),
      .detected_Lane      ( Lane_number       ),
      .detected_Ctrl      ( Control_bits      ),

      .IDLE_detected      ( IDLE_detected     ),
      .IDLE_count_maxed   ( s_rx_flag_IDLE    ),

      .rx_data_DLL        ( o_RxData          )
   );

   // Tx Count
   ccfpga_tx_count #(
      .COUNT_WIDTH               ( 5                             ),
      .DATA_BYTES                ( DATA_BYTES                    )
   ) tx_count_inst (
      .clk                       ( i_PCLK                        ),
      .OS_reset_flag             ( s_tx_OS_flag_rst              ),
      .IDLE_reset_flag           ( s_tx_IDLE_flag_rst            ),
      .polling_active_reset_flag ( s_polling_active_tx_flag_rst  ),
      .OS_sent                   ( OS_sent                       ),
      .OS_valid                  ( OS_valid                      ),
      .IDLE_sent                 ( IDLE_sent                     ),
      .IDLE_detected             ( IDLE_detected                 ),
      .OS_max_count              ( tx_max_count                  ),

      .OS_count_maxed            ( s_tx_flag_OS                  ),
      .IDLE_count_maxed          ( s_tx_flag_IDLE                ),
      .polling_active_count_maxed( s_polling_active_tx_flag      )
   );

   // Clock count (Timeout)
   ccfpga_clk_counter # (
      .BIT_WIDTH        ( 21                 )
   ) timeout_counter_inst (
      .i_clk            ( i_PCLK             ),
      .i_reset          ( s_clk_timeout_rst  ),     // Asynchronous Reset
      .max_count        ( clk_max_count      ),     // Max Count
      .o_flag           ( s_timeout_clk      )      // Output Flag when Count reaches max count
   );

   // Set detected Link and Lane number
   always @(posedge i_PCLK or negedge i_Reset_n) begin
      if ( !i_Reset_n ) begin
         expected_Link <= 8'hF7;
         expected_Lane <= 8'hF7;
         expected_Ctrl <= 8'h00;
         link_detected <= 1'b0;
         lane_detected <= 1'b0;
      end else if ( fsm_state == 5'b10010 ) begin // CONFIG_LINKWIDTH_START_LINKNUM
         if ( OS_detected == 1'b1 && Link_number != 8'hF7 ) begin
            expected_Link <= Link_number;
            expected_Lane <= 8'hF7;
            expected_Ctrl <= 8'h00;
            link_detected <= 1'b1;
            lane_detected <= 1'b0;
         end
      end else if ( fsm_state == 5'b10011 ) begin // CONFIG_LINKWIDTH_ACCEPT_LANENUM
         if ( OS_detected == 1'b1 && Lane_number != 8'hF7 && Link_number == expected_Link ) begin
            expected_Lane <= Lane_number;
            expected_Ctrl <= 8'h00;
            link_detected <= 1'b1;
            lane_detected <= 1'b1;
         end
      end else if ( fsm_state == 5'b01000 ) begin // CONFIG_COMPLETE
         expected_Ctrl <= Control_bits;
      end
   end

// Send OS module
   ccfpga_send_OS #(
   .PATTERN_WIDTH   ( PATTERN_WIDTH   ),
   .DATA_BYTES      ( DATA_BYTES      )
   ) send_OS_inst (
   .clk             ( i_PCLK          ),
   .send_OS_trigger ( send_OS_trigger ),
   .reset           ( reset           ),
   .received_Link   ( expected_Link   ),
   .received_Lane   ( expected_Lane   ),
   .received_Ctrl   ( expected_Ctrl   ),
   .OS_type         ( OS_type         ), // 0:TS1, 1:TS2

   .txdata          ( txdata_OS       ),
   .txdatak         ( txdatak_OS      ),
   .OS_sent         ( OS_sent         ),
   .sending_OS      ( sending_OS      )
   );

// Send IDLE module
   ccfpga_send_IDLE #(
   .IDLE_WIDTH        ( 8                 ),
   .DATA_WIDTH        ( DATA_WIDTH        )
   ) send_IDLE_inst (
   .clk               ( i_PCLK            ),
   .send_IDLE_trigger ( send_IDLE_trigger ),
   .reset             ( reset             ),

   .txdata            ( txdata_IDLE       ),
   .txdatak           ( txdatak_IDLE      ),
   .IDLE_sent         ( IDLE_sent         )
   );

// Send Data
   ccfpga_send_data #(
   .DATA_BYTES      ( DATA_BYTES   )
   ) send_data_inst (
   .clk             ( i_PCLK       ),
   .reset           ( reset        ),
   .txdata_DLL      ( i_TxData     ),

   .txdata          ( txdata_DLL   ),
   .txdatak         ( txdatak_DLL  ),
   .sending_data    ( sending_data )
   );

   // SKP Generator
   ccfpga_SKP_generator #(
   .SKP_WIDTH       ( 32                ),
   .DATA_BYTES      ( DATA_BYTES        )
   )  SKP_generator_inst (
   .clk             ( i_PCLK            ),
   .reset           ( reset             ),
   .sending_data    ( sending_data      ),
   .sending_OS      ( sending_OS        ),
   .sending_IDLE    ( send_IDLE_trigger ),

   .txdata          ( txdata_SKP        ),
   .txdatak         ( txdatak_SKP       ),
   .sending_SKP     ( sending_SKP       )
   );

   // Transmitted data multiplexer
   always @(posedge i_PCLK or posedge reset) begin
      if ( reset ) begin
         txdata_reg  <= {DATA_WIDTH{1'b0}};
         txdatak_reg <= {DATA_BYTES{1'b0}};
      end else if ( sending_data ) begin
         txdata_reg  <= txdata_DLL;
         txdatak_reg <= txdatak_DLL;
      end else if ( sending_OS ) begin
         txdata_reg  <= txdata_OS;
         txdatak_reg <= txdatak_OS;
      end else if ( send_IDLE_trigger ) begin
         txdata_reg  <= txdata_IDLE;
         txdatak_reg <= txdatak_IDLE;
      end else if ( sending_SKP ) begin
         txdata_reg  <= txdata_SKP;
         txdatak_reg <= txdatak_SKP;
      end else begin
         txdata_reg  <= {DATA_WIDTH{1'b0}};
         txdatak_reg <= {DATA_BYTES{1'b0}};
      end
   end

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
   .data_in_TS    ( rx_char_is_training_sequence ), // TODO: how to know if it is TS?

   .data_out      ( unscrambled_data             ),
   .data_out_k    ( unscrambled_data_k            )
   );

   // TODO: Question: if we sending nothing, maybe waiting for data from upper layer
   // should the scrambler_en disabled?
   assign scrambler_en = (sending_data | sending_OS | send_IDLE_trigger | sending_SKP) & ~expected_Ctrl[3];
   assign descrambler_en = ~expected_Ctrl[3];
   assign tx_char_is_training_sequence = sending_OS ? {DATA_BYTES{1'b1}} : {DATA_BYTES{1'b0}};
   assign rx_char_is_training_sequence = fsm_state == 5'b01010 ? {DATA_BYTES{1'b0}} : {DATA_BYTES{1'b1}};

endmodule