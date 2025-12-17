//----------------------------------------------------------------------------------------
// Description: Top module for Rx MAC Ordered Set processing
// - Instantiates OS Process modules
// - Count logic for Ordered Sets, Timeout
// - Sets expected Link, Lane and Ctrl
//========================================================================================

module ccfpga_rx_MAC_OS #(
    parameter DATA_BYTES           = 8,
    parameter DATA_WIDTH           = DATA_BYTES * 8,
    parameter PATTERN_WIDTH        = 128,
    parameter NUMBER_OF_STEPS      = 8,
    parameter COUNT_WIDTH          = 4,
    parameter TIMEOUT_MAX_COUNT    = 2,
    parameter REC_CFG_MAX_COUNT    = 8,
    parameter REC_IDLE_MAX_COUNT   = 2
)(
    input  wire                     clk,                         // Clock
    input  wire                     reset,                       // Asynchronous reset
    input  wire               [4:0] fsm_state,                   // FSM current state

    input  wire [PATTERN_WIDTH-1:0] data,                        // Received data bytes

    input  wire                     OS_reset_flag,               // Ordered Set reset flag
    input  wire                     timeout_reset_flag,          // Timeout reset flag
    input  wire                     rec_cfg_reset_flag,          // Recovery.RcvrCfg reset flag
    input  wire                     rec_idle_reset_flag,         // Recovery.Idle reset flag
    input  wire                     TS1_pattern_en,              // TS1 pattern enable
    input  wire                     TS2_pattern_en,              // TS2 pattern enable
    input  wire                     COM_detected,                // COM detected flag

    input  wire   [COUNT_WIDTH-1:0] max_count,                   // Maximum count for Ordered Set counting

    output wire                     OS_valid,             // Ordered Set valid flag
    output wire                     OS_detected,          // Ordered Set detection flag
    output wire                     OS_rec_cfg_detected,  // Ordered Set with non-matched Link/Lane number in Recovery.RcvrCfg detection flag
    output wire                     inversion_detected,   // Polarity inversion detection flag

    output reg                [7:0] expected_Link,        // Expected Link number
    output reg                [7:0] expected_Lane,        // Expected Lane number
    output reg                [7:0] expected_Ctrl,        // Expected Ctrl field
    output reg                      link_detected,        // Link number detected flag
    output reg                      lane_detected,        // Lane number detected flag

    output reg                      OS_count_maxed,       // Ordered Set count maxed flag
    output reg                      timeout_flag,         // Timeout flag
    output reg                      rec_cfg_count_maxed,  // Recovery.RcvrCfg count maxed
    output reg                      rec_idle_count_maxed  // Recovery.Idle count maxed
);

    localparam PAD = 8'hF7; // K23.7

    wire               [7:0] detected_Link;  // Detected Link number
    wire               [7:0] detected_Lane;  // Detected Lane number
    wire               [7:0] detected_Ctrl;  // Detected Ctrl field

    wire               inc_count_OS;         // Increment Ordered Set count
    wire               clear_count_OS;       // Clear Ordered Set count
    wire               inc_count_timeout;    // Increment Timeout count
    wire               clear_count_timeout;  // Clear Timeout count
    wire               inc_count_rec_cfg;    // Increment TS1 count with non-matched Link/Lane number in Recovery.RcvrCfg
    wire               clear_count_rec_cfg;  // Clear TS1 count with non-matched Link/Lane number in Recovery.RcvrCfg
    wire               inc_count_rec_idle;   // Increment TS1 count with PAD-Lane in Recovery.Idle
    wire               clear_count_rec_idle; // Clear TS1 count with PAD-Lane in Recovery.Idle

    reg [COUNT_WIDTH-1:0] rx_count_OS;       // Ordered Set count
    reg             [1:0] rx_count_timeout;  // Ordered Set count for timeout
    reg             [3:0] rx_count_rec_cfg;  // Ordered Set count for Recovery config
    reg             [1:0] rx_count_rec_idle; // Ordered Set count for Recovery idle

    ccfpga_OS_process #(
        .PATTERN_WIDTH        ( PATTERN_WIDTH        )
    ) ccfpga_OS_process_inst (
        .clk                  ( clk                  ),
        .reset                ( reset                ),

        .data                 ( data                 ),

        .OS_reset_flag        ( OS_reset_flag        ),
        .rec_cfg_reset_flag   ( rec_cfg_reset_flag   ),
        .COM_detected         ( COM_detected         ),
        .TS1_pattern_en       ( TS1_pattern_en       ),
        .TS2_pattern_en       ( TS2_pattern_en       ),
        .expected_Link        ( expected_Link        ),
        .expected_Lane        ( expected_Lane        ),
        .expected_Ctrl        ( expected_Ctrl        ),

        .OS_valid             ( OS_valid             ),
        .OS_detected          ( OS_detected          ),
        .OS_rec_cfg_detected  ( OS_rec_cfg_detected  ),
        .inversion_detected   ( inversion_detected   ),

        .detected_Link        ( detected_Link        ),
        .detected_Lane        ( detected_Lane        ),
        .detected_Ctrl        ( detected_Ctrl        ),

        .inc_count_OS         ( inc_count_OS         ),
        .clear_count_OS       ( clear_count_OS       ),
        .inc_count_timeout    ( inc_count_timeout    ),
        .clear_count_timeout  ( clear_count_timeout  ),
        .inc_count_rec_cfg    ( inc_count_rec_cfg    ),
        .clear_count_rec_cfg  ( clear_count_rec_cfg  ),
        .inc_count_rec_idle   ( inc_count_rec_idle   ),
        .clear_count_rec_idle ( clear_count_rec_idle )
    );

// Counting logic
// inc_count = 1 if correctly received
// clear_count = 1 if incorrectly received
    // Ordered Set Pattern counting/ count_maxed is hold until reset or clear_count
    always @ (posedge clk or posedge OS_reset_flag) begin
        if ( OS_reset_flag ) begin
            rx_count_OS <= {COUNT_WIDTH{1'b0}};
            OS_count_maxed <= 1'b0;
        end else if ( rx_count_OS == max_count ) begin
            rx_count_OS <= rx_count_OS;
            OS_count_maxed <= 1'b1;
        end else if ( clear_count_OS ) begin
            rx_count_OS <= {COUNT_WIDTH{1'b0}};
            OS_count_maxed <= 1'b0;
        end else if ( inc_count_OS ) begin
            rx_count_OS <= rx_count_OS + 1'b1;
            OS_count_maxed <= 1'b0;
        end
    end

    // Ordered Set Timeout counting/ count_maxed is hold until reset or clear_count
    // Receives Ordered Sets with PAD-Link/Lane can lead to timeout in some states
    always @ (posedge clk or posedge timeout_reset_flag) begin
        if ( timeout_reset_flag ) begin
            rx_count_timeout <= 2'b00;
            timeout_flag <= 1'b0;
        end else if ( rx_count_timeout == TIMEOUT_MAX_COUNT ) begin
            rx_count_timeout <= rx_count_timeout;
            timeout_flag <= 1'b1;
        end else if ( clear_count_timeout ) begin
            rx_count_timeout <= 2'b00;
            timeout_flag <= 1'b0;
        end else if ( inc_count_timeout ) begin
            rx_count_timeout <= rx_count_timeout + 1'b1;
            timeout_flag <= 1'b0;
        end
    end

    // TS1 with non-matched Link/Lane in Recovery.RcvrCfg counting
    // count_maxed is hold until reset or clear_count
    always @ (posedge clk or posedge rec_cfg_reset_flag) begin
        if ( rec_cfg_reset_flag ) begin
            rx_count_rec_cfg    <= 4'b0;
            rec_cfg_count_maxed <= 1'b0;
        end else if ( rx_count_rec_cfg == REC_CFG_MAX_COUNT ) begin
            rx_count_rec_cfg    <= rx_count_rec_cfg;
            rec_cfg_count_maxed <= 1'b1;
        end else if ( clear_count_rec_cfg ) begin
            rx_count_rec_cfg    <= 4'b0;
            rec_cfg_count_maxed <= 1'b0;
        end else if ( inc_count_rec_cfg ) begin
            rx_count_rec_cfg    <= rx_count_rec_cfg + 1'b1;
            rec_cfg_count_maxed <= 1'b0;
        end
    end

    // TS1 with PAD-Lane in Recovery.Idle counting
    // count_maxed is hold until reset or clear_count
    always @ (posedge clk or posedge rec_idle_reset_flag) begin
        if ( rec_idle_reset_flag ) begin
            rx_count_rec_idle     <= 2'b0;
            rec_idle_count_maxed  <= 1'b0;
        end else if ( rx_count_rec_idle == REC_IDLE_MAX_COUNT ) begin
            rx_count_rec_idle     <= rx_count_rec_idle;
            rec_idle_count_maxed  <= 1'b1;
        end else if ( clear_count_rec_idle ) begin
            rx_count_rec_idle     <= 2'b0;
            rec_idle_count_maxed  <= 1'b0;
        end else if ( inc_count_rec_idle ) begin
            rx_count_rec_idle     <= rx_count_rec_idle + 1'b1;
            rec_idle_count_maxed  <= 1'b0;
        end
    end

    // Set detected Link/Lane number and control bits based on received Ordered Sets
    always @(posedge clk or posedge reset) begin
        if ( reset ) begin
            expected_Link <= PAD;
            expected_Lane <= PAD;
            expected_Ctrl <= 8'h00;
            link_detected <= 1'b0;
            lane_detected <= 1'b0;
        end else if ( fsm_state == 5'b10010 ) begin // CONFIG_LINKWIDTH_START_LINKNUM
            if ( OS_detected == 1'b1 && detected_Link != PAD ) begin
                expected_Link <= detected_Link;
                expected_Lane <= PAD;
                expected_Ctrl <= 8'h00;
                link_detected <= 1'b1;
                lane_detected <= 1'b0;
            end
        end else if ( fsm_state == 5'b10011 ) begin // CONFIG_LINKWIDTH_ACCEPT_LANENUM
            if ( OS_detected == 1'b1 && detected_Lane != PAD && detected_Link == expected_Link ) begin
            expected_Lane <= detected_Lane;
            expected_Ctrl <= 8'h00;
            link_detected <= 1'b1;
            lane_detected <= 1'b1;
            end
        end else if ( fsm_state == 5'b01000 ) begin // CONFIG_COMPLETE
            expected_Ctrl <= detected_Ctrl;
        end else if ( fsm_state == 5'b00000 ) begin // DETECT_QUIET
            expected_Link <= PAD;
            expected_Lane <= PAD;
            expected_Ctrl <= 8'h00;
            link_detected <= 1'b0;
            lane_detected <= 1'b0;
        end
    end

endmodule