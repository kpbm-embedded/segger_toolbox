# @NAME@

Zig firmware with SEGGER RTT, from `segger-box new zig_rtt_firmware @NAME@` (32_12_segger), for the BlackPill
STM32F411CE. `main.zig` calls SEGGER's C RTT functions (declared as `extern`: Zig 0.17 dropped `@cImport`); the C
parts (RTT, `startup.c`) are compiled by the pinned arm-none-eabi-gcc and Zig links everything with `link.ld`
(same as `rtt_firmware`) and its own memcpy/memset. Zig comes from 32_24_microzig (`$BOX_MICROZIG`, else the sibling folder).

    segger-box run make -C @NAME@ check    # build, run in cmsim, check the RTT output and the vector table
    segger-box plan blackpill_f411 @NAME@/build/@NAME@.elf     # J-Link commands for the ELF (printed)

The ELF is an ordinary Arm ELF: J-Link Commander `loadfile`, JLinkGDBServer + gdb, Ozone and RTT Viewer
treat it like a C build. Not verified with a probe here.
