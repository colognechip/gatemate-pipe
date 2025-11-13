`timescale 1ns/100fs

module rx_MAC_tb();

    // Parameters
    parameter CLK_PERIOD = 32; // 31.25MHz
    parameter DATA_BYTES = 8;
    parameter DATA_WIDTH = DATA_BYTES * 8;
    parameter COUNT_WIDTH = 4;

    // Inputs
    reg clk;
    reg reset;
    reg [DATA_WIDTH-1:0] rx_data;
    reg [7:0] expected_Link;
    reg [7:0] expected_Lane;
    reg [7:0] expected_Ctrl;
    reg [COUNT_WIDTH-1:0] max_count;
    reg TS1_pattern_en;
    reg TS2_pattern_en;

    wire OS_detected;
    wire OS_valid;
    wire count_maxed;
    wire [7:0] detected_Link;
    wire [7:0] detected_Lane;

    // Instantiate the Unit Under Test (UUT)
    rx_count #(
        .COUNT_WIDTH(COUNT_WIDTH),
        .PATTERN_WIDTH(128),
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .clk(clk),
        .reset(reset),
        .rx_data(rx_data),
        .expected_Link(expected_Link),
        .expected_Lane(expected_Lane),
        .expected_Ctrl(expected_Ctrl),
        .max_count(max_count),
        .TS1_pattern_en(TS1_pattern_en),
        .TS2_pattern_en(TS2_pattern_en),

        .OS_valid(OS_valid),
        .OS_detected(OS_detected),
        .count_maxed(count_maxed),
        .detected_Link(detected_Link),
        .detected_Lane(detected_Lane)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    initial begin
        $dumpfile("uut.vcd");
        $dumpvars(0,uut);
    end

    // Test sequence
    if (DATA_BYTES == 8) begin
        initial begin
            // Initialize Inputs
            reset = 1;
            rx_data = 64'h0000000000000000;
            expected_Link = 8'h01;
            expected_Lane = 8'h02;
            expected_Ctrl = 8'h00;
            max_count = 4'd4;
            TS1_pattern_en = 1;
            TS2_pattern_en = 0;

            // Wait for global reset to finish
            #(CLK_PERIOD * 10);
            reset = 0;

            // Add stimulus
            $display("---------------------------------------------");
            $display("  Reset Deasserted - Start Test Sequence     ");
            $display("---------------------------------------------");
            $display("  Test with COM position 0  ");
            #(CLK_PERIOD * 10);
            rx_data = 64'h4A4A_0002_0002_01BC; // TS1 pattern part 1
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 64'h4A4A_4A4A_4A4A_4A4A; // TS1 pattern part 2
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 64'h4A4A_0002_0002_01BC; // TS1 pattern part 1
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 64'h4A4A_4A4A_4A4A_4A4A; // TS1 pattern part 2
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 64'h4A4A_0002_0002_01BC; // TS1 pattern part 1
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 64'h4A4A_4A4A_4A4A_4A4A; // TS1 pattern part 2
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 64'h1C1C_1CBC_4A4A_4A4A; // SKP OS
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 64'h4A00_0200_0201_BC1C; //SKP OS and TS1 pattern part 1
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 64'h4A4A_4A4A_4A4A_4A4A; // TS1 pattern part 2
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 64'h0002_01BC_4A4A_4A4A; // TS1 pattern part 1
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 64'h4A4A_4A4A_4A4A_4A4A; // TS1 pattern part 2
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 64'h4A4A_4A4A_4A4A_4A4A; // TS1 pattern part 2
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 64'h4A4A_0002_00F7_F7BC; // TS1 pattern part 1
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 64'h4A4A_4A4A_4A4A_4A4A; // TS1 pattern part 2
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            #(CLK_PERIOD);
            rx_data = 64'h0000000000000000;
            #(CLK_PERIOD*10);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            #(CLK_PERIOD);
            reset = 1;
            rx_data = 64'h0000000000000000;
            #(CLK_PERIOD * 10);
            reset = 0;

            $finish;
        end
    end else if (DATA_BYTES == 4) begin
        initial begin
            // Initialize Inputs
            reset = 1;
            rx_data = 32'h0000000000000000;
            expected_Link = 8'h01;
            expected_Lane = 8'h02;
            expected_Ctrl = 8'h00;
            max_count = 4'd4;
            TS1_pattern_en = 1;
            TS2_pattern_en = 0;

            // Wait for global reset to finish
            #(CLK_PERIOD * 10);
            reset = 0;

            // Add stimulus
            $display("---------------------------------------------");
            $display("  Reset Deasserted - Start Test Sequence     ");
            $display("---------------------------------------------");
            #(CLK_PERIOD * 10);
            rx_data = 32'h0002_01BC; // TS1 pattern part 1
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 32'h4A4A_0002; // TS1 pattern part 1
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 32'h4A4A_4A4A; // TS1 pattern part 2
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 32'h4A4A_4A4A; // TS1 pattern part 2
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 32'h0002_01BC; // TS1 pattern part 1
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 32'h4A4A_0002; // TS1 pattern part 1
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 32'h4A4A_4A4A; // TS1 pattern part 2
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 32'h4A4A_4A4A; // TS1 pattern part 2
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 32'h0002_01BC; // TS1 pattern part 1
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 32'h4A4A_0002; // TS1 pattern part 1
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 32'h4A4A_4A4A; // TS1 pattern part 2
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 32'h4A4A_4A4A; // TS1 pattern part 2
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 32'h00000000;
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 32'h00000000;
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 32'h0002_01BC; // TS1 pattern part 1
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 32'h4A4A_0002; // TS1 pattern part 1
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 32'h4A4A_4A4A; // TS1 pattern part 2
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 32'h4A4A_4A4A; // TS1 pattern part 2
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 32'h00F7_F7BC; // TS1 pattern part 1
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 32'h4A4A_0002; // TS1 pattern part 1
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 32'h4A4A_4A4A; // TS1 pattern part 2
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 32'h4A4A_4A4A; // TS1 pattern part 2
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 32'h00F7_F7BC; // TS1 pattern part 1
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 32'h4A4A_0002; // TS1 pattern part 1
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 32'h4A4A_4A4A; // TS1 pattern part 2
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            rx_data = 32'h4A4A_4A4A; // TS1 pattern part 2
            #(CLK_PERIOD);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            #(CLK_PERIOD);
            rx_data = 32'h00000000;
            #(CLK_PERIOD*10);
            $display("OS Detected: %b, OS Valid: %b", OS_detected, OS_valid);
            $display("Count Maxed: %b", count_maxed);
            $display("Detected Link: %h, Detected Lane: %h", detected_Link, detected_Lane);
            $display("Rx Data: %h", rx_data);
            $display("---------------------------------------------");
            #(CLK_PERIOD);
            #(CLK_PERIOD);
            reset = 1;
            rx_data = 32'h00000000;
            #(CLK_PERIOD * 10);
            reset = 0;

            $finish;
        end
    end
endmodule