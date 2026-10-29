/* @NAME@ application at 0x08008000: reports over RTT whether the bootloader started it. */
#include <stdint.h>
#include "SEGGER_RTT.h"

extern volatile uint32_t boot_handover;            /* same fixed address as in the bootloader */
#define VTOR (*(volatile uint32_t *)0xE000ED08u)

int main(void) {
  SEGGER_RTT_Init();
  SEGGER_RTT_printf(0, "@NAME@ app: VTOR=0x%08X handover=0x%08X\n", (unsigned)VTOR, (unsigned)boot_handover);
  if (boot_handover == 0xB007C0DEu && VTOR == 0x08008000u) {
    SEGGER_RTT_WriteString(0, "@NAME@ app: started by the bootloader\n");
    return 0;
  }
  SEGGER_RTT_WriteString(0, "@NAME@ app: started directly\n");
  return 1;
}
