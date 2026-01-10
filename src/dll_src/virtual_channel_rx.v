module virtual_channel_rx #
(
    parameter DATA_BYTES = 8,
    parameter DATA_WIDTH = DATA_BYTES * 8,
    parameter PATTERN_WIDTH = 64
)
(
    input  wire                         clk,
    input  wire                         reset,
    input  wire [PATTERN_WIDTH-1:0]     rx_data_DLL,
    input  wire                         SDP_detected,
    input  wire [DATA_WIDTH-1:0]        rx_data,

    output reg  [1:0]                   update_type,
    output reg  [1:0]                   packet_type,
    output reg  [7:0]                   hdrfc,
    output reg  [11:0]                  datafc,
    output reg                          crc_valid,
    output reg  [DATA_WIDTH-1:0]        rx_data_TL
);

    wire        rx_valid;
    wire [15:0] calc_crc;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            update_type       <= 2'b00;
            packet_type       <= 2'b11;
            hdrfc             <= 8'b0;
            datafc            <= 12'b0;
            crc_valid         <= 1'b0;
        end else if (SDP_detected) begin
            update_type <= rx_data_DLL[7:6];
            packet_type <= rx_data_DLL[5:4];
            hdrfc     <= {rx_data_DLL[13:8], rx_data_DLL[23:22]};
            datafc    <= {rx_data_DLL[19:16], rx_data_DLL[31:24]};
            crc_valid <= rx_valid;
        end
    end

    crc_gen crc_inst (
        .clk(clk),
        .reset(reset),
        .crc_en(SDP_detected),
        .data_in(rx_data_DLL[39:8]),

        .calc_crc(calc_crc)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_data_TL <= {DATA_WIDTH{1'b0}};
        end else if (SDP_detected) begin
            rx_data_TL <= rx_data;
        end
    end

    assign rx_valid   = calc_crc == rx_data_DLL[55:40];
endmodule