SHELL := /bin/bash
## tools
YOSYS = yosys
NEXTPNR = nextpnr-himbaechel
PACK = gmpack
OFL = openFPGALoader

TOP = ccfpga_pipe_logic
PRFLAGS  = -ccf src/$(TOP).ccf -cCP -crc
NEXTPNRFLAGS = --vopt allow-unconstrained
OFLFLAGS = --index-chain 0

## target sources
VLOG_SRC = $(shell find ./src/ -type f \( -iname \*.v -o -iname \*.sv \))
VHDL_SRC = $(shell find ./src/ -type f \( -iname \*.vhd -o -iname \*.vhdl \))

## testcases
testcase: serdesflow_mod
	source serdesflow_mod

## open source toolchain
net/$(TOP)_synth.json: $(VLOG_SRC)
	mkdir -p log/
	mkdir -p net/
	$(YOSYS) -l log/synth.log -p 'read_verilog -sv $^; synth_gatemate -top $(TOP) -luttree $(YSFLAGS) -vlog net/$(TOP)_synth.v -json net/$(TOP)_synth.json'

$(TOP).txt: net/$(TOP)_synth.json src/$(TOP).ccf
	$(NEXTPNR) --device CCGM1A1 --json net/$(TOP)_synth.json --vopt ccf=src/$(TOP).ccf $(NEXTPNRFLAGS) --vopt out=$(TOP).txt --router router2

$(TOP).bit: $(TOP).txt
	$(PACK) $(TOP).txt $(TOP).bit

jtag: $(TOP).bit
	$(OFL) $(OFLFLAGS) -b gatemate_evb_jtag $(TOP).bit

clean:
	$(RM) rm log/*.log
	$(RM) net/*_synth.json
	$(RM) net/*_synth.v
	$(RM) work-obj*.cf
	$(RM) *.txt
	$(RM) *.crf
	$(RM) *.refwire
	$(RM) *.refparam
	$(RM) *.refcomp
	$(RM) *.pos
	$(RM) *.pathes
	$(RM) *.path_struc
	$(RM) *.net
	$(RM) *.id
	$(RM) *.prn
	$(RM) *_00.v
	$(RM) *.used
	$(RM) *.sdf
	$(RM) *.place
	$(RM) *.pin
	$(RM) *.cfg*
	$(RM) *.cdf
	$(RM) -rf net
	$(RM) -rf log
