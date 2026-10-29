# @NAME@

Printf over SWO (ITM stimulus port 0) and 32-bit samples on port 1, from `segger-box new itm_swo @NAME@`
(32_12_segger). `main.c` sets DEMCR.TRCENA, the TPIU (NRZ, 2 MHz SWO) and the ITM with architectural
register addresses, so it works on every ARMv7-M/ARMv8-M board in `board.mk` (not on the Cortex-M0+
RP2040, which has no ITM). Set `CPU_HZ` to your core clock (the BlackPill runs at 100 MHz after clock
setup; without clock setup the reset clock is 16 MHz HSI: `make CPU_HZ=16000000`).

    segger-box run make -C @NAME@ sim        # cmsim captures the ITM port writes and prints them per port
    segger-box run make -C @NAME@ swo-plan   # the JLinkSWOViewerCLExe line for the probe

The SWO pin is PB3 on STM32F4/G4/H7 (`DBGMCU_CR.TRACE_IOEN`); the nice!nano does not bring SWO out.
Not verified with a probe here.
