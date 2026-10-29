# @NAME@

GDB command file for JLinkGDBServer, from `segger-box new gdb_jlink @NAME@` (32_12_segger): connect on
port 2331, set the interface speed, reset and halt, `load`, `compare-sections`, break at `main`, run to it.

    segger-box gdbserver -device STM32F411CE -if SWD -speed 4000 -port 2331 -nogui    # with a probe (you)
    segger-box run arm-none-eabi-gdb -x @NAME@/@NAME@.gdb fw.elf

Without a probe, `check.sh` runs the same script against cmsim's GDB server (same remote protocol,
J-Link-style `monitor` replies):

    segger-box run @NAME@/check.sh path/to/fw.elf    # e.g. an ELF from `segger-box new rtt_firmware`

`load` writes flash on a real target (J-Link's flash loader). Not verified with a probe here.
