////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Interessengruppe fuer Mikroelektronik und Eingebettete Systeme (IMES)
// Fachhochschule Dortmund
//
// Development in cooperation with Cologne Chip AG
//
// Filename     : ccfpga_pipe_mux.v
// Author       : Philipp Leduc
// Tool         :
// Description  : Used in PIPE Logic to mux Rx SerDes (64-Bit) to Rx PIPE (8-,16-Bit).
//                Also includes Control Symbols (K Data) and Error Detection Logic (e.g. RxStatus).
//                Module also contains the additional Control Support Signals (CSS).
//                RX SERDES ---> MUX ---> RX PIPE
// Commentary   : Parameter DATA_BYTES refers to Rx PIPE. Reset is asynchronous.
// Abreviations : [i_] > input (port)
//                [o_] > output (port)
//                [s_] > signal
//                [_n] > low active
//
//
// Changelog:
// -------------------------------------------------------------------------------------------------
// Version | Author             | Date       | Changes
// -------------------------------------------------------------------------------------------------
// 1.0     | Leduc              | 05.06.2021 | released
// -------------------------------------------------------------------------------------------------
// 1.01    | Leduc              | 01.08.2021 | changed reset values for s_msb and s_msb_k
// -------------------------------------------------------------------------------------------------
////////////////////////////////////////////////////////////////////////////////////////////////////

module ccfpga_pipe_rx_mux #(
  parameter DATA_BYTES = 2,                 // Set to configure width of used pipe datapath
  parameter DATA_WIDTH = DATA_BYTES*8       // Used to configure bitwidth of datapath
  )
  (
  input  wire                  i_clk,
  input  wire                  i_reset,
  input  wire                  i_enable,

  input  wire           [ 7:0] i_disp_err,     // Disparity Error (SerDes)
  input  wire           [ 7:0] i_char_is_com,  // Byte is COM symbol    (SerDes)
  input  wire           [ 7:0] i_decode_err,   // Decoding Error 8b/10b (SerDes)
  input  wire           [63:0] i_data,         // Rx  Data (SerDes)
  input  wire           [ 7:0] i_k_data,       // RxK Data (SerDes)

  output wire [DATA_WIDTH-1:0] o_data,         // Rx  Data (PIPE)
  output reg  [DATA_BYTES-1:0] o_k_data,       // RxK Data (PIPE)
  output reg             [2:0] o_rx_status,    // Rx Status Signal (PIPE)
  output reg  [DATA_BYTES-1:0] o_rx_comma,     // Rx Comma Signal (CSS)
  output wire [DATA_BYTES-1:0] o_rx_dec_err,   // Rx Decode Error (CSS)
  output wire [DATA_BYTES-1:0] o_rx_disp_err   // Rx Disparity Error (CSS)
  );


  localparam MSB_INIT   = DATA_WIDTH-1;        // Used to configure the msb data init position
  localparam MSB_INIT_K = DATA_BYTES-1;        // Used to configure the msb k data init position

  reg [DATA_WIDTH-1:0] s_data;
  reg [DATA_BYTES-1:0] s_dec_err;
  reg [DATA_BYTES-1:0] s_disp_err;
  wire                 s_dec_err_flag;
  wire                 s_disp_err_flag;
  reg           [ 5:0] s_msb;                 // Used for partial vector selection of SerDes Port
  reg           [ 2:0] s_msb_k;               // Used for partial vector selection of SerDes Port


  assign s_dec_err_flag  = |s_dec_err;
  assign s_disp_err_flag = |s_disp_err;
  assign o_rx_dec_err    = s_dec_err;
  assign o_rx_disp_err   = s_disp_err;


  // clocked mux for data
  always@(posedge i_clk, posedge i_reset) begin
      if(i_reset == 1'b1) begin
        s_data <= {DATA_WIDTH{1'b0}};
        s_msb  <= 6'd63;
        end
      else begin
        if (i_enable == 1'b1) begin
          s_data = i_data [s_msb -: DATA_WIDTH];
          if (s_msb == 6'd63)
            s_msb <= MSB_INIT;
          else
            s_msb <= s_msb + DATA_WIDTH;
        end
      end
  end

  // clocked mux for k data, comma, error signals
  always@ (posedge i_clk, posedge i_reset) begin
      if(i_reset == 1'b1) begin
        o_k_data   = {DATA_BYTES{1'b0}};
        o_rx_comma = {DATA_BYTES{1'b0}};
        s_dec_err  = {DATA_BYTES{1'b0}};
        s_disp_err = {DATA_BYTES{1'b0}};
        s_msb_k    = 3'd7;
        end
      else begin
        if (i_enable == 1'b1) begin
          o_k_data   = i_k_data [s_msb_k -: DATA_BYTES];
          o_rx_comma = i_char_is_com [s_msb_k -: DATA_BYTES];
          s_dec_err  = i_decode_err [s_msb_k -: DATA_BYTES];
          s_disp_err = i_disp_err [s_msb_k -: DATA_BYTES];

          if (s_msb_k == 3'd7)
            s_msb_k <= MSB_INIT_K;
          else
            s_msb_k <= s_msb_k + DATA_BYTES;
        end
      end
  end

  // logic for setting rx status
  always@* begin
    if (s_dec_err_flag == 1'b1)       // 8b/10b error
      o_rx_status = 3'b100;
    else if (s_disp_err_flag == 1'b1) // Disparity error
      o_rx_status = 3'b111;
    else                              // Data OK (rst value)
      o_rx_status = 3'b000;
  end

 // logic for implementing EDB Symbol (8b/10b Error)
  genvar i;

  generate
    for (i = 0; i < DATA_BYTES ; i = i + 1) begin : gen_block_rx_mux
      localparam integer j = i*8 + 7;
      assign o_data [ j -: 8] = ( s_dec_err[i] == 1'b1 ) ? 8'hFE : s_data [ j -: 8];
    end
  endgenerate


endmodule