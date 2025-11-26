//----------------------------------------------------------------------------------------
// Description: This module calculates the scrambled data
//========================================================================================

module ccfpga_scrambler_data #(
    parameter DATA_BYTES   = 8,
    parameter DATA_WIDTH   = DATA_BYTES*8
    )
    (
    input wire  [DATA_WIDTH - 1 : 0] data_in,
    input wire  [DATA_BYTES - 1 : 0] data_in_k,
    input wire  [DATA_BYTES - 1 : 0] data_in_TS,
    input wire                       scrambler_en,
    input wire  [DATA_WIDTH - 1 : 0] lfsr_value,
    output wire [DATA_WIDTH - 1 : 0] data_out
    );

    wire [DATA_WIDTH-1:0] scrambled_data;
    wire [DATA_BYTES-1:0] scrambler_enabled;

    genvar i;
    generate
        for(i = 0; i < DATA_BYTES; i = i + 1) begin
            assign scrambler_enabled[i] = ~(data_in_TS[i] | data_in_k[i] | ~(scrambler_en));
            // Scrambling with XOR operation
            assign scrambled_data[8*i +: 8] = data_in[8*i +: 8] ^ (lfsr_value[8*i +: 8] & {8{scrambler_enabled[i]}});
        end
    endgenerate

    assign data_out = scrambled_data;
endmodule