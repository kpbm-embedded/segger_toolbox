# @NAME@

Target-side SEGGER RTT project from `segger-box new rtt_app @NAME@` (32_12_segger), for the
BlackPill STM32F411CE (any Cortex-M works: change `DEVICE` in the Makefile).

SEGGER's RTT sources (`SEGGER_RTT.c`, `SEGGER_RTT.h`, `SEGGER_RTT_printf.c`) are under SEGGER's
BSD-style licence and are not copied here: `segger-box bootstrap` pins them from github.com/SEGGERMicro/RTT
(`$SEGGER_RTT_DIR`, set inside `segger-box shell`); without them `make check` falls back to the copy in the
installed J-Link pack (`$SEGGER_JLINK_DIR`), or set `RTT_DIR=...`:

    segger-box shell -- make check          # syntax-checks main.c + config against the RTT sources
    make RTT_DIR=/path/to/RTT check

`rtt_conf_box.h` holds the buffer sizes and is included by SEGGER's `SEGGER_RTT_Conf.h` via
`-include`. To build real firmware, add these files to your STM32 project (CMake/Make, any
arm-none-eabi toolchain), then view the output with `segger-box rtt` or
`segger-box rtt-logger -Device STM32F411CE -If SWD -Speed 4000 -RTTChannel 0 log.txt`.
