# @NAME@

Per-unit production programming with J-Link Commander, from `segger-box new production_flash @NAME@`
(32_12_segger), for the BlackPill STM32F411CE: full-chip erase, firmware `.bin` at 0x08000000, a 16-byte serial
record (`SN01`, serial, time, CRC-32) in the last flash sector at 0x08060000, both verified with `verifybin`.

    segger-box run make -C @NAME@ FW=../fw/build/blackpill_f411/fw.bin SERIALS="1001 1002 1003" check
    segger-box run make -C @NAME@ FW=... SERIAL=1001 program     # prints the JLinkExe line (dry run)

Run the printed line yourself to program a unit (it ERASES and WRITES the target). `check` runs offline:
known Commander commands, ranges inside the 512 KB flash, files present, records and CRCs, firmware below
the serial sector. Not verified with a probe here.
