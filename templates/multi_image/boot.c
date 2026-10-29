/* @NAME@ bootloader: checks the application's vector table, leaves a hand-over word in RAM and jumps.
 * Real bootloaders also verify a CRC/signature and de-initialise clocks/peripherals before jumping. */
#include <stdint.h>

#define APP_BASE   0x08008000u
#define RAM_START  0x20000000u
#define RAM_END    0x20020000u
#define VTOR       (*(volatile uint32_t *)0xE000ED08u)

__attribute__((section(".handover"))) volatile uint32_t boot_handover;   /* fixed address, see *.ld */

int main(void) {
  const uint32_t *app = (const uint32_t *)APP_BASE;
  uint32_t sp = app[0], entry = app[1];
  if (sp < RAM_START || sp > RAM_END || (entry & 1u) == 0) {
    return 1;                                     /* no valid application: stay here (BKPT #2) */
  }
  boot_handover = 0xB007C0DEu;
  VTOR = APP_BASE;                                /* the app's vector table from now on */
  __asm volatile("msr msp, %0\n bx %1" : : "r"(sp), "r"(entry));
  return 1;
}
