`timescale 1ns/100fs

module send_OS_tb();

    // Parameters
    parameter CLK_PERIOD = 32; // 31.25MHz

    // Inputs
    reg clk;
    reg send_OS_trigger;
    reg reset_n;
    reg [7:0] received_Link;
    reg [7:0] received_Lane;
    reg [7:0] received_Ctrl;
    reg OS_type;          // 0:TS1, 1:TS2
    wire [63:0] txdata;
    wire [7:0] txdatak;
    wire OS_sent;

    // Instantiate the Unit Under Test (UUT)
    send_OS #(
        .PATTERN_WIDTH(128),
        .DATA_BYTES(8)
    ) uut (
        .clk(clk),
        .send_OS_trigger(send_OS_trigger),
        .reset_n(reset_n),
        .received_Link(received_Link),
        .received_Lane(received_Lane),
        .received_Ctrl(received_Ctrl),
        .OS_type(OS_type),

        .txdata(txdata),
        .txdatak(txdatak),
        .OS_sent(OS_sent)
   );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Test sequence
    initial begin
        // Initialize Inputs
        send_OS_trigger = 0;
        reset_n = 0;
        received_Link = 8'hF7;
        received_Lane = 8'hF7;
        received_Ctrl = 8'h00;
        OS_type = 0;          // 0:TS1, 1:TS2

        // Wait for global reset to finish
        #(CLK_PERIOD * 10);
        reset_n = 1;

        // Add stimulus
        $display("---------------------------------------------");
        $display("  Reset Deasserted - Start Test Sequence     ");
        $display("---------------------------------------------");
        #(CLK_PERIOD * 10);
        send_OS_trigger = 1;
        $display("send_OS_trigger asserted");
        #(CLK_PERIOD);
        $display("txdata: %h, txdatak: %h, OS_sent: %b", txdata, txdatak, OS_sent);
        #(CLK_PERIOD);
        $display("txdata: %h, txdatak: %h, OS_sent: %b", txdata, txdatak, OS_sent);
        #(CLK_PERIOD);
        $display("txdata: %h, txdatak: %h, OS_sent: %b", txdata, txdatak, OS_sent);
        #(CLK_PERIOD);
        $display("txdata: %h, txdatak: %h, OS_sent: %b", txdata, txdatak, OS_sent);
        #(CLK_PERIOD);
        $display("txdata: %h, txdatak: %h, OS_sent: %b", txdata, txdatak, OS_sent);
        #(CLK_PERIOD);
        received_Link = 8'h01;
        $display("Received_Link changed to 0x01");
        $display("txdata: %h, txdatak: %h, OS_sent: %b", txdata, txdatak, OS_sent);
        #(CLK_PERIOD);
        $display("txdata: %h, txdatak: %h, OS_sent: %b", txdata, txdatak, OS_sent);
        #(CLK_PERIOD);
        $display("txdata: %h, txdatak: %h, OS_sent: %b", txdata, txdatak, OS_sent);
        #(CLK_PERIOD);
        $display("txdata: %h, txdatak: %h, OS_sent: %b", txdata, txdatak, OS_sent);
        #(CLK_PERIOD);
        $display("txdata: %h, txdatak: %h, OS_sent: %b", txdata, txdatak, OS_sent);
        #(CLK_PERIOD);
        $display("txdata: %h, txdatak: %h, OS_sent: %b", txdata, txdatak, OS_sent);
        #(CLK_PERIOD);
        received_Lane = 8'h02;
        $display("Received_Lane changed to 0x02");
        $display("txdata: %h, txdatak: %h, OS_sent: %b", txdata, txdatak, OS_sent);
        #(CLK_PERIOD);
        $display("txdata: %h, txdatak: %h, OS_sent: %b", txdata, txdatak, OS_sent);
        #(CLK_PERIOD);
        $display("txdata: %h, txdatak: %h, OS_sent: %b", txdata, txdatak, OS_sent);
        #(CLK_PERIOD);
        $display("txdata: %h, txdatak: %h, OS_sent: %b", txdata, txdatak, OS_sent);
        #(CLK_PERIOD);
        $display("txdata: %h, txdatak: %h, OS_sent: %b", txdata, txdatak, OS_sent);
        #(CLK_PERIOD);
        $display("txdata: %h, txdatak: %h, OS_sent: %b", txdata, txdatak, OS_sent);
        #(CLK_PERIOD);
        OS_type = 1;
        $display("OS_type changed to TS2");
        $display("txdata: %h, txdatak: %h, OS_sent: %b", txdata, txdatak, OS_sent);
        #(CLK_PERIOD);
        $display("txdata: %h, txdatak: %h, OS_sent: %b", txdata, txdatak, OS_sent);
        #(CLK_PERIOD);
        $display("txdata: %h, txdatak: %h, OS_sent: %b", txdata, txdatak, OS_sent);
        #(CLK_PERIOD);
        $display("txdata: %h, txdatak: %h, OS_sent: %b", txdata, txdatak, OS_sent);
        #(CLK_PERIOD);
        $display("txdata: %h, txdatak: %h, OS_sent: %b", txdata, txdatak, OS_sent);
        #(CLK_PERIOD);
        $display("txdata: %h, txdatak: %h, OS_sent: %b", txdata, txdatak, OS_sent);

        $finish;
    end
endmodule