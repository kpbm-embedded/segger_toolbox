/* SystemView target configuration for the BlackPill STM32F411CE (Cortex-M4F @ 100 MHz).
 * Force-included before SEGGER's SEGGER_SYSVIEW_Conf.h. SystemView target sources come from the
 * SystemView/J-Link packages (SEGGER BSD-style licence) or https://github.com/SEGGERMicro/SystemView. */
#ifndef SEGGER_SYSVIEW_CONF_BOX_H
#define SEGGER_SYSVIEW_CONF_BOX_H
#define SEGGER_SYSVIEW_APP_NAME        "BlackPill F411 demo"
#define SEGGER_SYSVIEW_DEVICE_NAME     "STM32F411CE"
#define SEGGER_SYSVIEW_CORE            SEGGER_SYSVIEW_CORE_CM3   /* CM3 covers CM4/CM7: DWT cycle counter */
#define SEGGER_SYSVIEW_TIMESTAMP_FREQ  (100000000u)              /* SYSCLK, DWT->CYCCNT */
#define SEGGER_SYSVIEW_CPU_FREQ        (100000000u)
#define SEGGER_SYSVIEW_RAM_BASE        (0x20000000u)             /* 128 KB SRAM */
#define SEGGER_SYSVIEW_ID_SHIFT        (2)
#define SEGGER_SYSVIEW_RTT_BUFFER_SIZE (4096)
#define SEGGER_SYSVIEW_RTT_CHANNEL     (1)
#endif
