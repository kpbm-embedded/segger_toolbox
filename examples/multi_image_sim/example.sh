#!/usr/bin/env bash
# about: bootloader + application (templates/multi_image) for BlackPill F411: layout/merged-image checks, then cmsim runs bootloader -> app (no probe)
# Usage (through ./segger-box examples ...): example.sh build | run | test
set -euo pipefail
act=${1:-run}
OUT=${EX_OUT:?run through ./segger-box examples}
L="${BOXT_ROOT:?}/segger-box"
CHK="python3 $BOXT_ROOT/lib/jlink_check.py"
fail() { echo "FAIL $*"; exit 1; }
build() { "$L" new multi_image bootapp --dir "$OUT" --force >/dev/null; make -s -C "$OUT/bootapp" all >/dev/null; }
case "$act" in
  build) build; ls "$OUT/bootapp/build" ;;
  run) build; make -s -C "$OUT/bootapp" check sim ;;
  test)
    build
    out=$(make -s -C "$OUT/bootapp" check 2>&1) || fail "$out"
    grep -q '^PASS bootapp layout' <<<"$out" || fail "$out"
    out=$(make -s -C "$OUT/bootapp" sim 2>&1) || fail "$out"
    grep -q 'started by the bootloader' <<<"$out" || fail "$out"
    (cd "$OUT/bootapp" && $CHK commander build/flash_bootapp.jlink --flash 0x08000000:0x80000 --files-exist >/dev/null) || fail "commander"
    echo "PASS multi_image_sim (layout + hand-over in the simulator; flashing not run)" ;;
  *) echo "usage: example.sh build|run|test" >&2; exit 2 ;;
esac
