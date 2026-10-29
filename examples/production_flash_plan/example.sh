#!/usr/bin/env bash
# about: production programming for 3 BlackPill units (templates/production_flash): per-unit Commander scripts + serial records with CRC, checked offline; the JLinkExe line only as a dry run
# Usage (through ./segger-box examples ...): example.sh build | run | test
set -euo pipefail
act=${1:-run}
OUT=${EX_OUT:?run through ./segger-box examples}
L="${BOXT_ROOT:?}/segger-box"
fail() { echo "FAIL $*"; exit 1; }
build() {
  "$L" new rtt_firmware prodfw --dir "$OUT" --force >/dev/null
  make -s -C "$OUT/prodfw" all >/dev/null
  "$L" new production_flash line1 --dir "$OUT" --force >/dev/null
  SOURCE_DATE_EPOCH=1793232000 make -s -C "$OUT/line1" FW="$OUT/prodfw/build/blackpill_f411/prodfw.bin" SERIALS="2001 2002 2003" all >/dev/null
}
case "$act" in
  build) build; ls "$OUT/line1/build" ;;
  run) build; cat "$OUT/line1/build/prog_2001.jlink"; make -s -C "$OUT/line1" FW="$OUT/prodfw/build/blackpill_f411/prodfw.bin" SERIAL=2001 program ;;
  test)
    build
    out=$(make -s -C "$OUT/line1" FW="$OUT/prodfw/build/blackpill_f411/prodfw.bin" SERIALS="2001 2002 2003" check 2>&1) || fail "$out"
    grep -q 'PASS line1: 3 unit' <<<"$out" || fail "$out"
    out=$(make -s -C "$OUT/line1" FW="$OUT/prodfw/build/blackpill_f411/prodfw.bin" SERIAL=2002 program 2>&1) || fail "$out"
    grep -q '^+ JLinkExe -device STM32F411CE .*prog_2002.jlink' <<<"$out" || fail "dry run: $out"
    cmp -s "$OUT/line1/build/serial_2001.bin" "$OUT/line1/build/serial_2002.bin" && fail "records not unique"
    echo "PASS production_flash_plan (3 units checked offline; nothing programmed)" ;;
  *) echo "usage: example.sh build|run|test" >&2; exit 2 ;;
esac
