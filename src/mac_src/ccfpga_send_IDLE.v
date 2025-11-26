//-----------------------------------------------------------------------------
// Description: This module sends IDLE characters when triggered (IDLE = 8'h00)
//=============================================================================

module ccfpga_send_IDLE #(
   parameter IDLE_WIDTH = 8,
   parameter DATA_BYTES = 8,
   parameter DATA_WIDTH = DATA_BYTES * 8
   )
   (
   input wire clk,
   input wire send_IDLE_trigger,
   input wire reset,

   output reg [DATA_WIDTH - 1 : 0] txdata,
   output reg [DATA_BYTES - 1 : 0] txdatak,
   output reg IDLE_sent
   );

   always @ (posedge clk or posedge reset) begin
      if ( reset ) begin
         txdata  <= {DATA_WIDTH{1'b0}};
         txdatak <= {DATA_BYTES{1'b0}};
         IDLE_sent <= 1'b0;
      end else if ( send_IDLE_trigger ) begin
         txdata  <= {DATA_WIDTH{1'b0}};
         txdatak <= {DATA_BYTES{1'b0}};
         IDLE_sent <= 1'b1;
      end else begin
         txdata  <= {DATA_WIDTH{1'b0}};
         txdatak <= {DATA_BYTES{1'b0}};
         IDLE_sent <= 1'b0;
      end
   end

endmodule