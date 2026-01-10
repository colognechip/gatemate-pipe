// Separate sending InitFC logic
module virtual_channel_tx #
(
    parameter DATA_BYTES = 8,
    parameter DATA_WIDTH = DATA_BYTES * 8,
    parameter PATTERN_WIDTH = 64
)
(
    input  wire                         clk,
    input  wire                         reset,

    input  wire                   [7:0] dllp_type,  // DLLP Type Field
    input  wire                  [23:0] data,       // DLLP Data Field

    input  wire                         initfc1_en, // Sending InitFC1 sequence
    input  wire                         initfc2_en, // Sending InitFC2 sequence
    input  wire                         dllp_en,    // Sending normal DLLP
    input  wire                         tlp_en,     // Sending TLP
    input  wire        [DATA_WIDTH-1:0] tx_data_TL, // Data from transaction layer

    output reg                          dllp_initfc1_sent,
    output reg                          dllp_initfc2_sent,
    output reg                          dllp_sent,
    output reg         [DATA_WIDTH-1:0] txdata,
    output reg         [DATA_BYTES-1:0] txdatak
);

    localparam  SDP = 8'h5C;
    localparam _END = 8'hFD;
    localparam NUMBER_OF_STEPS = PATTERN_WIDTH / DATA_WIDTH - 1;
    localparam INITFC_NUMBER_OF_STEPS = (PATTERN_WIDTH * 3) / DATA_WIDTH - 1;

    wire [PATTERN_WIDTH-1:0] DLLP;
    wire [PATTERN_WIDTH/8-1:0] DLLP_k;
    wire [PATTERN_WIDTH*3-1:0] DLLP_initfc1;
    wire [PATTERN_WIDTH*3/8-1:0] DLLP_initfc1_k;
    wire [PATTERN_WIDTH*3-1:0] DLLP_initfc2;
    wire [PATTERN_WIDTH*3/8-1:0] DLLP_initfc2_k;
    wire [15:0] calc_crc;

    reg  [$clog2(NUMBER_OF_STEPS) : 0] step;
    reg  [$clog2(INITFC_NUMBER_OF_STEPS) : 0] initfc_step;

    always @ (posedge clk or posedge reset) begin
        if ( reset ) begin
            txdata  <= {DATA_WIDTH{1'b0}};
            txdatak <= {DATA_BYTES{1'b0}};
            step    <= 0;
            initfc_step <= 0;
            dllp_sent <= 1'b0;
            dllp_initfc1_sent <= 1'b0;
            dllp_initfc2_sent <= 1'b0;
        end else if (dllp_en) begin
            if ( step != NUMBER_OF_STEPS ) begin
                txdata  <= DLLP[DATA_WIDTH * step +: DATA_WIDTH];
                txdatak <= DLLP_k[DATA_BYTES * step +: DATA_BYTES];
                dllp_sent <= 1'b0;
                dllp_initfc1_sent <= 1'b0;
                dllp_initfc2_sent <= 1'b0;
                step    <= step + 1;
                initfc_step <= 0;
            end else if ( step == NUMBER_OF_STEPS ) begin
                txdata  <= DLLP[DATA_WIDTH * step +: DATA_WIDTH];
                txdatak <= DLLP_k[DATA_BYTES * step +: DATA_BYTES];
                dllp_sent <= 1'b1;
                dllp_initfc1_sent <= 1'b0;
                dllp_initfc2_sent <= 1'b0;
                step    <= 0;
                initfc_step <= 0;
            end
        end else if (initfc1_en) begin
            if ( initfc_step != INITFC_NUMBER_OF_STEPS ) begin
                txdata  <= DLLP_initfc1[DATA_WIDTH * initfc_step +: DATA_WIDTH];
                txdatak <= DLLP_initfc1_k[DATA_BYTES * initfc_step +: DATA_BYTES];
                dllp_sent <= 1'b0;
                dllp_initfc1_sent <= 1'b0;
                dllp_initfc2_sent <= 1'b0;
                initfc_step <= initfc_step + 1;
                step    <= 0;
            end else if ( initfc_step == INITFC_NUMBER_OF_STEPS ) begin
                txdata  <= DLLP_initfc1[DATA_WIDTH * initfc_step +: DATA_WIDTH];
                txdatak <= DLLP_initfc1_k[DATA_BYTES * initfc_step +: DATA_BYTES];
                dllp_sent <= 1'b0;
                dllp_initfc1_sent <= 1'b1;
                dllp_initfc2_sent <= 1'b0;
                initfc_step <= 0;
                step    <= 0;
            end
        end else if (initfc2_en) begin
            if ( initfc_step != INITFC_NUMBER_OF_STEPS ) begin
                txdata  <= DLLP_initfc2[DATA_WIDTH * initfc_step +: DATA_WIDTH];
                txdatak <= DLLP_initfc2_k[DATA_BYTES * initfc_step +: DATA_BYTES];
                dllp_sent <= 1'b0;
                dllp_initfc1_sent <= 1'b0;
                dllp_initfc2_sent <= 1'b0;
                initfc_step <= initfc_step + 1;
                step    <= 0;
            end else if ( initfc_step == INITFC_NUMBER_OF_STEPS ) begin
                txdata  <= DLLP_initfc2[DATA_WIDTH * initfc_step +: DATA_WIDTH];
                txdatak <= DLLP_initfc2_k[DATA_BYTES * initfc_step +: DATA_BYTES];
                dllp_sent <= 1'b0;
                dllp_initfc1_sent <= 1'b0;
                dllp_initfc2_sent <= 1'b1;
                initfc_step <= 0;
                step    <= 0;
            end
        end else if ( tlp_en ) begin
            txdata  <= tx_data_TL;
            txdatak <= {DATA_BYTES{1'b0}};
            dllp_sent <= 1'b0;
            dllp_initfc1_sent <= 1'b0;
            dllp_initfc2_sent <= 1'b0;
            step    <= 0;
            initfc_step <= 0;
        end else begin
            txdata  <= {DATA_WIDTH{1'b0}};
            txdatak <= {DATA_BYTES{1'b0}};
            dllp_sent <= 1'b0;
            dllp_initfc1_sent <= 1'b0;
            dllp_initfc2_sent <= 1'b0;
            step    <= 0;
            initfc_step <= 0;
        end
    end

    crc_gen crc_inst (
        .clk(clk),
        .reset(reset),
        .crc_en(1'b1),
        .data_in(data[31:0]),

        .calc_crc(calc_crc)
    );

    assign DLLP = {_END, calc_crc, data, dllp_type, SDP};
    assign DLLP_k = {1'b1, 6'b0, 1'b1};
    assign DLLP_initfc1 = {_END, 8'hbc, 8'h35, 8'hf0, 8'h03, 8'h08, 8'h40, SDP,
                           _END, 8'hf6, 8'hb1, 8'h01, 8'h00, 8'h08, 8'h50, SDP,
                           _END, 8'h92, 8'hd8, 8'h00, 8'h00, 8'h00, 8'h60, SDP};
    assign DLLP_initfc1_k = {1'b1, 6'b0, 1'b1, 1'b1, 6'b0, 1'b1, 1'b1, 6'b0, 1'b1};
    assign DLLP_initfc2 = {_END, 8'hc3, 8'h4f, 8'hf0, 8'h03, 8'h08, 8'hc0, SDP,
                           _END, 8'h89, 8'hcb, 8'h01, 8'h00, 8'h08, 8'hd0, SDP,
                           _END, 8'hed, 8'ha2, 8'h00, 8'h00, 8'h00, 8'he0, SDP};
    assign DLLP_initfc2_k = {1'b1, 6'b0, 1'b1, 1'b1, 6'b0, 1'b1, 1'b1, 6'b0, 1'b1};
endmodule