//----------------------------------------------------------------------------------------
// Description: This module handles the Rx MAC data forwarding to DLL
// - Forwards received data to DLL when STP or SDP is detected
// - Stops forwarding when END is detected
// - No alignment support for now
//========================================================================================

module ccfpga_rx_MAC_data #(
    parameter DATA_BYTES        = 8,
    parameter DATA_WIDTH        = DATA_BYTES * 8,
    parameter NUMBER_OF_STEPS   = 4
)(
    input wire                       clk,                                 // Clock
    input wire                       L0_enabled,                          // L0 state enable signal
    input wire  [DATA_WIDTH - 1 : 0] rx_data,                             // Rx Data

    output reg  [DATA_WIDTH - 1 : 0] rx_data_DLL,                         // Data forwarded to DLL
    output reg  [DATA_BYTES - 1 : 0] rx_dataK_DLL                         // K-character indicators for DLL
);

    localparam STP  = 8'hFB; // K27.7
    localparam SDP  = 8'h5C; // K28.2
    localparam _END = 8'hFD; // K29.7

    wire    [DATA_BYTES - 1 : 0] char_is_K;       // STP or SDP detected in received data
    wire    [DATA_BYTES - 1 : 0] char_is_END;     // END detected in received data
    wire                         K_detected;      // STP or SDP detected flag
    wire                         END_detected;    // END detected flag

    reg                          receiving_data;  // Data receiving flag for DLL (needed??)

// Forwarding data to DLL when STP or SDP detected
// Stop when END detected
// No alignment support for now - the whole datapath is forwarded
    always @ (posedge clk) begin
        if (L0_enabled == 1'b0) begin
            receiving_data <= 1'b0;
            rx_data_DLL    <= { DATA_WIDTH{1'b0} };
            rx_dataK_DLL  <= { DATA_BYTES{1'b0} };
        end else begin
            if (K_detected) begin
                receiving_data <= 1'b1;
                rx_data_DLL    <= rx_data;
                rx_dataK_DLL  <= char_is_K;
            end else if (END_detected) begin
                receiving_data <= 1'b0;
                rx_data_DLL    <= rx_data;
                rx_dataK_DLL  <= char_is_END;
            end else if (receiving_data == 1'b1) begin
                receiving_data <= 1'b1;
                rx_data_DLL    <= rx_data;
                rx_dataK_DLL  <= { DATA_BYTES{1'b0} };
            end else begin
                receiving_data <= 1'b0;
                rx_data_DLL    <= { DATA_WIDTH{1'b0} };
                rx_dataK_DLL  <= { DATA_BYTES{1'b0} };
            end
        end
    end

    // Detection of special characters (STP, SDP or END) in all symbol positions
    generate
        genvar j;
        for (j = 0; j < DATA_BYTES; j = j + 1) begin
            assign char_is_K[j]   = (rx_data[8*j +: 8] == STP) || (rx_data[8*j +: 8] == SDP);
            assign char_is_END[j] = (rx_data[8*j +: 8] == _END);
        end
    endgenerate

    // Detection flags
    assign K_detected   = |char_is_K;
    assign END_detected = |char_is_END;

endmodule