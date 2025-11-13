`timescale 1ns/100fs

module tx_count_tb();

    // Parameters
    parameter CLK_PERIOD = 32; // 31.25MHz

    // Inputs
    reg         clk;
    reg         reset;
    reg         OS_sent;
    reg         OS_detected;
    reg [3:0]   max_count;

    // Instantiate the Unit Under Test (UUT)
    tx_count #(
        .COUNT_WIDTH(4)
    ) uut (
        .clk(clk),
        .reset(reset),
        .OS_sent(OS_sent),
        .OS_detected(OS_detected),
        .max_count(max_count),

        .count_maxed(count_flag)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Test sequence
    initial begin
        // Initialize Inputs
        reset = 1;
        OS_detected = 0;
        OS_sent = 0;
        max_count = 4'd4;

        // Wait for global reset to finish
        #(CLK_PERIOD * 10);
        reset = 0;

        // Add stimulus
        $display("---------------------------------------------");
        $display("  Reset Deasserted - Start Test Sequence     ");
        $display("---------------------------------------------");
        #(CLK_PERIOD * 10);
        OS_detected = 1;
        $display("OS_detected asserted");
        $display("Max_count set to: %d", max_count);
        #(CLK_PERIOD);
        OS_detected = 0;
        $display("OS_detected deasserted");
        #(CLK_PERIOD * 10);
        OS_sent = 1;
        $display("OS_sent asserted, count_flag: %b", count_flag);
        #(CLK_PERIOD);
        OS_sent = 0;
        $display("OS_sent deasserted, count_flag: %b", count_flag);
        #(CLK_PERIOD*2);
        OS_sent = 1;
        $display("OS_sent asserted, count_flag: %b", count_flag);
        #(CLK_PERIOD);
        OS_sent = 0;
        $display("OS_sent deasserted, count_flag: %b", count_flag);
        #(CLK_PERIOD*2);
        OS_sent = 1;
        OS_detected = 1; // Should not affect counting
        $display("OS_sent asserted, count_flag: %b", count_flag);
        #(CLK_PERIOD);
        OS_sent = 0;
        $display("OS_sent deasserted, count_flag: %b", count_flag);
        #(CLK_PERIOD*2);
        OS_sent = 1;
        $display("OS_sent asserted, count_flag: %b", count_flag);
        #(CLK_PERIOD);
        OS_sent = 0;
        $display("4 OSs sent, count_flag: %b", count_flag);
        #(CLK_PERIOD*2);
        OS_sent = 1;
        $display("OS_sent asserted, count_flag: %b", count_flag);
        #(CLK_PERIOD);
        OS_sent = 0;
        $display("OS_sent deasserted, count_flag: %b", count_flag);
        #(CLK_PERIOD*2);
        OS_sent = 1;
        $display("OS_sent asserted, count_flag: %b", count_flag);
        #(CLK_PERIOD);
        OS_sent = 0;
        $display("OS_sent deasserted, count_flag: %b", count_flag);
        #(CLK_PERIOD*2);
        OS_sent = 1;
        $display("OS_sent asserted, count_flag: %b", count_flag);
        #(CLK_PERIOD);
        OS_sent = 0;
        #(CLK_PERIOD);
        reset = 1; // Reset the counter
        $display("Reset, count_flag: %b", count_flag);
        #2;
        reset = 0;
        max_count = 4'd2; // Change max_count
        $display("Max_count set to: %d", max_count);
        $display("Reset deasserted, count_flag: %b", count_flag);
        #(CLK_PERIOD * 10 - 2);
        OS_detected = 1;
        $display("OS_detected, count_flag: %b", count_flag);
        #(CLK_PERIOD);
        OS_detected = 0;
        $display("OS_detected deasserted, count_flag: %b", count_flag);
        #(CLK_PERIOD * 10);
        OS_sent = 1;
        $display("OS_sent asserted, count_flag: %b", count_flag);
        #(CLK_PERIOD);
        OS_sent = 0;
        $display("OS_sent deasserted, count_flag: %b", count_flag);
        #(CLK_PERIOD*2);
        OS_sent = 1;
        $display("OS_sent asserted, count_flag: %b", count_flag);
        #(CLK_PERIOD);
        OS_sent = 0;
        $display("OS_sent deasserted, count_flag: %b", count_flag);
        $display("2 OSs sent, count_flag: %b", count_flag);
        #(CLK_PERIOD*2);
        OS_sent = 1;
        $display("OS_sent asserted, count_flag: %b", count_flag);

        $finish;
    end
endmodule