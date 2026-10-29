/* @NAME@: RTT hello for Cortex-M (BlackPill STM32F411CE by default). */
#include "SEGGER_RTT.h"

static volatile unsigned counter;

int main(void) {
  SEGGER_RTT_ConfigUpBuffer(0, NULL, NULL, 0, SEGGER_RTT_MODE_NO_BLOCK_SKIP);
  SEGGER_RTT_WriteString(0, "@NAME@: hello over RTT\r\n");
  for (;;) {
    SEGGER_RTT_printf(0, "@NAME@: tick %u\r\n", counter++);
    for (volatile unsigned i = 0; i < 1000000u; i++) { }
    if (SEGGER_RTT_HasKey()) {
      int c = SEGGER_RTT_GetKey();
      SEGGER_RTT_printf(0, "@NAME@: got key %c\r\n", c);
    }
  }
}
