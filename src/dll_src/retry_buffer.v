module retry_buffer #(
    parameter DATA_BYTES      = 8,
    parameter DATA_WIDTH      = DATA_BYTES * 8,
    parameter BRAM_ADDR_WIDTH = 9,
    parameter DEPTH           = 1 << BRAM_ADDR_WIDTH,
    parameter LFSR_WIDTH      = 32
)(
    input  wire                   clk,
    input  wire                   reset,

    input  wire                   tlp_valid,
    input  wire                   tlp_first,
    input  wire                   tlp_last,
    input  wire                   tlp_last_half, // only for DATA_BYTES=8
    input  wire  [DATA_WIDTH-1:0] tlp_in_data,

    input  wire            [11:0] current_seq_num, // Sequence number of the TLP being sent

    output wire                   empty,
    output wire                   full,

    input  wire                   release_flag,
    input  wire                   retransmit_flag,
    input  wire            [11:0] retransmit_seq_num, // not used

    input  wire                   tlp_sending,
    output reg                    tlp_scheduled,
    output wire  [DATA_WIDTH-1:0] tlp_out_data,
    output wire  [DATA_BYTES-1:0] tlp_out_data_k
);

    // K characters
    localparam  STP = 8'hFB;
    localparam _END = 8'hFD;

    reg [DATA_WIDTH-1:0] buffer [DEPTH-1:0];

    reg [BRAM_ADDR_WIDTH-1:0] write_ptr;
    reg [BRAM_ADDR_WIDTH-1:0] read_ptr;
    reg [BRAM_ADDR_WIDTH-1:0] word_cnt;
    reg [BRAM_ADDR_WIDTH-1:0] read_cnt;

    reg [2:0] state;

    wire last_half = (DATA_BYTES == 8) && tlp_last && tlp_last_half;
    reg  last_half_reg;

    localparam [2:0]    IDLE        = 3'b000,
                        STORE_TLP   = 3'b001,
                        STORE_CRC   = 3'b010, // not used
                        PRE_WRITE   = 3'b011,
                        WRITE_START = 3'b100,
                        SEND_TLP    = 3'b101,
                        TLP_SENT    = 3'b110;

    assign empty = (state == IDLE);
    assign full  = (state != IDLE);

    // Block RAM: one write port, one registered read port. The read address
    // is read_ptr's next value, so mem_rdata is buffer[read_ptr], as
    // the combinational read had it
    reg                       mem_we;
    reg [BRAM_ADDR_WIDTH-1:0] mem_waddr;
    reg      [DATA_WIDTH-1:0] mem_wdata;
    reg [BRAM_ADDR_WIDTH-1:0] mem_raddr;
    reg      [DATA_WIDTH-1:0] mem_rdata;

    always @(posedge clk) begin
        if (mem_we)
            buffer[mem_waddr] <= mem_wdata;
        mem_rdata <= buffer[mem_raddr];
    end

    always @(*) begin
        mem_raddr = read_ptr;
        case (state)
            IDLE:        if (tlp_valid && tlp_first && tlp_last) mem_raddr = 0;
            STORE_TLP:   if (tlp_valid && tlp_last)              mem_raddr = 0;
            WRITE_START: if (!release_flag && tlp_sending)       mem_raddr = 1;
            SEND_TLP:    if (read_cnt != word_cnt - 1)           mem_raddr = read_ptr + 1'b1;
            TLP_SENT:    if (!release_flag && retransmit_flag)   mem_raddr = 0;
            default:     ;
        endcase
    end

    assign tlp_out_data = ((state == WRITE_START) || (state == SEND_TLP))
                          ? mem_rdata : {DATA_WIDTH{1'b0}};

    assign tlp_out_data_k = (state == WRITE_START)
                            ? {{(DATA_BYTES-1){1'b0}}, 1'b1} : (state == SEND_TLP && read_cnt == word_cnt - 1)
                            ? (last_half_reg ? {{(DATA_BYTES/2){1'b0}}, 1'b1, {(DATA_BYTES/2-1){1'b0}}} : {1'b1, {(DATA_BYTES-1){1'b0}}})
                            : {DATA_BYTES{1'b0}};

    // CRC also takes sequence number into account
    // Feed sequence number first
    wire [LFSR_WIDTH-1:0] crc_seq_0;
    wire [LFSR_WIDTH-1:0] crc_seq_1;
    wire crc_en = tlp_valid && ((state == IDLE && tlp_first) || state == STORE_TLP); // enabled when sequence number and TLP available

    reg [LFSR_WIDTH-1:0] crc_state; // store current CRC state
    reg [LFSR_WIDTH-1:0] lcrc_reg; // stored but not used

    lcrc_byte seq_0 (
        .data_in ({4'b0, current_seq_num[11:8]}),
        .crc_en  ((state == IDLE && tlp_first) && tlp_valid),
        .crcIn   (crc_state),
        .crcOut  (crc_seq_0)
    );

    lcrc_byte seq_1 (
        .data_in (current_seq_num[7:0]),
        .crc_en  ((state == IDLE && tlp_first) && tlp_valid),
        .crcIn   (crc_seq_0),
        .crcOut  (crc_seq_1)
    );

    wire [LFSR_WIDTH-1:0] crc_tlp_in = (state == IDLE && tlp_first) ? crc_seq_1 : crc_state; // crc after sequence number as crc_In for first tlp word
    wire [DATA_BYTES*LFSR_WIDTH-1:0] lfsr_in;
    wire [DATA_BYTES*LFSR_WIDTH-1:0] lfsr_out;

    assign lfsr_in = {lfsr_out[(DATA_BYTES-1)*LFSR_WIDTH-1:0], crc_tlp_in};

    wire [LFSR_WIDTH-1:0] crc_next = lfsr_out[DATA_BYTES*LFSR_WIDTH-1 -: LFSR_WIDTH];

    genvar i;
    generate
        for (i = 0; i < DATA_BYTES; i = i + 1) begin : crc_bytes
            lcrc_byte crc_b (
                .data_in (tlp_in_data[i*8 +: 8]),
                .crc_en  (crc_en && (i < DATA_BYTES/2 || !last_half)),
                .crcIn   (lfsr_in [i*LFSR_WIDTH +: LFSR_WIDTH]),
                .crcOut  (lfsr_out[i*LFSR_WIDTH +: LFSR_WIDTH])
            );
        end
    endgenerate

    // bit complemented and bit-reversed for each byte
    wire [LFSR_WIDTH-1:0] crc_computed;
    genvar l;
    generate
        for (l = 0; l < 8; l = l + 1) begin : compute_lcrc
            assign crc_computed[l]    = ~crc_state[7-l];
            assign crc_computed[l+8]  = ~crc_state[15-l];
            assign crc_computed[l+16] = ~crc_state[23-l];
            assign crc_computed[l+24] = ~crc_state[31-l];
        end
    endgenerate

    // Needed in case the first payload is also the last payload
    // We need crc output in the same cycle as the first payload
    wire [LFSR_WIDTH-1:0] crc_computed_next;
    genvar m;
    generate
        for (m = 0; m < 8; m = m + 1) begin : compute_lcrc_next
            assign crc_computed_next[m]    = ~crc_next[7-m];
            assign crc_computed_next[m+8]  = ~crc_next[15-m];
            assign crc_computed_next[m+16] = ~crc_next[23-m];
            assign crc_computed_next[m+24] = ~crc_next[31-m];
        end
    endgenerate

    // Write port: one whole word a clock. A TLP word straddles two buffer
    // words (STP and the sequence number come first), so the part that starts
    // the next word waits in carry until the next TLP word completes it. The
    // last words (the rest of the TLP, the LCRC, END) go in after the last TLP
    // word: tail_word0 in PRE_WRITE at write_ptr - 1, tail_word1 (32-bit only)
    // one clock later at write_ptr. Nothing reads them before.
    wire                tlp_beat = tlp_valid && ((state == IDLE && tlp_first) || state == STORE_TLP);
    reg          [23:0] carry;
    reg [DATA_WIDTH-1:0] tail_word0;
    reg [DATA_WIDTH-1:0] tail_word1;
    reg                 tail_we0;
    reg                 tail_we1;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tail_we0 <= 1'b0;
            tail_we1 <= 1'b0;
        end else begin
            tail_we0 <= tlp_beat && tlp_last;
            tail_we1 <= tail_we0 && (DATA_WIDTH == 32);
        end
    end

    generate
        if ( DATA_WIDTH == 64 ) begin : retry_buffer_64
            always @(posedge clk) begin
                if (tlp_beat) begin
                    carry <= tlp_in_data[63:40];
                    if (state == STORE_TLP && last_half)
                        tail_word0 <= {32'b0, _END, crc_computed_next[7:0], crc_computed_next[15:8], crc_computed_next[23:16]};
                    else
                        tail_word0 <= {_END, crc_computed_next[7:0], crc_computed_next[15:8], crc_computed_next[23:16], crc_computed_next[31:24], tlp_in_data[63:40]};
                end
            end

            always @(*) begin
                mem_we    = 1'b0;
                mem_waddr = write_ptr - 1'b1;
                mem_wdata = {tlp_in_data[39:0], carry};
                if ((state == IDLE && tlp_first) && tlp_valid) begin
                    mem_we    = 1'b1;
                    mem_waddr = 0;
                    mem_wdata = {tlp_in_data[39:0], current_seq_num[7:0], {4'b0, current_seq_num[11:8]}, STP};
                end else if (state == STORE_TLP && tlp_valid) begin
                    mem_we    = 1'b1;
                    if (last_half)
                        mem_wdata = {crc_computed_next[31:24], tlp_in_data[31:0], carry};
                end else if (tail_we0) begin
                    mem_we    = 1'b1;
                    mem_wdata = tail_word0;
                end
            end
        end else if (DATA_WIDTH == 32) begin : retry_buffer_32
            always @(posedge clk) begin
                if (tlp_beat) begin
                    carry      <= tlp_in_data[31:8];
                    tail_word0 <= {crc_computed_next[31:24], tlp_in_data[31:8]};
                    tail_word1 <= {_END, crc_computed_next[7:0], crc_computed_next[15:8], crc_computed_next[23:16]};
                end
            end

            always @(*) begin
                mem_we    = 1'b0;
                mem_waddr = write_ptr - 1'b1;
                mem_wdata = {tlp_in_data[7:0], carry};
                if ((state == IDLE && tlp_first) && tlp_valid) begin
                    mem_we    = 1'b1;
                    mem_waddr = 0;
                    mem_wdata = {tlp_in_data[7:0], current_seq_num[7:0], {4'b0, current_seq_num[11:8]}, STP};
                end else if (state == STORE_TLP && tlp_valid) begin
                    mem_we    = 1'b1;
                end else if (tail_we0) begin
                    mem_we    = 1'b1;
                    mem_wdata = tail_word0;
                end else if (tail_we1) begin
                    mem_we    = 1'b1;
                    mem_waddr = write_ptr;
                    mem_wdata = tail_word1;
                end
            end
        end
    endgenerate

    // FSM
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state         <= IDLE;
            write_ptr     <= 0;
            read_ptr      <= 0;
            read_cnt      <= 0;
            word_cnt      <= 0;
            tlp_scheduled <= 1'b0;
            lcrc_reg      <= {LFSR_WIDTH{1'b0}};
            crc_state     <= {LFSR_WIDTH{1'b1}};
            last_half_reg <= 1'b0;
        end else begin
            case (state)

                IDLE: begin
                    if (tlp_valid && tlp_first) begin
                        write_ptr <= 2;
                        crc_state <= crc_next;
                        last_half_reg <= 1'b0;
                        if (tlp_last) begin // First is last
                            read_ptr <= 0;
                            state    <= PRE_WRITE;
                            word_cnt <= (DATA_WIDTH == 32) ? 3 : 2; // 32-bit datapath needs two extra words in total (one already added at the beginning)
                        end else begin
                            state    <= STORE_TLP;
                            word_cnt <= 2;
                        end
                    end
                end
                
                STORE_TLP: begin
                    if (tlp_valid) begin
                        write_ptr <= write_ptr + 1;
                        word_cnt  <= word_cnt + 1;
                        if (tlp_last) begin
                            read_ptr <= 0;
                            state    <= PRE_WRITE;
                            if (DATA_WIDTH == 32) // 32-bit datapath needs two extra words in total (one already added at the beginning)
                                word_cnt <= word_cnt + 1;

                            // Store LCRC
                            lcrc_reg <= crc_computed;
                            last_half_reg <= last_half;
                        end
                        crc_state <= crc_next;
                    end
                end

                PRE_WRITE: begin
                    state <= WRITE_START;
                end

                WRITE_START: begin
                    tlp_scheduled <= 1'b1;

                    // Release the packet
                    if (release_flag) begin
                        tlp_scheduled <= 1'b0;
                        write_ptr     <= 0;
                        word_cnt      <= 0;
                        crc_state     <= {LFSR_WIDTH{1'b1}};
                        state         <= IDLE;
                    // We want to wait for the TLP to be allowed to be sent before moving to next state
                    end else if (tlp_sending) begin
                        read_ptr      <= 1;
                        read_cnt      <= 1;
                        if (word_cnt == 1) begin
                            tlp_scheduled <= 1'b0;
                            state         <= TLP_SENT;
                        end else begin
                            state         <= SEND_TLP;
                        end
                    end
                end

                SEND_TLP: begin
                    if (read_cnt == word_cnt - 1) begin
                        tlp_scheduled <= 1'b0;
                        read_cnt      <= 0;
                        state         <= TLP_SENT;
                    end else begin
                        read_ptr     <= read_ptr + 1;
                        read_cnt     <= read_cnt + 1;
                    end
                end

                TLP_SENT: begin
                    tlp_scheduled <= 1'b0;

                    // Release the packet
                    // Buffer is then empty
                    if (release_flag) begin
                        write_ptr <= 0;
                        word_cnt  <= 0;
                        crc_state <= {LFSR_WIDTH{1'b1}};
                        state     <= IDLE;
                    // Retransmit the packet
                    // TODO: Add a counter for the retransmission
                    end else if (retransmit_flag) begin
                        read_ptr  <= 0;
                        state     <= PRE_WRITE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
