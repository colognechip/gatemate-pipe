`timescale 1ns/100fs

module send_IDLE_tb();

    // Parameters
    parameter CLK_PERIOD = 32; // 31.25MHz

    // Inputs
    reg clk;
    reg send_IDLE_trigger;
    reg reset_n;
    wire [63:0] txdata;
    wire [7:0] txdatak;
    wire IDLE_sent;

    // Instantiate the Unit Under Test (UUT)
    send_IDLE #(
        .IDLE_WIDTH(8),
        .DATA_BYTES(8)
    ) uut (
        .clk(clk),
        .send_IDLE_trigger(send_IDLE_trigger),
        .reset_n(reset_n),

        .txdata(txdata),
        .txdatak(txdatak),
        .IDLE_sent(IDLE_sent)
   );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Test sequence
    initial begin
        // Initialize Inputs
        send_IDLE_trigger = 0;
        reset_n = 0;

        #(CLK_PERIOD * 10);
        reset_n = 1;
        // Add stimulus
        $display("---------------------------------------------");
        $display("  Reset Deasserted - Start Test Sequence     ");
        $display("---------------------------------------------");
        #(CLK_PERIOD * 10);
        send_IDLE_trigger = 1;
        $display("send_IDLE_trigger asserted");
        #(CLK_PERIOD);
        $display("txdata: %h, txdatak: %h, IDLE_sent: %b", txdata, txdatak, IDLE_sent);
        #(CLK_PERIOD);
        $display("txdata: %h, txdatak: %h, IDLE_sent: %b", txdata, txdatak, IDLE_sent);
        #(CLK_PERIOD);
        $display("txdata: %h, txdatak: %h, IDLE_sent: %b", txdata, txdatak, IDLE_sent);
        #(CLK_PERIOD);
        $display("txdata: %h, txdatak: %h, IDLE_sent: %b", txdata, txdatak, IDLE_sent);
        #(CLK_PERIOD);
        $display("txdata: %h, txdatak: %h, IDLE_sent: %b", txdata, txdatak, IDLE_sent);
        
        $finish;
    end
endmodule