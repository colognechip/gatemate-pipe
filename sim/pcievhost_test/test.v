//=============================================================
//
// Copyright (c) 2016 Simon Southwell. All rights reserved.
//
// Date: 20th Sep 2016
//
// This file is part of the pcieVHost package.
//
// pcieVHost is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// pcieVHost is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with pcieVHost. If not, see <http://www.gnu.org/licenses/>.
//
//=============================================================

`ifdef VPROC_SV
`include "allheaders.v"
`endif

`WsTimeScale

//-------------------------------------------------------------
//-------------------------------------------------------------
module test
#(parameter VCD_DUMP       = 0,
  parameter DEBUG_STOP     = 0,
  parameter DATA_BYTES     = 8,
  parameter DATA_WIDTH     = DATA_BYTES*8
);

localparam RcNodeNum       = 0;
localparam EpNodeNum       = 1;
localparam ROOTCMPLX       = 0;
localparam ENDPOINT        = 1;

localparam PATTERN_WIDTH   = 128;

reg     Clk;
integer Count;

reg                   PClk;
reg                   s_rx_valid;
reg                   s_phy_status;
reg             [2:0] s_rx_status;
reg                   s_rx_elec_idle;
reg  [DATA_WIDTH-1:0] s_txdata;
reg  [DATA_BYTES-1:0] s_txdatak;

wire            [1:0] s_power_down;
wire                  s_tx_detect_rx;
wire                  s_tx_elec_idle;
wire [DATA_BYTES-1:0] s_tx_compliance;
wire                  s_rx_polarity;
wire                  s_linkup;
wire [DATA_WIDTH-1:0] s_rx_data;
wire [DATA_BYTES-1:0] s_rx_datak;

wire [DATA_WIDTH-1:0] LinkDownData;
wire [DATA_BYTES-1:0] LinkDownDataK;

wire [DATA_WIDTH-1:0] LinkUpData;
wire [DATA_BYTES-1:0] LinkUpDataK;

wire  ElecIdleUp, ElecIdleDown;

// Generate a reset signal
wire #`RegDel notReset = (Count > 10);

`ifdef VERILATOR
reg  [7:0] LinkDownDataInt;
reg        LinkDownDataKInt;

reg  [7:0] LinkUpDataInt;
reg        LinkUpDataKInt;

always @(negedge Clk)
begin

  LinkDownDataInt            <= LinkDownData;
  LinkDownDataKInt           <= LinkDownDataK;
  LinkUpDataInt              <= LinkUpData;
  LinkUpDataKInt             <= LinkUpDataK;
end

`else

wire [DATA_WIDTH-1:0] LinkDownDataInt   = LinkDownData;
wire [DATA_BYTES-1:0] LinkDownDataKInt  = LinkDownDataK;

wire [DATA_WIDTH-1:0] LinkUpDataInt     = LinkUpData;
wire [DATA_BYTES-1:0] LinkUpDataKInt    = LinkUpDataK;

`endif
    pcieVHostPipex1 #(RcNodeNum, ROOTCMPLX, DATA_WIDTH) rc
    (
       .pcieclk             (Clk),
       .pclk                (PClk),
       .nreset              (notReset),

`ifdef VERILATOR
       .ElecIdleOut         (ElecIdleDown),
       .ElecIdleIn          (ElecIdleUp),
`endif
       
       .TxData              (LinkDownData),
       .TxDataK             (LinkDownDataK),
       
       .RxData              (LinkUpDataInt),
       .RxDataK             (LinkUpDataKInt)
    );
    
    ccfpga_LTSSM_logic #(
      .DATA_BYTES          ( DATA_BYTES       ),
      .PATTERN_WIDTH       ( PATTERN_WIDTH    )
    ) mac_inst (
      .i_Reset_n           ( notReset         ),
      .i_PCLK              ( PClk             ),
      .i_RxValid           ( s_rx_valid       ),
      .i_PhyStatus         ( s_phy_status     ),
      .i_RxStatus          ( s_rx_status      ),
      .i_RxElecIdle        ( s_rx_elec_idle   ),
      .i_RxData            ( LinkDownDataInt  ),
      .i_RxDataK           ( LinkDownDataKInt ),
      .i_TxData            ( s_txdata         ),    // From DLL
      .i_TxDataK           ( s_txdatak        ),    // From DLL

      .o_PowerDown         ( s_power_down     ),
      .o_TxDetectRx        ( s_tx_detect_rx   ),
      .o_TxElecIdle        ( s_tx_elec_idle   ),
      .o_TxCompliance      ( s_tx_compliance  ),
      .o_RxPolarity        ( s_rx_polarity    ),
      .o_TxData            ( LinkUpData       ),
      .o_TxDataK           ( LinkUpDataK      ),
      .o_RxData            ( s_rx_data        ),    // To DLL
      .o_RxDataK           ( s_rx_datak       ),    // To DLL
      .o_LinkUp            ( s_linkup         )
   );

initial
begin
  // If specified, dump a VCD file
  if (VCD_DUMP != 0)
  begin
    $dumpfile("waves.vcd");
    $dumpvars(0, test);
  end

    Clk = 1;

`ifndef VERILATOR
    #0                  // Ensure first x->1 clock edge is complete before initialisation
`endif

    // If specified, stop for debugger attachement
    if (DEBUG_STOP != 0)
    begin
      $display("\n***********************************************");
      $display("* Stopping simulation for debugger attachment *");
      $display("***********************************************\n");
      $stop;
    end

    Count = 0;
    forever # (`CLK_PERIOD/2) Clk = ~Clk;
end

initial
begin
    PClk = 1;
    forever # (`CLK_PERIOD*4) PClk = ~PClk;
end

initial
begin
  s_rx_valid      = 1'b0;
  s_phy_status    = 1'b0;
  s_rx_status     = 3'b000;
  s_rx_elec_idle  = 1'b1;
  s_txdata        = 64'h0000_0000_0000_0000;
  s_txdatak       = 8'h00;

  # (`CLK_PERIOD*100);
  s_rx_valid      = 1'b1;
  $display("---------------------------------------------");
  $display("Power state: %b", s_power_down);
  $display("FSM State: %b", mac_inst.s_fsm_state);
  $display("Link Up: %b", s_linkup);
  $display("---------------------------------------------");
  # (`CLK_PERIOD*100);
  s_rx_elec_idle  = 1'b0;
  $display("---------------------------------------------");
  $display("  Receiver detects a signal from the link partner  ");
  $display("---------------------------------------------");
  $display("---------------------------------------------");
  $display("Power state: %b", s_power_down);
  $display("FSM State: %b", mac_inst.s_fsm_state);
  $display("Link Up: %b", s_linkup);
  $display("---------------------------------------------");
  # (`CLK_PERIOD*100);
  s_rx_status = 3'b011;
  $display("---------------------------------------------");
  $display("  RxStatus indicates receiver detection complete  ");
  $display("---------------------------------------------");
  $display("---------------------------------------------");
  $display("Power state: %b", s_power_down);
  $display("FSM State: %b", mac_inst.s_fsm_state);
  $display("Link Up: %b", s_linkup);
  $display("---------------------------------------------");
  # (`CLK_PERIOD*10);
  s_rx_elec_idle  = 1'b1;
  # (`CLK_PERIOD*100);
  $display("---------------------------------------------");
  $display("Power state: %b", s_power_down);
  $display("FSM State: %b", mac_inst.s_fsm_state);
  $display("Link Up: %b", s_linkup);
  $display("---------------------------------------------");
end

always @(posedge Clk)
begin
    Count = Count + 1;
    if (Count == `TIMEOUT_COUNT)
    begin
        `fatal
    end
end

// Top level fatal task, which can be called from anywhere in verilog code.
// via the `fatal definition in pciedispheader.v. Any data logging, error
// message displays etc., on a fatal, should be placed in here.
task Fatal;
begin
    $display("***FATAL ERROR...calling $finish!");
    $finish;
end
endtask
endmodule