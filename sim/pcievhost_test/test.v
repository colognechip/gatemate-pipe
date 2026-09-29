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
  parameter DISABLE_SCRAMBLING = 0,
  parameter REALIGN_RX     = 1,
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
wire [DATA_WIDTH-1:0] s_txdata;
wire [DATA_BYTES-1:0] s_txdatak;

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

localparam [7:0] RA_COM  = 8'hBC;
localparam [7:0] RA_SKP  = 8'h1C;
localparam [7:0] RA_SDP  = 8'h5C;
localparam [7:0] RA_STP  = 8'hFB;
localparam [7:0] RA_END  = 8'hFD;
localparam [7:0] RA_EDB  = 8'hFE;
localparam       RA_DEPTH = 256;

reg  [7:0]            ra_fifo_data [0:RA_DEPTH-1];
reg                   ra_fifo_k    [0:RA_DEPTH-1];
reg                   ra_fifo_drop [0:RA_DEPTH-1];
integer               ra_head, ra_tail, ra_level, ra_os_left, ra_b;
integer               ra_pads, ra_drops;
reg                   ra_in_pkt;
reg  [7:0]            ra_byte;
reg                   ra_bk;
reg  [DATA_WIDTH-1:0] ra_word;
reg  [DATA_BYTES-1:0] ra_word_k;
reg  [DATA_WIDTH-1:0] AlignedData;
reg  [DATA_BYTES-1:0] AlignedDataK;

always @(posedge PClk or negedge notReset)
begin
  if (!notReset)
  begin
    ra_head      = 0;
    ra_tail      = 0;
    ra_level     = 0;
    ra_os_left   = 0;
    ra_in_pkt    = 1'b0;
    ra_pads      = 0;
    ra_drops     = 0;
    AlignedData  <= {DATA_WIDTH{1'b0}};
    AlignedDataK <= {DATA_BYTES{1'b0}};
  end
  else
  begin
    for (ra_b = 0; ra_b < DATA_BYTES; ra_b = ra_b + 1)
    begin
      ra_byte = LinkDownDataInt[8*ra_b +: 8];
      ra_bk   = LinkDownDataKInt[ra_b];

      ra_fifo_data[ra_tail] = ra_byte;
      ra_fifo_k[ra_tail]    = ra_bk;
      ra_fifo_drop[ra_tail] = !ra_bk && !ra_in_pkt && (ra_os_left == 0);

      if (ra_bk && ra_byte == RA_COM && !ra_in_pkt)
        ra_os_left = 15;
      else if (ra_bk && ra_byte == RA_SKP && ra_os_left == 15)
        ra_os_left = 2;
      else if (ra_os_left > 0)
        ra_os_left = ra_os_left - 1;

      if (ra_bk && (ra_byte == RA_SDP || ra_byte == RA_STP))
        ra_in_pkt = 1'b1;
      else if (ra_bk && (ra_byte == RA_END || ra_byte == RA_EDB))
        ra_in_pkt = 1'b0;

      ra_tail  = (ra_tail + 1) % RA_DEPTH;
      ra_level = ra_level + 1;
    end

    if (ra_level > RA_DEPTH - 2*DATA_BYTES)
    begin
      $display("***REALIGN: FIFO overflow at %t", $time);
      `fatal
    end

    while (ra_level > DATA_BYTES && ra_fifo_drop[ra_head])
    begin
      ra_head  = (ra_head + 1) % RA_DEPTH;
      ra_level = ra_level - 1;
      ra_drops = ra_drops + 1;
    end

    for (ra_b = 0; ra_b < DATA_BYTES; ra_b = ra_b + 1)
    begin
      if (ra_fifo_k[ra_head] && (ra_fifo_data[ra_head] == RA_SDP || ra_fifo_data[ra_head] == RA_STP) && (ra_b % 4) != 0)
      begin
        ra_word[8*ra_b +: 8] = 8'h00;
        ra_word_k[ra_b]      = 1'b0;
        ra_pads              = ra_pads + 1;
      end
      else
      begin
        ra_word[8*ra_b +: 8] = ra_fifo_data[ra_head];
        ra_word_k[ra_b]      = ra_fifo_k[ra_head];
        ra_head              = (ra_head + 1) % RA_DEPTH;
        ra_level             = ra_level - 1;
      end
    end

    AlignedData  <= ra_word;
    AlignedDataK <= ra_word_k;
  end
end

wire [DATA_WIDTH-1:0] MacRxData  = REALIGN_RX ? AlignedData  : LinkDownDataInt;
wire [DATA_BYTES-1:0] MacRxDataK = REALIGN_RX ? AlignedDataK : LinkDownDataKInt;

integer ra_chk;
always @(posedge PClk)
begin
  if (REALIGN_RX && notReset)
    for (ra_chk = 0; ra_chk < DATA_BYTES; ra_chk = ra_chk + 1)
      if (MacRxDataK[ra_chk] && (MacRxData[8*ra_chk +: 8] == RA_SDP || MacRxData[8*ra_chk +: 8] == RA_STP) && (ra_chk % 4) != 0)
        $display("***REALIGN: start symbol %h at byte %0d at %t", MacRxData[8*ra_chk +: 8], ra_chk, $time);
end

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
      .i_RxData            ( MacRxData        ),
      .i_RxDataK           ( MacRxDataK       ),
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

wire                  dll_reset = ~notReset;

reg  [DATA_WIDTH-1:0] tl_tx_data;
reg                   tl_tx_tlp_valid;
reg                   tl_tx_tlp_first;
reg                   tl_tx_tlp_last;
wire                  tl_tx_tlp_ready;

reg              [7:0] tl_tx_hdr_credit;
reg             [11:0] tl_tx_data_credit;
reg              [1:0] tl_tx_update_type;
reg              [1:0] tl_tx_packet_type;
reg                    tl_tx_dllp_valid;

wire [DATA_WIDTH-1:0] tl_rx_data;
wire                  tl_rx_tlp_valid;
wire                  tl_rx_tlp_first;
wire                  tl_rx_tlp_last;

wire             [7:0] tl_rx_hdr_credit;
wire            [11:0] tl_rx_data_credit;
wire             [1:0] tl_rx_update_type;
wire             [1:0] tl_rx_packet_type;
wire                   tl_rx_dllp_valid;

dll_logic #(
   .DATA_BYTES                 ( DATA_BYTES               ),
   .NUMBER_OF_VIRTUAL_CHANNELS ( 1                         ),
   .PATTERN_WIDTH              ( 64                        )
) dll_inst (
   .phy_clk             ( PClk              ),
   .phy_reset           ( dll_reset         ),
   .phy_linkup          ( s_linkup          ),

   .phy_rx_data         ( s_rx_data         ),    // From MAC

   .tl_tx_data          ( tl_tx_data        ),
   .tl_tx_tlp_valid     ( tl_tx_tlp_valid   ),
   .tl_tx_tlp_first     ( tl_tx_tlp_first   ),
   .tl_tx_tlp_last      ( tl_tx_tlp_last    ),
   .tl_tx_tlp_ready     ( tl_tx_tlp_ready   ),

   .tl_tx_hdr_credit    ( tl_tx_hdr_credit  ),
   .tl_tx_data_credit   ( tl_tx_data_credit ),
   .tl_tx_update_type   ( tl_tx_update_type ),
   .tl_tx_packet_type   ( tl_tx_packet_type ),
   .tl_tx_dllp_valid    ( tl_tx_dllp_valid  ),

   .phy_tx_data         ( s_txdata          ),    // To MAC
   .phy_tx_data_k       ( s_txdatak         ),    // To MAC

   .tl_rx_data          ( tl_rx_data        ),
   .tl_rx_tlp_valid     ( tl_rx_tlp_valid   ),
   .tl_rx_tlp_first     ( tl_rx_tlp_first   ),
   .tl_rx_tlp_last      ( tl_rx_tlp_last    ),

   .tl_rx_hdr_credit    ( tl_rx_hdr_credit  ),
   .tl_rx_data_credit   ( tl_rx_data_credit ),
   .tl_rx_update_type   ( tl_rx_update_type ),
   .tl_rx_packet_type   ( tl_rx_packet_type ),
   .tl_rx_dllp_valid    ( tl_rx_dllp_valid  )
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
  if (DISABLE_SCRAMBLING != 0)
  begin
    force mac_inst.scrambler_en   = 1'b0;
    force mac_inst.descrambler_en = 1'b0;
  end
end

initial
begin
  s_rx_valid      = 1'b0;
  s_phy_status    = 1'b0;
  s_rx_status     = 3'b000;
  s_rx_elec_idle  = 1'b1;

  tl_tx_data        = {DATA_WIDTH{1'b0}};
  tl_tx_tlp_valid   = 1'b0;
  tl_tx_tlp_first   = 1'b0;
  tl_tx_tlp_last    = 1'b0;
  tl_tx_hdr_credit  = 8'b0;
  tl_tx_data_credit = 12'b0;
  tl_tx_update_type = 2'b0;
  tl_tx_packet_type = 2'b0;
  tl_tx_dllp_valid  = 1'b0;

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