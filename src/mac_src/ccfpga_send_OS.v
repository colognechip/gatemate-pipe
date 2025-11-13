// Send 128-bit Ordered Sets, which will be transmitted through multiple cycles depending on the DATA_WIDTH
// OS_sent is set at the end for one cycle
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

   localparam NUMBER_OF_STEPS = PATTERN_WIDTH / DATA_WIDTH;
   localparam COM  = 8'hBC; // K28.5
   localparam PAD  = 8'hF7; // K23.7

   localparam ID1  = 8'h4A; // D10.2
   localparam ID2  = 8'h45; // D5.2

   wire [PATTERN_WIDTH - 1 : 0] pattern;
   wire [PATTERN_BYTES - 1 : 0] pattern_k;

   reg [$clog2(NUMBER_OF_STEPS) : 0] step;

   always @ (posedge clk or posedge reset) begin
      if ( reset ) begin
         txdata  <= {DATA_WIDTH{1'b0}};
         txdatak <= {DATA_BYTES{1'b0}};
         OS_sent <= 1'b0;
         step    <= 0;
         sending_OS <= 1'b0;
      end else if ( send_OS_trigger && (step != NUMBER_OF_STEPS) ) begin
         txdata  <= pattern[DATA_WIDTH * step +: DATA_WIDTH];
         txdatak <= pattern_k[DATA_BYTES * step +: DATA_BYTES];
         OS_sent <= 1'b0;
         sending_OS <= 1'b1;
         step    <= step + 1;
      end else if ( step == NUMBER_OF_STEPS ) begin
         txdata  <= {DATA_WIDTH{1'b0}};
         txdatak <= {DATA_BYTES{1'b0}};
         OS_sent <= 1'b1;
         sending_OS <= 1'b0;
         step    <= 0;
      end else begin
         txdata  <= {DATA_WIDTH{1'b0}};
         txdatak <= {DATA_BYTES{1'b0}};
         OS_sent <= 1'b0;
         sending_OS <= 1'b0;
         step    <= 0;
      end
   end

   assign pattern = OS_type == 1'b0 ? {ID1, ID1, ID1, ID1, ID1, ID1, ID1, ID1, ID1, ID1, received_Ctrl, 8'h02, 8'h00, received_Lane, received_Link, COM} :
                                      {ID2, ID2, ID2, ID2, ID2, ID2, ID2, ID2, ID2, ID2, received_Ctrl, 8'h02, 8'h00, received_Lane, received_Link, COM};
   assign pattern_k = {{15'b0}, 1'b1};

endmodule