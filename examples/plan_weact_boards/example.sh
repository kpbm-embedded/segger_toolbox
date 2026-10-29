#!/usr/bin/env bash
# about: J-Link plans for the WeAct G431/H562/H743, Pico 2 and nice!nano boards (prints only), plus why ESP32-C3 and CH32V003 are not J-Link targets
# Usage (through ./segger-box examples ...): example.sh build | run | test   (prints only, runs no probe)
set -euo pipefail
act=${1:-run}
OUT=${EX_OUT:?run through ./segger-box examples}
L="${BOXT_ROOT:?}/segger-box"
CHK="python3 $BOXT_ROOT/lib/jlink_check.py"
fail() { echo "FAIL $*"; exit 1; }
BOARDS="weact_g431 weact_h562 weact_h743 pico2_rp2350 nicenano_nrf52840 esp32c3_supermini ch32v003"
build() { for b in $BOARDS; do "$L" plan "$b" fw.bin >"$OUT/$b.txt"; done; }
case "$act" in
  build) build; ls "$OUT" ;;
  run) build; cat "$OUT"/*.txt ;;
  test)
    build
    while read -r b dev base; do
      grep -q -- "-device $dev -if SWD" "$OUT/$b.txt" || fail "$b device"
      grep -q "loadbin fw.bin $base" "$OUT/$b.txt" || fail "$b base"
      sed -n "/^cat > flash_$b.jlink/,/^JL$/p" "$OUT/$b.txt" | sed '1d;$d' >"$OUT/$b.jlink"
      : >"$OUT/fw.bin"; (cd "$OUT" && $CHK commander "$b.jlink" >/dev/null) || fail "$b commander script"
    done <<'TAB'
weact_g431 STM32G431CB 0x08000000
weact_h562 STM32H562RG 0x08000000
weact_h743 STM32H743VI 0x08000000
pico2_rp2350 RP2350_M33_0 0x10000000
nicenano_nrf52840 nRF52840_xxAA 0x00026000
TAB
    grep -q 'NOT SUPPORTED.*USB-Serial/JTAG' "$OUT/esp32c3_supermini.txt" || fail "esp32c3 note"
    grep -q 'NOT SUPPORTED.*WCH-LinkE' "$OUT/ch32v003.txt" || fail "ch32v003 note"
    echo "PASS plan_weact_boards (5 J-Link plans checked, 2 boards explained; nothing run)" ;;
  *) echo "usage: example.sh build|run|test" >&2; exit 2 ;;
esac
