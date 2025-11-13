module ccfpga_scrambler_byte(
    input wire  [7:0] data_in,
    input wire        scrambler_en,
    input wire [15:0] lfsr_in,
    output reg [15:0] lfsr_out,
    output wire [7:0] data_out
    );

    reg [7:0] data_c;

    localparam COM = 8'hBC;
    localparam SKP = 8'h1C;

    always @(*) begin
        if (data_in == COM) begin // Initialize LFSR on COM
            lfsr_out = 16'hFFFF;
        end else if (data_in == SKP || !scrambler_en) begin // no advancement of LFSR for SKP
            lfsr_out = lfsr_in;
        end else begin
            lfsr_out[0] = lfsr_in[8];
            lfsr_out[1] = lfsr_in[9];
            lfsr_out[2] = lfsr_in[10];
            lfsr_out[3] = lfsr_in[8] ^ lfsr_in[11];
            lfsr_out[4] = lfsr_in[8] ^ lfsr_in[9] ^ lfsr_in[12];
            lfsr_out[5] = lfsr_in[8] ^ lfsr_in[9] ^ lfsr_in[10] ^ lfsr_in[13];
            lfsr_out[6] = lfsr_in[9] ^ lfsr_in[10] ^ lfsr_in[11] ^ lfsr_in[14];
            lfsr_out[7] = lfsr_in[10] ^ lfsr_in[11] ^ lfsr_in[12] ^ lfsr_in[15];
            lfsr_out[8] = lfsr_in[0] ^ lfsr_in[11] ^ lfsr_in[12] ^ lfsr_in[13];
            lfsr_out[9] = lfsr_in[1] ^ lfsr_in[12] ^ lfsr_in[13] ^ lfsr_in[14];
            lfsr_out[10] = lfsr_in[2] ^ lfsr_in[13] ^ lfsr_in[14] ^ lfsr_in[15];
            lfsr_out[11] = lfsr_in[3] ^ lfsr_in[14] ^ lfsr_in[15];
            lfsr_out[12] = lfsr_in[4] ^ lfsr_in[15];
            lfsr_out[13] = lfsr_in[5];
            lfsr_out[14] = lfsr_in[6];
            lfsr_out[15] = lfsr_in[7];
            // XOR with data_in is performed in another block
            data_c[0] = lfsr_in[15];
            data_c[1] = lfsr_in[14];
            data_c[2] = lfsr_in[13];
            data_c[3] = lfsr_in[12];
            data_c[4] = lfsr_in[11];
            data_c[5] = lfsr_in[10];
            data_c[6] = lfsr_in[9];
            data_c[7] = lfsr_in[8];
        end
    end

    assign data_out = data_c;

endmodule