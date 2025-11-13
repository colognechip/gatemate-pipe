`timescale 1ns/100fs

module tx_count_tb();

    // Parameters
    parameter CLK_PERIOD = 32; // 31.25MHz

    // Inputs
    reg         clk;
    reg         reset;
    reg         OS_sent;
    reg         OS_valid;
    reg [3:0]   max_count;

    wire        count_flag;

    // Instantiate the Unit Under Test (UUT)
    ccfpga_tx_count #(
        .COUNT_WIDTH(4)
    ) uut (
        .clk(clk),
        .OS_reset_flag(reset),
        .IDLE_reset_flag(1'b1),
        .polling_active_reset_flag(1'b1),

        .OS_sent(OS_sent),
        .OS_valid(OS_valid),
        .IDLE_sent(1'b0),
        .IDLE_detected(1'b0),
        .OS_max_count(max_count),

        .OS_count_maxed(count_flag),
        .IDLE_count_maxed(),
        .polling_active_count_maxed()
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
        OS_valid = 0;
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
        OS_valid = 1;
        $display("OS_valid asserted");
        $display("Max_count set to: %d", max_count);
        #(CLK_PERIOD);
        OS_valid = 0;
        $display("OS_valid deasserted");
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
        OS_valid = 1; // Should not affect counting
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
        OS_valid = 1;
        $display("OS_valid asserted, count_flag: %b", count_flag);
        #(CLK_PERIOD);
        OS_valid = 0;
        $display("OS_valid deasserted, count_flag: %b", count_flag);
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