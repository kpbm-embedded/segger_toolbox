# @NAME@

Bootloader + application layout for the BlackPill STM32F411CE, from `segger-box new multi_image @NAME@`
(32_12_segger): bootloader at 0x08000000 (32 KB, first flash sectors 0-1), application at 0x08008000.
The bootloader checks the app's vector table, writes a hand-over word at 0x20000000, sets VTOR and jumps;
the app reports over RTT. One merged `.bin` (gap filled with 0xFF) and a J-Link Commander script for it.

    segger-box run make -C @NAME@ check   # layout checks: ranges, vector tables, merged image, script
    segger-box run make -C @NAME@ sim     # cmsim: bootloader -> app, app's RTT output (no probe)

On hardware (you run it, it WRITES flash): `segger-box jlink -device STM32F411CE -if SWD -speed 4000
-autoconnect 1 -NoGui 1 -ExitOnError 1 -CommanderScript build/flash_@NAME@.jlink`. Not verified with a probe.
