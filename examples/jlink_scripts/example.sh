#!/usr/bin/env bash
# about: J-Link Commander + JLinkScript files for BlackPill F411 and Pico RP2040 from templates/jlink_script (validated, not run)
# Usage (through ./segger-box examples ...): example.sh build | run | test
set -euo pipefail
act=${1:-run}
OUT=${EX_OUT:?run through ./segger-box examples}
L="${BOXT_ROOT:?}/segger-box"
KNOWN='^(r|h|g|s|q|exit|sleep [0-9]+|loadfile [^ ]+( 0x[0-9a-fA-F]+)?|loadbin [^ ]+ 0x[0-9a-fA-F]+|verifybin [^ ]+ 0x[0-9a-fA-F]+|erase|mem32 0x[0-9a-fA-F]+ [0-9]+|w4 0x[0-9a-fA-F]+ 0x[0-9a-fA-F]+|speed [0-9]+|device [A-Za-z0-9_]+|si (SWD|JTAG|1|0)|connect)$'
build() {
  "$L" new jlink_script blackpill_f411 --dir "$OUT" --force >/dev/null
  "$L" new jlink_script pico_rp2040 --dir "$OUT" --force >/dev/null
  # Pico: ELF/HEX load at XIP flash; BlackPill: binary at 0x08000000
  sed -i 's#^loadfile .*#loadbin build/blackpill_f411.bin 0x08000000\nverifybin build/blackpill_f411.bin 0x08000000#' "$OUT/blackpill_f411/blackpill_f411.jlink"
  sed -i 's#^loadfile .*#loadfile build/pico_rp2040.elf#' "$OUT/pico_rp2040/pico_rp2040.jlink"
}
check() { # commander script -> every line a known command
  local f=$1 bad
  bad=$(grep -vE "$KNOWN" "$f" || true)
  [[ -z "$bad" ]] || { echo "FAIL: unknown J-Link command(s) in $f: $bad"; return 1; }
  grep -qx exit <<<"$(tail -1 "$f")" || { echo "FAIL: $f does not end with exit"; return 1; }
}
case "$act" in
  build) build; find "$OUT" -type f | sort ;;
  run) build; for f in "$OUT"/*/*.jlink; do echo "== $f"; cat "$f"; done ;;
  test)
    build
    for b in blackpill_f411 pico_rp2040; do
      check "$OUT/$b/$b.jlink"
      s="$OUT/$b/$b.JLinkScript"
      if ! grep -q 'int ConfigTargetSettings(void)' "$s" || ! grep -q 'int ResetTarget(void)' "$s"; then echo "FAIL: $s hooks"; exit 1; fi
      [[ "$(grep -o '{' "$s" | wc -l)" = "$(grep -o '}' "$s" | wc -l)" ]] || { echo "FAIL: $s braces"; exit 1; }
    done
    grep -q 'loadbin build/blackpill_f411.bin 0x08000000' "$OUT/blackpill_f411/blackpill_f411.jlink" || { echo "FAIL: base"; exit 1; }
    echo "PASS jlink_scripts (scripts generated and validated; running them writes a target, so they are never run here)" ;;
  *) echo "usage: example.sh build|run|test" >&2; exit 2 ;;
esac
