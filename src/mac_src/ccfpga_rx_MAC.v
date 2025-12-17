//----------------------------------------------------------------------------------------
// Description: This module handles the Rx side of PHY/MAC
// - It counts the number of consecutive received Ordered Set sequences, Idle sequences
// - Link and lane defines the expected Link and Lane numbers in the received Ordered Sets
// - Ctrl defines the expected control signal for the received Ordered Sets
// - It handles and forwards the received data to DLL
// - It detects inversion in the received Ordered Sets
// - It handles Rx timeout detection
// - The received data is stored in a shift register for processing
//========================================================================================

module ccfpga_rx_MAC #(
    parameter COUNT_WIDTH = 4,
    parameter PATTERN_WIDTH = 128,
    parameter DATA_BYTES = 8,
    parameter DATA_WIDTH = DATA_BYTES * 8
) (
    input wire                       clk,
    input wire                       reset,
    input wire                 [4:0] fsm_state,

    input wire  [DATA_WIDTH - 1 : 0] rx_data,

    input wire                       OS_reset_flag,
    input wire                       IDLE_reset_flag,
    input wire                       timeout_reset_flag,
    input wire                       rec_cfg_reset_flag,
    input wire                       rec_idle_reset_flag,
    input wire                       TS1_pattern_en,
    input wire                       TS2_pattern_en,
    input wire [COUNT_WIDTH - 1 : 0] max_count,
    input wire                       L0_enabled,

    output wire                      OS_valid,
    output wire                      OS_detected,
    output wire                      inversion_detected,
    output wire                      OS_rec_cfg_detected,
    output wire                      IDLE_detected,
    output wire                      OS_count_maxed,
    output wire                      timeout_flag,
    output wire                      IDLE_count_maxed,
    output wire                      rec_cfg_count_maxed,
    output wire                      rec_idle_count_maxed,
    output wire                [7:0] expected_Link,
    output wire                [7:0] expected_Lane,
    output wire                [7:0] expected_Ctrl,
    output wire                      link_detected,
    output wire                      lane_detected,
    output wire [DATA_WIDTH - 1 : 0] rx_data_DLL,
    output wire [DATA_BYTES - 1 : 0] rx_dataK_DLL
    );

    localparam IDL_MAX_COUNT                 = 8;
    localparam TIMEOUT_MAX_COUNT             = 2;
    localparam REC_CFG_MAX_COUNT             = 8;
    localparam REC_IDLE_MAX_COUNT            = 2;

    localparam NUMBER_OF_STEPS               = PATTERN_WIDTH / DATA_WIDTH;

    wire                     COM_detected;
    wire [PATTERN_WIDTH-1:0] data_OS;
    wire    [DATA_WIDTH-1:0] data_DLL;

//--------------------------------------------------------------------------------
    ccfpga_data_assembly #(
        .DATA_BYTES         ( DATA_BYTES        ),
        .PATTERN_WIDTH      ( PATTERN_WIDTH     ),
        .NUMBER_OF_STEPS    ( NUMBER_OF_STEPS   )
    ) data_assembly_inst (
        .clk                ( clk          ),
        .reset              ( reset        ),
        .rx_data            ( rx_data      ),
        .COM_detected       ( COM_detected ),
        .data_OS            ( data_OS      ),
        .data_DLL           ( data_DLL     )
    );
//--------------------------------------------------------------------------------
// Instantiation of Rx MAC Ordered Set processing module
    ccfpga_rx_MAC_OS #(
        .DATA_BYTES         ( DATA_BYTES         ),
        .PATTERN_WIDTH      ( PATTERN_WIDTH      ),
        .NUMBER_OF_STEPS    ( NUMBER_OF_STEPS    ),
        .COUNT_WIDTH        ( COUNT_WIDTH        ),
        .TIMEOUT_MAX_COUNT  ( TIMEOUT_MAX_COUNT  ),
        .REC_CFG_MAX_COUNT  ( REC_CFG_MAX_COUNT  ),
        .REC_IDLE_MAX_COUNT ( REC_IDLE_MAX_COUNT )
    ) rx_mac_os_inst (
        .clk                    ( clk                  ),
        .reset                  ( reset                ),
        .fsm_state              ( fsm_state            ),

        .data                   ( data_OS              ),

        .OS_reset_flag          ( OS_reset_flag        ),
        .timeout_reset_flag     ( timeout_reset_flag   ),
        .rec_cfg_reset_flag     ( rec_cfg_reset_flag   ),
        .rec_idle_reset_flag    ( rec_idle_reset_flag  ),
        .TS1_pattern_en         ( TS1_pattern_en       ),
        .TS2_pattern_en         ( TS2_pattern_en       ),
        .COM_detected           ( COM_detected         ),

        .max_count              ( max_count            ),

        .OS_valid               ( OS_valid             ),
        .OS_detected            ( OS_detected          ),
        .OS_rec_cfg_detected    ( OS_rec_cfg_detected  ),
        .inversion_detected     ( inversion_detected   ),

        .expected_Link          ( expected_Link        ),
        .expected_Lane          ( expected_Lane        ),
        .expected_Ctrl          ( expected_Ctrl        ),
        .link_detected          ( link_detected        ),
        .lane_detected          ( lane_detected        ),

        .OS_count_maxed         ( OS_count_maxed       ),
        .timeout_flag           ( timeout_flag         ),
        .rec_cfg_count_maxed    ( rec_cfg_count_maxed  ),
        .rec_idle_count_maxed   ( rec_idle_count_maxed )
    );
//--------------------------------------------------------------------------------
// Instantiation of Rx MAC IDLE processing module
    ccfpga_rx_MAC_IDLE #(
        .DATA_BYTES     ( DATA_BYTES    ),
        .IDL_MAX_COUNT  ( IDL_MAX_COUNT )
    ) rx_mac_idle_inst (
        .clk                ( clk              ),
        .IDLE_reset_flag    ( IDLE_reset_flag  ),
        .COM_detected       ( COM_detected     ),

        .IDLE_detected      ( IDLE_detected    ),
        .IDLE_count_maxed   ( IDLE_count_maxed )
    );
//--------------------------------------------------------------------------------
// Instantiation of Rx MAC data processing module
    ccfpga_rx_MAC_data #(
        .DATA_BYTES        ( DATA_BYTES      ),
        .NUMBER_OF_STEPS   ( NUMBER_OF_STEPS )
    ) rx_mac_data_inst (
        .clk            ( clk           ),
        .L0_enabled     ( L0_enabled    ),
        .rx_data        ( data_DLL      ),

        .rx_data_DLL    ( rx_data_DLL   ),
        .rx_dataK_DLL   ( rx_dataK_DLL  )
    );
//--------------------------------------------------------------------------------
endmodule