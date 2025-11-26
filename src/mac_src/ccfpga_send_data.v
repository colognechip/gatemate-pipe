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

   output reg [DATA_WIDTH - 1 : 0] txdata,
   output reg [DATA_BYTES - 1 : 0] txdatak,
   output reg sending_data
   );

   localparam COM  = 8'hBC; // K28.5
   localparam STP  = 8'hFB; // K27.7
   localparam SDP  = 8'h5C; // K28.2
   localparam _END = 8'hFD; // K29.7
   localparam EDB  = 8'hFE; // K30.7
   localparam PAD  = 8'hF7; // K23.7

   wire K_detected;
   wire [DATA_BYTES - 1 : 0] char_is_K;
   wire END_detected;
   wire [DATA_BYTES - 1 : 0] char_is_END;
   wire [DATA_BYTES - 1 : 0] txdatak_reg;

   reg send_data_trigger;

   always @ (posedge clk or posedge reset) begin
      if (reset) begin
         txdata  <= { DATA_WIDTH{1'b0} };
         txdatak <= { DATA_BYTES{1'b0} };
         send_data_trigger <= 1'b0;
         sending_data <= 1'b0;
      end else if (L0_enabled == 1'b1) begin
         if (K_detected) begin
            txdata  <= txdata_DLL;
            txdatak <= txdatak_reg;
            send_data_trigger <= 1'b1;
            sending_data <= 1'b1;
         end else if (END_detected) begin
            txdata  <= txdata_DLL;
            txdatak <= txdatak_reg;
            send_data_trigger <= 1'b0;
            sending_data <= 1'b1;
         end else if (send_data_trigger == 1'b1) begin
            txdata  <= txdata_DLL;
            txdatak <= txdatak_reg;
            send_data_trigger <= 1'b1;
            sending_data <= 1'b1;
         end else begin
            txdata  <= { DATA_WIDTH{1'b0} };
            txdatak <= { DATA_BYTES{1'b0} };
            send_data_trigger <= 1'b0;
            sending_data <= 1'b0;
         end
      end else begin
         txdata  <= { DATA_WIDTH{1'b0} };
         txdatak <= { DATA_BYTES{1'b0} };
         send_data_trigger <= 1'b0;
         sending_data <= 1'b0;
      end
   end

   // Detect special characters (STP, SDP or END) in all symbol positions
   generate
      genvar i;
      for (i = 0; i < DATA_BYTES; i = i + 1) begin
         assign char_is_K[i] = (txdata_DLL[8*i +: 8] == STP) || (txdata_DLL[8*i +: 8] == SDP);
         assign char_is_END[i] = (txdata_DLL[8*i +: 8] == _END);
         assign txdatak_reg[i] = char_is_K[i] || char_is_END[i];
      end
   endgenerate

   assign K_detected = |char_is_K;
   assign END_detected = |char_is_END;
endmodule