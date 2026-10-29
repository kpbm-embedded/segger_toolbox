#!/usr/bin/env bash
# about: Ozone project (templates/ozone_project) for a built BlackPill ELF, checked offline: actions, hooks, C syntax, File.Open target (Ozone not started)
# Usage (through ./segger-box examples ...): example.sh build | run | test
set -euo pipefail
act=${1:-run}
OUT=${EX_OUT:?run through ./segger-box examples}
L="${BOXT_ROOT:?}/segger-box"
CHK="python3 $BOXT_ROOT/lib/jlink_check.py"
fail() { echo "FAIL $*"; exit 1; }
build() {
  "$L" new rtt_firmware ozfw --dir "$OUT" --force >/dev/null
  make -s -C "$OUT/ozfw" all >/dev/null
  "$L" new ozone_project ozproj --dir "$OUT" --force >/dev/null
}
case "$act" in
  build) build ;;
  run) build; cat "$OUT/ozproj/ozproj.jdebug" ;;
  test)
    build
    out=$("$OUT/ozproj/check.sh" "$OUT/ozfw/build/blackpill_f411/ozfw.elf" 2>&1) || fail "$out"
    grep -q '^PASS ozproj' <<<"$out" || fail "$out"
    sed 's/Target.ReadU32/Target.ReadU33/' "$OUT/ozproj/ozproj.jdebug" >"$OUT/ozproj/bad.jdebug"
    if $CHK ozone "$OUT/ozproj/bad.jdebug" >/dev/null 2>&1; then fail "a misspelt action was not caught"; fi
    echo "PASS ozone_project_check (checked offline; Ozone and a probe not used)" ;;
  *) echo "usage: example.sh build|run|test" >&2; exit 2 ;;
esac
