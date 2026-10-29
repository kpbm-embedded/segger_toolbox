#!/usr/bin/env bash
# about: GDB script for JLinkGDBServer (templates/gdb_jlink) run by the pinned arm-none-eabi-gdb against cmsim's GDB server: load, compare-sections, break main, monitor commands (no probe)
# Usage (through ./segger-box examples ...): example.sh build | run | test
set -euo pipefail
act=${1:-run}
OUT=${EX_OUT:?run through ./segger-box examples}
L="${BOXT_ROOT:?}/segger-box"
fail() { echo "FAIL $*"; exit 1; }
build() {
  "$L" new rtt_firmware dbgfw --dir "$OUT" --force >/dev/null
  make -s -C "$OUT/dbgfw" BOARD=weact_h743 all >/dev/null
  "$L" new gdb_jlink flashdebug --dir "$OUT" --force >/dev/null
}
case "$act" in
  build) build ;;
  run|test)
    build
    d="$OUT/flashdebug"
    elf="$OUT/dbgfw/build/weact_h743/dbgfw.elf"
    out=$(OUT="$d/build" "$d/check.sh" "$elf" 2>&1) || fail "$out"
    [[ "$act" = run ]] && echo "$out"
    grep -q '^PASS flashdebug' <<<"$out" || fail "$out"
    echo "PASS gdbserver_sim (GDB flow against the simulator; JLinkGDBServer itself not run)" ;;
  *) echo "usage: example.sh build|run|test" >&2; exit 2 ;;
esac
