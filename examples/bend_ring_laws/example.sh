#!/usr/bin/env bash
# about: Bend 2 (host only, via 32_31_bend): RTT ring-buffer index laws (used/free/full/wrap) checked for every offset pair (the arithmetic cmsim and J-Link use); exit 3 without 32_31_bend (Bend has no MCU target)
# Usage (through ./segger-box examples ...): example.sh build | run | test
set -euo pipefail
act=${1:-run}
OUT=${EX_OUT:?run through ./segger-box examples}
fail() { echo "FAIL $*"; exit 1; }
[[ -x "${SEGGER_BEND_ID:-}/bend-box" ]] || { echo "skip: 32_31_bend not found (BOX_BEND); Bend is host-only, the laws need it" >&2; exit 3; }
case "$act" in
  build) cp ring_laws.bend "$OUT/" ;;
  run|test)
    cp ring_laws.bend "$OUT/"
    out=$("$SEGGER_BEND_ID/bend-box" bend "$OUT/ring_laws.bend" 2>&1) || fail "bend: $out"
    [[ "$act" = run ]] && echo "$out"
    [[ "$(tail -1 <<<"$out")" =~ (^|[^0-9])0$ ]] || fail "law violations: $out"
    echo "PASS bend_ring_laws (0 violations in Bend; host-side only)" ;;
  *) echo "usage: example.sh build|run|test" >&2; exit 2 ;;
esac
