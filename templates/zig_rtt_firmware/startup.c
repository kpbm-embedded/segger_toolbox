/* @NAME@: minimal Cortex-M startup (vector table, .data copy, .bss zero). No vendor headers needed. */
#include <stdint.h>

extern uint32_t _sidata, _sdata, _edata, _sbss, _ebss, _estack;
int main(void);

void Default_Handler(void) {
  for (;;) { __asm volatile("bkpt #1"); }   /* any fault/interrupt stops a debugger (or cmsim) here */
}

void Reset_Handler(void) {
  uint32_t *src = &_sidata, *dst = &_sdata;
  while (dst < &_edata) { *dst++ = *src++; }
  for (dst = &_sbss; dst < &_ebss;) { *dst++ = 0; }
  int rc = main();
  /* main returned: BKPT #0 = success for the simulator, a halted core on hardware */
  if (rc == 0) { __asm volatile("bkpt #0"); } else { __asm volatile("bkpt #2"); }
  for (;;) { }
}

__attribute__((section(".isr_vector"), used))
void (*const vector_table[16])(void) = {
  (void (*)(void))&_estack, Reset_Handler,
  Default_Handler, Default_Handler, Default_Handler, Default_Handler, Default_Handler, 0, 0, 0, 0,
  Default_Handler, Default_Handler, 0, Default_Handler, Default_Handler,
};

/* newlib-nano stubs, so memcpy/strlen from libc link without semihosting */
void _exit(int rc) { (void)rc; for (;;) { __asm volatile("bkpt #3"); } }
