/* @NAME@: linker script; FLASH/RAM come from build/memory.ld (written by the Makefile from board.mk). */
INCLUDE memory.ld
ENTRY(Reset_Handler)
_estack = ORIGIN(RAM) + LENGTH(RAM);
SECTIONS {
  .isr_vector : { KEEP(*(.isr_vector)) } > FLASH
  .text : { *(.text*) *(.rodata*) . = ALIGN(4); } > FLASH
  .ARM.exidx : { *(.ARM.exidx*) } > FLASH
  _sidata = ALIGN(4);    /* .data initial values follow the code in flash (explicit: an empty .data gets no LMA) */
  .data : AT(_sidata) { _sdata = .; *(.data*) . = ALIGN(4); _edata = .; } > RAM
  /* RTT control block in its own section: fixed place for J-Link's RTT search (SEGGER_RTT_SECTION) */
  .rtt (NOLOAD) : { . = ALIGN(4); *(.rtt*) } > RAM
  .bss (NOLOAD) : { _sbss = .; *(.bss*) *(COMMON) . = ALIGN(4); _ebss = .; } > RAM
  /DISCARD/ : { *(.ARM.attributes) }
}
