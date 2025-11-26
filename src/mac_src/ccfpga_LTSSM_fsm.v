//----------------------------------------------------------------------------
// Description: This module defines the LTSSM for PCIe
// - It handles the state transitions and based on input flags and conditions
// - Outputs appropriate triggers for OS, IDLE, and data transmission
// - Outputs reset flags for timeouts, Rx/Tx counters, and link/lane detection
//============================================================================

module ccfpga_LTSSM_fsm #(
   parameter DATA_BYTES = 8,
   parameter DATA_WIDTH = DATA_BYTES*8
   )
   (
   input wire                    i_reset_n,                   // Asynchronous Reset
   input wire                    i_PCLK,                      // Parallel Interface Clock
   input wire              [2:0] i_RxStatus,                  // Receiver Status
   input wire                    s_timeout,                   // Timeout Flag
   input wire                    s_rx_flag,                   // Rx Flag
   input wire                    s_tx_flag,                   // Tx Flag
   input wire                    s_polling_active_tx_flag,    // Polling Active Tx flag
   input wire                    s_recovery_cfg_rx_flag,      // Recovery Rcvrcfg Rx flag
   input wire                    s_recovery_idle_rx_flag,     // Recovery Idle Rx flag
   input wire                    i_RxElecIdle,                // Electrical Idle at Receiver
   input wire                    link_detected,               // Link Detected
   input wire                    lane_detected,               // Lane Detected

   output reg                   o_TxDetectRx,                 // Receiver Detection (P1)/Loopback (P0)
   output reg                   o_TxElecIdle,                 // Electrical Idle
   output reg  [DATA_BYTES-1:0] o_TxCompliance,               // Compliance Pattern
   output reg                   o_send_OS_trigger,            // Trigger the sending of OS
   output reg                   o_send_IDLE_trigger,          // Trigger the sending of IDLE
   output reg                   o_send_data_trigger,          // Trigger the sending of data
   output wire            [4:0] o_fsm_state,                  // fsm status
   output reg                   s_clk_timeout_rst,            // Timeout Reset
   output reg                   s_OS_timeout_rst,             // OS Timeout Reset
   output reg                   s_rx_flag_rst,                // Rx Flag Reset
   output reg                   s_tx_flag_rst,                // Tx Flag Reset
   output reg                   s_polling_active_tx_flag_rst, // Polling Active Tx flag Reset
   output reg                   s_recovery_cfg_rx_flag_rst,   // Recovery Rcvrcfg Rx flag Reset
   output reg                   s_recovery_idle_rx_flag_rst,  // Recovery Idle Rx flag Reset
   output reg                   s_link_detected_rst,          // Link Detected Reset
   output reg                   s_lane_detected_rst           // Lane Detected Reset
   );

   reg [4:0] s_state, s_next_state;
   assign o_fsm_state         = s_state;

   // FSM States
   localparam [4:0]  DETECT_QUIET                    = 5'b00000,
                     DETECT_ACTIVE                   = 5'b00001,
                     POLLING_ACTIVE                  = 5'b00010,
                     POLLING_CONFIG                  = 5'b00011,
                     CONFIG_LINKWIDTH_START          = 5'b00100,
                     CONFIG_LINKWIDTH_ACCEPT         = 5'b00101,
                     CONFIG_LANENUM_WAIT             = 5'b00110,
                     CONFIG_LANENUM_ACCEPT           = 5'b00111,
                     CONFIG_COMPLETE                 = 5'b01000,
                     CONFIG_IDLE                     = 5'b01001,
                     L0                              = 5'b01010,
                     RECOVERY_RCVRLOCK               = 5'b01011,
                     PRE_CONFIG_LINKWIDTH_START      = 5'b01100,
                     PRE_CONFIG_LINKWIDTH_ACCEPT     = 5'b01101,
                     PRE_CONFIG_LANENUM_WAIT         = 5'b01110,
                     PRE_CONFIG_LANENUM_ACCEPT       = 5'b01111,
                     PRE_CONFIG_COMPLETE             = 5'b10000,
                     PRE_CONFIG_IDLE                 = 5'b10001,
                     CONFIG_LINKWIDTH_START_LINKNUM  = 5'b10010,
                     CONFIG_LINKWIDTH_ACCEPT_LANENUM = 5'b10011,
                     RECOVERY_RCVRCFG                = 5'b10100,
                     RECOVERY_IDLE                   = 5'b10101,
                     PRE_L0                          = 5'b10110,
                     PRE_RECOVERY_RCVRLOCK           = 5'b10111,
                     PRE_RECOVERY_RCVRCFG            = 5'b11000,
                     PRE_RECOVERY_IDLE               = 5'b11001;


   //State Register
   always @(posedge i_PCLK, negedge i_reset_n) begin
      if ( !i_reset_n )
         s_state <= DETECT_QUIET;
      else 
         s_state <= s_next_state;
   end

   //Transition logic
   always @(*) begin
      s_next_state = s_state;
      case ( s_state )
         DETECT_QUIET : begin
            if ( s_timeout == 1'b1 | i_RxElecIdle == 1'b0 )
               s_next_state = DETECT_ACTIVE;
            else
               s_next_state = DETECT_QUIET;
         end
         DETECT_ACTIVE : begin
            if ( i_RxStatus == 3'b011 )
               s_next_state = POLLING_ACTIVE;
            else
               s_next_state = DETECT_ACTIVE;
         end
         POLLING_ACTIVE : begin
            if ( (s_rx_flag == 1'b1) && (s_polling_active_tx_flag == 1'b1) )
               s_next_state = POLLING_CONFIG;
            else if ( s_timeout == 1'b1 )
               s_next_state = DETECT_QUIET;
         end
         POLLING_CONFIG : begin
            if ( (s_rx_flag == 1'b1) && (s_tx_flag == 1'b1) )
               s_next_state = PRE_CONFIG_LINKWIDTH_START;
            else if ( s_timeout == 1'b1 )
               s_next_state = DETECT_QUIET;
         end
         PRE_CONFIG_LINKWIDTH_START : begin
            s_next_state = CONFIG_LINKWIDTH_START_LINKNUM;
         end
         CONFIG_LINKWIDTH_START_LINKNUM : begin
            if ( link_detected == 1'b1 )
               s_next_state = CONFIG_LINKWIDTH_START;
         end
         CONFIG_LINKWIDTH_START : begin
            if ( s_rx_flag == 1'b1 )
               s_next_state = PRE_CONFIG_LINKWIDTH_ACCEPT;
            else if ( s_timeout == 1'b1 )
               s_next_state = DETECT_QUIET;
         end
         PRE_CONFIG_LINKWIDTH_ACCEPT : begin
            s_next_state = CONFIG_LINKWIDTH_ACCEPT_LANENUM;
         end
         CONFIG_LINKWIDTH_ACCEPT_LANENUM : begin
            if ( lane_detected == 1'b1 )
               s_next_state = CONFIG_LINKWIDTH_ACCEPT;
         end
         CONFIG_LINKWIDTH_ACCEPT : begin
            if ( s_rx_flag == 1'b1 )
               s_next_state = PRE_CONFIG_LANENUM_ACCEPT;
            else if ( s_timeout == 1'b1 )
               s_next_state = DETECT_QUIET;
         end
         PRE_CONFIG_LANENUM_ACCEPT : begin
            s_next_state = CONFIG_LANENUM_ACCEPT;
         end
         CONFIG_LANENUM_WAIT : begin
            if ( s_rx_flag == 1'b1 )
               s_next_state = PRE_CONFIG_LANENUM_ACCEPT;
            else if ( s_timeout == 1'b1 )
               s_next_state = DETECT_QUIET;
         end
         PRE_CONFIG_LANENUM_ACCEPT : begin
            s_next_state = CONFIG_LANENUM_ACCEPT;
         end
         CONFIG_LANENUM_ACCEPT : begin
            if ( s_rx_flag == 1'b1 )
               s_next_state = PRE_CONFIG_COMPLETE;
            else if ( s_timeout == 1'b1 )
               s_next_state = DETECT_QUIET;
         end
         PRE_CONFIG_COMPLETE : begin
            s_next_state = CONFIG_COMPLETE;
         end
         CONFIG_COMPLETE : begin
            if ( (s_rx_flag == 1'b1) && (s_tx_flag == 1'b1) )
               s_next_state = PRE_CONFIG_IDLE;
            else if ( s_timeout == 1'b1 )
               s_next_state = DETECT_QUIET;
         end
         PRE_CONFIG_IDLE : begin
            s_next_state = CONFIG_IDLE;
         end
         CONFIG_IDLE : begin
            if ( (s_rx_flag == 1'b1) && (s_tx_flag == 1'b1) )
               s_next_state = PRE_L0;
            else if ( s_timeout == 1'b1 )
               s_next_state = DETECT_QUIET;
         end
         PRE_L0 : begin
            s_next_state = L0;
         end
         L0 : begin
            if ( s_rx_flag == 1'b1 )
               s_next_state = PRE_RECOVERY_RCVRLOCK;
         end
         PRE_RECOVERY_RCVRLOCK : begin
            s_next_state = RECOVERY_RCVRLOCK;
         end
         RECOVERY_RCVRLOCK : begin
            if ( s_rx_flag == 1'b1 )
               s_next_state = PRE_RECOVERY_RCVRCFG;
            else if ( s_timeout == 1'b1 )
               s_next_state = DETECT_QUIET;
         end
         PRE_RECOVERY_RCVRCFG : begin
            s_next_state = RECOVERY_RCVRCFG;
         end
         RECOVERY_RCVRCFG : begin
            if ( (s_rx_flag == 1'b1) && (s_tx_flag == 1'b1) )
               s_next_state = PRE_RECOVERY_IDLE;
            else if ( (s_recovery_cfg_rx_flag == 1'b1) && (s_tx_flag == 1'b1) ) // Received 2 consecutive TS1 with PAD-Lane
               s_next_state = PRE_CONFIG_LINKWIDTH_START;
            else if ( s_timeout == 1'b1 )
               s_next_state = DETECT_QUIET;
         end
         PRE_RECOVERY_IDLE : begin
            s_next_state = RECOVERY_IDLE;
         end
         RECOVERY_IDLE : begin
            if ( (s_rx_flag == 1'b1) && (s_tx_flag == 1'b1) )
               s_next_state = PRE_L0;
            else if ( s_recovery_idle_rx_flag == 1'b1 ) // Received 2 consecutive TS1 with PAD-Lane
               s_next_state = PRE_CONFIG_LINKWIDTH_START;
            else if ( s_timeout == 1'b1 )
               s_next_state = DETECT_QUIET;
         end
      endcase
   end

   // Output logic
   always @(s_state) begin
      o_TxDetectRx                   = 1'b0;
      o_TxElecIdle                   = 1'b0;
      o_TxCompliance                 = {DATA_BYTES{1'b0}};
      s_OS_timeout_rst               = 1'b1;
      s_clk_timeout_rst              = 1'b1;
      s_rx_flag_rst                  = 1'b1;
      s_tx_flag_rst                  = 1'b1;
      s_polling_active_tx_flag_rst   = 1'b1;
      s_recovery_cfg_rx_flag_rst     = 1'b1;
      s_recovery_idle_rx_flag_rst    = 1'b1;
      o_send_OS_trigger              = 1'b0;
      o_send_IDLE_trigger            = 1'b0;
      o_send_data_trigger            = 1'b0;
      s_lane_detected_rst            = 1'b1;
      s_link_detected_rst            = 1'b1;
      case (s_state)
         DETECT_QUIET : begin
            o_TxDetectRx      = 1'b0;
            o_TxElecIdle      = 1'b1;
            s_clk_timeout_rst = 1'b0;  // Start counting 12ms
         end
         DETECT_ACTIVE : begin
            o_TxDetectRx = 1'b1;
            o_TxElecIdle = 1'b1;
         end
         POLLING_ACTIVE : begin
            o_send_OS_trigger            = 1'b1;
            s_rx_flag_rst                = 1'b0;
            s_polling_active_tx_flag_rst = 1'b0;
            s_clk_timeout_rst            = 1'b0; // Start counting 24ms
         end
         POLLING_CONFIG : begin
            o_send_OS_trigger            = 1'b1;
            s_rx_flag_rst                = 1'b0;
            s_tx_flag_rst                = 1'b0;
            s_clk_timeout_rst            = 1'b0; // Start counting 48ms
         end
         CONFIG_LINKWIDTH_START_LINKNUM : begin
            s_link_detected_rst          = 1'b0;
         end
         CONFIG_LINKWIDTH_START : begin
            o_send_OS_trigger            = 1'b1;
            s_rx_flag_rst                = 1'b0;
            s_clk_timeout_rst            = 1'b0; // Start counting 24ms
         end
         CONFIG_LINKWIDTH_ACCEPT_LANENUM : begin
            s_lane_detected_rst          = 1'b0;
         end
         CONFIG_LINKWIDTH_ACCEPT : begin
            o_send_OS_trigger            = 1'b1;
            s_rx_flag_rst                = 1'b0;
            s_clk_timeout_rst            = 1'b0; // Start counting 2ms
            s_OS_timeout_rst             = 1'b0; // Start counting 2 consecutive TS1 with PAD Link and Lane
         end
         CONFIG_LANENUM_WAIT : begin
            o_send_OS_trigger            = 1'b1;
            s_rx_flag_rst                = 1'b0;
            s_clk_timeout_rst            = 1'b0; // Start counting 2ms
            s_OS_timeout_rst             = 1'b0; // Start counting 2 consecutive TS1 with PAD Link and Lane
         end
         CONFIG_LANENUM_ACCEPT : begin
            o_send_OS_trigger            = 1'b1;
            s_rx_flag_rst                = 1'b0;
            s_OS_timeout_rst             = 1'b0; // 2 consecutive TS1 with PAD Link and Lane
         end
         CONFIG_COMPLETE : begin
            o_send_OS_trigger            = 1'b1;
            s_rx_flag_rst                = 1'b0;
            s_tx_flag_rst                = 1'b0;
            s_clk_timeout_rst            = 1'b0; // Start counting 2ms
         end
         CONFIG_IDLE : begin
            o_send_IDLE_trigger          = 1'b1;
            s_rx_flag_rst                = 1'b0;
            s_tx_flag_rst                = 1'b0;
            s_clk_timeout_rst            = 1'b0; // Start counting 2ms
         end
         L0 : begin
            // Normal Operation
            o_send_data_trigger          = 1'b1;
            s_rx_flag_rst                = 1'b0;
         end
         RECOVERY_RCVRLOCK : begin
            o_send_OS_trigger            = 1'b1;
            s_rx_flag_rst                = 1'b0;
            s_recovery_cfg_rx_flag_rst   = 1'b0;
            s_clk_timeout_rst            = 1'b0; // Start counting 24ms
         end
         RECOVERY_RCVRCFG : begin
            o_send_OS_trigger            = 1'b1;
            s_rx_flag_rst                = 1'b0;
            s_tx_flag_rst                = 1'b0;
            s_clk_timeout_rst            = 1'b0; // Start counting 48ms
         end
         RECOVERY_IDLE : begin
            o_send_IDLE_trigger          = 1'b1;
            s_rx_flag_rst                = 1'b0;
            s_tx_flag_rst                = 1'b0;
            s_recovery_idle_rx_flag_rst  = 1'b0;
            s_clk_timeout_rst            = 1'b0; // Start counting 2ms
         end
      endcase
   end

endmodule
