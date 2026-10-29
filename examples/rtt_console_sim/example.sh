#!/usr/bin/env bash
# about: RTT down channel + virtual terminals (templates/rtt_console): cmsim types commands into down channel 0 and splits the answers by terminal (no probe)
# Usage (through ./segger-box examples ...): example.sh build | run | test
set -euo pipefail
act=${1:-run}
OUT=${EX_OUT:?run through ./segger-box examples}
L="${BOXT_ROOT:?}/segger-box"
SIM="python3 $BOXT_ROOT/lib/cmsim.py"
fail() { echo "FAIL $*"; exit 1; }
build() { "$L" new rtt_console console --dir "$OUT" --force >/dev/null; make -s -C "$OUT/console" BOARD=weact_g431 all >/dev/null; }
sim() { $SIM run "$OUT/console/build/weact_g431/console.elf" --terminals --down 'help\n' --down 'add 2 40\n' \
          --down 'add -5 3\n' --down 'warn battery low\n' --down 'nope\n' --down 'quit\n'; }
case "$act" in
  build) build ;;
  run) build; sim ;;
  test)
    build
    out=$(sim 2>&1) || fail "$out"
    for want in 'console ready' 'commands: help' 'sum 42' 'sum -2' 'unknown: nope' 'bye'; do
      grep -q -- "$want" <<<"$out" || fail "missing '$want' in: $out"
    done
    t1=$(sed -n '/^\[terminal 1\]/,$p' <<<"$out")
    grep -q 'battery low' <<<"$t1" || fail "warning not on terminal 1: $out"
    echo "PASS rtt_console_sim (down channel input + terminal 1; simulated)" ;;
  *) echo "usage: example.sh build|run|test" >&2; exit 2 ;;
esac
