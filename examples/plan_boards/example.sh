#!/usr/bin/env bash
# about: J-Link flash/GDB/RTT plans for all owned boards (BlackPill F411, Pico RP2040; ESP32-S3, Nano: unsupported)
# Usage (through ./segger-box examples ...): example.sh build | run | test   (prints only, runs no probe)
set -euo pipefail
act=${1:-run}
OUT=${EX_OUT:?run through ./segger-box examples}
L="${BOXT_ROOT:?}/segger-box"
build() { "$L" plan all firmware.elf >"$OUT/plans.txt"; "$L" plan blackpill_f411 firmware.bin >"$OUT/blackpill_bin.txt"; }
case "$act" in
  build) build; echo "wrote $OUT/plans.txt" ;;
  run) build; cat "$OUT/plans.txt" ;;
  test)
    build
    f="$OUT/plans.txt"
    grep -q -- '-device STM32F411CE -if SWD' "$f" || { echo "FAIL: BlackPill device"; exit 1; }
    grep -q -- '-device RP2040_M0_0 -if SWD' "$f" || { echo "FAIL: Pico device"; exit 1; }
    grep -q 'NOT SUPPORTED by J-Link: J-Link does not support the Xtensa ESP32-S3' "$f" || { echo "FAIL: ESP32-S3 note"; exit 1; }
    grep -q 'NOT SUPPORTED by J-Link: J-Link does not support AVR' "$f" || { echo "FAIL: Nano note"; exit 1; }
    grep -q 'loadbin firmware.bin 0x08000000' "$OUT/blackpill_bin.txt" || { echo "FAIL: .bin base address"; exit 1; }
    grep -q 'PRINTED ONLY' "$f" || { echo "FAIL: plan header"; exit 1; }
    echo "PASS plan_boards" ;;
  *) echo "usage: example.sh build|run|test" >&2; exit 2 ;;
esac
