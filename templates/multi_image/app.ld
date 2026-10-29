/* @NAME@ app: BlackPill STM32F411CE, flash 0x08008000 (480K). 4 bytes at 0x20000000 are the hand-over word. */
MEMORY {
  FLASH (rx)    : ORIGIN = 0x08008000, LENGTH = 480K
  HANDOVER (rw) : ORIGIN = 0x20000000, LENGTH = 4
  RAM (rwx)     : ORIGIN = 0x20000004, LENGTH = 128K - 4
}
ENTRY(Reset_Handler)
_estack = ORIGIN(RAM) + LENGTH(RAM);
PROVIDE(boot_handover = ORIGIN(HANDOVER));
SECTIONS {
  .isr_vector : { KEEP(*(.isr_vector)) } > FLASH
  .text : { *(.text*) *(.rodata*) . = ALIGN(4); } > FLASH
  .ARM.exidx : { *(.ARM.exidx*) } > FLASH
  _sidata = ALIGN(4);    /* .data initial values follow the code in flash (explicit: an empty .data gets no LMA) */
  .data : AT(_sidata) { _sdata = .; *(.data*) . = ALIGN(4); _edata = .; } > RAM
  .handover (NOLOAD) : { *(.handover) } > HANDOVER
  .bss (NOLOAD) : { _sbss = .; *(.bss*) *(.rtt*) *(COMMON) . = ALIGN(4); _ebss = .; } > RAM
  /DISCARD/ : { *(.ARM.attributes) }
}
