/* @NAME@: SystemView configuration without an OS (based on SEGGER's Sample/NoOS/Config/Cortex-M).
 * ARMv7-M/ARMv8-M: timestamps from DWT->CYCCNT, so CPU_HZ must be the real core clock.
 * Cortex-M0+ (RP2040) has no cycle counter: SEGGER_SYSVIEW_X_GetTimestamp() below is a software tick
 * placeholder; on the Pico return the 1 MHz TIMERAWL register instead (and TIMESTAMP_HZ 1000000). */
#include "SEGGER_SYSVIEW.h"

#ifndef CPU_HZ
#define CPU_HZ 100000000u
#endif
#ifndef RAM_BASE
#define RAM_BASE 0x20000000u
#endif
#define DEMCR     (*(volatile unsigned long *)0xE000EDFCuL)
#define DWT_CTRL  (*(volatile unsigned long *)0xE0001000uL)

#if defined(__ARM_ARCH_6M__)
#define TIMESTAMP_HZ 1000000u
U32 SEGGER_SYSVIEW_X_GetTimestamp(void) {
  static U32 ticks;
  return ticks += 10u;                     /* placeholder: monotonic, 10 us per event */
}
#else
#define TIMESTAMP_HZ CPU_HZ
#endif

static void send_system_desc(void) {
  SEGGER_SYSVIEW_SendSysDesc("N=@NAME@,D=" SYSVIEW_DEVICE ",O=NoOS");
  SEGGER_SYSVIEW_SendSysDesc("I#15=SysTick,I#16=WWDG");
}

void SEGGER_SYSVIEW_Conf(void) {
#if !defined(__ARM_ARCH_6M__)
  DEMCR |= 1uL << 24;                      /* TRCENA: DWT usable without a debugger (post-mortem too) */
  if ((DWT_CTRL & (1uL << 25)) == 0) {      /* NOCYCCNT clear: cycle counter present */
    DWT_CTRL |= 1uL;                        /* CYCCNTENA */
  }
#endif
  SEGGER_SYSVIEW_Init(TIMESTAMP_HZ, CPU_HZ, 0, send_system_desc);
  SEGGER_SYSVIEW_SetRAMBase(RAM_BASE);
}
