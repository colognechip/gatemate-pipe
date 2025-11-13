// Count number of transmitted Ordered Sets sequences after receiving one Ordered Set sequence
module ccfpga_tx_count #(
    parameter COUNT_WIDTH = 5,
    parameter DATA_BYTES  = 8,
    parameter DATA_WIDTH  = DATA_BYTES * 8,
    parameter IDLE_WIDTH  = 8
    )
    (
    input wire clk,
    input wire OS_reset_flag,
    input wire IDLE_reset_flag,
    input wire polling_active_reset_flag,

    input wire OS_sent,
    input wire OS_valid,
    input wire IDLE_sent,
    input wire IDLE_detected,
    input wire [COUNT_WIDTH - 1 : 0] OS_max_count,

    output wire OS_count_maxed,
    output wire IDLE_count_maxed,
    output wire polling_active_count_maxed
    );

    localparam IDLE_MAX_COUNT = 16;
    localparam POLLING_ACTIVE_MAX_COUNT = 1024;
    localparam NUMBER_OF_STEPS = DATA_WIDTH / IDLE_WIDTH;

    reg [COUNT_WIDTH - 1 : 0] OS_tx_count;
    reg [COUNT_WIDTH - 1 : 0] IDLE_tx_count;
    reg [10:0] polling_active_tx_count;
    reg OS_count_enabled;
    reg IDLE_count_enabled;

    // Pattern counting
    always @ (posedge clk or posedge OS_reset_flag) begin
        if ( OS_reset_flag ) begin
            OS_tx_count <= {COUNT_WIDTH{1'b0}};
        end 
        else if ( OS_count_enabled == 1'b1 ) begin
            if ( OS_tx_count == OS_max_count ) begin
                OS_tx_count <= OS_tx_count;
            end else if (OS_sent) begin
                OS_tx_count <= OS_tx_count + 1'b1;
            end
        end
    end

    // IDLE counting
    always @ (posedge clk or posedge IDLE_reset_flag) begin
        if ( IDLE_reset_flag ) begin
            IDLE_tx_count <= {COUNT_WIDTH{1'b0}};
        end 
        else if ( IDLE_count_enabled == 1'b1 ) begin
            if ( IDLE_tx_count == IDLE_MAX_COUNT ) begin
                IDLE_tx_count <= IDLE_tx_count;
            end else if (IDLE_sent) begin
                IDLE_tx_count <= IDLE_tx_count + NUMBER_OF_STEPS;
            end
        end
    end

    // Polling Active counting
    always @ (posedge clk or posedge polling_active_reset_flag) begin
        if ( polling_active_reset_flag ) begin
            polling_active_tx_count <= {10{1'b0}};
        end 
        else begin
            if ( polling_active_tx_count == POLLING_ACTIVE_MAX_COUNT ) begin
                polling_active_tx_count <= polling_active_tx_count;
            end else if (OS_sent) begin
                polling_active_tx_count <= polling_active_tx_count + 1'b1;
            end
        end
    end

    // Enable counting after an Ordered Set is detected
    always @ (posedge clk or posedge OS_reset_flag) begin
        if ( OS_reset_flag ) begin
            OS_count_enabled <= 1'b0;
        end else if ( OS_valid ) begin
            OS_count_enabled <= 1'b1;
        end
    end

    // Enable IDLE counting after an IDLE is detected
    always @ (posedge clk or posedge IDLE_reset_flag) begin
        if ( IDLE_reset_flag ) begin
            IDLE_count_enabled <= 1'b0;
        end else if ( IDLE_detected ) begin
            IDLE_count_enabled <= 1'b1;
        end
    end

    assign OS_count_maxed = (OS_tx_count == OS_max_count) ? 1'b1 : 1'b0;
    assign IDLE_count_maxed = (IDLE_tx_count == IDLE_MAX_COUNT) ? 1'b1 : 1'b0;
    assign polling_active_count_maxed = (polling_active_tx_count == POLLING_ACTIVE_MAX_COUNT) ? 1'b1 : 1'b0;

endmodule