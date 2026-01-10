module dllp_assembly #(
    parameter DATA_BYTES       = 8,
    parameter DATA_WIDTH       = DATA_BYTES * 8,
    parameter PATTERN_WIDTH    = 64,
    parameter NUMBER_OF_STEPS  = PATTERN_WIDTH / DATA_WIDTH
)(
    input wire                     clk,                         // Clock
    input wire                     reset,                       // Asynchronous reset
    input wire    [DATA_WIDTH-1:0] rx_data,                     // Received data bytes
    output reg                     SDP_detected,                // SDP detected flag
    output reg [PATTERN_WIDTH-1:0] data_DLLP,                   // Extracted DLLP
    output wire   [DATA_WIDTH-1:0] data_TL                      // Data forwarded to Transaction Layer
);

    // K characters
    localparam  SDP = 8'h5C;

    // Shift registers to store received data for Ordered Set assembly
    reg [DATA_WIDTH - 1 : 0] rx_data_shift [NUMBER_OF_STEPS : 0];
    integer i;

    always @ (posedge clk) begin
        rx_data_shift[0] <= rx_data;
        for ( i = 1; i < NUMBER_OF_STEPS + 1; i = i + 1 ) begin
            rx_data_shift[i] <= rx_data_shift[i - 1];
        end
    end

    generate
        if ( DATA_WIDTH == 64 ) begin
            always @ (posedge clk or posedge reset) begin
                if ( reset ) begin
                    SDP_detected      <= 1'b0;
                    data_DLLP         <= {PATTERN_WIDTH{1'b0}};
                end else if ( rx_data_shift[NUMBER_OF_STEPS][7:0] == SDP ) begin
                    SDP_detected      <= 1'b1;
                    data_DLLP[63:0]   <= rx_data_shift[NUMBER_OF_STEPS];
                end else if (rx_data_shift[NUMBER_OF_STEPS][15:8] == SDP ) begin
                    SDP_detected      <= 1'b1;
                    data_DLLP[55:0]   <= rx_data_shift[NUMBER_OF_STEPS][63:8];
                    data_DLLP[63:56]  <= rx_data_shift[NUMBER_OF_STEPS - 1][7:0];
                end else if (rx_data_shift[NUMBER_OF_STEPS][23:16] == SDP ) begin
                    SDP_detected      <= 1'b1;
                    data_DLLP[47:0]   <= rx_data_shift[NUMBER_OF_STEPS][63:16];
                    data_DLLP[63:48]  <= rx_data_shift[NUMBER_OF_STEPS - 1][15:0];
                end else if (rx_data_shift[NUMBER_OF_STEPS][31:24] == SDP ) begin
                    SDP_detected      <= 1'b1;
                    data_DLLP[39:0]   <= rx_data_shift[NUMBER_OF_STEPS][63:24];
                    data_DLLP[63:40]  <= rx_data_shift[NUMBER_OF_STEPS - 1][23:0];
                end else if (rx_data_shift[NUMBER_OF_STEPS][39:32] == SDP ) begin
                    SDP_detected      <= 1'b1;
                    data_DLLP[31:0]   <= rx_data_shift[NUMBER_OF_STEPS][63:32];
                    data_DLLP[63:32]  <= rx_data_shift[NUMBER_OF_STEPS - 1][31:0];
                end else if (rx_data_shift[NUMBER_OF_STEPS][47:40] == SDP ) begin
                    SDP_detected      <= 1'b1;
                    data_DLLP[23:0]   <= rx_data_shift[NUMBER_OF_STEPS][63:40];
                    data_DLLP[63:24]  <= rx_data_shift[NUMBER_OF_STEPS - 1][39:0];
                end else if (rx_data_shift[NUMBER_OF_STEPS][55:48] == SDP ) begin
                    SDP_detected      <= 1'b1;
                    data_DLLP[15:0]   <= rx_data_shift[NUMBER_OF_STEPS][63:48];
                    data_DLLP[63:16]  <= rx_data_shift[NUMBER_OF_STEPS - 1][47:0];
                end else if (rx_data_shift[NUMBER_OF_STEPS][63:56] == SDP ) begin
                    SDP_detected      <= 1'b1;
                    data_DLLP[7:0]    <= rx_data_shift[NUMBER_OF_STEPS][63:56];
                    data_DLLP[63:8]   <= rx_data_shift[NUMBER_OF_STEPS - 1][55:0];
                end else begin
                    SDP_detected      <= 1'b0;
                    data_DLLP         <= {PATTERN_WIDTH{1'b0}};
                end
            end
        end else if ( DATA_WIDTH == 32 ) begin
            always @ (posedge clk or posedge reset) begin
                if ( reset ) begin
                    SDP_detected      <= 1'b0;
                    data_DLLP         <= {PATTERN_WIDTH{1'b0}};
                end else if ( rx_data_shift[NUMBER_OF_STEPS][7:0] == SDP  ) begin
                    SDP_detected      <= 1'b1;
                    data_DLLP[31:0]   <= rx_data_shift[NUMBER_OF_STEPS];
                    data_DLLP[63:32]  <= rx_data_shift[NUMBER_OF_STEPS - 1];
                end else if (rx_data_shift[NUMBER_OF_STEPS][15:8] == SDP ) begin
                    SDP_detected      <= 1'b1;
                    data_DLLP[23:0]   <= rx_data_shift[NUMBER_OF_STEPS][31:8];
                    data_DLLP[55:24]  <= rx_data_shift[NUMBER_OF_STEPS - 1][31:0];
                    data_DLLP[63:56]  <= rx_data_shift[NUMBER_OF_STEPS - 2][7:0];
                end else if (rx_data_shift[NUMBER_OF_STEPS][23:16] == SDP ) begin
                    SDP_detected      <= 1'b1;
                    data_DLLP[15:0]   <= rx_data_shift[NUMBER_OF_STEPS][31:16];
                    data_DLLP[47:16]  <= rx_data_shift[NUMBER_OF_STEPS - 1][31:0];
                    data_DLLP[63:48]  <= rx_data_shift[NUMBER_OF_STEPS - 2][15:0];
                end else if (rx_data_shift[NUMBER_OF_STEPS][31:24] == SDP ) begin
                    SDP_detected      <= 1'b1;
                    data_DLLP[7:0]    <= rx_data_shift[NUMBER_OF_STEPS][31:24];
                    data_DLLP[39:8]   <= rx_data_shift[NUMBER_OF_STEPS - 1][31:0];
                    data_DLLP[63:40]  <= rx_data_shift[NUMBER_OF_STEPS - 2][23:0];
                end else begin
                    SDP_detected      <= 1'b0;
                    data_DLLP         <= {PATTERN_WIDTH{1'b0}};
                end
            end
        end else if ( DATA_WIDTH == 16 ) begin
            always @ (posedge clk or posedge reset) begin
                if ( reset ) begin
                    SDP_detected      <= 1'b0;
                    data_DLLP         <= {PATTERN_WIDTH{1'b0}};
                end else if ( rx_data_shift[NUMBER_OF_STEPS][7:0] == SDP ) begin
                    SDP_detected      <= 1'b1;
                    data_DLLP[15:0]   <= rx_data_shift[NUMBER_OF_STEPS];
                    data_DLLP[31:16]  <= rx_data_shift[NUMBER_OF_STEPS - 1];
                    data_DLLP[47:32]  <= rx_data_shift[NUMBER_OF_STEPS - 2];
                    data_DLLP[63:48]  <= rx_data_shift[NUMBER_OF_STEPS - 3];
                end else if (rx_data_shift[NUMBER_OF_STEPS][15:8] == SDP ) begin
                    SDP_detected      <= 1'b1;
                    data_DLLP[7:0]    <= rx_data_shift[NUMBER_OF_STEPS][15:8];
                    data_DLLP[23:8]   <= rx_data_shift[NUMBER_OF_STEPS - 1][15:0];
                    data_DLLP[39:24]  <= rx_data_shift[NUMBER_OF_STEPS - 2][15:0];
                    data_DLLP[55:40]  <= rx_data_shift[NUMBER_OF_STEPS - 3][15:0];
                    data_DLLP[63:56]  <= rx_data_shift[NUMBER_OF_STEPS - 4][7:0];
                end else begin
                    SDP_detected      <= 1'b0;
                    data_DLLP         <= {PATTERN_WIDTH{1'b0}};
                end
            end
        end else begin // 8-Bit data width
            always @ (posedge clk or posedge reset) begin
                if ( reset ) begin
                    SDP_detected      <= 1'b0;
                    data_DLLP         <= {PATTERN_WIDTH{1'b0}};
                end else if ( rx_data_shift[NUMBER_OF_STEPS][7:0] == SDP ) begin
                    SDP_detected      <= 1'b1;
                    data_DLLP[7:0]    <= rx_data_shift[NUMBER_OF_STEPS];
                    data_DLLP[15:8]   <= rx_data_shift[NUMBER_OF_STEPS - 1];
                    data_DLLP[23:16]  <= rx_data_shift[NUMBER_OF_STEPS - 2];
                    data_DLLP[31:24]  <= rx_data_shift[NUMBER_OF_STEPS - 3];
                    data_DLLP[39:32]  <= rx_data_shift[NUMBER_OF_STEPS - 4];
                    data_DLLP[47:40]  <= rx_data_shift[NUMBER_OF_STEPS - 5];
                    data_DLLP[55:48]  <= rx_data_shift[NUMBER_OF_STEPS - 6];
                    data_DLLP[63:56]  <= rx_data_shift[NUMBER_OF_STEPS - 7];
                end else begin
                    SDP_detected      <= 1'b0;
                    data_DLLP         <= {PATTERN_WIDTH{1'b0}};
                end
            end
        end
    endgenerate

    // For now, forward the last received data to TL
    assign data_TL = rx_data;

endmodule