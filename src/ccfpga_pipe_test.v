`timescale 1ns/100fs

module ccfpga_pipe_test #(
   parameter DATA_BYTES = 8,
   parameter DATA_WIDTH = DATA_BYTES*8
   )
   (
   input wire                   clk_ref,
   input wire                   i_trx_rstn,
   input wire                   i_pll_rstn,
// Debug
   output wire                  o_LED1,
   output wire                  o_LED2,
   output wire                  o_LED3,
   output wire                  o_LED4,
   output wire                  o_LED5,
   output wire                  o_LED6
   );

   wire                  i_Reset_n;
   wire            [1:0] i_PowerDown;
   wire                  i_TxDetectRx;
   wire                  i_TxElecIdle;
   wire [DATA_BYTES-1:0] i_TxCompliance;
   wire                  i_RxPolarity;
   wire [DATA_WIDTH-1:0] i_TxData;
   wire [DATA_BYTES-1:0] i_TxDataK;

   wire                  o_PCLK;
   wire [DATA_WIDTH-1:0] o_RxData;
   wire [DATA_BYTES-1:0] o_RxDataK;
   wire                  o_RxValid;
   wire                  o_PhyStatus;
   wire            [2:0] o_RxStatus;
   wire                  o_RxElecIdle;

// reset
   reg [8:0] rst_cnt = 0;
   wire rstn = &rst_cnt;
   wire rst = !rstn;

   always @(posedge ref_clk) begin
      rst_cnt <= rst_cnt + !rstn;
   end

   wire i_trx_rst = ~i_trx_rstn | rst;
   wire i_pll_rst = ~i_pll_rstn | rst;
   wire fsm_rstn  =  i_pll_rstn & rstn;

   ccfpga_pipe_wrapper #(
      .DATA_BYTES ( DATA_BYTES )
   )
   ccfpga_pipe_wrapper_inst (
      .i_Reset_n             ( i_Reset_n),      // Asyn. Reset
      .i_PowerDown           ( i_PowerDown),    // Power states
      .i_TxDetectRx          ( i_TxDetectRx),   // Receiver Detection (P1)/Loopback (P0)
      .i_TxElecIdle          ( i_TxElecIdle),   // Electrical Idle
      .i_TxCompliance        ( i_TxCompliance), // Compliance Pattern
      .i_RxPolarity          ( i_RxPolarity),   // Received data polarity
      .i_TxData              ( i_TxData),       // Tx Data
      .i_TxDataK             ( i_TxDataK),      // Tx K Data
      //.i_TxSwing             ( i_TxSwing),      // Tx Voltage Swing Level [Optional by Spec]

      .o_PCLK                ( o_PCLK),         // Parallel Interface Clock
      .o_RxValid             ( o_RxValid),      // Received data is valid
      .o_PhyStatus           ( o_PhyStatus),    // Physical Status
      .o_RxStatus            ( o_RxStatus),     // Receiver Status
      .o_RxElecIdle          ( o_RxElecIdle),   // Electrical Idle at Receiver
      .o_RxData              ( o_RxData),       // Rx Data
      .o_RxDataK             ( o_RxDataK)       // Rx K Data
   );

   ccfpga_test_fsm #(
      .DATA_BYTES ( DATA_BYTES )
   )
   ccfpga_test_fsm_inst (
      .i_clk                 ( o_PCLK           ),
      .i_reset_n             ( fsm_rstn         ),
      .i_PhyStatus           ( o_PhyStatus      ),

      .o_TxData              ( i_TxData         ),
      .o_TxDataK             ( i_TxDataK        ),
      .o_Reset_n             ( i_Reset_n        ),
      .o_PowerDown           ( i_PowerDown      ),
      .o_TxDetectRx          ( i_TxDetectRx     ),
      .o_TxElecIdle          ( i_TxElecIdle     ),
      .o_TxCompliance        ( i_TxCompliance   ),
      .o_RxPolarity          ( i_RxPolarity     ),
      .o_phy_correct         ( o_LED4           ), //Debug
      .o_en_rst              ( o_LED1           ), //Debug
      .o_dis_rst             ( o_LED2           ), //Debug
      .o_wait_pll            ( o_LED3           ), //Debug
      .o_word_align          ( o_LED5           ), //Debug
      .o_send_data_flag      ( o_LED6           )  //Debug
   );

endmodule
