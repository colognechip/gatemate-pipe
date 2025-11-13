// LFSR with polynomial x^16 + x^5 + x^4 +x^3 +1
// Parallel scrambler

module ccfpga_scrambler #(
    parameter DATA_BYTES   = 8,
    parameter DATA_WIDTH   = DATA_BYTES*8,
    parameter LENGTH       = $clog2(DATA_BYTES)
)
(
    input wire clk,
    input wire reset,
    input wire scrambler_en,
    input wire  [DATA_WIDTH - 1 : 0] data_in,
    input wire  [DATA_BYTES - 1 : 0] data_in_k,
    input wire  [DATA_BYTES - 1 : 0] data_in_TS,

    output wire [DATA_WIDTH - 1 : 0] data_out,
    output wire [DATA_BYTES - 1 : 0] data_out_k
);

    localparam LFSR_WIDTH = 16;

    reg [DATA_WIDTH - 1 : 0] scrambled_data_reg, scrambled_data_next;
    reg               [15:0] first_lfsr, first_lfsr_next;

    wire [LFSR_WIDTH*DATA_BYTES - 1 : 0] lfsr_vector;
    wire [LFSR_WIDTH*DATA_BYTES - 1 : 0] lfsr_out;
    wire            [DATA_WIDTH - 1 : 0] lfsr_value;

    always @(posedge clk or posedge reset) begin
        if ( reset ) begin
            first_lfsr         <= 16'hFFFF;
            scrambled_data_reg <= {DATA_WIDTH{1'b0}};
        end else begin
            first_lfsr         <= first_lfsr_next;
            scrambled_data_reg <= scrambled_data_next;
        end
    end

    assign lfsr_vector = {lfsr_out[LFSR_WIDTH*(DATA_BYTES-1) - 1 : 0], first_lfsr};

    // Generate scrambler_value for each byte
    genvar i;
    generate
        for (i = 0; i < DATA_BYTES; i = i + 1) begin
            ccfpga_scrambler_byte scrambler_byte_inst (
                .data_in               (data_in[i*8 +: 8]),
                .scrambler_en          (scrambler_en),
                .lfsr_in               (lfsr_vector[i*LFSR_WIDTH +: LFSR_WIDTH]),
                .lfsr_out              (lfsr_out[i*LFSR_WIDTH +: LFSR_WIDTH]),
                .data_out              (lfsr_value[i*8 +: 8])
            );
        end
    endgenerate

    ccfpga_scrambler_data #(
        .DATA_BYTES (DATA_BYTES)
    ) scrambler_data_inst (
        .data_in               (data_in),
        .data_in_k             (data_in_k),
        .data_in_TS            (data_in_TS),
        .scrambler_en          (scrambler_en),
        .lfsr_value            (lfsr_value),
        .data_out              (scrambled_data_next)
    );

    assign data_out        = scrambled_data_reg;
    assign first_lfsr_next = lfsr_out[LFSR_WIDTH*DATA_BYTES - 1 -: LFSR_WIDTH];
    assign data_out_k      = data_in_k;

endmodule