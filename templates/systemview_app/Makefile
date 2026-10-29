# @NAME@: SystemView (no OS) firmware, built with the pinned arm-none-eabi-gcc of 32_12_segger.
# SEGGER_RTT_DIR / SEGGER_SYSVIEW_DIR (set by segger-box): SEGGER's BSD-licensed target sources.
# RTT V8.58 sets its buffer counts in SEGGER_RTT_ConfDefaults.h, which SystemView V4.10 checks before it is
# included: the counts are passed on the command line. RTT_USE_ASM=0: C version of the RTT write path (the
# ARMv7-M assembly file would not build for the Cortex-M0+/M33 boards).
# segger-box run make -C @NAME@ [BOARD=...] [all|sim|check]
include board.mk
CPU_HZ  ?= 100000000
BUILD   ?= build/$(BOARD)
CC      := arm-none-eabi-gcc
CMSIM   ?= python3 $(SEGGER_BOX_ROOT)/lib/cmsim.py
RTT     ?= $(SEGGER_RTT_DIR)
SV      ?= $(SEGGER_SYSVIEW_DIR)
CFLAGS  := $(CPU) -mthumb -Os -g3 -std=c11 -Wall -ffunction-sections -fdata-sections \
           -I. -I$(SV)/SYSVIEW -I$(SV)/Config -I$(SV)/SEGGER -I$(RTT)/RTT -I$(RTT)/Config \
           -DSEGGER_RTT_MAX_NUM_UP_BUFFERS=3 -DSEGGER_RTT_MAX_NUM_DOWN_BUFFERS=3 -DRTT_USE_ASM=0 \
           -DCPU_HZ=$(CPU_HZ)u -DRAM_BASE=$(RAM_BASE)u -DSYSVIEW_DEVICE=\"$(JLINK_DEVICE)\" -DSEGGER_RTT_SECTION=\".rtt\"
LDFLAGS := $(CPU) -mthumb -nostartfiles --specs=nano.specs -Wl,--gc-sections -L$(BUILD) -T link.ld
SRCS    := main.c sysview_config.c startup.c $(SV)/SYSVIEW/SEGGER_SYSVIEW.c $(RTT)/RTT/SEGGER_RTT.c
ELF     := $(BUILD)/@NAME@.elf
.PHONY: all sim check
all: $(ELF)
$(BUILD)/memory.ld: board.mk
	@mkdir -p $(BUILD)
	@printf 'MEMORY {\n  FLASH (rx) : ORIGIN = %s, LENGTH = %s\n  RAM (rwx) : ORIGIN = %s, LENGTH = %s\n}\n' \
	  $(FLASH_BASE) $(FLASH_SIZE) $(RAM_BASE) $(RAM_SIZE) >$@
$(ELF): $(SRCS) link.ld $(BUILD)/memory.ld
	@test -f "$(SV)/SYSVIEW/SEGGER_SYSVIEW.c" || { echo "SystemView sources not found (SEGGER_SYSVIEW_DIR=$(SV)); run ./segger-box bootstrap"; exit 1; }
	$(CC) $(CFLAGS) $(SRCS) $(LDFLAGS) -o $@
sim: $(ELF)
	$(CMSIM) run $< --channel 1 --json $(SIM_ARGS)
check: $(ELF)
	$(CMSIM) run $< --json >$(BUILD)/sim.json
	python3 sv_check.py $(BUILD)/sim.json @NAME@
