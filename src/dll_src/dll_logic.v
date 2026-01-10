module dll_logic #
(
    parameter DATA_BYTES = 8,
    parameter DATA_WIDTH = DATA_BYTES * 8,
    parameter NUMBER_OF_VIRTUAL_CHANNELS = 1,
)
(
    input  wire                         i_clk,
    input  wire                         i_reset,
    input  wire                         i_linkup,
    input  wire        [DATA_WIDTH-1:0] i_rx_data,
    input  wire        [DATA_WIDTH-1:0] i_tx_data_TL,
    input  wire        [DATA_BYTES-1:0] i_tx_data_TL_k,

    output wire        [DATA_WIDTH-1:0] o_txdata,
    output wire        [DATA_BYTES-1:0] o_txdatak,
    output wire        [DATA_WIDTH-1:0] o_rx_data_TL,
    output wire        [DATA_BYTES-1:0] o_rx_data_TL_k
);

    generate
        genvar i;
        for ( i = 0; i < NUMBER_OF_VIRTUAL_CHANNELS; i = i + 1 ) begin
            virtual_channel #(
                .DATA_BYTES (DATA_BYTES),
                .PATTERN_WIDTH (64)
            ) vc_inst (
                .i_clk(i_clk),
                .i_reset(i_reset),
                .i_linkup(i_linkup),
                .i_virtual_channel(i[2:0]),
                .rx_data(i_rx_data), // Direct connection for now
                .tx_data_TL(),
                .tx_data_TL_k(),

                .txdata(o_txdata), // Direct connection for now
                .txdatak(o_txdatak), // Direct connection for now
                .rx_data_TL(),
                .rx_data_TL_k()
            );
        end
    endgenerate

    // TODO: Arbiter to handle multiple virtual channels

endmodule
