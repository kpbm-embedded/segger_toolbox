#!/usr/bin/env bash
# about: printf over SWO/ITM (templates/itm_swo) for BlackPill F411 and WeAct H743; cmsim captures the stimulus ports; prints the SWO viewer line (no probe)
# Usage (through ./segger-box examples ...): example.sh build | run | test
set -euo pipefail
act=${1:-run}
OUT=${EX_OUT:?run through ./segger-box examples}
L="${BOXT_ROOT:?}/segger-box"
SIM="python3 $BOXT_ROOT/lib/cmsim.py"
fail() { echo "FAIL $*"; exit 1; }
build() {
  "$L" new itm_swo swo --dir "$OUT" --force >/dev/null
  make -s -C "$OUT/swo" BOARD=blackpill_f411 all >/dev/null
  make -s -C "$OUT/swo" BOARD=weact_h743 CPU_HZ=480000000 all >/dev/null
}
case "$act" in
  build) build ;;
  run) build; $SIM run "$OUT/swo/build/blackpill_f411/swo.elf" --itm; make -s -C "$OUT/swo" swo-plan ;;
  test)
    build
    for b in blackpill_f411 weact_h743; do
      out=$($SIM run "$OUT/swo/build/$b/swo.elf" --itm 2>&1) || fail "$b: $out"
      grep -q 'sample 300' <<<"$out" || fail "$b port 0: $out"
      grep -q '0xc0de0001 0xc0de0002 0xc0de0003' <<<"$out" || fail "$b port 1: $out"
    done
    make -s -C "$OUT/swo" BOARD=weact_h743 CPU_HZ=480000000 swo-plan | grep -q -- '-cpufreq 480000000' || fail "swo-plan"
    echo "PASS itm_swo_sim (ITM ports 0 and 1 on 2 boards; simulated, SWO pin not checked)" ;;
  *) echo "usage: example.sh build|run|test" >&2; exit 2 ;;
esac
