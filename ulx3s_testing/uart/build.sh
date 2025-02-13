#!/usr/bin/env sh

set -e

rm -r build || true

mkdir build

yosys  -p 'read_verilog -sv ../../uart/rtl/uart_rx.sv ChipInterface.sv; synth_ecp5 -json build/synthesis.json -top ChipInterface -noflatten'
# yosys  -p 'read_verilog -sv ../../uart/rtl/224_uart_rx.sv ChipInterface.sv; synth_ecp5 -json build/synthesis.json -top ChipInterface -noflatten'

nextpnr-ecp5 --12k --json build/synthesis.json --lpf ../ulx3s_v20.lpf --textcfg build/pnr_out.config --freq 25

ecppack --compress build/pnr_out.config build/bitstream.bit

fujprog build/bitstream.bit
