/* @NAME@: SystemView events without an RTOS: markers, a fake ISR, printf and warnings.
 * Recording streams over RTT channel 1 ("SysView"); SystemView (the host app) reads it via J-Link. */
#include "SEGGER_SYSVIEW.h"

#define MARKER_WORK 1u

static volatile unsigned sink;

static void fake_isr(void) {               /* what an ISR wrapper records around the handler */
  SEGGER_SYSVIEW_RecordEnterISR();
  sink++;
  SEGGER_SYSVIEW_RecordExitISR();
}

int main(void) {
  SEGGER_SYSVIEW_Conf();
  SEGGER_SYSVIEW_Start();                  /* start recording without waiting for the host */
  SEGGER_SYSVIEW_NameMarker(MARKER_WORK, "work");
  SEGGER_SYSVIEW_Print("@NAME@ start");
  for (unsigned i = 0; i < 3; i++) {
    SEGGER_SYSVIEW_MarkStart(MARKER_WORK);
    for (volatile unsigned d = 0; d < 200u; d++) { }
    fake_isr();
    SEGGER_SYSVIEW_MarkStop(MARKER_WORK);
    SEGGER_SYSVIEW_PrintfHost("loop %u", i);
  }
  SEGGER_SYSVIEW_Warn("@NAME@ warning sample");
  SEGGER_SYSVIEW_Print("@NAME@ end");
  return 0;
}
