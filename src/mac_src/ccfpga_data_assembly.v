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
    input wire    [DATA_BYTES-1:0] rx_data_k,                   // Received K flags
    output reg                     COM_detected,                // COM detected flag
    output reg [PATTERN_WIDTH-1:0] data_OS,                     // Extracted Ordered Set data
    output reg    [DATA_WIDTH-1:0] data_DLL                     // Data forwarded to DLL
);

    // K characters
    localparam COM = 8'hBC;
    localparam SKP = 8'h1C;

    // Shift registers to store received data for Ordered Set assembly
    reg [DATA_WIDTH - 1 : 0] rx_data_shift   [NUMBER_OF_STEPS : 0];
    reg [DATA_BYTES - 1 : 0] rx_data_k_shift [NUMBER_OF_STEPS : 0];
    integer i;

    always @ (posedge clk) begin
        rx_data_shift[0]   <= rx_data;
        rx_data_k_shift[0] <= rx_data_k;
        for ( i = 1; i < NUMBER_OF_STEPS + 1; i = i + 1 ) begin
            rx_data_shift[i]   <= rx_data_shift[i - 1];
            rx_data_k_shift[i] <= rx_data_k_shift[i - 1];
        end
    end

    // Note: this design is a bit overkilled as the current SerDes setup aligns the COM
    // to the first or the fifth byte for 64 bit data width and always to the first byte for 32 bit or narrower.
    // However, this design can handle any COM position and is more robust to potential future changes in SerDes alignment.

    localparam WIN_BYTES = (NUMBER_OF_STEPS + 1) * DATA_BYTES;

    wire [WIN_BYTES*8-1:0] win; //  flatten out the received window
    wire   [WIN_BYTES-1:0] win_k;

    genvar w;
    generate
        for ( w = 0; w < NUMBER_OF_STEPS + 1; w = w + 1 ) begin : window
            assign win  [w*DATA_WIDTH +: DATA_WIDTH] = rx_data_shift  [NUMBER_OF_STEPS - w];
            assign win_k[w*DATA_BYTES +: DATA_BYTES] = rx_data_k_shift[NUMBER_OF_STEPS - w];
        end
    endgenerate

    reg                     com_found;
    reg                     skp_found;
    reg [PATTERN_WIDTH-1:0] os_found;
    integer p;

    always @ (*) begin
        com_found = 1'b0;
        skp_found = 1'b0;
        os_found  = {PATTERN_WIDTH{1'b0}};
        for ( p = DATA_BYTES - 1; p >= 0; p = p - 1 ) begin
            if ( win[8*p +: 8] == COM && win_k[p] ) begin
                com_found = 1'b1;
                skp_found = ( win[8*(p+1) +: 8] == SKP && win_k[p+1] );
                os_found  = win[8*p +: PATTERN_WIDTH];
            end
        end
    end

    always @ (posedge clk or posedge reset) begin
        if ( reset ) begin
            data_DLL        <= {DATA_WIDTH{1'b0}};
            COM_detected    <= 1'b0;
            data_OS         <= {PATTERN_WIDTH{1'b0}};
        end else begin
            data_DLL        <= rx_data_shift[NUMBER_OF_STEPS];
            if ( com_found && !skp_found ) begin
                COM_detected    <= 1'b1;
                data_OS         <= os_found;
            end else begin
                COM_detected    <= 1'b0;
                data_OS         <= {PATTERN_WIDTH{1'b0}};
            end
        end
    end

endmodule