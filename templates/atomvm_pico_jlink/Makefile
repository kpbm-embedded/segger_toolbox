# @NAME@: AtomVM (Erlang) app for the Raspberry Pi Pico, flashed over SWD with J-Link instead of the BOOTSEL
# drive. AtomVM, atomvmlib and the Erlang tools come from 32_29_atomvm (reached, not copied).
#   segger-box run make -C @NAME@ check     # build .avm, run it on the host AtomVM, J-Link script + offline checks
A        ?= $(SEGGER_ATOMVM_ID)
AB       := $(A)/atomvm-box
BUILD    ?= build
VM_UF2   ?= $(A)/cache/downloads/AtomVM-pico-v0.6.6.uf2
LIB_UF2  ?= $(A)/cache/downloads/atomvmlib-v0.6.6.uf2
# AtomVM 0.6.6 rp2 layout, read from the VM image itself (LIB_AVM/MAIN_AVM constants): VM 0x10000000,
# lib.avm 0x10100000, main.avm 0x10180000 (up to 0x10200000)
LIB_ADDR := 0x10100000
APP_ADDR := 0x10180000
.PHONY: all check host
all: $(BUILD)/flash_@NAME@.jlink
$(BUILD)/@NAME@.avm: src/@NAME@.erl
	@test -x "$(AB)" || { echo "skip: 32_29_atomvm not found (set BOX_ATOMVM)"; exit 3; }
	@mkdir -p $(BUILD)
	$(AB) build $(CURDIR) >/dev/null
	cp "$$($(AB) where | awk '$$1=="build" {print $$2}')/apps/@NAME@/@NAME@.avm" $@
$(BUILD)/vm.bin: $(VM_UF2)
	@mkdir -p $(BUILD)
	python3 uf2tobin.py $< $@ >$(BUILD)/vm.addr
$(BUILD)/lib.bin: $(LIB_UF2)
	@mkdir -p $(BUILD)
	python3 uf2tobin.py $< $@ >$(BUILD)/lib.addr
$(BUILD)/flash_@NAME@.jlink: $(BUILD)/@NAME@.avm $(BUILD)/vm.bin $(BUILD)/lib.bin
	printf 'r\nh\nloadbin %s 0x10000000\nloadbin %s $(LIB_ADDR)\nloadbin %s $(APP_ADDR)\nverifybin %s $(APP_ADDR)\nr\ng\nexit\n' \
	  $(abspath $(BUILD)/vm.bin) $(abspath $(BUILD)/lib.bin) $(abspath $(BUILD)/@NAME@.avm) $(abspath $(BUILD)/@NAME@.avm) >$@
host: $(BUILD)/@NAME@.avm
	$(AB) avm $(BUILD)/@NAME@.avm
check: all
	$(AB) avm $(BUILD)/@NAME@.avm | tee $(BUILD)/host.txt
	grep -q '@NAME@ squares \[1,4,9,16,25\] sum 55' $(BUILD)/host.txt
	test "$$(cat $(BUILD)/vm.addr)" = 0x10000000 && test "$$(cat $(BUILD)/lib.addr)" = $(LIB_ADDR)
	python3 layout_check.py $(BUILD)/vm.bin $(BUILD)/lib.bin $(BUILD)/@NAME@.avm $(LIB_ADDR) $(APP_ADDR)
	python3 $(SEGGER_BOX_ROOT)/lib/jlink_check.py commander $(BUILD)/flash_@NAME@.jlink --flash 0x10000000:0x200000 --files-exist
	@echo "PASS @NAME@ (app ran on the host AtomVM; VM/lib/app placed for J-Link, not flashed)"
