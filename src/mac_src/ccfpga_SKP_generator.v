//------------------------------------------------------------------------------
// Description: This module generates SKP OS for compensating the clock mismatch
// - SKP OS needs to be sent between 1180 to 1538 symbol times
//==============================================================================

module ccfpga_SKP_generator #(
    parameter SKP_WIDTH  = 32,
    parameter DATA_BYTES = 8,
    parameter DATA_WIDTH = DATA_BYTES*8
    )
    (
    input wire clk,
    input wire reset,
    input wire sending_data,
    input wire sending_OS,
    input wire sending_IDLE,

    output wire SKP_in_queue,
    output reg [DATA_WIDTH - 1 : 0] txdata,
    output reg [DATA_BYTES - 1 : 0] txdatak,
    output reg sending_SKP
    );

    localparam COUNT_MIN   = (1180 - 1)/DATA_BYTES + 1;
    localparam COUNT_MAX   = (1538 - 1)/DATA_BYTES + 1;
    localparam COUNT_WIDTH = $clog2(COUNT_MAX) + 1;

    reg             [3:0] number_of_queued_SKP;
    reg [COUNT_WIDTH-1:0] s_count;

    wire SKP_count_inc;
    wire SKP_send_enable;

    localparam  COM    = 8'hBC; // K28.5
    localparam  SKP    = 8'h1C; // K28.0
    wire [31:0] SKP_OS = {SKP, SKP, SKP, COM}; // SKP Ordered Set

    always@(posedge clk or posedge reset) begin
        if (reset) begin
            s_count     <= {COUNT_WIDTH{1'b0}};
        end
        else begin
            if (s_count == COUNT_MAX) begin
                s_count <= 0;
            end
            else begin
                s_count <= s_count + 1'b1;
            end
        end
    end

    generate
        if (DATA_WIDTH == 64) begin
            always @(posedge clk or posedge reset) begin
                if (reset) begin
                    txdata               <= {DATA_WIDTH{1'b0}};
                    txdatak              <= {DATA_BYTES{1'b0}};
                    sending_SKP          <= 1'b0;
                    number_of_queued_SKP <= 4'b0;
                end else if (SKP_send_enable) begin
                    if (number_of_queued_SKP >= DATA_WIDTH/SKP_WIDTH) begin
                        // Send 2 SKP OSs at once if more than 1 are queued
                        // Subtract only 1 SKP from the queue as one is added
                        txdata               <= {SKP_OS, SKP_OS};
                        txdatak              <= {DATA_BYTES{1'b1}};
                        sending_SKP          <= 1'b1;
                        if (SKP_count_inc)
                            number_of_queued_SKP <= number_of_queued_SKP - 1'b1;
                        else
                            number_of_queued_SKP <= number_of_queued_SKP - DATA_WIDTH/SKP_WIDTH;
                    end else if (number_of_queued_SKP == 1) begin
                        // Send 2 SKP OSs at once if one SKP is queued and one is added
                        if (SKP_count_inc) begin
                            txdata               <= {SKP_OS, SKP_OS};
                            txdatak              <= {DATA_BYTES{1'b1}};
                        end else begin
                            txdata               <= {32'h00000000, SKP_OS};
                            txdatak              <= 8'b00001111;
                        end
                        sending_SKP          <= 1'b1;
                        number_of_queued_SKP <= 4'b0;
                    end else if (number_of_queued_SKP == 0 && SKP_count_inc) begin
                        // Send 1 SKP OS with IDLE data
                        txdata               <= {32'h00000000, SKP_OS};
                        txdatak              <= 8'b00001111;
                        sending_SKP          <= 1'b1;
                        number_of_queued_SKP <= 4'b0;
                    end else begin
                        // No SKP OS to send
                        txdata               <= {DATA_WIDTH{1'b0}};
                        txdatak              <= {DATA_BYTES{1'b0}};
                        sending_SKP          <= 1'b0;
                        number_of_queued_SKP <= 4'b0;
                    end
                end else if (SKP_count_inc) begin
                    txdata               <= {DATA_WIDTH{1'b0}};
                    txdatak              <= {DATA_BYTES{1'b0}};
                    sending_SKP          <= 1'b0;
                    number_of_queued_SKP <= number_of_queued_SKP + 1'b1;
                end else begin
                    txdata               <= {DATA_WIDTH{1'b0}};
                    txdatak              <= {DATA_BYTES{1'b0}};
                    sending_SKP          <= 1'b0;
                    number_of_queued_SKP <= number_of_queued_SKP;
                end
            end
        end else begin
            localparam NUMBER_OF_STEP = SKP_WIDTH / DATA_WIDTH;
            reg [$clog2(NUMBER_OF_STEP):0] step_count;

            always @(posedge clk or posedge reset) begin
                if (reset) begin
                    txdata               <= {DATA_WIDTH{1'b0}};
                    txdatak              <= {DATA_BYTES{1'b0}};
                    sending_SKP          <= 1'b0;
                    number_of_queued_SKP <= 4'b0;
                    step_count           <= 0;
                end else if (SKP_send_enable) begin
                    if (step_count < (NUMBER_OF_STEP - 1)) begin
                        txdata               <= SKP_OS[step_count*DATA_WIDTH - 1 +: DATA_WIDTH];
                        txdatak              <= {DATA_BYTES{1'b1}};
                        sending_SKP          <= 1'b1;
                        if (SKP_count_inc)
                            number_of_queued_SKP <= number_of_queued_SKP + 1'b1;
                        else
                            number_of_queued_SKP <= number_of_queued_SKP;
                        step_count           <= step_count + 1'b1;
                    end else if (step_count == (NUMBER_OF_STEP - 1)) begin
                        txdata               <= SKP_OS[step_count*DATA_WIDTH - 1 +: DATA_WIDTH];
                        txdatak              <= {DATA_BYTES{1'b1}};
                        sending_SKP          <= 1'b1;
                        if (SKP_count_inc)
                            number_of_queued_SKP <= number_of_queued_SKP;
                        else
                            number_of_queued_SKP <= number_of_queued_SKP - 1'b1;
                        step_count           <= 0;
                    end
                end else begin
                    txdata               <= {DATA_WIDTH{1'b0}};
                    txdatak              <= {DATA_BYTES{1'b0}};
                    sending_SKP          <= 1'b0;
                    number_of_queued_SKP <= number_of_queued_SKP;
                    step_count           <= 0;
                end
            end
        end
    endgenerate

    assign SKP_count_inc   = s_count == COUNT_MIN;
    assign SKP_send_enable = (number_of_queued_SKP != 4'b0) && (sending_data == 1'b0) && (sending_OS == 1'b0) && (sending_IDLE == 1'b0);
    assign SKP_in_queue    = (number_of_queued_SKP != 4'b0);

endmodule
