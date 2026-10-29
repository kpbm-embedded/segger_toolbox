#!/usr/bin/env bash
# about: RTT firmware (templates/rtt_firmware) built for 7 boards (F411, G431, H562, H743, RP2040, RP2350, nRF52840) and run in cmsim: RTT output read like J-Link does (no probe)
# Usage (through ./segger-box examples ...): example.sh build | run | test
set -euo pipefail
act=${1:-run}
OUT=${EX_OUT:?run through ./segger-box examples}
L="${BOXT_ROOT:?}/segger-box"
SIM="python3 $BOXT_ROOT/lib/cmsim.py"
fail() { echo "FAIL $*"; exit 1; }
BOARDS="blackpill_f411 weact_g431 weact_h562 weact_h743 pico_rp2040 pico2_rp2350 nicenano_nrf52840"
build() {
  "$L" new rtt_firmware rttfw --dir "$OUT" --force >/dev/null
  for b in $BOARDS; do make -s -C "$OUT/rttfw" BOARD="$b" all >/dev/null; done
}
case "$act" in
  build) build; ls "$OUT"/rttfw/build/*/rttfw.elf ;;
  run) build; for b in $BOARDS; do echo "== $b"; $SIM run "$OUT/rttfw/build/$b/rttfw.elf"; done ;;
  test)
    build
    for b in $BOARDS; do
      elf="$OUT/rttfw/build/$b/rttfw.elf"
      out=$($SIM run "$elf" 2>&1) || fail "$b: $out"
      grep -q 'rttfw: tick 5' <<<"$out" || fail "$b: RTT output: $out"
      grep -q 'rttfw: done' <<<"$out" || fail "$b: RTT output: $out"
      grep -q 'stop: bkpt #0' <<<"$out" || fail "$b: did not finish"
      info=$($SIM info "$elf") || fail "$b: info"
      grep -q "up   0  name 'Terminal'" <<<"$info" || fail "$b: channel 0"
      echo "ok $b: $(grep _SEGGER_RTT <<<"$info")"
    done
    echo "PASS rtt_sim_boards (7 boards; simulated, not run on hardware)" ;;
  *) echo "usage: example.sh build|run|test" >&2; exit 2 ;;
esac
