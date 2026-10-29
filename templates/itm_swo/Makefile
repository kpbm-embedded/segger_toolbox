# @NAME@: ITM/SWO output, built with the pinned arm-none-eabi-gcc of 32_12_segger.
# segger-box run make -C @NAME@ [BOARD=...] [all|sim|size|swo-plan]
include board.mk
BUILD   ?= build/$(BOARD)
CC      := arm-none-eabi-gcc
OBJCOPY := arm-none-eabi-objcopy
CMSIM   ?= python3 $(SEGGER_BOX_ROOT)/lib/cmsim.py
CFLAGS  := $(CPU) -mthumb -Os -g3 -std=c11 -Wall -Wextra -ffunction-sections -fdata-sections -DCPU_HZ=$(CPU_HZ)u
LDFLAGS := $(CPU) -mthumb -nostartfiles --specs=nano.specs -Wl,--gc-sections -L$(BUILD) -T link.ld
ELF     := $(BUILD)/@NAME@.elf
.PHONY: all sim size swo-plan
all: $(ELF) $(BUILD)/@NAME@.hex
$(BUILD)/memory.ld: board.mk
	@mkdir -p $(BUILD)
	@printf 'MEMORY {\n  FLASH (rx) : ORIGIN = %s, LENGTH = %s\n  RAM (rwx) : ORIGIN = %s, LENGTH = %s\n}\n' \
	  $(FLASH_BASE) $(FLASH_SIZE) $(RAM_BASE) $(RAM_SIZE) >$@
$(ELF): main.c startup.c link.ld $(BUILD)/memory.ld
	$(CC) $(CFLAGS) main.c startup.c $(LDFLAGS) -o $@
$(BUILD)/@NAME@.hex: $(ELF)
	$(OBJCOPY) -O ihex $< $@
size: $(ELF)
	arm-none-eabi-size $<
sim: $(ELF)
	$(CMSIM) run $< --itm $(SIM_ARGS)
swo-plan:
	@echo "# SWO viewer (J-Link pack, licensed; you run it with the probe attached):"
	@echo "JLinkSWOViewerCLExe -device $(JLINK_DEVICE) -itmport 0x3 -swofreq 2000000 -cpufreq $(CPU_HZ)"
