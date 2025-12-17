//----------------------------------------------------------------------------------------
// Description: This module handles the Rx MAC IDLE detection and counting
// - Counts the number of consecutive IDLE symbols received
// - Generates IDLE detected and count maxed signals
//========================================================================================

module ccfpga_rx_MAC_IDLE #(
    parameter DATA_BYTES        = 8,
    parameter IDL_MAX_COUNT     = 8
)(
    input wire                   clk,                  // Clock
    input wire                   IDLE_reset_flag,      // IDLE count reset flag
    input wire                   COM_detected,         // COM detected signal

    output reg                   IDLE_detected,        // IDLE detected signal
    output reg                   IDLE_count_maxed      // IDLE count maxed signal
);

    reg [3:0] rx_count_IDL;         // IDLE count

    wire      inc_count_IDL;        // IDLE count increment signal
    wire      clear_count_IDL;      // IDLE count clear signal

// IDLE detection signal
    always @ (posedge clk or posedge IDLE_reset_flag) begin
        if ( IDLE_reset_flag )
            IDLE_detected <= 1'b0;
        else if ( inc_count_IDL ) // Idle pattern detected
            IDLE_detected <= 1'b1;
        else
            IDLE_detected <= 1'b0;
    end

// IDLE counting/ count_maxed is hold until reset or clear_count
    always @ (posedge clk or posedge IDLE_reset_flag) begin
        if ( IDLE_reset_flag ) begin
            rx_count_IDL <= 4'b0;
            IDLE_count_maxed <= 1'b0;
        end else if ( clear_count_IDL ) begin
            rx_count_IDL <= 4'b0;
            IDLE_count_maxed <= 1'b0;
        end else if ( inc_count_IDL ) begin
            if ( rx_count_IDL == IDL_MAX_COUNT ) begin
                rx_count_IDL <= rx_count_IDL;
                IDLE_count_maxed <= 1'b1;
            end else begin
                rx_count_IDL <= rx_count_IDL + DATA_BYTES;
                IDLE_count_maxed <= 1'b0;
            end
        end
    end

    // IDLE counting signals
    //assign inc_count_IDL = ( rx_data_shift[NUMBER_OF_STEPS] == { DATA_WIDTH{1'b0} } );
    assign inc_count_IDL   = COM_detected == 1'b0;
    assign clear_count_IDL = !inc_count_IDL;

endmodule