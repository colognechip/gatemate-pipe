//----------------------------------------------------------------------------
// Description: This module detects valid data from DLL and sends it out
//============================================================================

module ccfpga_send_data #(
   parameter DATA_BYTES = 8,
   parameter DATA_WIDTH = DATA_BYTES*8
   )
   (
   input wire clk,
   input wire reset,
   input wire L0_enabled,
   input wire [DATA_WIDTH - 1 : 0] txdata_DLL,
   input wire [DATA_BYTES - 1 : 0] txdatak_DLL,

   output reg [DATA_WIDTH - 1 : 0] txdata,
   output reg [DATA_BYTES - 1 : 0] txdatak,
   output reg sending_data
   );

   localparam STP  = 8'hFB; // K27.7
   localparam SDP  = 8'h5C; // K28.2
   localparam _END = 8'hFD; // K29.7
   localparam EDB  = 8'hFE; // K30.7

   reg     in_packet;
   reg     in_packet_next;
   integer i;

   always @ (*) begin
      in_packet_next = in_packet;
      for (i = 0; i < DATA_BYTES; i = i + 1) begin
         if (txdatak_DLL[i]) begin
            if (txdata_DLL[8*i +: 8] == STP || txdata_DLL[8*i +: 8] == SDP)
               in_packet_next = 1'b1;
            else if (txdata_DLL[8*i +: 8] == _END || txdata_DLL[8*i +: 8] == EDB)
               in_packet_next = 1'b0;
         end
      end
   end

   always @ (posedge clk or posedge reset) begin
      if (reset) begin
         txdata       <= { DATA_WIDTH{1'b0} };
         txdatak      <= { DATA_BYTES{1'b0} };
         in_packet    <= 1'b0;
         sending_data <= 1'b0;
      end else if (L0_enabled && (in_packet || |txdatak_DLL)) begin
         txdata       <= txdata_DLL;
         txdatak      <= txdatak_DLL;
         in_packet    <= in_packet_next;
         sending_data <= 1'b1;
      end else begin
         txdata       <= { DATA_WIDTH{1'b0} };
         txdatak      <= { DATA_BYTES{1'b0} };
         in_packet    <= 1'b0;
         sending_data <= 1'b0;
      end
   end
endmodule