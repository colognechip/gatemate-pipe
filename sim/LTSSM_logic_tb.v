`timescale 1ns/100fs

module LTSSM_logic_tb();

    // Parameters
    parameter CLK_PERIOD = 32; // 31.25MHz
    parameter DATA_BYTES = 8;
    parameter DATA_WIDTH = DATA_BYTES*8;
    parameter ID1  = 8'h4A; // D10.2
    parameter ID2  = 8'h45; // D5.2
    parameter COM  = 8'hBC; // K28.5
    parameter SKP  = 8'h1C; // K28.0

    parameter CLK_TIMEOUT_TEST = 1'b0;
    parameter RX_TIMEOUT_TEST  = 1'b0;
    parameter POWERUP_TEST     = 1'b0;
    parameter SCRAMBLER_TEST   = 1'b0;
    parameter INVERSION_TEST   = 1'b0;

    // Inputs
    reg         clk;
    reg         i_Reset_n;        // Asynchronous Reset
    reg         i_RxValid;        // Received data is valid
    reg         i_PhyStatus;      // Physical Status
    reg  [2:0]  i_RxStatus;       // Receiver Status
    reg         i_RxElecIdle;     // Electrical Idle at Receiver
    reg  [DATA_WIDTH-1:0] i_RxData;         // Rx Data
    reg  [DATA_BYTES-1:0] i_RxDataK;        // Rx K Data
    reg  [DATA_WIDTH-1:0] i_TxData;         // Tx Data
    reg  [DATA_BYTES-1:0] i_TxDataK;        // Tx K Data

    wire o_Reset_n;                       // Asyn. Reset
    wire [1:0] o_PowerDown;               // Power states
    wire o_TxDetectRx;                    // Receiver Detection (P1)/Loopback (P0)
    wire o_TxElecIdle;                    // Electrical Idle
    wire [DATA_BYTES-1:0] o_TxCompliance; // Compliance Pattern
    wire o_RxPolarity;                    // Received data polarity
    wire [DATA_WIDTH-1:0] o_TxData;       // Tx Data
    wire [DATA_BYTES-1:0] o_TxDataK;      // Tx K Data
    wire [DATA_BYTES-1:0] o_RxDataK;      // Rx K Data
    wire [DATA_WIDTH-1:0] o_RxData;       // Rx Data
    wire o_LinkUp;                        // Link is on

    // Instantiate the Unit Under Test (UUT)
    ccfpga_LTSSM_logic #(
        .DATA_BYTES(DATA_BYTES),
        .PATTERN_WIDTH(128),
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .i_Reset_n(i_Reset_n),           // Asynchronous Reset
        .i_PCLK(clk),                    // Parallel Interface Clock
        .i_RxValid(i_RxValid),           // Received data is valid
        .i_PhyStatus(i_PhyStatus),       // Physical Status
        .i_RxStatus(i_RxStatus),         // Receiver Status
        .i_RxElecIdle(i_RxElecIdle),     // Electrical Idle at Receiver
        .i_RxData(i_RxData),             // Rx Data
        .i_RxDataK(i_RxDataK),           // Rx K Data
        .i_TxData(i_TxData),             // Tx Data
        .i_TxDataK(i_TxDataK),           // Tx K Data

        .o_Reset_n(o_Reset_n),           // Asyn. Reset
        .o_PowerDown(o_PowerDown),       // Power states
        .o_TxDetectRx(o_TxDetectRx),     // Receiver Detection (P1)/Loopback (P0)
        .o_TxElecIdle(o_TxElecIdle),     // Electrical Idle
        .o_TxCompliance(o_TxCompliance), // Compliance Pattern
        .o_RxPolarity(o_RxPolarity),     // Received data polarity
        .o_TxData(o_TxData),             // Tx Data
        .o_TxDataK(o_TxDataK),           // Tx K Data
        .o_RxData(o_RxData),             // Rx Data
        .o_RxDataK(o_RxDataK),           // Rx K Data

        .o_LinkUp(o_LinkUp)              // Link is on
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

    task receive_TS1;
        input integer cycles;
        input [7:0] Link_number;
        input [7:0] Lane_number;
        integer i;
        begin
            for (i = 0; i < cycles; i = i + 1) begin
                @(posedge clk);
                i_RxData = {ID1, ID1, 8'h00, 8'h02, 8'h00, Lane_number, Link_number, COM};
                i_RxDataK = 8'b0000_0001;
                $display("---------------------------------------------");
                $display("Power state: %b", o_PowerDown);
                $display("FSM State: %b", uut.fsm_state);
                $display("Tx Data: %b", o_TxData);
                $display("Tx DataK: %b", o_TxDataK);
                $display("Link Up: %b", o_LinkUp);
                $display("Rx flag rst: %b", uut.s_rx_flag_rst);
                $display("Tx flag rst: %b", uut.s_tx_flag_rst);
                $display("Polling active Tx flag rst: %b", uut.s_polling_active_tx_flag_rst);
                $display("Rx flag: %b", uut.s_rx_flag);
                $display("Tx flag: %b", uut.s_tx_flag);
                $display("Polling active Tx flag: %b", uut.s_polling_active_tx_flag);
                $display("---------------------------------------------");
                @(posedge clk);
                i_RxData = {ID1, ID1, ID1, ID1, ID1, ID1, ID1, ID1};
                i_RxDataK = 8'b0000_0000;
                $display("---------------------------------------------");
                $display("Power state: %b", o_PowerDown);
                $display("FSM State: %b", uut.fsm_state);
                $display("Tx Data: %b", o_TxData);
                $display("Tx DataK: %b", o_TxDataK);
                $display("Link Up: %b", o_LinkUp);
                $display("Rx flag rst: %b", uut.s_rx_flag_rst);
                $display("Tx flag rst: %b", uut.s_tx_flag_rst);
                $display("Polling active Tx flag rst: %b", uut.s_polling_active_tx_flag_rst);
                $display("Rx flag: %b", uut.s_rx_flag);
                $display("Tx flag: %b", uut.s_tx_flag);
                $display("Polling active Tx flag: %b", uut.s_polling_active_tx_flag);
                $display("---------------------------------------------");
            end
        end
    endtask

    task receive_TS2;
        input integer cycles;
        input [7:0] Link_number;
        input [7:0] Lane_number;
        integer i;
        begin
            for (i = 0; i < cycles; i = i + 1) begin
                @(posedge clk);
                i_RxData = {ID2, ID2, 8'h00, 8'h02, 8'h00, Lane_number, Link_number, COM};
                i_RxDataK = 8'b0000_0001;
                $display("---------------------------------------------");
                $display("Power state: %b", o_PowerDown);
                $display("FSM State: %b", uut.fsm_state);
                $display("Tx Data: %b", o_TxData);
                $display("Tx DataK: %b", o_TxDataK);
                $display("Link Up: %b", o_LinkUp);
                $display("Rx flag rst: %b", uut.s_rx_flag_rst);
                $display("Tx flag rst: %b", uut.s_tx_flag_rst);
                $display("Rx flag: %b", uut.s_rx_flag);
                $display("Tx flag: %b", uut.s_tx_flag);
                $display("---------------------------------------------");
                @(posedge clk);
                i_RxData = {ID2, ID2, ID2, ID2, ID2, ID2, ID2, ID2};
                i_RxDataK = 8'b0000_0000;
                $display("---------------------------------------------");
                $display("Power state: %b", o_PowerDown);
                $display("FSM State: %b", uut.fsm_state);
                $display("Tx Data: %b", o_TxData);
                $display("Tx DataK: %b", o_TxDataK);
                $display("Link Up: %b", o_LinkUp);
                $display("Rx flag rst: %b", uut.s_rx_flag_rst);
                $display("Tx flag rst: %b", uut.s_tx_flag_rst);
                $display("Rx flag: %b", uut.s_rx_flag);
                $display("Tx flag: %b", uut.s_tx_flag);
                $display("---------------------------------------------");
            end
        end
    endtask

    task receive_IDLE;
        input integer cycles;

        integer i;
        begin
            for (i = 0; i < cycles; i = i + 1) begin
                @(posedge clk);
                i_RxData = 64'h0000000000000000;
                i_RxDataK = 8'h00;
                $display("---------------------------------------------");
                $display("Power state: %b", o_PowerDown);
                $display("FSM State: %b", uut.fsm_state);
                $display("Tx Data: %b", o_TxData);
                $display("Tx DataK: %b", o_TxDataK);
                $display("Link Up: %b", o_LinkUp);
                $display("---------------------------------------------");
            end
        end
    endtask

    task receive_SKP;
        begin
            @(posedge clk);
            i_RxData = {8'h00, 8'h00, 8'h00, SKP, SKP, SKP, SKP, COM};
            i_RxDataK = 8'b00000001;
            $display("---------------------------------------------");
            $display("Power state: %b", o_PowerDown);
            $display("FSM State: %b", uut.fsm_state);
            $display("Tx Data: %b", o_TxData);
            $display("Tx DataK: %b", o_TxDataK);
            $display("Link Up: %b", o_LinkUp);
            $display("---------------------------------------------");
        end
    endtask

    task receive_TS1_inv;
        input integer cycles;
        input [7:0] Link_number;
        input [7:0] Lane_number;
        integer i;
        begin
            for (i = 0; i < cycles; i = i + 1) begin
                @(posedge clk);
                i_RxData = {~ID1, ~ID1, ~8'h00, ~8'h02, ~8'h00, ~Lane_number, ~Link_number, COM};
                i_RxDataK = 8'b0000_0001;
                $display("---------------------------------------------");
                $display("Power state: %b", o_PowerDown);
                $display("FSM State: %b", uut.fsm_state);
                $display("Tx Data: %b", o_TxData);
                $display("Tx DataK: %b", o_TxDataK);
                $display("Link Up: %b", o_LinkUp);
                $display("Rx flag rst: %b", uut.s_rx_flag_rst);
                $display("Tx flag rst: %b", uut.s_tx_flag_rst);
                $display("Polling active Tx flag rst: %b", uut.s_polling_active_tx_flag_rst);
                $display("Rx flag: %b", uut.s_rx_flag);
                $display("Tx flag: %b", uut.s_tx_flag);
                $display("Polling active Tx flag: %b", uut.s_polling_active_tx_flag);
                $display("---------------------------------------------");
                @(posedge clk);
                i_RxData = ~{ID1, ID1, ID1, ID1, ID1, ID1, ID1, ID1};
                i_RxDataK = 8'b0000_0000;
                $display("---------------------------------------------");
                $display("Power state: %b", o_PowerDown);
                $display("FSM State: %b", uut.fsm_state);
                $display("Tx Data: %b", o_TxData);
                $display("Tx DataK: %b", o_TxDataK);
                $display("Link Up: %b", o_LinkUp);
                $display("Rx flag rst: %b", uut.s_rx_flag_rst);
                $display("Tx flag rst: %b", uut.s_tx_flag_rst);
                $display("Polling active Tx flag rst: %b", uut.s_polling_active_tx_flag_rst);
                $display("Rx flag: %b", uut.s_rx_flag);
                $display("Tx flag: %b", uut.s_tx_flag);
                $display("Polling active Tx flag: %b", uut.s_polling_active_tx_flag);
                $display("---------------------------------------------");
            end
        end
    endtask

    // Test sequence
    initial begin
        // Initialize Inputs
        i_Reset_n = 0;
        i_RxValid = 1'b0;
        i_PhyStatus = 1'b0;
        i_RxStatus = 3'b000;
        i_RxElecIdle = 1'b1;
        i_RxData = 64'h0000000000000000;
        i_RxDataK = 8'h00;
        i_TxData = 64'h0000000000000000; // Don't care
        i_TxDataK = 8'h00; // Don't care

        // Add stimulus
        $display("---------------------------------------------");
        $display("  Reset Deasserted - Start Test Sequence     ");
        $display("---------------------------------------------");
        #(CLK_PERIOD * 100);

        // Wait for global reset to finish
        $display("---------------------------------------------");
        $display("Power state: %b", o_PowerDown);
        $display("FSM State: %b", uut.fsm_state);
        $display("Tx Data: %b", o_TxData);
        $display("Tx DataK: %b", o_TxDataK);
        $display("Link Up: %b", o_LinkUp);
        $display("---------------------------------------------");
        #(CLK_PERIOD * 100);
        i_Reset_n = 1;
        i_RxValid = 1'b1;
        $display("---------------------------------------------");
        $display("Power state: %b", o_PowerDown);
        $display("FSM State: %b", uut.fsm_state);
        $display("Link Up: %b", o_LinkUp);
        $display("---------------------------------------------");
        #(CLK_PERIOD * 100);
        $display("---------------------------------------------");
        $display("  Receiver detects a signal from the link partner  ");
        $display("---------------------------------------------");
        i_RxElecIdle = 1'b0; // DETECT_ACTIVE
        $display("---------------------------------------------");
        $display("Power state: %b", o_PowerDown);
        $display("FSM State: %b", uut.fsm_state);
        $display("Link Up: %b", o_LinkUp);
        $display("---------------------------------------------");
        #(CLK_PERIOD * 10);
        $display("---------------------------------------------");
        $display("Power state: %b", o_PowerDown);
        $display("FSM State: %b", uut.fsm_state);
        $display("Link Up: %b", o_LinkUp);
        $display("---------------------------------------------");
        #(CLK_PERIOD * 100);
        $display("---------------------------------------------");
        $display("  RxStatus indicates receiver detection complete  ");
        $display("---------------------------------------------");
        i_RxStatus = 3'b011; // Move to POLLING_ACTIVE
        $display("---------------------------------------------");
        $display("Power state: %b", o_PowerDown);
        $display("FSM State: %b", uut.fsm_state);
        $display("Link Up: %b", o_LinkUp);
        $display("---------------------------------------------");
        #(CLK_PERIOD * 10);
        i_RxElecIdle = 1'b1;
        $display("---------------------------------------------");
        $display("Power state: %b", o_PowerDown);
        $display("FSM State: %b", uut.fsm_state);
        $display("Link Up: %b", o_LinkUp);
        $display("---------------------------------------------");
        if (POWERUP_TEST) begin
            $display("---------------------------------------------");
            $display("Power Up Test");
            $display("---------------------------------------------");
            #(CLK_PERIOD * 100);
            $display("---------------------------------------------");
            $display("Power state: %b", o_PowerDown);
            $display("FSM State: %b", uut.fsm_state);
            $display("Link Up: %b", o_LinkUp);
            $display("---------------------------------------------");
            $display("---------------------------------------------");
            $display("  Receiving TS1 packets from link partner to move to POLLING_CONFIG  ");
            $display("---------------------------------------------");
            receive_TS1(20, 8'hF7, 8'hF7); // Move to POLLING_CONFIG
            #(CLK_PERIOD * 3000);
            $display("---------------------------------------------");
            $display("Power state: %b", o_PowerDown);
            $display("FSM State: %b", uut.fsm_state);
            $display("Link Up: %b", o_LinkUp);
            $display("Rx flag rst: %b", uut.s_rx_flag_rst);
            $display("Tx flag rst: %b", uut.s_tx_flag_rst);
            $display("Polling active Tx flag rst: %b", uut.s_polling_active_tx_flag_rst);
            $display("Rx flag: %b", uut.s_rx_flag);
            $display("Tx flag: %b", uut.s_tx_flag);
            $display("Polling active Tx flag: %b", uut.s_polling_active_tx_flag);
            $display("---------------------------------------------");
            $display("---------------------------------------------");
            $display("  Receiving TS2 packets from link partner to move to CONFIG_LINKWIDTH_START  ");
            $display("---------------------------------------------");
            receive_TS2(5, 8'hF7, 8'hF7); // Move to CONFIG_LINKWIDTH_START
            receive_TS1(1, 8'hFF, 8'hF7);
            receive_TS2(20, 8'hF7, 8'hF7);
            #(CLK_PERIOD * 1000);
            $display("---------------------------------------------");
            $display("Power state: %b", o_PowerDown);
            $display("FSM State: %b", uut.fsm_state);
            $display("Link Up: %b", o_LinkUp);
            $display("---------------------------------------------");
            $display("---------------------------------------------");
            $display("  Receiving TS1 packets from link partner to determine link number and move to CONFIG_LINKWIDTH_WAIT  ");
            $display("---------------------------------------------");
            receive_TS1(5, 8'h01, 8'hF7); // Move to CONFIG_LINKWIDTH_ACCEPT
            receive_TS1(1, 8'hF7, 8'hF7);
            receive_TS1(20, 8'h01, 8'hF7);
            #(CLK_PERIOD * 1000);
            $display("---------------------------------------------");
            $display("Power state: %b", o_PowerDown);
            $display("FSM State: %b", uut.fsm_state);
            $display("Link Up: %b", o_LinkUp);
            $display("---------------------------------------------");
            $display("---------------------------------------------");
            $display("  Receiving TS1 packets from link partner to determine lane number and move to CONFIG_COMPLETE  ");
            $display("---------------------------------------------");
            receive_TS1(20, 8'h01, 8'h02); // Move to CONFIG_COMPLETE
            #(CLK_PERIOD * 1000);
            $display("---------------------------------------------");
            $display("Power state: %b", o_PowerDown);
            $display("FSM State: %b", uut.fsm_state);
            $display("Link Up: %b", o_LinkUp);
            $display("---------------------------------------------");
            $display("---------------------------------------------");
            $display("  Receiving TS2 packets from link partner to move to CONFIG_IDLE  ");
            $display("---------------------------------------------");
            receive_TS2(20, 8'h01, 8'h02); // Move to CONFIG_IDLE
            #(CLK_PERIOD * 100);
            $display("---------------------------------------------");
            $display("Power state: %b", o_PowerDown);
            $display("FSM State: %b", uut.fsm_state);
            $display("Link Up: %b", o_LinkUp);
            $display("---------------------------------------------");
            $display("---------------------------------------------");
            $display("  Receiving IDLE packets from link partner to move to L0  ");
            $display("---------------------------------------------");
            receive_IDLE(30); // Need to disable Scrambling for this to work
            $display("---------------------------------------------");
            $display("Power state: %b", o_PowerDown);
            $display("FSM State: %b", uut.fsm_state);
            $display("Link Up: %b", o_LinkUp);
            $display("---------------------------------------------");
            $display("---------------------------------------------");
            $display("  Receiving IDLE packets from link partner to move to L0  ");
            $display("---------------------------------------------");
        end else if (CLK_TIMEOUT_TEST) begin
            $display("---------------------------------------------");
            $display("Clock Timeout Test");
            $display("---------------------------------------------");
            #(CLK_PERIOD * 100);
            $display("---------------------------------------------");
            $display("Power state: %b", o_PowerDown);
            $display("FSM State: %b", uut.fsm_state);
            $display("Link Up: %b", o_LinkUp);
            $display("---------------------------------------------");
            $display("---------------------------------------------");
            $display("  Receiving TS1 packets from link partner to move to POLLING_CONFIG  ");
            $display("---------------------------------------------");
            receive_TS1(20, 8'hF7, 8'hF7); // Move to POLLING_CONFIG
            #(CLK_PERIOD * 3000);
            $display("---------------------------------------------");
            $display("Power state: %b", o_PowerDown);
            $display("FSM State: %b", uut.fsm_state);
            $display("Link Up: %b", o_LinkUp);
            $display("Rx flag rst: %b", uut.s_rx_flag_rst);
            $display("Tx flag rst: %b", uut.s_tx_flag_rst);
            $display("Polling active Tx flag rst: %b", uut.s_polling_active_tx_flag_rst);
            $display("Rx flag: %b", uut.s_rx_flag);
            $display("Tx flag: %b", uut.s_tx_flag);
            $display("Polling active Tx flag: %b", uut.s_polling_active_tx_flag);
            $display("---------------------------------------------");
            $display("---------------------------------------------");
            $display("  Receiving TS2 packets from link partner to move to CONFIG_LINKWIDTH_START  ");
            $display("---------------------------------------------");
            receive_TS2(5, 8'hF7, 8'hF7); // Move to CONFIG_LINKWIDTH_START
            receive_TS1(1, 8'hFF, 8'hF7);
            receive_TS2(20, 8'hF7, 8'hF7);
            #(CLK_PERIOD * 1000);
            $display("---------------------------------------------");
            $display("Power state: %b", o_PowerDown);
            $display("FSM State: %b", uut.fsm_state);
            $display("Link Up: %b", o_LinkUp);
            $display("---------------------------------------------");
            $display("---------------------------------------------");
            $display("  Receiving TS1 packets from link partner to determine link number and move to CONFIG_LINKWIDTH_WAIT  ");
            $display("---------------------------------------------");
            receive_TS1(5, 8'h01, 8'hF7); // Move to CONFIG_LINKWIDTH_ACCEPT
            receive_TS1(1, 8'hF7, 8'hF7);
            receive_TS1(20, 8'h01, 8'hF7);
            receive_TS1(1, 8'h01, 8'h02);
            #(CLK_PERIOD * 1000);
            $display("---------------------------------------------");
            $display("Power state: %b", o_PowerDown);
            $display("FSM State: %b", uut.fsm_state);
            $display("Link Up: %b", o_LinkUp);
            $display("---------------------------------------------");
            i_RxData = 64'h0000000000000000;
            i_RxDataK = 8'h00;
            #(CLK_PERIOD * 62500); // Wait for clock timeout (2ms)
            $display("---------------------------------------------");
            $display("Power state: %b", o_PowerDown);
            $display("FSM State: %b", uut.fsm_state);
            $display("Link Up: %b", o_LinkUp);
            $display("End clock timeout test");
            $display("---------------------------------------------");
        end else if (RX_TIMEOUT_TEST) begin
            $display("---------------------------------------------");
            $display("Receiver Timeout Test");
            $display("---------------------------------------------");
            #(CLK_PERIOD * 100);
            $display("---------------------------------------------");
            $display("Power state: %b", o_PowerDown);
            $display("FSM State: %b", uut.fsm_state);
            $display("Link Up: %b", o_LinkUp);
            $display("---------------------------------------------");
            $display("---------------------------------------------");
            $display("  Receiving TS1 packets from link partner to move to POLLING_CONFIG  ");
            $display("---------------------------------------------");
            receive_TS1(20, 8'hF7, 8'hF7); // Move to POLLING_CONFIG
            #(CLK_PERIOD * 3000);
            $display("---------------------------------------------");
            $display("Power state: %b", o_PowerDown);
            $display("FSM State: %b", uut.fsm_state);
            $display("Link Up: %b", o_LinkUp);
            $display("Rx flag rst: %b", uut.s_rx_flag_rst);
            $display("Tx flag rst: %b", uut.s_tx_flag_rst);
            $display("Polling active Tx flag rst: %b", uut.s_polling_active_tx_flag_rst);
            $display("Rx flag: %b", uut.s_rx_flag);
            $display("Tx flag: %b", uut.s_tx_flag);
            $display("Polling active Tx flag: %b", uut.s_polling_active_tx_flag);
            $display("---------------------------------------------");
            $display("---------------------------------------------");
            $display("  Receiving TS2 packets from link partner to move to CONFIG_LINKWIDTH_START  ");
            $display("---------------------------------------------");
            receive_TS2(5, 8'hF7, 8'hF7); // Move to CONFIG_LINKWIDTH_START
            receive_TS1(1, 8'hFF, 8'hF7);
            receive_TS2(20, 8'hF7, 8'hF7);
            #(CLK_PERIOD * 1000);
            $display("---------------------------------------------");
            $display("Power state: %b", o_PowerDown);
            $display("FSM State: %b", uut.fsm_state);
            $display("Link Up: %b", o_LinkUp);
            $display("---------------------------------------------");
            $display("---------------------------------------------");
            $display("  Receiving TS1 packets from link partner to determine link number and move to CONFIG_LINKWIDTH_WAIT  ");
            $display("---------------------------------------------");
            receive_TS1(5, 8'h01, 8'hF7); // Move to CONFIG_LINKWIDTH_ACCEPT
            receive_TS1(1, 8'hF7, 8'hF7);
            receive_TS1(8, 8'h01, 8'hF7);
            #(CLK_PERIOD * 10);
            $display("---------------------------------------------");
            $display("Power state: %b", o_PowerDown);
            $display("FSM State: %b", uut.fsm_state);
            $display("Link Up: %b", o_LinkUp);
            $display("---------------------------------------------");
            $display("---------------------------------------------");
            $display("  Receiving TS1 packets from link partner to determine lane number and move to CONFIG_COMPLETE  ");
            $display("---------------------------------------------");
            receive_TS1(7, 8'h01, 8'h02); // Move to CONFIG_LANENUM_ACCEPT
            receive_TS1(3, 8'hF7, 8'hF7);
            #(CLK_PERIOD * 10);
            $display("---------------------------------------------");
            $display("Power state: %b", o_PowerDown);
            $display("FSM State: %b", uut.fsm_state);
            $display("Link Up: %b", o_LinkUp);
            $display("---------------------------------------------");
        end else if (SCRAMBLER_TEST) begin
            $display("---------------------------------------------");
            $display("Scrambler Test");
            $display("---------------------------------------------");
        end else if (INVERSION_TEST) begin
            $display("---------------------------------------------");
            $display("Inversion Test");
            $display("---------------------------------------------");
            #(CLK_PERIOD * 100);
            $display("---------------------------------------------");
            $display("Power state: %b", o_PowerDown);
            $display("FSM State: %b", uut.fsm_state);
            $display("Link Up: %b", o_LinkUp);
            $display("---------------------------------------------");
            $display("---------------------------------------------");
            $display("  Receiving inverted TS1 packets from link partner  ");
            $display("---------------------------------------------");
            receive_TS1_inv(10, 8'hF7, 8'hF7); // Move to POLLING_CONFIG
            #(CLK_PERIOD * 10);
            $display("---------------------------------------------");
            $display("Polarity Bit: %b", o_RxPolarity);
            $display("---------------------------------------------");
        end
        $finish;
    end
endmodule