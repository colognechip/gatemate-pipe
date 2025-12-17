//----------------------------------------------------------------------------------------
// Description: This module processes received Ordered Sets
// - Detects and validates received Ordered Sets (TS1/TS2)
// - Extracts Link number, Lane number and Ctrl field from received Ordered Sets
// - Detects polarity inversion of received Ordered Sets
// - Generates counting signals for received Ordered Sets and timeouts
//========================================================================================

module ccfpga_OS_process #(
    parameter PATTERN_WIDTH        = 128
)(
    input  wire                     clk,                  // Clock
    input  wire                     reset,                // Asynchronous reset

    input  wire [PATTERN_WIDTH-1:0] data,                 // Extracted Ordered Set data

    input  wire                     OS_reset_flag,        // Ordered Set reset flag
    input  wire                     rec_cfg_reset_flag,   // Recovery.RcvrCfg reset flag
    input  wire                     COM_detected,         // COM detection flag
    input  wire                     TS1_pattern_en,       // TS1 pattern enable
    input  wire                     TS2_pattern_en,       // TS2 pattern enable

    input  wire [7:0]               expected_Link,        // Expected Link number
    input  wire [7:0]               expected_Lane,        // Expected Lane number
    input  wire [7:0]               expected_Ctrl,        // Expected Ctrl field
    input  wire                     detect_inversion_en,  // Inversion detection enable

    output reg                      OS_valid,             // Ordered Set valid flag
    output reg                      OS_detected,          // Ordered Set detection flag
    output reg                      OS_rec_cfg_detected,  // Ordered Set with non-matched Link/Lane number in Recovery.RcvrCfg detection flag
    output reg                      inversion_detected,   // Polarity inversion detection flag

    output reg  [7:0]               detected_Link,        // Detected Link number
    output reg  [7:0]               detected_Lane,        // Detected Lane number
    output reg  [7:0]               detected_Ctrl,        // Detected Ctrl field

    output wire                     inc_count_OS,         // Increment Ordered Set count
    output wire                     clear_count_OS,       // Clear Ordered Set count
    output wire                     inc_count_timeout,    // Increment Timeout count
    output wire                     clear_count_timeout,  // Clear Timeout count
    output wire                     inc_count_rec_cfg,    // Increment TS1 count with non-matched Link/Lane number in Recovery.RcvrCfg
    output wire                     clear_count_rec_cfg,  // Clear TS1 count with non-matched Link/Lane number in Recovery.RcvrCfg
    output wire                     inc_count_rec_idle,   // Increment TS1 count with PAD-Lane in Recovery.Idle
    output wire                     clear_count_rec_idle  // Clear TS1 count with PAD-Lane in Recovery.Idle
);

    // Masks
    localparam OS_MASK    = 128'hFF_FF_FF_FF_FF_FF_FF_FF_FF_FF_00_00_00_00_00_FF;
    localparam VALID_MASK = 128'hFF_FF_FF_FF_FF_FF_FF_FF_FF_FF_00_00_00_FF_FF_FF;
    // K characters
    localparam COM     = 8'hBC; // K28.5
    localparam PAD     = 8'hF7; // K23.7
    // Data Characters
    localparam ID1     = 8'h4A; // D10.2
    localparam ID2     = 8'h45; // D5.2
    localparam ID1_inv = 8'hB5; // D10.2 inverted
    localparam ID2_inv = 8'hBA; // D5.2 inverted

    // Rx flags
    wire                         rx_valid;    // received Ordered Set is valid
    wire                         rx_OS;       // received data is an Ordered Set
    wire                         rx_OS_inv;   // received Ordered Set is inverted
    wire                         rx_timeout;  // received Ordered Set with PAD-Lane and PAD-Link, used for timeout
    wire                         rx_rec_cfg;  // received Ordered Set with non-matched Link/Lane, used in Recovery.RcvrCfg
    wire                         rx_rec_idl;  // received recovery idle Ordered Set with PAD-Lane, used in Recovery.Idle

    // TS1/TS2 pattern
    wire [PATTERN_WIDTH - 1 : 0] TS1_pattern; // TS1 pattern
    wire [PATTERN_WIDTH - 1 : 0] TS2_pattern; // TS2 pattern
    wire [PATTERN_WIDTH - 1 : 0] TS1_inv;     // TS1 inverted pattern
    wire [PATTERN_WIDTH - 1 : 0] TS2_inv;     // TS2 inverted pattern
    // masked TS1/TS2 pattern for detection
    wire [PATTERN_WIDTH - 1 : 0] TS1_OS;      // TS1 pattern masked for OS detection
    wire [PATTERN_WIDTH - 1 : 0] TS2_OS;      // TS2 pattern masked for OS detection
    wire [PATTERN_WIDTH - 1 : 0] TS1_OS_inv;  // TS1 inverted pattern masked for OS detection
    wire [PATTERN_WIDTH - 1 : 0] TS2_OS_inv;  // TS2 inverted pattern masked for OS detection
    // masked TS1/TS2 pattern for validation
    wire [PATTERN_WIDTH - 1 : 0] TS1_valid;   // TS1 pattern masked for OS validation
    wire [PATTERN_WIDTH - 1 : 0] TS2_valid;   // TS2 pattern masked for OS validation
    // masked received data for comparison
    wire [PATTERN_WIDTH - 1 : 0] data_OS;     // Masked received data for OS detection
    wire [PATTERN_WIDTH - 1 : 0] data_valid;  // Masked received data for OS validation

// Processing received Ordered Sets
    // Ordered Set validation
    // OS_valid = 1 for one clock cycle when an Ordered Set is correctly received
    always @ (posedge clk or posedge OS_reset_flag) begin
        if ( OS_reset_flag ) begin
            OS_valid <= 1'b0;
        end
        else begin
            if ( (COM_detected == 1'b1) && rx_valid ) begin
                OS_valid <= 1'b1;
            end else begin
                OS_valid <= 1'b0;
            end
        end
    end

    // Ordered Set received detection
    // Extract Link, Lane and Ctrl from the received Ordered Set
    // OS_detected = 1 for one clock cycle when an Ordered Set received
    always @ (posedge clk or posedge OS_reset_flag) begin
        if ( OS_reset_flag ) begin
            OS_detected <= 1'b0;
            detected_Link <= 8'h00;
            detected_Lane <= 8'h00;
            detected_Ctrl <= 8'h00;
        end
        else begin
            if ( (COM_detected == 1'b1) && rx_OS ) begin
                OS_detected   <= 1'b1;
                detected_Link <= data[15:8];
                detected_Lane <= data[23:16];
                detected_Ctrl <= data[47:40];
            end else begin
                OS_detected   <= 1'b0;
                detected_Link <= 8'h00;
                detected_Lane <= 8'h00;
                detected_Ctrl <= 8'h00;
            end
        end
    end

    // Ordered Set received with non-matched Link/Lane in Recovery.RcvrCfg
    always @ (posedge clk or posedge rec_cfg_reset_flag) begin
        if ( rec_cfg_reset_flag ) begin
            OS_rec_cfg_detected <= 1'b0;
        end
        else begin
            if ( (COM_detected == 1'b1) && rx_rec_cfg ) begin
                OS_rec_cfg_detected <= 1'b1;
            end else begin
                OS_rec_cfg_detected <= 1'b0;
            end
        end
    end

    // Polarity inversion detection
    always @ (posedge clk or posedge reset) begin
        if ( reset ) begin
            inversion_detected <= 1'b0;
        end else if ( detect_inversion_en ) begin
            if ( (COM_detected == 1'b1) && rx_OS_inv ) begin
                inversion_detected <= 1'b1;
            end
        end
    end

    // Ordered Set patterns
    assign TS1_pattern = {{10{ID1}}, expected_Ctrl, 8'h02, 8'h00, expected_Lane, expected_Link, COM};
    assign TS2_pattern = {{10{ID2}}, expected_Ctrl, 8'h02, 8'h00, expected_Lane, expected_Link, COM};
    assign TS1_inv     = {{10{ID1_inv}}, expected_Ctrl, 8'h02, 8'h00, expected_Lane, expected_Link, COM};
    assign TS2_inv     = {{10{ID2_inv}}, expected_Ctrl, 8'h02, 8'h00, expected_Lane, expected_Link, COM};
    // Masked patterns
    assign TS1_OS      = TS1_pattern & OS_MASK;
    assign TS2_OS      = TS2_pattern & OS_MASK;
    assign TS1_OS_inv  = TS1_inv     & OS_MASK;
    assign TS2_OS_inv  = TS2_inv     & OS_MASK;
    assign TS1_valid   = TS1_pattern & VALID_MASK;
    assign TS2_valid   = TS2_pattern & VALID_MASK;
    // Masked received data
    assign data_OS     = data        & OS_MASK;
    assign data_valid  = data        & VALID_MASK;

    // Rx Ordered Set detection signals
    assign rx_OS      = (TS1_pattern_en && (data_OS == TS1_OS))       || (TS2_pattern_en && (data_OS == TS2_OS));
    assign rx_OS_inv  = (TS1_pattern_en && (data_OS == TS1_OS_inv))   || (TS2_pattern_en && (data_OS == TS2_OS_inv));
    assign rx_valid   = (TS1_pattern_en && (data_valid == TS1_valid)) || (TS2_pattern_en && (data_valid == TS2_valid));
    assign rx_timeout = (data[127:48] == {10{ID1}}) && (data[23:16] == PAD) && (data[15:8] == PAD); // TS1 with PAD-Lane and PAD-Link
    assign rx_rec_cfg = (data_OS == TS1_OS) && ((data[23:16] != expected_Lane) || (data[15:8] != expected_Link)); // TS1 with non-matched Link/Lane
    assign rx_rec_idl = (data_OS == TS1_OS) && (data[23:16] == PAD); // TS1 with PAD-Lane

    // Rx Ordered Set counting signals
    assign inc_count_OS   = (COM_detected == 1'b1) && rx_valid;
    assign clear_count_OS = (COM_detected == 1'b1) && !rx_valid;
    // Rx Timeout counting signals
    assign inc_count_timeout   = (COM_detected == 1'b1) && rx_timeout;
    assign clear_count_timeout = (COM_detected == 1'b1) && !rx_timeout;
    // Recovery.RcvrCfg counting signals
    assign inc_count_rec_cfg   = (COM_detected == 1'b1) && rx_rec_cfg;
    assign clear_count_rec_cfg = (COM_detected == 1'b1) && !rx_rec_cfg;
    // Recovery.Idle counting signals
    assign inc_count_rec_idle   = (COM_detected == 1'b1) && rx_rec_idl;
    assign clear_count_rec_idle = (COM_detected == 1'b1) && !rx_rec_idl;

endmodule