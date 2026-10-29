#!/usr/bin/env bash
# about: SystemView without an OS (templates/systemview_app) on F411 (DWT timestamps) and RP2040 (software timestamps): the "SysView" RTT stream is checked in cmsim (no probe)
# Usage (through ./segger-box examples ...): example.sh build | run | test
set -euo pipefail
act=${1:-run}
OUT=${EX_OUT:?run through ./segger-box examples}
L="${BOXT_ROOT:?}/segger-box"
fail() { echo "FAIL $*"; exit 1; }
build() { "$L" new systemview_app sysview --dir "$OUT" --force >/dev/null; }
case "$act" in
  build) build; make -s -C "$OUT/sysview" all ;;
  run) build; make -s -C "$OUT/sysview" sim ;;
  test)
    build
    for b in blackpill_f411 pico_rp2040 weact_h562; do
      out=$(make -s -C "$OUT/sysview" BOARD=$b check 2>&1) || fail "$b: $out"
      grep -q '^PASS sysview' <<<"$out" || fail "$b: $out"
      echo "ok $b: $(tail -1 <<<"$out")"
    done
    echo "PASS systemview_sim (3 boards; stream checked in the simulator, SystemView app not run)" ;;
  *) echo "usage: example.sh build|run|test" >&2; exit 2 ;;
esac
