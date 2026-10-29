# @NAME@: per-unit production programming for the BlackPill STM32F411CE with J-Link Commander:
# firmware at 0x08000000 + a 16-byte serial-number record in the last flash sector (0x08060000).
#   segger-box run make -C @NAME@ FW=path/fw.bin SERIALS="1001 1002"   # scripts + records in build/
#   segger-box run make -C @NAME@ FW=... check                           # offline checks (no probe)
#   segger-box run make -C @NAME@ FW=... SERIAL=1001 program             # PRINTS the JLinkExe line (dry run)
FW       ?= fw.bin
SERIALS  ?= 1001
SERIAL   ?= $(firstword $(SERIALS))
BUILD    ?= build
DEVICE   := STM32F411CE
FW_BASE  := 0x08000000
SN_BASE  := 0x08060000
FLASH    := 0x08000000:0x80000
.PHONY: all check program
.SECONDARY:    # keep build/serial_*.bin (make would delete them as intermediate files)
all: $(foreach s,$(SERIALS),$(BUILD)/prog_$(s).jlink)
$(BUILD)/serial_%.bin:
	@mkdir -p $(BUILD)
	python3 serial_record.py write $* $@
$(BUILD)/prog_%.jlink: $(BUILD)/serial_%.bin prog.jlink.in $(FW)
	sed -e 's#@FW@#$(abspath $(FW))#g' -e 's#@SN@#$(abspath $<)#g' -e 's#@FW_BASE@#$(FW_BASE)#g' \
	  -e 's#@SN_BASE@#$(SN_BASE)#g' prog.jlink.in >$@
check: all
	@for s in $(SERIALS); do \
	  python3 $(SEGGER_BOX_ROOT)/lib/jlink_check.py commander $(BUILD)/prog_$$s.jlink --flash $(FLASH) --files-exist || exit 1; \
	  python3 serial_record.py read $(BUILD)/serial_$$s.bin $$s || exit 1; \
	done
	python3 serial_record.py fits $(FW) $(FW_BASE) $(SN_BASE)
	@echo "PASS @NAME@: $(words $(SERIALS)) unit script(s) checked offline"
program: $(BUILD)/prog_$(SERIAL).jlink
	$(SEGGER_BOX_ROOT)/segger-box --dry-run jlink -device $(DEVICE) -if SWD -speed 4000 -autoconnect 1 -NoGui 1 \
	  -ExitOnError 1 -CommanderScript $<
