# @NAME@

SystemView recording without an RTOS, from `segger-box new systemview_app @NAME@` (32_12_segger):
`sysview_config.c` (DWT cycle counter timestamps, `CPU_HZ`), `main.c` (markers, an ISR enter/exit pair,
prints and a warning). SEGGER's SystemView and RTT target sources come from `$SEGGER_SYSVIEW_DIR` and
`$SEGGER_RTT_DIR` (BSD-licensed, pinned by `segger-box bootstrap`).

    segger-box run make -C @NAME@ check      # run in cmsim, check the "SysView" RTT channel (no probe)
    segger-box run make -C @NAME@ BOARD=weact_h743 CPU_HZ=480000000 all

On hardware: flash, then `segger-box systemview` (SystemView is licensed: free for non-commercial use)
-> Target -> Start Recording, device `JLINK_DEVICE` from `board.mk`. For FreeRTOS use SEGGER's
`Sample/FreeRTOSV11` instead of `sysview_config.c`. Not verified with a probe here.
