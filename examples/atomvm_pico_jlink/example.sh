#!/usr/bin/env bash
# about: AtomVM (Erlang) app for the Pico flashed over SWD (templates/atomvm_pico_jlink): app run on the host AtomVM of 32_29, VM/lib/app placed at the addresses the VM expects, J-Link script checked (not flashed; exit 3 without 32_29)
# Usage (through ./segger-box examples ...): example.sh build | run | test
set -euo pipefail
act=${1:-run}
OUT=${EX_OUT:?run through ./segger-box examples}
L="${BOXT_ROOT:?}/segger-box"
fail() { echo "FAIL $*"; exit 1; }
[[ -x "${SEGGER_ATOMVM_ID:-}/atomvm-box" ]] || { echo "skip: 32_29_atomvm not found (BOX_ATOMVM)"; exit 3; }
build() { "$L" new atomvm_pico_jlink beamapp --dir "$OUT" --force >/dev/null; make -s -C "$OUT/beamapp" all >/dev/null; }
case "$act" in
  build) build; cat "$OUT/beamapp/build/flash_beamapp.jlink" ;;
  run|test)
    build
    out=$(make -s -C "$OUT/beamapp" check 2>&1) || fail "$out"
    [[ "$act" = run ]] && echo "$out"
    grep -q '^PASS beamapp' <<<"$out" || fail "$out"
    echo "PASS atomvm_pico_jlink (host AtomVM run + layout/script checks; nothing flashed)" ;;
  *) echo "usage: example.sh build|run|test" >&2; exit 2 ;;
esac
