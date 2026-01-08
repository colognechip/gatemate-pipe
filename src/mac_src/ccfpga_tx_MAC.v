//----------------------------------------------------------------------------------------
// Description: Top module for Tx side of PHY/MAC
// - It handles the transmission of Ordered Sets, data, IDLE sequences and SKP sequences
// - It counts the number of transmitted Ordered Sets and IDLE sequences
//========================================================================================

module ccfpga_tx_MAC #(
   parameter DATA_BYTES     = 8,
   parameter DATA_WIDTH     = DATA_BYTES * 8,
   parameter PATTERN_WIDTH  = 128
)(
   input wire                  clk,                          // Clock
   input wire                  reset,                        // Asynchronous reset

   input wire [DATA_WIDTH-1:0] tx_data,                      // Data from DLL

   input wire                  s_tx_OS_flag_rst,             // Transmitter OS flag Reset
   input wire                  s_tx_IDLE_flag_rst,           // Transmitter IDLE flag Reset
   input wire                  s_polling_active_tx_flag_rst, // Polling active flag Reset

   input wire                  OS_valid,                     // Ordered Set valid indication
   input wire                  OS_rec_cfg_detected,          // non-matched Link/Lane Ordered Set detected in Recovery Config state
   input wire                  IDLE_detected,                // IDLE detected indication
   input wire                  L0_enabled,                   // L0 state enabled

   input wire                  send_OS_trigger,              // Trigger to send Ordered Set
   input wire                  send_IDLE_trigger,            // Trigger to send IDLE
   input wire                  OS_type,                      // Type of OS to send (0:TS1, 1:TS2)
   input wire            [4:0] tx_max_count,                 // Max count for transmitted Ordered Set

   input wire            [7:0] expected_Link,                // Expected link number in Ordered Set
   input wire            [7:0] expected_Lane,                // Expected lane number in Ordered Set
   input wire            [7:0] expected_Ctrl,                // Expected control

   output wire                 s_tx_flag_OS,                 // Max count for transmitted OS reached
   output wire                 s_tx_flag_IDLE,               // Max count for transmitted IDLE reached
   output wire                 s_polling_active_tx_flag,     // Max count for transmitted polling active reached

   output wire                 sending_OS,                   // Sending Ordered Set indication
   output wire                 sending_data,                 // Sending Data indication
   output wire                 sending_SKP,                  // Sending SKP indication

   output reg [DATA_WIDTH-1:0] txdata_reg,                   // Data to be transmitted
   output reg [DATA_BYTES-1:0] txdatak_reg                   // Data K to be transmitted
);

   wire                    OS_sent;       // Ordered Set sent indication
   wire                    IDLE_sent;     // IDLE sent indication
   wire                    SKP_in_queue;  // SKP Ordered Set scheduled in queue
   wire                    sending_IDLE;  // Sending IDLE indication

// Transmitter counter
   ccfpga_tx_count #(
      .COUNT_WIDTH               ( 5                             ),
      .DATA_BYTES                ( DATA_BYTES                    )
   ) tx_count_inst (
      .clk                       ( clk                           ),
      .OS_reset_flag             ( s_tx_OS_flag_rst              ),
      .IDLE_reset_flag           ( s_tx_IDLE_flag_rst            ),
      .polling_active_reset_flag ( s_polling_active_tx_flag_rst  ),
      .OS_sent                   ( OS_sent                       ),
      .OS_valid                  ( OS_valid                      ),
      .OS_rec_cfg_detected       ( OS_rec_cfg_detected           ),
      .IDLE_sent                 ( IDLE_sent                     ),
      .IDLE_detected             ( IDLE_detected                 ),
      .OS_max_count              ( tx_max_count                  ),

      .OS_count_maxed            ( s_tx_flag_OS                  ),
      .IDLE_count_maxed          ( s_tx_flag_IDLE                ),
      .polling_active_count_maxed( s_polling_active_tx_flag      )
   );

// Sending modules
   // Send OS module
   wire [DATA_WIDTH-1:0]    txdata_OS;
   wire [DATA_BYTES-1:0]    txdatak_OS;

   ccfpga_send_OS #(
   .PATTERN_WIDTH   ( PATTERN_WIDTH   ),
   .DATA_BYTES      ( DATA_BYTES      )
   ) send_OS_inst (
   .clk             ( clk             ),
   .send_OS_trigger ( send_OS_trigger ),
   .reset           ( reset           ),
   .received_Link   ( expected_Link   ),
   .received_Lane   ( expected_Lane   ),
   .received_Ctrl   ( expected_Ctrl   ),
   .OS_type         ( OS_type         ), // 0:TS1, 1:TS2
   .SKP_in_queue    ( SKP_in_queue    ),

   .txdata          ( txdata_OS       ),
   .txdatak         ( txdatak_OS      ),
   .OS_sent         ( OS_sent         ),
   .sending_OS      ( sending_OS      )
   );

   // Send IDLE module
   wire [DATA_WIDTH-1:0]    txdata_IDLE;
   wire [DATA_BYTES-1:0]    txdatak_IDLE;

   ccfpga_send_IDLE #(
   .IDLE_WIDTH        ( 8                 ),
   .DATA_WIDTH        ( DATA_WIDTH        )
   ) send_IDLE_inst (
   .clk               ( clk               ),
   .send_IDLE_trigger ( send_IDLE_trigger ),
   .reset             ( reset             ),
   .SKP_in_queue      ( SKP_in_queue      ),

   .txdata            ( txdata_IDLE       ),
   .txdatak           ( txdatak_IDLE      ),
   .IDLE_sent         ( IDLE_sent         ),
   .sending_IDLE      ( sending_IDLE      )
   );

   // Send Data
   wire [DATA_WIDTH-1:0]    txdata_DLL;
   wire [DATA_BYTES-1:0]    txdatak_DLL;

   ccfpga_send_data #(
   .DATA_BYTES      ( DATA_BYTES   )
   ) send_data_inst (
   .clk             ( clk          ),
   .reset           ( reset        ),
   .L0_enabled      ( L0_enabled   ),
   .txdata_DLL      ( tx_data      ),

   .txdata          ( txdata_DLL   ),
   .txdatak         ( txdatak_DLL  ),
   .sending_data    ( sending_data )
   );

   // SKP Generator
   wire [DATA_WIDTH-1:0]    txdata_SKP;
   wire [DATA_BYTES-1:0]    txdatak_SKP;

   ccfpga_SKP_generator #(
   .SKP_WIDTH       ( 32                ),
   .DATA_BYTES      ( DATA_BYTES        )
   )  SKP_generator_inst (
   .clk             ( clk               ),
   .reset           ( reset             ),
   .sending_data    ( sending_data      ),
   .sending_OS      ( sending_OS        ),
   .sending_IDLE    ( sending_IDLE      ),

   .SKP_in_queue    ( SKP_in_queue      ),
   .txdata          ( txdata_SKP        ),
   .txdatak         ( txdatak_SKP       ),
   .sending_SKP     ( sending_SKP       )
   );

   // Transmitted data multiplexer
   always @(posedge clk or posedge reset) begin
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

endmodule