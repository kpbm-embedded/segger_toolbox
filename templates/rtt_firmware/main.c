/* @NAME@: RTT hello for Cortex-M (counts to 5, then returns: BKPT #0). */
#include "SEGGER_RTT.h"

static unsigned counter;

int main(void) {
  SEGGER_RTT_Init();
  SEGGER_RTT_WriteString(0, "@NAME@: hello over RTT\n");
  for (counter = 1; counter <= 5; counter++) {
    SEGGER_RTT_printf(0, "@NAME@: tick %u\n", counter);
  }
  SEGGER_RTT_WriteString(0, "@NAME@: done\n");
  return 0;
}
