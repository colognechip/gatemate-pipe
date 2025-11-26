//----------------------------------------------------------------------------
// Description: This module sends 128-bit Ordered Set, which will be
// transmitted through multiple cycles depending on the DATA_WIDTH
// - OS_sent flag is set at the end for one cycle
//============================================================================

module ccfpga_send_OS #(
   parameter PATTERN_WIDTH = 128,
   parameter PATTERN_BYTES = PATTERN_WIDTH/8,
   parameter DATA_BYTES = 8,
   parameter DATA_WIDTH = DATA_BYTES*8
   )
   (
   input wire clk,
   input wire send_OS_trigger,
   input wire reset,

   input wire [7:0] received_Link,
   input wire [7:0] received_Lane,
   input wire [7:0] received_Ctrl,
   input wire OS_type,          // 0:TS1, 1:TS2

   output reg [DATA_WIDTH - 1 : 0] txdata,
   output reg [DATA_BYTES - 1 : 0] txdatak,
   output reg OS_sent,
   output reg sending_OS
   );

   localparam NUMBER_OF_STEPS = PATTERN_WIDTH / DATA_WIDTH - 1;
   localparam COM  = 8'hBC; // K28.5
   localparam PAD  = 8'hF7; // K23.7

   localparam ID1  = 8'h4A; // D10.2
   localparam ID2  = 8'h45; // D5.2

   wire [PATTERN_WIDTH - 1 : 0] pattern;
   wire [PATTERN_BYTES - 1 : 0] pattern_k;
   wire                         PAD_link;
   wire                         PAD_lane;

   reg [$clog2(NUMBER_OF_STEPS) : 0] step;

   always @ (posedge clk or posedge reset) begin
      if ( reset ) begin
         txdata  <= {DATA_WIDTH{1'b0}};
         txdatak <= {DATA_BYTES{1'b0}};
         OS_sent <= 1'b0;
         step    <= 0;
         sending_OS <= 1'b0;
      end else if (send_OS_trigger == 1'b1) begin
         if ( step != NUMBER_OF_STEPS ) begin
            txdata  <= pattern[DATA_WIDTH * step +: DATA_WIDTH];
            txdatak <= pattern_k[DATA_BYTES * step +: DATA_BYTES];
            OS_sent <= 1'b0;
            sending_OS <= 1'b1;
            step    <= step + 1;
         end else if ( step == NUMBER_OF_STEPS ) begin
            txdata  <= pattern[DATA_WIDTH * step +: DATA_WIDTH];
            txdatak <= pattern_k[DATA_BYTES * step +: DATA_BYTES];
            OS_sent <= 1'b1;
            sending_OS <= 1'b1;
            step    <= 0;
         end
      end else begin
         txdata  <= {DATA_WIDTH{1'b0}};
         txdatak <= {DATA_BYTES{1'b0}};
         OS_sent <= 1'b0;
         sending_OS <= 1'b0;
         step    <= 0;
      end
   end

   assign pattern = OS_type == 1'b0 ? {{10{ID1}}, received_Ctrl, 8'h02, 8'h04, received_Lane, received_Link, COM} :
                                      {{10{ID2}}, received_Ctrl, 8'h02, 8'h04, received_Lane, received_Link, COM};
   assign PAD_link = received_Link == PAD;
   assign PAD_lane = received_Lane == PAD;
   assign pattern_k = {{13'b0}, PAD_lane, PAD_link, 1'b1};

endmodule