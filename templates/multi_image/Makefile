# @NAME@: bootloader (0x08000000, 32 KB) + application (0x08008000) for the BlackPill STM32F411CE.
# segger-box run make -C @NAME@ [all|check|sim]
BUILD   ?= build
CPU     := -mcpu=cortex-m4 -mfpu=fpv4-sp-d16 -mfloat-abi=hard
CC      := arm-none-eabi-gcc
OBJCOPY := arm-none-eabi-objcopy
CMSIM   ?= python3 $(SEGGER_BOX_ROOT)/lib/cmsim.py
RTT     ?= $(SEGGER_RTT_DIR)
CFLAGS  := $(CPU) -mthumb -Os -g3 -std=c11 -Wall -ffunction-sections -fdata-sections -I$(RTT)/RTT -I$(RTT)/Config
LDFLAGS := $(CPU) -mthumb -nostartfiles --specs=nano.specs -Wl,--gc-sections
# only what goes to flash; .data only when it is not empty (ld gives an empty .data its RAM address as LMA)
FLASH_SECTIONS = -j .isr_vector -j .text -j .ARM.exidx \
  $$(arm-none-eabi-size -A $(1) | awk '$$1==".data" && $$2>0 {print "-j .data"}')
.PHONY: all check sim
all: $(BUILD)/@NAME@_merged.bin $(BUILD)/flash_@NAME@.jlink
$(BUILD)/boot.elf: boot.c startup.c boot.ld
	@mkdir -p $(BUILD)
	$(CC) $(CFLAGS) boot.c startup.c $(LDFLAGS) -T boot.ld -Wl,-Map=$(BUILD)/boot.map -o $@
$(BUILD)/app.elf: app.c startup.c app.ld
	@mkdir -p $(BUILD)
	$(CC) $(CFLAGS) app.c startup.c $(RTT)/RTT/SEGGER_RTT.c $(RTT)/RTT/SEGGER_RTT_printf.c $(LDFLAGS) -T app.ld \
	  -Wl,-Map=$(BUILD)/app.map -o $@
# one image for production: bootloader padded with 0xFF up to the app, then the app
$(BUILD)/@NAME@_merged.bin: $(BUILD)/boot.elf $(BUILD)/app.elf
	$(OBJCOPY) -O binary $(call FLASH_SECTIONS,$(BUILD)/boot.elf) --gap-fill 0xFF --pad-to 0x08008000 $(BUILD)/boot.elf $(BUILD)/boot_padded.bin
	$(OBJCOPY) -O binary $(call FLASH_SECTIONS,$(BUILD)/app.elf) $(BUILD)/app.elf $(BUILD)/app.bin
	cat $(BUILD)/boot_padded.bin $(BUILD)/app.bin >$@
$(BUILD)/flash_@NAME@.jlink: flash.jlink
	sed 's#@BUILD@#$(BUILD)#g' flash.jlink >$@
check: all
	python3 layout_check.py $(BUILD)
sim: $(BUILD)/boot.elf $(BUILD)/app.elf
	$(CMSIM) run $(BUILD)/boot.elf --also $(BUILD)/app.elf --rtt-elf $(BUILD)/app.elf
