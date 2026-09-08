//----------------------------------------------------------------------------------------
// Description: This module assembles the received data bytes into patterns
// - COM detected, start assembling the Ordered Set
// - New COM arrival before completing the Ordered Set resets the assembly
// - Completion of Ordered Set assembly resets the assembly
// - Forward the last received data to DLL
//========================================================================================

module ccfpga_data_assembly #(
    parameter DATA_BYTES       = 8,
    parameter DATA_WIDTH       = DATA_BYTES * 8,
    parameter PATTERN_WIDTH    = 128,
    parameter NUMBER_OF_STEPS  = 2
)(
    input wire                     clk,                         // Clock
    input wire                     reset,                       // Asynchronous reset
    input wire    [DATA_WIDTH-1:0] rx_data,                     // Received data bytes
    output reg                     COM_detected,                // COM detected flag
    output reg [PATTERN_WIDTH-1:0] data_OS,                     // Extracted Ordered Set data
    output reg    [DATA_WIDTH-1:0] data_DLL                     // Data forwarded to DLL
);

    // K characters
    localparam COM = 8'hBC;
    localparam SKP = 8'h1C;

    // Shift registers to store received data for Ordered Set assembly
    reg [DATA_WIDTH - 1 : 0] rx_data_shift [NUMBER_OF_STEPS : 0];
    integer i;

    always @ (posedge clk) begin
        rx_data_shift[0] <= rx_data;
        for ( i = 1; i < NUMBER_OF_STEPS + 1; i = i + 1 ) begin
            rx_data_shift[i] <= rx_data_shift[i - 1];
        end
    end

    // Note: this design is a bit overkilled as the current SerDes setup aligns the COM
    // to the first or the fifth byte for 64 bit data width and always to the first byte for 32 bit or narrower.
    // However, this design can handle any COM position and is more robust to potential future changes in SerDes alignment.

    generate
        if ( DATA_WIDTH == 64 ) begin
            always @ (posedge clk or posedge reset) begin
                if ( reset ) begin
                    data_DLL        <= {DATA_WIDTH{1'b0}};
                    COM_detected    <= 1'b0;
                    data_OS         <= {PATTERN_WIDTH{1'b0}};
                end else if ( rx_data_shift[NUMBER_OF_STEPS][7:0] == COM ) begin
                    data_DLL        <= {DATA_WIDTH{1'b0}};
                    if ( rx_data_shift[NUMBER_OF_STEPS][15:8] == SKP ) begin
                        COM_detected       <= 1'b0;
                        data_OS            <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected       <= 1'b1;
                        data_OS[63:0]      <= rx_data_shift[NUMBER_OF_STEPS];
                        data_OS[127:64]    <= rx_data_shift[NUMBER_OF_STEPS - 1];
                    end
                end else if (rx_data_shift[NUMBER_OF_STEPS][15:8] == COM ) begin
                    data_DLL        <= {DATA_WIDTH{1'b0}};
                    if ( rx_data_shift[NUMBER_OF_STEPS][23:16] == SKP ) begin
                        COM_detected       <= 1'b0;
                        data_OS            <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected       <= 1'b1;
                        data_OS[55:0]      <= rx_data_shift[NUMBER_OF_STEPS][63:8];
                        data_OS[119:56]    <= rx_data_shift[NUMBER_OF_STEPS - 1][63:0];
                        data_OS[127:120]   <= rx_data_shift[NUMBER_OF_STEPS - 2][7:0];
                    end
                end else if (rx_data_shift[NUMBER_OF_STEPS][23:16] == COM ) begin
                    data_DLL        <= {DATA_WIDTH{1'b0}};
                    if ( rx_data_shift[NUMBER_OF_STEPS][31:24] == SKP ) begin
                        COM_detected       <= 1'b0;
                        data_OS            <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected       <= 1'b1;
                        data_OS[47:0]      <= rx_data_shift[NUMBER_OF_STEPS][63:16];
                        data_OS[111:48]    <= rx_data_shift[NUMBER_OF_STEPS - 1][63:0];
                        data_OS[127:112]   <= rx_data_shift[NUMBER_OF_STEPS - 2][15:0];
                    end
                end else if (rx_data_shift[NUMBER_OF_STEPS][31:24] == COM ) begin
                    data_DLL        <= {DATA_WIDTH{1'b0}};
                    if ( rx_data_shift[NUMBER_OF_STEPS][39:32] == SKP ) begin
                        COM_detected       <= 1'b0;
                        data_OS            <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected       <= 1'b1;
                        data_OS[39:0]      <= rx_data_shift[NUMBER_OF_STEPS][63:24];
                        data_OS[103:40]    <= rx_data_shift[NUMBER_OF_STEPS - 1][63:0];
                        data_OS[127:104]   <= rx_data_shift[NUMBER_OF_STEPS - 2][23:0];
                    end
                end else if (rx_data_shift[NUMBER_OF_STEPS][39:32] == COM ) begin
                    data_DLL        <= {DATA_WIDTH{1'b0}};
                    if ( rx_data_shift[NUMBER_OF_STEPS][47:40] == SKP ) begin
                        COM_detected       <= 1'b0;
                        data_OS            <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected       <= 1'b1;
                        data_OS[31:0]      <= rx_data_shift[NUMBER_OF_STEPS][63:32];
                        data_OS[95:32]     <= rx_data_shift[NUMBER_OF_STEPS - 1][63:0];
                        data_OS[127:96]    <= rx_data_shift[NUMBER_OF_STEPS - 2][31:0];
                    end
                end else if (rx_data_shift[NUMBER_OF_STEPS][47:40] == COM ) begin
                    data_DLL        <= {DATA_WIDTH{1'b0}};
                    if ( rx_data_shift[NUMBER_OF_STEPS][55:48] == SKP ) begin
                        COM_detected       <= 1'b0;
                        data_OS            <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected       <= 1'b1;
                        data_OS[23:0]      <= rx_data_shift[NUMBER_OF_STEPS][63:40];
                        data_OS[87:24]     <= rx_data_shift[NUMBER_OF_STEPS - 1][63:0];
                        data_OS[127:88]    <= rx_data_shift[NUMBER_OF_STEPS - 2][39:0];
                    end
                end else if (rx_data_shift[NUMBER_OF_STEPS][55:48] == COM ) begin
                    data_DLL        <= {DATA_WIDTH{1'b0}};
                    if ( rx_data_shift[NUMBER_OF_STEPS][63:56] == SKP ) begin
                        COM_detected       <= 1'b0;
                        data_OS            <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected       <= 1'b1;
                        data_OS[15:0]      <= rx_data_shift[NUMBER_OF_STEPS][63:48];
                        data_OS[79:16]     <= rx_data_shift[NUMBER_OF_STEPS - 1][63:0];
                        data_OS[127:80]    <= rx_data_shift[NUMBER_OF_STEPS - 2][47:0];
                    end
                end else if (rx_data_shift[NUMBER_OF_STEPS][63:56] == COM ) begin
                    data_DLL        <= {DATA_WIDTH{1'b0}};
                    if ( rx_data_shift[NUMBER_OF_STEPS - 1][7:0] == SKP ) begin
                        COM_detected       <= 1'b0;
                        data_OS            <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected       <= 1'b1;
                        data_OS[7:0]       <= rx_data_shift[NUMBER_OF_STEPS][63:56];
                        data_OS[71:8]      <= rx_data_shift[NUMBER_OF_STEPS - 1][63:0];
                        data_OS[127:72]    <= rx_data_shift[NUMBER_OF_STEPS - 2][55:0];
                    end
                end else begin
                    data_DLL        <= rx_data_shift[NUMBER_OF_STEPS];
                    COM_detected    <= 1'b0;
                    data_OS         <= {PATTERN_WIDTH{1'b0}};
                end
            end
        end else if ( DATA_WIDTH == 32 ) begin
            always @ (posedge clk or posedge reset) begin
                if ( reset ) begin
                    data_DLL        <= {DATA_WIDTH{1'b0}};
                    COM_detected    <= 1'b0;
                    data_OS         <= {PATTERN_WIDTH{1'b0}};
                end else if ( rx_data_shift[NUMBER_OF_STEPS][7:0] == COM ) begin
                    data_DLL        <= {DATA_WIDTH{1'b0}};
                    if ( rx_data_shift[NUMBER_OF_STEPS][15:8] == SKP ) begin
                        COM_detected       <= 1'b0;
                        data_OS            <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected       <= 1'b1;
                        data_OS[31:0]      <= rx_data_shift[NUMBER_OF_STEPS];
                        data_OS[63:32]     <= rx_data_shift[NUMBER_OF_STEPS - 1];
                        data_OS[95:64]     <= rx_data_shift[NUMBER_OF_STEPS - 2];
                        data_OS[127:96]    <= rx_data_shift[NUMBER_OF_STEPS - 3];
                    end
                end else if (rx_data_shift[NUMBER_OF_STEPS][15:8] == COM ) begin
                    data_DLL        <= {DATA_WIDTH{1'b0}};
                    if ( rx_data_shift[NUMBER_OF_STEPS][23:16] == SKP ) begin
                        COM_detected       <= 1'b0;
                        data_OS            <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected       <= 1'b1;
                        data_OS[23:0]      <= rx_data_shift[NUMBER_OF_STEPS][31:8];
                        data_OS[55:24]     <= rx_data_shift[NUMBER_OF_STEPS - 1][31:0];
                        data_OS[87:56]     <= rx_data_shift[NUMBER_OF_STEPS - 2][31:0];
                        data_OS[119:88]    <= rx_data_shift[NUMBER_OF_STEPS - 3][31:0];
                        data_OS[127:120]   <= rx_data_shift[NUMBER_OF_STEPS - 4][7:0];
                    end
                end else if (rx_data_shift[NUMBER_OF_STEPS][23:16] == COM ) begin
                    data_DLL        <= {DATA_WIDTH{1'b0}};
                    if ( rx_data_shift[NUMBER_OF_STEPS][31:24] == SKP ) begin
                        COM_detected       <= 1'b0;
                        data_OS            <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected       <= 1'b1;
                        data_OS[15:0]      <= rx_data_shift[NUMBER_OF_STEPS][31:16];
                        data_OS[47:16]     <= rx_data_shift[NUMBER_OF_STEPS - 1][31:0];
                        data_OS[79:48]     <= rx_data_shift[NUMBER_OF_STEPS - 2][31:0];
                        data_OS[111:80]    <= rx_data_shift[NUMBER_OF_STEPS - 3][31:0];
                        data_OS[127:112]   <= rx_data_shift[NUMBER_OF_STEPS - 4][15:0];
                    end
                end else if (rx_data_shift[NUMBER_OF_STEPS][31:24] == COM ) begin
                    data_DLL        <= {DATA_WIDTH{1'b0}};
                    if ( rx_data_shift[NUMBER_OF_STEPS - 1][7:0] == SKP ) begin
                        COM_detected       <= 1'b0;
                        data_OS            <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected       <= 1'b1;
                        data_OS[7:0]       <= rx_data_shift[NUMBER_OF_STEPS][31:24];
                        data_OS[39:8]      <= rx_data_shift[NUMBER_OF_STEPS - 1][31:0];
                        data_OS[71:40]     <= rx_data_shift[NUMBER_OF_STEPS - 2][31:0];
                        data_OS[103:72]    <= rx_data_shift[NUMBER_OF_STEPS - 3][31:0];
                        data_OS[127:104]   <= rx_data_shift[NUMBER_OF_STEPS - 4][23:0];
                    end
                end else begin
                    data_DLL        <= rx_data_shift[NUMBER_OF_STEPS];
                    COM_detected    <= 1'b0;
                    data_OS         <= {PATTERN_WIDTH{1'b0}};
                end
            end
        end else if ( DATA_WIDTH == 16 ) begin
            always @ (posedge clk or posedge reset) begin
                if ( reset ) begin
                    data_DLL        <= {DATA_WIDTH{1'b0}};
                    COM_detected    <= 1'b0;
                    data_OS         <= {PATTERN_WIDTH{1'b0}};
                end else if ( rx_data_shift[NUMBER_OF_STEPS][7:0] == COM ) begin
                    data_DLL        <= {DATA_WIDTH{1'b0}};
                    if ( rx_data_shift[NUMBER_OF_STEPS][15:8] == SKP ) begin
                        COM_detected    <= 1'b0;
                        data_OS         <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected       <= 1'b1;
                        data_OS[15:0]      <= rx_data_shift[NUMBER_OF_STEPS];
                        data_OS[31:16]     <= rx_data_shift[NUMBER_OF_STEPS - 1];
                        data_OS[47:32]     <= rx_data_shift[NUMBER_OF_STEPS - 2];
                        data_OS[63:48]     <= rx_data_shift[NUMBER_OF_STEPS - 3];
                        data_OS[79:64]     <= rx_data_shift[NUMBER_OF_STEPS - 4];
                        data_OS[95:80]     <= rx_data_shift[NUMBER_OF_STEPS - 5];
                        data_OS[111:96]    <= rx_data_shift[NUMBER_OF_STEPS - 6];
                        data_OS[127:112]   <= rx_data_shift[NUMBER_OF_STEPS - 7];
                    end
                end else if (rx_data_shift[NUMBER_OF_STEPS][15:8] == COM ) begin
                    data_DLL        <= {DATA_WIDTH{1'b0}};
                    if ( rx_data_shift[NUMBER_OF_STEPS-1][7:0] == SKP ) begin
                        COM_detected       <= 1'b0;
                        data_OS            <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected       <= 1'b1;
                        data_OS[7:0]       <= rx_data_shift[NUMBER_OF_STEPS][15:8];
                        data_OS[23:8]      <= rx_data_shift[NUMBER_OF_STEPS - 1][15:0];
                        data_OS[39:24]     <= rx_data_shift[NUMBER_OF_STEPS - 2][15:0];
                        data_OS[55:40]     <= rx_data_shift[NUMBER_OF_STEPS - 3][15:0];
                        data_OS[71:56]     <= rx_data_shift[NUMBER_OF_STEPS - 4][15:0];
                        data_OS[87:72]     <= rx_data_shift[NUMBER_OF_STEPS - 5][15:0];
                        data_OS[103:88]    <= rx_data_shift[NUMBER_OF_STEPS - 6][15:0];
                        data_OS[119:104]   <= rx_data_shift[NUMBER_OF_STEPS - 7][15:0];
                        data_OS[127:120]   <= rx_data_shift[NUMBER_OF_STEPS - 8][7:0];
                    end
                end else begin
                    data_DLL        <= rx_data_shift[NUMBER_OF_STEPS];
                    COM_detected    <= 1'b0;
                    data_OS         <= {PATTERN_WIDTH{1'b0}};
                end
            end
        end else begin // 8-Bit data width
            always @ (posedge clk or posedge reset) begin
                if ( reset ) begin
                    data_DLL        <= {DATA_WIDTH{1'b0}};
                    COM_detected    <= 1'b0;
                    data_OS         <= {PATTERN_WIDTH{1'b0}};
                end else if ( rx_data_shift[NUMBER_OF_STEPS][7:0] == COM ) begin
                    data_DLL        <= {DATA_WIDTH{1'b0}};
                    if ( rx_data_shift[NUMBER_OF_STEPS - 1][7:0] == SKP ) begin
                        COM_detected    <= 1'b0;
                        data_OS         <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected       <= 1'b1;
                        data_OS[7:0]       <= rx_data_shift[NUMBER_OF_STEPS];
                        data_OS[15:8]      <= rx_data_shift[NUMBER_OF_STEPS - 1];
                        data_OS[23:16]     <= rx_data_shift[NUMBER_OF_STEPS - 2];
                        data_OS[31:24]     <= rx_data_shift[NUMBER_OF_STEPS - 3];
                        data_OS[39:32]     <= rx_data_shift[NUMBER_OF_STEPS - 4];
                        data_OS[47:40]     <= rx_data_shift[NUMBER_OF_STEPS - 5];
                        data_OS[55:48]     <= rx_data_shift[NUMBER_OF_STEPS - 6];
                        data_OS[63:56]     <= rx_data_shift[NUMBER_OF_STEPS - 7];
                        data_OS[71:64]     <= rx_data_shift[NUMBER_OF_STEPS - 8];
                        data_OS[79:72]     <= rx_data_shift[NUMBER_OF_STEPS - 9];
                        data_OS[87:80]     <= rx_data_shift[NUMBER_OF_STEPS - 10];
                        data_OS[95:88]     <= rx_data_shift[NUMBER_OF_STEPS - 11];
                        data_OS[103:96]    <= rx_data_shift[NUMBER_OF_STEPS - 12];
                        data_OS[111:104]   <= rx_data_shift[NUMBER_OF_STEPS - 13];
                        data_OS[119:112]   <= rx_data_shift[NUMBER_OF_STEPS - 14];
                        data_OS[127:120]   <= rx_data_shift[NUMBER_OF_STEPS - 15];
                    end
                end else begin
                    data_DLL        <= rx_data_shift[NUMBER_OF_STEPS];
                    COM_detected    <= 1'b0;
                    data_OS         <= {PATTERN_WIDTH{1'b0}};
                end
            end
        end
    endgenerate

endmodule