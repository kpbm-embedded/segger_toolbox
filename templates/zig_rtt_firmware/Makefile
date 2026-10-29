# @NAME@: Zig + SEGGER RTT firmware for the BlackPill STM32F411CE (Cortex-M4F), built with the Zig of
# 32_24_microzig (reached through its launcher, not copied). segger-box run make -C @NAME@ [all|sim|check]
# -fno-strip: ReleaseSmall strips symbols by default, and GDB/Ozone need them (break main, variables).
ZIG     ?= $(SEGGER_ZIG_ID)/microzig-box zig
BUILD   ?= build
RTT     ?= $(SEGGER_RTT_DIR)
CMSIM   ?= python3 $(SEGGER_BOX_ROOT)/lib/cmsim.py
CFLAGS  := -mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard -Os -g -ffunction-sections -fdata-sections \
           -I$(RTT)/RTT -I$(RTT)/Config -DRTT_USE_ASM=0 -DSEGGER_RTT_SECTION=\".rtt\"
ELF     := $(BUILD)/@NAME@.elf
.PHONY: all sim check
all: $(ELF)
$(BUILD)/memory.ld:
	@mkdir -p $(BUILD)
	@printf 'MEMORY {\n  FLASH (rx) : ORIGIN = 0x08000000, LENGTH = 512K\n  RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 128K\n}\n' >$@
# C parts with the pinned arm-none-eabi-gcc (newlib headers; Zig ships no libc for freestanding Arm)
$(BUILD)/c_parts.a: startup.c
	@mkdir -p $(BUILD)/obj
	arm-none-eabi-gcc $(CFLAGS) -c startup.c -o $(BUILD)/obj/startup.o
	arm-none-eabi-gcc $(CFLAGS) -c $(RTT)/RTT/SEGGER_RTT.c -o $(BUILD)/obj/SEGGER_RTT.o
	arm-none-eabi-gcc $(CFLAGS) -c $(RTT)/RTT/SEGGER_RTT_printf.c -o $(BUILD)/obj/SEGGER_RTT_printf.o
	arm-none-eabi-ar rcs $@ $(BUILD)/obj/*.o
# lld does not search -L folders for INCLUDE: a copy of link.ld that names memory.ld by path
$(BUILD)/zig.ld: link.ld $(BUILD)/memory.ld
	sed 's#^INCLUDE memory.ld#INCLUDE $(abspath $(BUILD))/memory.ld#' link.ld >$@
$(ELF): main.zig $(BUILD)/c_parts.a $(BUILD)/zig.ld
	@test -n "$(SEGGER_ZIG_ID)" || { echo "skip: 32_24_microzig not found (set BOX_MICROZIG)"; exit 3; }
	$(ZIG) build-exe -target thumb-freestanding-eabihf -mcpu=cortex_m4 -O ReleaseSmall -fno-strip -fno-entry \
	  main.zig $(BUILD)/c_parts.a -T $(BUILD)/zig.ld --name @NAME@ -femit-bin=$@
sim: $(ELF)
	$(CMSIM) run $<
check: $(ELF)
	$(CMSIM) run $< | tee $(BUILD)/rtt.txt
	grep -q '@NAME@: fib(30) = 832040' $(BUILD)/rtt.txt
	arm-none-eabi-readelf -S $< | grep -Eq '\.isr_vector +PROGBITS +08000000'
	@echo "PASS @NAME@ (Zig ELF: RTT read in cmsim, vector table at 0x08000000)"
