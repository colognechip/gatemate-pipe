`timescale 1ns/100fs
// Ref_clk for 64-Bit Datapath is 31.25Mhz -> T = 32ns

module ccfpga_test_fsm #(
   parameter DATA_BYTES = 8,
   parameter DATA_WIDTH = DATA_BYTES*8
   )
   (
   input wire                   i_clk,
   input wire                   i_reset_n,
   input wire                   i_PhyStatus,

   output wire [DATA_WIDTH-1:0] o_TxData,
   output wire [DATA_BYTES-1:0] o_TxDataK,
   output wire                  o_Reset_n,
   output wire            [1:0] o_PowerDown,
   output wire                  o_TxDetectRx,
   output wire                  o_TxElecIdle,
   output wire [DATA_BYTES-1:0] o_TxCompliance,
   output wire                  o_RxPolarity,
   output wire                  o_phy_correct,    // Debug
   output wire                  o_en_rst,         // Debug
   output wire                  o_dis_rst,        // Debug
   output wire                  o_wait_pll,       // Debug
   output wire                  o_word_align,     // Debug
   output wire                  o_send_data_flag  // Debug
   );

   reg                     reset_n;
   reg               [1:0] powerdown;
   reg                     txdetectrx;
   reg                     txelecidle;
   reg    [DATA_BYTES-1:0] txcompliance;
   reg                     rxpolarity;
   reg                     phy_correct;
   reg                     en_rst; //Debug
   reg                     dis_rst; //Debug
   reg                     wait_pll; //Debug
   reg                     word_align; //Debug
   reg                     send_data_flag; //Debug

   reg    [DATA_WIDTH-1:0] txdata;
   reg    [DATA_BYTES-1:0] txdataK;

   assign                  o_Reset_n        = reset_n;
   assign                  o_PowerDown      = powerdown;
   assign                  o_TxDetectRx     = txdetectrx;
   assign                  o_TxElecIdle     = txelecidle;
   assign                  o_TxCompliance   = txcompliance;
   assign                  o_RxPolarity     = rxpolarity;
   assign                  o_phy_correct    = phy_correct;
   assign                  o_en_rst         = en_rst;
   assign                  o_dis_rst        = dis_rst;
   assign                  o_wait_pll       = wait_pll;
   assign                  o_word_align     = word_align;
   assign                  o_send_data_flag = send_data_flag;

   assign                  o_TxData       = txdata;
   assign                  o_TxDataK      = txdataK;

   localparam [3:0]  ENABLE_RESET         = 4'b0000,
                     DISABLE_RESET        = 4'b0001,
                     //REGISTER_WRITE_SEL   = 4'b0010,
                     //REGISTER_WRITE_ADPLL = 4'b0011,
                     WAIT_PLL_LOCK        = 4'b0100,
                     CHECK_PHYSTATUS      = 4'b0101,
                     S1                   = 4'b0110,
                     S2                   = 4'b0111,
                     S3                   = 4'b1000,
                     S4                   = 4'b1001,
                     S5                   = 4'b1010,
                     S6                   = 4'b1011,
                     S7                   = 4'b1100,
                     S8                   = 4'b1101,
                     WORD_ALIGN           = 4'b1110,
                     SEND_DATA            = 4'b1111;

   enum { TS1_FIRST_PART, TS1_SECOND_PART} send_TS1_state;

// Clock Counter
   reg               cnt_reset_wait_reset_done       = 1'b1;
   wire              cnt_flag_wait_reset_done;

   reg               cnt_reset_wait_pll_lock         = 1'b1;
   wire              cnt_flag_wait_pll_lock;

   reg               cnt_reset_state_change          = 1'b1;
   wire              cnt_flag_state_change;

   reg               cnt_reset_TS1_OS                = 1'b1;
   wire              cnt_flag_TS1_OS;

// Wait at least 600ns
   ccfpga_pipe_clk_counter #(
      .BIT_WIDTH (5),
      .CLK_NUMB  (19)
      )
   clk_count_inst_wait_reset_done (
      .i_clk   ( i_clk                           ),
      .i_reset ( cnt_reset_wait_reset_done       ),
      .o_flag  ( cnt_flag_wait_reset_done        )
      );

// Wait 35200ns
   ccfpga_pipe_clk_counter #(
      .BIT_WIDTH (11),
      .CLK_NUMB  (1200)
      )
   clk_count_inst_wait_pll_lock (
      .i_clk   ( i_clk                           ),
      .i_reset ( cnt_reset_wait_pll_lock         ),
      .o_flag  ( cnt_flag_wait_pll_lock          )
      );

// Wait 128ns
   ccfpga_pipe_clk_counter #(
      .BIT_WIDTH (2),
      .CLK_NUMB  (4)
      )
   clk_count_inst_state_change (
      .i_clk   ( i_clk                           ),
      .i_reset ( cnt_reset_state_change          ),
      .o_flag  ( cnt_flag_state_change           )
      );

// Send TS1 OS 1024 times
   ccfpga_pipe_clk_counter #(
      .BIT_WIDTH (11),
      .CLK_NUMB  (2048)
      )
   clk_count_inst_TS1_OS (
      .i_clk   ( i_clk                           ),
      .i_reset ( cnt_reset_TS1_OS                ),
      .o_flag  ( cnt_flag_TS1_OS                 )
      );

// Send TS1
   task send_TS1();
      begin
      case (send_TS1_state)
         TS1_FIRST_PART : begin
            txdata   = 64'h0802_0100_012A_01BC; // TS1 first part
            txdataK  = 8'b0000_0001;
            send_TS1_state <= TS1_SECOND_PART;
         end
         TS1_SECOND_PART : begin
            txdata   = 64'h162B_F45F_238A_0103; // TS1 first part
            txdataK  = 8'b00_00_00_00;
            send_TS1_state <= TS1_FIRST_PART;
         end
      endcase
      end
   endtask

   function [63:0] calcTxData(input integer pos, input comma);
      begin
         if (comma == 1'b1) begin
            calcTxData =
               (pos == 0) ? 64'h4A4A4A4A_4A4A4ABC :
               (pos == 1) ? 64'h4A4A4A4A_4A4ABC4A :
               (pos == 2) ? 64'h4A4A4A4A_4ABC4A4A :
               (pos == 3) ? 64'h4A4A4A4A_BC4A4A4A :
               (pos == 4) ? 64'h4A4A4ABC_4A4A4A4A :
               (pos == 5) ? 64'h4A4ABC4A_4A4A4A4A :
               (pos == 6) ? 64'h4ABC4A4A_4A4A4A4A : 64'hBC4A4A4A_4A4A4A4A;
         end
      else begin
            calcTxData =
               (pos == 0) ? 64'h08070605_04030201 :
               (pos == 1) ? 64'h07060504_03020108 :
               (pos == 2) ? 64'h06050403_02010807 :
               (pos == 3) ? 64'h05040302_01080706 :
               (pos == 4) ? 64'h04030201_08070605 :
               (pos == 5) ? 64'h03020108_07060504 :
               (pos == 6) ? 64'h02010807_06050403 : 64'h01080706_05040302;
         end
      end
   endfunction

   function [7:0] calcTxK(input integer pos, input comma);
      begin
         if (comma == 1'b1) begin
            calcTxK =
               (comma_pos == 0) ? 8'b0000_0001 :
               (comma_pos == 1) ? 8'b0000_0010 :
               (comma_pos == 2) ? 8'b0000_0100 :
               (comma_pos == 3) ? 8'b0000_1000 :
               (comma_pos == 4) ? 8'b0001_0000 :
               (comma_pos == 5) ? 8'b0010_0000 :
               (comma_pos == 6) ? 8'b0100_0000 : 8'b1000_0000;
         end
         else begin
            calcTxK = 8'b0000_0000;
         end
      end
   endfunction

   parameter K_POS = 0;
// Send Data
   task send_data();
      begin
         txdata  <= calcTxData(K_POS, 1'b1);
         txdataK <= calcTxK(K_POS, 1'b1);
      end
   endtask

// FSM
   reg  [3:0] s_state;
   wire [3:0] s_next_state;

   //State Register
   always @(posedge i_clk, negedge i_reset_n) begin
      if (!i_reset_n)
         s_state <= ENABLE_RESET;
      else 
         s_state <= s_next_state;
   end

//-------------Transition logic-------------------
   always @(*) begin
      case(s_state)
         ENABLE_RESET : begin
            s_next_state = DISABLE_RESET;
         end
         DISABLE_RESET : begin
            if ( cnt_flag_wait_reset_done == 1'b1)
               s_next_state = WAIT_PLL_LOCK;
         end
         WAIT_PLL_LOCK : begin
            if ( cnt_flag_wait_pll_lock == 1'b1)
               s_next_state = CHECK_PHYSTATUS;
         end
         CHECK_PHYSTATUS : begin
            s_next_state = S1;
         end
         S1 : begin
            if ( cnt_flag_state_change == 1'b1) begin
               s_next_state = S2;
            end
         end
         S2 : begin
            if ( cnt_flag_state_change == 1'b1) begin
               s_next_state = S3;
            end
         end
         S3 : begin
            if ( cnt_flag_state_change == 1'b1) begin
               s_next_state = S4;
            end
         end
         S4 : begin
            if ( cnt_flag_state_change == 1'b1) begin
               s_next_state = S5;
            end
         end
         S5 : begin
            if ( cnt_flag_state_change == 1'b1) begin
               s_next_state = S6;
            end
         end
         S6 : begin
            if ( cnt_flag_state_change == 1'b1) begin
               s_next_state = S7;
            end
         end
         S7 : begin
            if ( cnt_flag_state_change == 1'b1) begin
               s_next_state = S8;
            end
         end
         S8 : begin
            if ( cnt_flag_state_change == 1'b1) begin
               s_next_state = WORD_ALIGN;
            end
         end
         WORD_ALIGN : begin
            if ( cnt_flag_TS1_OS == 1'b1) begin
               s_next_state = SEND_DATA;
            end
         end
         SEND_DATA : begin
               s_next_state = SEND_DATA;
         end
         default : s_next_state = ENABLE_RESET;
      endcase
   end
   //   end
   //endfunction
//-------------Function end--------------------

   //Output logic
   always @(posedge i_clk) begin
      case(s_state)
         ENABLE_RESET : begin
            reset_n      <= 1'b0;
            powerdown    <= 2'b10;
            txdetectrx   <= 1'b0;
            txelecidle   <= 1'b1;
            txcompliance <= {DATA_BYTES{1'b0}};
            rxpolarity   <= 1'b0;
            txdata       <= {DATA_WIDTH{1'b0}};
            txdataK      <= {DATA_BYTES{1'b0}};
            en_rst       <= 1'b0;
         end
         DISABLE_RESET : begin
            reset_n      <= 1'b1;
            cnt_reset_wait_reset_done <= 1'b0;
            dis_rst      <= 1'b0;
         end
         /*REGISTER_WRITE_SEL : begin
            resgister_write(8'h50, 16'h0002, 16'h0007);
         end
         REGISTER_WRITE_ADPLL : begin
            resgister_write(8'h50, 16'h0003, 16'h0003);
         end*/
         WAIT_PLL_LOCK : begin
            cnt_reset_wait_pll_lock <= 1'b0;
            wait_pll                <= 1'b0;
         end
         CHECK_PHYSTATUS : begin
            if (i_PhyStatus == 1'b0)
               phy_correct <= 1'b0;
            else
               phy_correct <= 1'b1;
         end
         S1 : begin
            powerdown    <= 2'b00;
            txdetectrx   <= 1'b0;
            txelecidle   <= 1'b1;
            txcompliance <= {DATA_BYTES{1'b0}};
            rxpolarity   <= 1'b0;
            txdata       <= {DATA_WIDTH{1'b0}};
            txdataK      <= {DATA_BYTES{1'b0}};
            if ( cnt_flag_state_change == 1'b1)
               cnt_reset_state_change <= 1'b1;
            else
               cnt_reset_state_change <= 1'b0;
         end
         S2 : begin
            powerdown    <= 2'b10;
            txdetectrx   <= 1'b0;
            txelecidle   <= 1'b1;
            txcompliance <= {DATA_BYTES{1'b0}};
            rxpolarity   <= 1'b0;
            txdata       <= {DATA_WIDTH{1'b0}};
            txdataK      <= {DATA_BYTES{1'b0}};
            if ( cnt_flag_state_change == 1'b1)
               cnt_reset_state_change <= 1'b1;
            else
               cnt_reset_state_change <= 1'b0;
         end
         S3 : begin
            powerdown    <= 2'b00;
            txdetectrx   <= 1'b0;
            txelecidle   <= 1'b0;
            txcompliance <= {DATA_BYTES{1'b0}};
            rxpolarity   <= 1'b0;
            txdata       <= {DATA_WIDTH{1'b0}};
            txdataK      <= {DATA_BYTES{1'b0}};
            if ( cnt_flag_state_change == 1'b1)
               cnt_reset_state_change <= 1'b1;
            else
               cnt_reset_state_change <= 1'b0;
         end
         S4 : begin
            powerdown    <= 2'b10;
            txdetectrx   <= 1'b0;
            txelecidle   <= 1'b1;
            txcompliance <= {DATA_BYTES{1'b0}};
            rxpolarity   <= 1'b0;
            txdata       <= {DATA_WIDTH{1'b0}};
            txdataK      <= {DATA_BYTES{1'b0}};
            if ( cnt_flag_state_change == 1'b1)
               cnt_reset_state_change <= 1'b1;
            else
               cnt_reset_state_change <= 1'b0;
         end
         S5 : begin
            powerdown    <= 2'b00;
            txdetectrx   <= 1'b1;
            txelecidle   <= 1'b0;
            txcompliance <= {DATA_BYTES{1'b0}};
            rxpolarity   <= 1'b0;
            txdata       <= {DATA_WIDTH{1'b0}};
            txdataK      <= {DATA_BYTES{1'b0}};
            if ( cnt_flag_state_change == 1'b1)
               cnt_reset_state_change <= 1'b1;
            else
               cnt_reset_state_change <= 1'b0;
         end
         S6 : begin
            powerdown    <= 2'b10;
            txdetectrx   <= 1'b0;
            txelecidle   <= 1'b1;
            txcompliance <= {DATA_BYTES{1'b0}};
            rxpolarity   <= 1'b0;
            txdata       <= {DATA_WIDTH{1'b0}};
            txdataK      <= {DATA_BYTES{1'b0}};
            if ( cnt_flag_state_change == 1'b1)
               cnt_reset_state_change <= 1'b1;
            else
               cnt_reset_state_change <= 1'b0;
         end
         S7 : begin
            powerdown    <= 2'b00;
            txdetectrx   <= 1'b0;
            txelecidle   <= 1'b1;
            txcompliance <= {DATA_BYTES{1'b0}};
            rxpolarity   <= 1'b0;
            txdata       <= {DATA_WIDTH{1'b0}};
            txdataK      <= {DATA_BYTES{1'b0}};
            if ( cnt_flag_state_change == 1'b1)
               cnt_reset_state_change <= 1'b1;
            else
               cnt_reset_state_change <= 1'b0;
         end
         S8 : begin
            powerdown    <= 2'b00;
            txdetectrx   <= 1'b0;
            txelecidle   <= 1'b0;
            txcompliance <= {DATA_BYTES{1'b0}};
            rxpolarity   <= 1'b0;
            txdata       <= {DATA_WIDTH{1'b0}};
            txdataK      <= {DATA_BYTES{1'b0}};
            if ( cnt_flag_state_change == 1'b1)
               cnt_reset_state_change <= 1'b1;
            else
               cnt_reset_state_change <= 1'b0;
         end
         WORD_ALIGN : begin
            word_align   <= 1'b0;
            send_TS1();
         end
         SEND_DATA : begin
            send_data_flag    <= 1'b0;
            send_data();
         end
      endcase
   end
endmodule