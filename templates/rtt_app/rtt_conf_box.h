/* @NAME@: RTT configuration overrides (force-included before SEGGER_RTT_Conf.h). */
#ifndef @NAME_UPPER@_RTT_CONF_BOX_H
#define @NAME_UPPER@_RTT_CONF_BOX_H
#define SEGGER_RTT_MAX_NUM_UP_BUFFERS     (3)
#define SEGGER_RTT_MAX_NUM_DOWN_BUFFERS   (3)
#define BUFFER_SIZE_UP                    (1024)   /* channel 0 up: terminal output */
#define BUFFER_SIZE_DOWN                  (16)     /* channel 0 down: terminal input */
#define SEGGER_RTT_PRINTF_BUFFER_SIZE     (64)
#define SEGGER_RTT_MODE_DEFAULT           SEGGER_RTT_MODE_NO_BLOCK_SKIP
#endif
