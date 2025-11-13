// Count the number of received consecutive Ordered Sets sequences
// Link and lane define the expected Link and Lane numbers in the received Ordered Sets
// Ctrl defines the expected control signal for the received Ordered Sets
// Link and Lane check necessary?

module ccfpga_rx_MAC #(
    parameter COUNT_WIDTH = 4,
    parameter PATTERN_WIDTH = 128,
    parameter DATA_BYTES = 8,
    parameter DATA_WIDTH = DATA_BYTES * 8,
    parameter IDLE_WIDTH = 8
    )
    (
    input wire clk,
    input wire reset,
    input wire OS_reset_flag,
    input wire IDLE_reset_flag,
    input wire timeout_reset_flag,

    input wire [DATA_WIDTH - 1 : 0] rx_data,

    // OS Flags
    input wire [7:0] expected_Link,
    input wire [7:0] expected_Lane,
    input wire [7:0] expected_Ctrl,
    input wire [COUNT_WIDTH - 1 : 0] max_count,
    input wire TS1_pattern_en,
    input wire TS2_pattern_en,

    // Data Flags
    input wire L0_enabled,

    // Rx Timeout
    output reg timeout_flag,

    output reg OS_valid,
    output reg OS_detected,
    output reg OS_count_maxed,
    output reg inversion_detected,
    output reg [7:0] detected_Link,
    output reg [7:0] detected_Lane,
    output reg [7:0] detected_Ctrl,

    output reg IDLE_detected,
    output reg IDLE_count_maxed,

    output reg [DATA_WIDTH - 1 : 0] rx_data_DLL
    //output reg [DATA_BYTES - 1 : 0] rx_data_k_DLL
    );

    localparam COM  = 8'hBC; // K28.5
    localparam STP  = 8'hFB; // K27.7
    localparam SDP  = 8'h5C; // K28.2
    localparam _END = 8'hFD; // K29.7
    localparam EDB  = 8'hFE; // K30.7
    localparam PAD  = 8'hF7; // K23.7
    localparam SKP  = 8'h1C; // K28.0
    localparam FTS  = 8'h3C; // K28.1
    localparam IDL  = 8'h7C; // K28.3

    localparam D00  = 8'h00; // D0.0
    localparam D10  = 8'h01; // D1.0
    localparam D20  = 8'h02; // D2.0
    localparam D40  = 8'h04; // D4.0
    localparam D80  = 8'h08; // D8.0
    localparam ID1  = 8'h4A; // D10.2
    localparam ID2  = 8'h45; // D5.2
    localparam ID1_inv = 8'hB5; // D10.2 inverted
    localparam ID2_inv = 8'hBA; // D5.2 inverted

    localparam IDL_MAX_COUNT                 = 8;
    localparam TIMEOUT_MAX_COUNT             = 2;
    localparam SYMBOL_WIDTH                  = 8;
    localparam NUMBER_OF_SYMBOL_PER_PATTERN  = PATTERN_WIDTH / SYMBOL_WIDTH;
    localparam NUMBER_OF_SYMBOL_PER_DATA     = DATA_WIDTH / SYMBOL_WIDTH;
    localparam NUMBER_OF_STEPS               = PATTERN_WIDTH / DATA_WIDTH;
    localparam NUMBER_OF_STEPS_IDL           = DATA_WIDTH / IDLE_WIDTH;
    localparam OS_MASK                       = 128'hFF_FF_FF_FF_FF_FF_FF_FF_FF_FF_00_00_00_00_00_FF;
    localparam VALID_MASK                    = 128'hFF_FF_FF_FF_FF_FF_FF_FF_FF_FF_00_00_00_FF_FF_FF;

    // Counting control signals
    wire inc_count_OS;          // Increment count when an Ordered Set is correctly received
    wire clear_count_OS;        // Clear count when an incorrect Ordered Set is received
    wire inc_count_IDL;         // Increment count when an idle data is correctly received
    wire clear_count_IDL;       // Clear count when an incorrect data is received
    wire inc_count_timeout;     // Increment timeout counter
    wire clear_count_timeout;   // Clear timeout counter

    // Processing received OS
    wire rx_valid;
    wire rx_OS;
    wire rx_OS_inv;
    wire [PATTERN_WIDTH - 1 : 0] TS1_pattern;
    wire [PATTERN_WIDTH - 1 : 0] TS2_pattern;
    wire [PATTERN_WIDTH - 1 : 0] TS1_inv;
    wire [PATTERN_WIDTH - 1 : 0] TS2_inv;
    wire [PATTERN_WIDTH - 1 : 0] TS1_OS;
    wire [PATTERN_WIDTH - 1 : 0] TS2_OS;
    wire [PATTERN_WIDTH - 1 : 0] TS1_OS_inv;
    wire [PATTERN_WIDTH - 1 : 0] TS2_OS_inv;
    wire [PATTERN_WIDTH - 1 : 0] TS1_valid;
    wire [PATTERN_WIDTH - 1 : 0] TS2_valid;
    wire [PATTERN_WIDTH - 1 : 0] data_OS;
    wire [PATTERN_WIDTH - 1 : 0] data_valid;

    reg [COUNT_WIDTH - 1 : 0] rx_count_OS;
    reg [IDL_MAX_COUNT - 1 : 0] rx_count_IDL;
    reg [1:0] rx_count_timeout;
    reg [PATTERN_WIDTH - 1 : 0] data;
    reg COM_detected;

    // Processing received data
    wire [DATA_BYTES - 1 : 0] char_is_K;
    wire [DATA_BYTES - 1 : 0] char_is_END;
    wire K_detected;
    wire END_detected;

    reg receiving_data;

    // Shift registers to store received data for Ordered Set assembly
    reg [DATA_WIDTH - 1 : 0] rx_data_shift [NUMBER_OF_STEPS : 0];

    always @ (posedge clk) begin
        integer i;
        rx_data_shift[0] <= rx_data;
        for ( i = 1; i < NUMBER_OF_STEPS + 1; i = i + 1 ) begin
            rx_data_shift[i] <= rx_data_shift[i - 1];
        end
    end

    // Pattern counting/ count_maxed is hold until reset or clear_count
    always @ (posedge clk or posedge OS_reset_flag) begin
        if ( OS_reset_flag ) begin
            rx_count_OS <= {COUNT_WIDTH{1'b0}};
            OS_count_maxed <= 1'b0;
        end else if ( clear_count_OS ) begin
            rx_count_OS <= {COUNT_WIDTH{1'b0}};
            OS_count_maxed <= 1'b0;
        end else if ( rx_count_OS == max_count ) begin
            rx_count_OS <= rx_count_OS;
            OS_count_maxed <= 1'b1;
        end else if ( inc_count_OS ) begin
            rx_count_OS <= rx_count_OS + 1'b1;
            OS_count_maxed <= 1'b0;
        end
    end

    // IDLE counting/ count_maxed is hold until reset or clear_count
    always @ (posedge clk or posedge IDLE_reset_flag) begin
        if ( IDLE_reset_flag ) begin
            rx_count_IDL <= {IDL_MAX_COUNT{1'b0}};
            IDLE_count_maxed <= 1'b0;
        end else if ( clear_count_IDL ) begin
            rx_count_IDL <= {IDL_MAX_COUNT{1'b0}};
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

    // IDLE detected signal
    always @ (posedge clk or posedge IDLE_reset_flag) begin
        if ( IDLE_reset_flag )
            IDLE_detected <= 1'b0;
        else if ( inc_count_IDL )
            IDLE_detected <= 1'b1;
        else
            IDLE_detected <= 1'b0;
    end

    // Timeout counting/ count_maxed is hold until reset or clear_count
    always @ (posedge clk or posedge timeout_reset_flag) begin
        if ( timeout_reset_flag ) begin
            rx_count_timeout <= 2'b00;
            timeout_flag     <= 1'b0;
        end else if ( clear_count_timeout ) begin
            rx_count_timeout <= 2'b00;
            timeout_flag <= 1'b0;
        end else if ( inc_count_timeout ) begin
            if ( rx_count_timeout == TIMEOUT_MAX_COUNT ) begin
                rx_count_timeout <= rx_count_timeout;
                timeout_flag <= 1'b1;
            end else begin
                rx_count_timeout <= rx_count_timeout + 1'b1;
                timeout_flag <= 1'b0;
            end
        end
    end

    // Ordered Set assembly
    // COM detected, start assembling the Ordered Set
    // New COM arrival before completing the Ordered Set resets the assembly
    // Completion of Ordered Set assembly resets the assembly
    // inc_count = 1 if Ordered Set correctly received
    // clear_count = 1 if Ordered Set incorrectly received

    generate
        if ( DATA_WIDTH == 64 ) begin
            always @ (posedge clk or posedge OS_reset_flag) begin
                if ( OS_reset_flag ) begin
                    COM_detected <= 1'b0;
                    data         <= {PATTERN_WIDTH{1'b0}};
                end else if ( rx_data_shift[NUMBER_OF_STEPS][7:0] == COM ) begin
                    if ( rx_data_shift[NUMBER_OF_STEPS][15:8] == SKP ) begin
                        COM_detected    <= 1'b0;
                        data            <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected    <= 1'b1;
                        data[63:0]      <= rx_data_shift[NUMBER_OF_STEPS];
                        data[127:64]    <= rx_data_shift[NUMBER_OF_STEPS - 1];
                    end
                end else if (rx_data_shift[NUMBER_OF_STEPS][15:8] == COM ) begin
                    if ( rx_data_shift[NUMBER_OF_STEPS][23:16] == SKP ) begin
                        COM_detected    <= 1'b0;
                        data            <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected    <= 1'b1;
                        data[55:0]      <= rx_data_shift[NUMBER_OF_STEPS][63:8];
                        data[119:56]    <= rx_data_shift[NUMBER_OF_STEPS - 1][63:0];
                        data[127:120]   <= rx_data_shift[NUMBER_OF_STEPS - 2][7:0];
                    end
                end else if (rx_data_shift[NUMBER_OF_STEPS][23:16] == COM ) begin
                    if ( rx_data_shift[NUMBER_OF_STEPS][31:24] == SKP ) begin
                        COM_detected    <= 1'b0;
                        data            <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected <= 1'b1;
                        data[47:0]      <= rx_data_shift[NUMBER_OF_STEPS][63:16];
                        data[111:48]    <= rx_data_shift[NUMBER_OF_STEPS - 1][63:0];
                        data[127:112]   <= rx_data_shift[NUMBER_OF_STEPS - 2][15:0];
                    end
                end else if (rx_data_shift[NUMBER_OF_STEPS][31:24] == COM ) begin
                    if ( rx_data_shift[NUMBER_OF_STEPS][39:32] == SKP ) begin
                        COM_detected    <= 1'b0;
                        data            <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected <= 1'b1;
                        data[39:0]      <= rx_data_shift[NUMBER_OF_STEPS][63:24];
                        data[103:40]    <= rx_data_shift[NUMBER_OF_STEPS - 1][63:0];
                        data[127:104]   <= rx_data_shift[NUMBER_OF_STEPS - 2][23:0];
                    end
                end else if (rx_data_shift[NUMBER_OF_STEPS][39:32] == COM ) begin
                    if ( rx_data_shift[NUMBER_OF_STEPS][47:40] == SKP ) begin
                        COM_detected    <= 1'b0;
                        data            <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected    <= 1'b1;
                        data[31:0]      <= rx_data_shift[NUMBER_OF_STEPS][63:32];
                        data[95:32]     <= rx_data_shift[NUMBER_OF_STEPS - 1][63:0];
                        data[127:96]    <= rx_data_shift[NUMBER_OF_STEPS - 2][31:0];
                    end
                end else if (rx_data_shift[NUMBER_OF_STEPS][47:40] == COM ) begin
                    if ( rx_data_shift[NUMBER_OF_STEPS][55:48] == SKP ) begin
                        COM_detected    <= 1'b0;
                        data            <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected    <= 1'b1;
                        data[23:0]      <= rx_data_shift[NUMBER_OF_STEPS][63:40];
                        data[87:24]     <= rx_data_shift[NUMBER_OF_STEPS - 1][63:0];
                        data[127:88]    <= rx_data_shift[NUMBER_OF_STEPS - 2][39:0];
                    end
                end else if (rx_data_shift[NUMBER_OF_STEPS][55:48] == COM ) begin
                    if ( rx_data_shift[NUMBER_OF_STEPS][63:56] == SKP ) begin
                        COM_detected    <= 1'b0;
                        data            <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected    <= 1'b1;
                        data[15:0]      <= rx_data_shift[NUMBER_OF_STEPS][63:48];
                        data[79:16]     <= rx_data_shift[NUMBER_OF_STEPS - 1][63:0];
                        data[127:80]    <= rx_data_shift[NUMBER_OF_STEPS - 2][47:0];
                    end
                end else if (rx_data_shift[NUMBER_OF_STEPS][63:56] == COM ) begin
                    if ( rx_data_shift[NUMBER_OF_STEPS - 1][7:0] == SKP ) begin
                        COM_detected    <= 1'b0;
                        data            <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected    <= 1'b1;
                        data[7:0]       <= rx_data_shift[NUMBER_OF_STEPS][63:56];
                        data[71:8]      <= rx_data_shift[NUMBER_OF_STEPS - 1][63:0];
                        data[127:72]    <= rx_data_shift[NUMBER_OF_STEPS - 2][55:0];
                    end
                end else begin
                    COM_detected <= 1'b0;
                    data         <= {PATTERN_WIDTH{1'b0}};
                end
            end
        end else if ( DATA_WIDTH == 32 ) begin
            always @ (posedge clk or posedge OS_reset_flag) begin
                if ( OS_reset_flag ) begin
                    COM_detected <= 1'b0;
                    data <= {PATTERN_WIDTH{1'b0}};
                end else if ( rx_data_shift[NUMBER_OF_STEPS][7:0] == COM ) begin
                    if ( rx_data_shift[NUMBER_OF_STEPS][15:8] == SKP ) begin
                        COM_detected    <= 1'b0;
                        data            <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected <= 1'b1;
                        data[31:0]      <= rx_data_shift[NUMBER_OF_STEPS];
                        data[63:32]     <= rx_data_shift[NUMBER_OF_STEPS - 1];
                        data[95:64]     <= rx_data_shift[NUMBER_OF_STEPS - 2];
                        data[127:96]    <= rx_data_shift[NUMBER_OF_STEPS - 3];
                    end
                end else if (rx_data_shift[NUMBER_OF_STEPS][15:8] == COM ) begin
                    if ( rx_data_shift[NUMBER_OF_STEPS][23:16] == SKP ) begin
                        COM_detected    <= 1'b0;
                        data            <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected <= 1'b1;
                        data[23:0]      <= rx_data_shift[NUMBER_OF_STEPS][31:8];
                        data[55:24]     <= rx_data_shift[NUMBER_OF_STEPS - 1][31:0];
                        data[87:56]     <= rx_data_shift[NUMBER_OF_STEPS - 2][31:0];
                        data[119:88]    <= rx_data_shift[NUMBER_OF_STEPS - 3][31:0];
                        data[127:120]   <= rx_data_shift[NUMBER_OF_STEPS - 4][7:0];
                    end
                end else if (rx_data_shift[NUMBER_OF_STEPS][23:16] == COM ) begin
                    if ( rx_data_shift[NUMBER_OF_STEPS][31:24] == SKP ) begin
                        COM_detected    <= 1'b0;
                        data            <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected <= 1'b1;
                        data[15:0]      <= rx_data_shift[NUMBER_OF_STEPS][31:16];
                        data[47:16]     <= rx_data_shift[NUMBER_OF_STEPS - 1][31:0];
                        data[79:48]     <= rx_data_shift[NUMBER_OF_STEPS - 2][31:0];
                        data[111:80]    <= rx_data_shift[NUMBER_OF_STEPS - 3][31:0];
                        data[127:112]   <= rx_data_shift[NUMBER_OF_STEPS - 4][15:0];
                    end
                end else if (rx_data_shift[NUMBER_OF_STEPS][31:24] == COM ) begin
                    if ( rx_data_shift[NUMBER_OF_STEPS - 1][7:0] == SKP ) begin
                        COM_detected    <= 1'b0;
                        data            <= {PATTERN_WIDTH{1'b0}};
                    end else begin
                        COM_detected <= 1'b1;
                        data[7:0]      <= rx_data_shift[NUMBER_OF_STEPS][31:24];
                        data[39:8]     <= rx_data_shift[NUMBER_OF_STEPS - 1][31:0];
                        data[71:40]    <= rx_data_shift[NUMBER_OF_STEPS - 2][31:0];
                        data[103:72]   <= rx_data_shift[NUMBER_OF_STEPS - 3][31:0];
                        data[127:104]  <= rx_data_shift[NUMBER_OF_STEPS - 4][23:0];
                    end
                end else begin
                    COM_detected <= 1'b0;
                    data <= {PATTERN_WIDTH{1'b0}};
                end
            end
        end
    endgenerate

    // Forward data to DLL when STP or SDP detected
    // Stop when END detected
    // No alignment support for now - the whole datapath is forwarded
    always @ (posedge clk or negedge L0_enabled) begin
        if (L0_enabled == 1'b0) begin
            receiving_data <= 1'b0;
            rx_data_DLL    <= { DATA_WIDTH{1'b0} };
            //rx_data_k_DLL  <= { DATA_BYTES{1'b0} };
        end else begin
            if (K_detected) begin
                receiving_data <= 1'b1;
                rx_data_DLL    <= rx_data;
                //rx_data_k_DLL <= { DATA_BYTES{1'b0} };
            end else if (END_detected) begin
                receiving_data <= 1'b0;
                rx_data_DLL    <= rx_data;
                //rx_data_k_DLL <= { DATA_BYTES{1'b0} };
            end else if (receiving_data == 1'b1)begin
                receiving_data <= 1'b1;
                rx_data_DLL    <= rx_data;
                //rx_data_k_DLL <= { DATA_BYTES{1'b0} };
            end else begin
                receiving_data <= 1'b0;
                rx_data_DLL    <= { DATA_WIDTH{1'b0} };
                //rx_data_k_DLL <= { DATA_BYTES{1'b0} };
            end
        end
    end

    // Ordered Set received validation
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
                OS_detected <= 1'b1;
                detected_Link <= data[15:8];
                detected_Lane <= data[23:16];
                detected_Ctrl <= data[47:40];
            end else begin
                OS_detected <= 1'b0;
                detected_Link <= 8'h00;
                detected_Lane <= 8'h00;
                detected_Ctrl <= 8'h00;
            end
        end
    end

    // Polarity inversion detection
    always @ (posedge clk or posedge reset) begin
        if ( reset ) begin
            inversion_detected <= 1'b0;
        end else if ( (COM_detected == 1'b1) && rx_OS_inv ) begin
            inversion_detected <= 1'b1;
        end else begin
            inversion_detected <= inversion_detected;
        end
    end

    assign TS1_pattern = {{10{ID1}}, expected_Ctrl, 8'h02, 8'h00, expected_Lane, expected_Link, COM};
    assign TS2_pattern = {{10{ID2}}, expected_Ctrl, 8'h02, 8'h00, expected_Lane, expected_Link, COM};
    assign TS1_inv     = {{10{ID1_inv}}, expected_Ctrl, 8'h02, 8'h00, expected_Lane, expected_Link, COM};
    assign TS2_inv     = {{10{ID2_inv}}, expected_Ctrl, 8'h02, 8'h00, expected_Lane, expected_Link, COM};
    assign TS1_OS      = TS1_pattern & OS_MASK;
    assign TS2_OS      = TS2_pattern & OS_MASK;
    assign TS1_OS_inv  = TS1_inv     & OS_MASK;
    assign TS2_OS_inv  = TS2_inv     & OS_MASK;
    assign TS1_valid   = TS1_pattern & VALID_MASK;
    assign TS2_valid   = TS2_pattern & VALID_MASK;
    assign data_OS     = data        & OS_MASK;
    assign data_valid  = data        & VALID_MASK;

    assign inc_count_OS   = (COM_detected == 1'b1) && rx_valid;
    assign clear_count_OS = (COM_detected == 1'b1) && !rx_valid && (rx_count_OS != max_count);

    // TS position shifted according to the COM position in the received data
    assign rx_OS     = (TS1_pattern_en && (data_OS == TS1_OS))       || (TS2_pattern_en && (data_OS == TS2_OS));
    assign rx_OS_inv = (TS1_pattern_en && (data_OS == TS1_OS_inv))   || (TS2_pattern_en && (data_OS == TS2_OS_inv));
    assign rx_valid  = (TS1_pattern_en && (data_valid == TS1_valid)) || (TS2_pattern_en && (data_valid == TS2_valid));

    // IDLE counting signals
    assign inc_count_IDL = ( rx_data_shift[NUMBER_OF_STEPS] == { DATA_WIDTH{1'b0} } );
    assign clear_count_IDL = !inc_count_IDL;

    // Rx Timeout counting signals
    assign data_timeout = (data[127:48] == {ID1, ID1, ID1, ID1, ID1, ID1, ID1, ID1, ID1, ID1}) && (data[23:16] == PAD) && (data[15:8] == PAD); // TS1 with PAD-Lane and PAD-Link
    assign inc_count_timeout = (COM_detected == 1'b1) && data_timeout;
    assign clear_count_timeout = (COM_detected == 1'b1) && !data_timeout && (rx_count_timeout != TIMEOUT_MAX_COUNT);

    // Detect special characters (STP, SDP or END) in all symbol positions
    generate
        genvar i;
        for (i = 0; i < DATA_BYTES; i = i + 1) begin
            assign char_is_K[i] = (rx_data_DLL[8*i +: 8] == STP) || (rx_data_DLL[8*i +: 8] == SDP);
            assign char_is_END[i] = (rx_data_DLL[8*i +: 8] == _END);
        end
    endgenerate

    assign K_detected = |char_is_K;
    assign END_detected = |char_is_END;

endmodule
    /*
    generate
        if ( DATA_WIDTH == 64 ) begin
            // For DATA_WIDTH = 64, COM can be at position 0 or 4 in the received data due to alignment
            // When byte_is_aligned, COM can only be at position 0 or 4 the whole time until alignment reset
            reg comma_is_middle; // COM at position 4 in the received data
            reg [31:0] data_reg; // Temporary storage for upper 4 bytes when COM is at position 4
            reg data_rx_done;
            reg data_before_COM; // COM at position 4 and there is previous data that needs to be stored
            always @ (posedge clk or posedge reset) begin
                if ( reset ) begin
                    step <= 0;
                    COM_detected <= 1'b0;
                    data <= {PATTERN_WIDTH{1'b0}};
                    comma_is_middle <= 1'b0;
                    data_rx_done <= 1'b0;
                    data_before_COM <= 1'b0;
                end
                else begin
                    if ( rx_data[7:0] == COM) begin // COM at position 0
                        COM_detected <= 1'b1;
                        data[63:0] <= rx_data;
                        step <= 1;
                        comma_is_middle <= 1'b0;
                        data_rx_done <= 1'b0;
                    end else if ( rx_data[39:32] == COM ) begin // COM at position 4
                        COM_detected <= 1'b1;
                        data_reg[31:0] <= rx_data[63:32]; // Store upper 4 bytes for next cycle
                        data[127:96] <= rx_data[31:0];    // Assign lower 4 bytes to previous sequence
                        step <= 0;
                        comma_is_middle <= 1'b1;
                        if (data_before_COM == 1'b0) begin // No previous data to be stored
                            data_before_COM <= 1'b1;
                            data_rx_done <= 1'b0;
                        end else begin // Previous data to be stored, complete assembly of previous sequence
                            data_before_COM <= 1'b1;
                            data_rx_done <= 1'b1;
                        end
                    end else if ( (step == 0) && (COM_detected == 1'b1) && (comma_is_middle == 1'b1) ) begin
                        data[31:0] <= data_reg[31:0];
                        data[95:32] <= rx_data[63:0];
                        step <= 1;
                        data_rx_done <= 1'b0;
                    end else if ( (step == 1) && (COM_detected == 1'b1) && (comma_is_middle == 1'b1) ) begin
                        data[127:96] <= rx_data[31:0];
                        data_rx_done <= 1'b1;
                        COM_detected <= 1'b0;
                        step <= 2;
                        data_before_COM <= 1'b0;
                    end else if ( (step == 1) && (COM_detected == 1'b1) && (comma_is_middle == 1'b0) ) begin
                        data[127:64] <= rx_data;
                        data_rx_done <= 1'b1;
                        COM_detected <= 1'b0;
                        step <= 2;
                    end else begin
                        step <= 0;
                        COM_detected <= 1'b0;
                        data <= {PATTERN_WIDTH{1'b0}};
                        comma_is_middle <= 1'b0;
                        data_rx_done <= 1'b0;
                    end
                end
            end

            // Ordered Set received validation
            // OS_valid = 1 for one clock cycle when an Ordered Set is correctly received
            always @ (posedge clk or posedge reset) begin
                if ( reset ) begin
                    OS_valid <= 1'b0;
                end
                else begin
                    if ( (data_rx_done == 1'b1) && rx_valid ) begin
                        OS_valid <= 1'b1;
                    end else begin
                        OS_valid <= 1'b0;
                    end
                end
            end

            // Ordered Set received detection
            // OS_detected = 1 for one clock cycle when an Ordered Set received
            always @ (posedge clk or posedge reset) begin
                if ( reset ) begin
                    OS_detected <= 1'b0;
                    detected_Link <= 8'h00;
                    detected_Lane <= 8'h00;
                end
                else begin
                    if ( (data_rx_done == 1'b1) && rx_OS ) begin
                        OS_detected <= 1'b1;
                        detected_Link <= data[15:8];
                        detected_Lane <= data[23:16];
                    end else begin
                        OS_detected <= 1'b0;
                        detected_Link <= 8'h00;
                        detected_Lane <= 8'h00;
                    end
                end
            end

            assign TS1_pattern = {ID1, ID1, ID1, ID1, ID1, ID1, ID1, ID1, ID1, ID1, expected_Ctrl, 8'h02, 8'h00, expected_Lane, expected_Link, COM};
            assign TS2_pattern = {ID2, ID2, ID2, ID2, ID2, ID2, ID2, ID2, ID2, ID2, expected_Ctrl, 8'h02, 8'h00, expected_Lane, expected_Link, COM};
            assign TS1_OS = {ID1, ID1, ID1, ID1, ID1, ID1, ID1, ID1, ID1, ID1, 8'h00, 8'h02, 8'h00, PAD, PAD, COM};
            assign TS2_OS = {ID2, ID2, ID2, ID2, ID2, ID2, ID2, ID2, ID2, ID2, 8'h00, 8'h02, 8'h00, PAD, PAD, COM};

            assign inc_count   = (data_rx_done == 1'b1) && rx_valid;
            assign clear_count = (data_rx_done == 1'b1) && !rx_valid && (rx_count != max_count);

            // TS position shifted according to the COM position in the received data
            assign rx_OS    = (TS1_pattern_en && data[127:48] == TS1_OS[127:48] && data[7:0] == COM) || (TS2_pattern_en && data[127:48] == TS2_OS[127:48] && data[7:0] == COM);
            assign rx_valid = (TS1_pattern_en && data[127:0] == TS1_pattern) || (TS2_pattern_en && data[127:0] == TS2_pattern);
        end else begin
            always @ (posedge clk or posedge reset) begin
                if ( reset ) begin
                    step <= 0;
                    COM_detected <= 1'b0;
                    data <= {PATTERN_WIDTH{1'b0}};
                end
                else begin
                    if ( rx_data[7:0] == COM ) begin
                        COM_detected <= 1'b1;
                        data[DATA_WIDTH - 1 : 0] <= rx_data;
                        step <= 1;
                    end else if ( (step != NUMBER_OF_STEPS) && (COM_detected == 1'b1) ) begin
                        data[DATA_WIDTH * step +: DATA_WIDTH] <= rx_data;
                        step <= step + 1;
                    end else begin
                        step <= 0;
                        COM_detected <= 1'b0;
                        data <= {PATTERN_WIDTH{1'b0}};
                    end
                end
            end

            // Ordered Set received validation
            // OS_valid = 1 for one clock cycle when an Ordered Set is correctly received
            always @ (posedge clk or posedge reset) begin
                if ( reset ) begin
                    OS_valid <= 1'b0;
                end
                else begin
                    if ( (step == NUMBER_OF_STEPS) && rx_valid ) begin
                        OS_valid <= 1'b1;
                    end else begin
                        OS_valid <= 1'b0;
                    end
                end
            end

            // Ordered Set received detection
            // OS_detected = 1 for one clock cycle when an Ordered Set received
            always @ (posedge clk or posedge reset) begin
                if ( reset ) begin
                    OS_detected <= 1'b0;
                    detected_Link <= 8'h00;
                    detected_Lane <= 8'h00;
                end
                else begin
                    if ( (step == NUMBER_OF_STEPS) && rx_OS ) begin
                        OS_detected <= 1'b1;
                        detected_Link <= data[15:8];
                        detected_Lane <= data[23:16];
                    end else begin
                        OS_detected <= 1'b0;
                        detected_Link <= 8'h00;
                        detected_Lane <= 8'h00;
                    end
                end
            end

            assign TS1_pattern = {ID1, ID1, ID1, ID1, ID1, ID1, ID1, ID1, ID1, ID1, expected_Ctrl, 8'h02, 8'h00, expected_Lane, expected_Link, COM};
            assign TS2_pattern = {ID2, ID2, ID2, ID2, ID2, ID2, ID2, ID2, ID2, ID2, expected_Ctrl, 8'h02, 8'h00, expected_Lane, expected_Link, COM};
            assign TS1_OS = {ID1, ID1, ID1, ID1, ID1, ID1, ID1, ID1, ID1, ID1, 8'h00, 8'h02, 8'h00, PAD, PAD, COM};
            assign TS2_OS = {ID2, ID2, ID2, ID2, ID2, ID2, ID2, ID2, ID2, ID2, 8'h00, 8'h02, 8'h00, PAD, PAD, COM};

            assign inc_count   = (step == NUMBER_OF_STEPS) && rx_valid;
            assign clear_count = (step == NUMBER_OF_STEPS) && !rx_valid && (rx_count != max_count);

            // TS position shifted according to the COM position in the received data
            assign rx_OS    = (TS1_pattern_en && data[127:48] == TS1_OS[127:48] && data[7:0] == COM) || (TS2_pattern_en && data[127:48] == TS2_OS[127:48] && data[7:0] == COM);
            assign rx_valid = (TS1_pattern_en && data[127:0] == TS1_pattern) || (TS2_pattern_en && data[127:0] == TS2_pattern);
        end
    endgenerate
    */