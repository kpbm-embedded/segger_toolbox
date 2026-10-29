# @NAME@

Bare-metal Cortex-M firmware with SEGGER RTT, from `segger-box new rtt_firmware @NAME@` (32_12_segger).
No vendor HAL: `startup.c` + `link.ld` + `board.mk` (flash/RAM per board). RTT sources come from
`$SEGGER_RTT_DIR` (SEGGER's BSD-licensed RTT, pinned by `segger-box bootstrap`).

    segger-box run make -C @NAME@                      # build/blackpill_f411/@NAME@.{elf,hex,bin,map}
    segger-box run make -C @NAME@ BOARD=weact_h743     # other boards: see board.mk
    segger-box run make -C @NAME@ sim                  # run in cmsim and print RTT channel 0 (no probe)
    segger-box run make -C @NAME@ info                 # RTT control block address and buffers

The RTT control block is placed in section `.rtt` (`SEGGER_RTT_SECTION`), so its address is fixed per
build: `segger-box plan <board> fw.elf` prints the J-Link commands; with RTT Viewer or
`JLinkRTTLogger -RTTAddress 0x...` you can give the address from `make info` instead of searching RAM.

On hardware (you run it, it writes the target): `segger-box jlink -device <JLINK_DEVICE> -if SWD -speed 4000
-autoconnect 1 -CommanderScript flash.jlink`, then `segger-box rtt-logger -Device <JLINK_DEVICE> -If SWD -Speed 4000
-RTTChannel 0 rtt.log`. Not verified on a board here (no J-Link attached).
