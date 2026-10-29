# Owned Cortex-M boards: CPU flags and memory (flash/RAM) for the linker script (build/memory.ld).
# BOARD=blackpill_f411 | weact_g431 | weact_h562 | weact_h743 | pico2_rp2350 | nicenano_nrf52840
# (no pico_rp2040: Cortex-M0+ has no ITM/SWO)
CPU_HZ ?= 100000000
BOARD ?= blackpill_f411
ifeq ($(BOARD),blackpill_f411)
  CPU := -mcpu=cortex-m4 -mfpu=fpv4-sp-d16 -mfloat-abi=hard
  FLASH_BASE := 0x08000000
  FLASH_SIZE := 512K
  RAM_BASE := 0x20000000
  RAM_SIZE := 128K
  JLINK_DEVICE := STM32F411CE
else ifeq ($(BOARD),weact_g431)
  CPU := -mcpu=cortex-m4 -mfpu=fpv4-sp-d16 -mfloat-abi=hard
  FLASH_BASE := 0x08000000
  FLASH_SIZE := 128K
  RAM_BASE := 0x20000000
  RAM_SIZE := 22K
  JLINK_DEVICE := STM32G431CB
else ifeq ($(BOARD),weact_h562)
  CPU := -mcpu=cortex-m33 -mfpu=fpv5-sp-d16 -mfloat-abi=hard
  FLASH_BASE := 0x08000000
  FLASH_SIZE := 1024K
  RAM_BASE := 0x20000000
  RAM_SIZE := 640K
  JLINK_DEVICE := STM32H562RG
else ifeq ($(BOARD),weact_h743)
  CPU := -mcpu=cortex-m7 -mfpu=fpv5-d16 -mfloat-abi=hard
  FLASH_BASE := 0x08000000
  FLASH_SIZE := 2048K
  RAM_BASE := 0x20000000
  RAM_SIZE := 128K
  JLINK_DEVICE := STM32H743VI
else ifeq ($(BOARD),pico2_rp2350)
  CPU := -mcpu=cortex-m33 -mfpu=fpv5-sp-d16 -mfloat-abi=hard
  FLASH_BASE := 0x10000000
  FLASH_SIZE := 4096K
  RAM_BASE := 0x20000000
  RAM_SIZE := 520K
  JLINK_DEVICE := RP2350_M33_0
else ifeq ($(BOARD),nicenano_nrf52840)
  CPU := -mcpu=cortex-m4 -mfpu=fpv4-sp-d16 -mfloat-abi=hard
  FLASH_BASE := 0x00026000
  FLASH_SIZE := 808K
  RAM_BASE := 0x20000000
  RAM_SIZE := 256K
  JLINK_DEVICE := nRF52840_xxAA
else
  $(error unknown BOARD=$(BOARD))
endif
