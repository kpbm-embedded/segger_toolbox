#!/usr/bin/env bash
# about: target-side RTT app (templates/rtt_app) for BlackPill STM32F411CE, syntax-checked against SEGGER's RTT sources (pinned by bootstrap)
# Usage (through ./segger-box examples ...): example.sh build | run | test
set -euo pipefail
act=${1:-run}
OUT=${EX_OUT:?run through ./segger-box examples}
L="${BOXT_ROOT:?}/segger-box"
build() {
  "$L" new rtt_app rtt_blackpill --dir "$OUT" --force >/dev/null
  local rc=0
  (cd "$OUT/rtt_blackpill" && make -s check DEVICE=STM32F411CE BUILD="$OUT/rtt_blackpill/build") || rc=$?
  return "$rc"
}
case "$act" in
  build|test)
    rc=0; build || rc=$?
    if [[ "$rc" = 0 ]]; then echo "PASS rtt_blackpill"; exit 0; fi
    echo "FAIL rtt_blackpill (rc=$rc)"; exit 1 ;;
  run) echo "Flash the firmware with your STM32 project, then: ./segger-box rtt-logger -Device STM32F411CE -If SWD -Speed 4000 -RTTChannel 0 rtt.log" ;;
  *) echo "usage: example.sh build|run|test" >&2; exit 2 ;;
esac
