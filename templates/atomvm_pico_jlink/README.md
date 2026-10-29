# @NAME@

AtomVM (Erlang) application for the Raspberry Pi Pico, flashed over SWD with a J-Link, from
`segger-box new atomvm_pico_jlink @NAME@` (32_12_segger). AtomVM 0.6.6, atomvmlib, OTP and packbeam come from
32_29_atomvm (`$BOX_ATOMVM`, else the sibling folder); nothing is installed here.

The BOOTSEL drive takes three UF2 files; with J-Link the same images go in as binaries (`uf2tobin.py`): the
AtomVM VM at 0x10000000, atomvmlib (the Pico `.uf2`) at 0x10100000, the app `.avm` at 0x10180000. These are
the LIB_AVM/MAIN_AVM addresses compiled into the 0.6.6 VM image; `layout_check.py` checks that the image
references them and that nothing overlaps.

    segger-box run make -C @NAME@ check     # .avm built + run on the host AtomVM, script and ranges checked
    segger-box jlink -device RP2040_M0_0 -if SWD -speed 4000 -autoconnect 1 -CommanderScript @NAME@/build/flash_@NAME@.jlink

The last command WRITES flash (you run it). Not verified with a probe here.
