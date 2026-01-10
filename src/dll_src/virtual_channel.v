module virtual_channel #
(
    parameter DATA_BYTES = 8,
    parameter DATA_WIDTH = DATA_BYTES * 8,
    parameter PATTERN_WIDTH = 64
)
(
    input  wire                         i_clk,
    input  wire                         i_reset,
    input  wire                         i_linkup,
    input  wire                         i_virtual_channel,
    input  wire        [DATA_WIDTH-1:0] rx_data,
    input  wire        [DATA_WIDTH-1:0] tx_data_TL,
    input  wire        [DATA_BYTES-1:0] tx_data_TL_k,

    output wire        [DATA_WIDTH-1:0] txdata,
    output wire        [DATA_BYTES-1:0] txdatak,
    output wire        [DATA_WIDTH-1:0] rx_data_TL,
    output reg         [DATA_BYTES-1:0] rx_data_TL_k
);
    // FSM
    wire initfc1_en;
    wire initfc2_en;
    // Tx side
    wire dllp_initfc1_sent;
    wire dllp_initfc2_sent;
    // Rx side
    wire [PATTERN_WIDTH-1:0] data_DLLP;
    wire [DATA_WIDTH-1:0] data_TL;
    wire [1:0] update_type;
    wire [1:0] packet_type;
    wire [7:0] hdrfc;
    wire [11:0] datafc;
    wire crc_valid;
    wire SDP_detected;

    reg [2:0] initfc1_received_flag;
    reg initfc1_seq_received;
    reg [2:0] initfc2_received_flag;
    reg initfc2_seq_received;

    dllp_assembly #(
        .DATA_BYTES(DATA_BYTES),
        .PATTERN_WIDTH(PATTERN_WIDTH)
    ) dllp_assembly_inst (
        .clk(clk),
        .reset(reset),
        .rx_data(rx_data),
        .SDP_detected(SDP_detected),
        .data_DLLP(data_DLLP),
        .data_TL(data_TL)
    );

    virtual_channel_rx #(
        .DATA_BYTES(DATA_BYTES),
        .PATTERN_WIDTH(PATTERN_WIDTH)
    ) vc_rx (
        .clk(clk),
        .reset(reset),
        .rx_data_DLL(data_DLLP),
        .SDP_detected(SDP_detected),
        .rx_data(data_TL),

        .update_type(update_type),
        .packet_type(packet_type),
        .hdrfc(hdrfc),
        .datafc(datafc),
        .crc_valid(crc_valid),
        .rx_data_TL(rx_data_TL)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            initfc1_received_flag <= 3'b000;
            initfc2_received_flag <= 3'b000;
        end else if (crc_valid) begin
            if (initfc1_en) begin
                if ({update_type, packet_type} == 4'b0100) begin
                    initfc1_received_flag[0] <= 1'b1;
                end else if ({update_type, packet_type} == 4'b0101) begin
                    initfc1_received_flag[1] <= 1'b1;
                end else if ({update_type, packet_type} == 4'b0110) begin
                    initfc1_received_flag[2] <= 1'b1;
                end
            end else if (initfc2_en) begin
                if ({update_type, packet_type} == 4'b1100) begin
                    initfc2_received_flag[0] <= 1'b1;
                end else if ({update_type, packet_type} == 4'b1101) begin
                    initfc2_received_flag[1] <= 1'b1;
                end else if ({update_type, packet_type} == 4'b1110) begin
                    initfc2_received_flag[2] <= 1'b1;
                end
            end
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            initfc1_seq_received <= 1'b0;
            initfc2_seq_received <= 1'b0;
        end else if (&initfc1_received_flag) begin
            initfc1_seq_received <= 1'b1;
        end else if (&initfc2_received_flag) begin
            initfc2_seq_received <= 1'b1;
        end
    end

    // TODO: Add credit update
    // TODO: Only send InitFC every 34us

    virtual_channel_tx # (
        .DATA_BYTES(DATA_BYTES),
        .PATTERN_WIDTH(64)
    ) vc_tx (
        .clk(clk),
        .reset(reset),

        .dllp_type(),
        .data(),

        .initfc1_en(initfc1_en),
        .initfc2_en(initfc2_en),
        .dllp_en(),
        .tlp_en(),
        .tx_data_TL(tx_data_TL),

        .dllp_sent(),
        .dllp_initfc1_sent(dllp_initfc1_sent),
        .dllp_initfc2_sent(dllp_initfc2_sent),
        .txdata(txdata),
        .txdatak(txdatak)
    );

    dll_fsm #(
        .DATA_BYTES(DATA_BYTES)
    ) init_fsm (
        .reset(reset),
        .i_clk(clk),
        .i_LinkUp(i_LinkUp),
        .i_initfc1_rx_done(initfc1_seq_received),
        .i_initfc1_tx_done(dllp_initfc1_sent),
        .i_initfc2_rx_done(initfc2_seq_received),
        .i_initfc2_tx_done(dllp_initfc2_sent),

        .o_initfc1_en(initfc1_en),
        .o_initfc2_en(initfc2_en),
        .o_fsm_state()
    );

endmodule
