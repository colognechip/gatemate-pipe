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
   input wire SKP_in_queue,

   output reg [DATA_WIDTH - 1 : 0] txdata,
   output reg [DATA_BYTES - 1 : 0] txdatak,
   output reg IDLE_sent,
   output reg sending_IDLE
   );

   reg SKP_in_queue_reg;

   always @ (posedge clk or posedge reset) begin
      if ( reset ) begin
         txdata  <= {DATA_WIDTH{1'b0}};
         txdatak <= {DATA_BYTES{1'b0}};
         IDLE_sent <= 1'b0;
         SKP_in_queue_reg <= 1'b0;
         sending_IDLE <= 1'b0;
      end else if ( send_IDLE_trigger && SKP_in_queue_reg == 1'b0) begin
         txdata  <= {DATA_WIDTH{1'b0}};
         txdatak <= {DATA_BYTES{1'b0}};
         IDLE_sent <= 1'b1;
         sending_IDLE <= 1'b1;
         if (SKP_in_queue == 1'b1) begin
            SKP_in_queue_reg <= 1'b1;
         end else begin
            SKP_in_queue_reg <= SKP_in_queue_reg;
         end
      end else begin
         txdata  <= {DATA_WIDTH{1'b0}};
         txdatak <= {DATA_BYTES{1'b0}};
         IDLE_sent <= 1'b0;
         sending_IDLE <= 1'b0;
         if (SKP_in_queue == 1'b0) begin
            SKP_in_queue_reg <= 1'b0;
         end else begin
            SKP_in_queue_reg <= SKP_in_queue_reg;
         end
      end
   end

endmodule