# @NAME@: RTT command console (down channel input, virtual terminals), built with the pinned arm-none-eabi-gcc of 32_12_segger.
# Run inside the ID's environment:  segger-box run make -C @NAME@ [BOARD=...] [all|sim|info|size]
# SEGGER_RTT_DIR (set by segger-box): SEGGER's RTT sources (pinned from github.com/SEGGERMicro/RTT).
include board.mk
BUILD   ?= build/$(BOARD)
CC      := arm-none-eabi-gcc
OBJCOPY := arm-none-eabi-objcopy
SIZE    := arm-none-eabi-size
CMSIM   ?= python3 $(SEGGER_BOX_ROOT)/lib/cmsim.py
RTT     ?= $(SEGGER_RTT_DIR)
CFLAGS  := $(CPU) -mthumb -Os -g3 -std=c11 -Wall -Wextra -ffunction-sections -fdata-sections \
           -I. -I$(RTT)/RTT -I$(RTT)/Config -DSEGGER_RTT_SECTION=\".rtt\" $(EXTRA_CFLAGS)
LDFLAGS := $(CPU) -mthumb -nostartfiles --specs=nano.specs -Wl,--gc-sections -L$(BUILD) -T link.ld \
           -Wl,-Map=$(BUILD)/@NAME@.map
SRCS    := $(wildcard *.c) $(RTT)/RTT/SEGGER_RTT.c $(RTT)/RTT/SEGGER_RTT_printf.c $(EXTRA_SRCS)
ELF     := $(BUILD)/@NAME@.elf

.PHONY: all sim info size
all: $(ELF) $(BUILD)/@NAME@.hex $(BUILD)/@NAME@.bin
$(BUILD)/memory.ld: board.mk
	@mkdir -p $(BUILD)
	@printf 'MEMORY {\n  FLASH (rx) : ORIGIN = %s, LENGTH = %s\n  RAM (rwx) : ORIGIN = %s, LENGTH = %s\n}\n' \
	  $(FLASH_BASE) $(FLASH_SIZE) $(RAM_BASE) $(RAM_SIZE) >$@
$(ELF): $(SRCS) link.ld $(BUILD)/memory.ld
	@test -f "$(RTT)/RTT/SEGGER_RTT.c" || { echo "SEGGER RTT sources not found (SEGGER_RTT_DIR=$(RTT)); run ./segger-box bootstrap"; exit 1; }
	$(CC) $(CFLAGS) $(SRCS) $(LDFLAGS) -o $@
$(BUILD)/@NAME@.hex: $(ELF)
	$(OBJCOPY) -O ihex $< $@
$(BUILD)/@NAME@.bin: $(ELF)
	$(OBJCOPY) -O binary $< $@
size: $(ELF)
	$(SIZE) -A -x $<
sim: $(ELF)
	$(CMSIM) run $< --down "help\n" --down "add 2 40\n" --down "warn disk 91%\n" --down "quit\n" --terminals $(SIM_ARGS)
info: $(ELF)
	$(CMSIM) info $<
