# @NAME@: syntax-check the RTT app against SEGGER's RTT sources from the J-Link pack.
# RTT_DIR: folder with SEGGER_RTT.c/.h (default: $(SEGGER_RTT_DIR), SEGGER's RTT pinned by segger-box bootstrap;
# without it: unpacked from the J-Link pack's $(SEGGER_JLINK_DIR)/Samples/RTT/*.tgz)
DEVICE ?= STM32F411CE
BUILD  ?= build
CC_CHECK ?= $(shell command -v arm-none-eabi-gcc >/dev/null 2>&1 && echo "arm-none-eabi-gcc -mcpu=cortex-m4 -mthumb" || { command -v clang >/dev/null 2>&1 && echo "clang --target=thumbv7em-none-eabi -ffreestanding" || echo cc; })
RTT_TGZ := $(firstword $(wildcard $(SEGGER_JLINK_DIR)/Samples/RTT/SEGGER_RTT_V*.tgz))
RTT_DIR ?= $(if $(wildcard $(SEGGER_RTT_DIR)/RTT/SEGGER_RTT.c),$(SEGGER_RTT_DIR),$(BUILD)/rtt)
.PHONY: check rtt clean-note
check: rtt
	@test -f "$(RTT_DIR)/RTT/SEGGER_RTT.c" || test -f "$(RTT_DIR)/SEGGER_RTT.c" || { echo "SKIP: SEGGER RTT sources not found (run segger-box bootstrap)"; exit 77; }
	@d=$$(dirname $$(find "$(RTT_DIR)/" -name SEGGER_RTT.c | head -1)); c=$$(dirname $$(find "$(RTT_DIR)/" -name SEGGER_RTT_Conf.h | head -1)); \
	  $(CC_CHECK) -fsyntax-only -I"$$d" -I"$$c" -include rtt_conf_box.h -I. main.c "$$d/SEGGER_RTT.c" && \
	  echo "@NAME@: RTT sources + config + main.c compile (syntax) for $(DEVICE)"
rtt:
	@mkdir -p $(BUILD)
	@if [ "$(RTT_DIR)" = "$(BUILD)/rtt" ] && [ ! -d "$(BUILD)/rtt" ] && [ -n "$(RTT_TGZ)" ]; then mkdir -p $(BUILD)/rtt && tar -xzf "$(RTT_TGZ)" -C $(BUILD)/rtt; fi
