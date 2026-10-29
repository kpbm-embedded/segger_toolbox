#!/usr/bin/env bash
# about: Zig firmware with SEGGER RTT (templates/zig_rtt_firmware, Zig from 32_24_microzig) run in cmsim, then the gdb_jlink script against the Zig ELF and its J-Link plan (no probe; exit 3 without 32_24)
# Usage (through ./segger-box examples ...): example.sh build | run | test
set -euo pipefail
act=${1:-run}
OUT=${EX_OUT:?run through ./segger-box examples}
L="${BOXT_ROOT:?}/segger-box"
fail() { echo "FAIL $*"; exit 1; }
[[ -x "${SEGGER_ZIG_ID:-}/microzig-box" ]] || { echo "skip: 32_24_microzig not found (BOX_MICROZIG)"; exit 3; }
build() {
  "$L" new zig_rtt_firmware zigfw --dir "$OUT" --force >/dev/null
  make -s -C "$OUT/zigfw" all >/dev/null
  "$L" new gdb_jlink zigdbg --dir "$OUT" --force >/dev/null
}
case "$act" in
  build) build ;;
  run|test)
    build
    out=$(make -s -C "$OUT/zigfw" check 2>&1) || fail "$out"
    grep -q '^PASS zigfw' <<<"$out" || fail "$out"
    elf="$OUT/zigfw/build/zigfw.elf"
    d="$OUT/zigdbg"
    gout=$(OUT="$d/build" "$d/check.sh" "$elf" 2>&1) || fail "gdb: $gout"
    "$L" plan blackpill_f411 "$elf" | grep -q "loadfile $elf" || fail "plan"
    [[ "$act" = run ]] && { echo "$out"; echo "$gout"; }
    echo "PASS zig_rtt_gdb_sim (Zig ELF: RTT output, GDB load/break main, J-Link plan; simulated)" ;;
  *) echo "usage: example.sh build|run|test" >&2; exit 2 ;;
esac
