#!/usr/bin/env bash
# about: Rust + defmt over RTT (templates/rust_defmt_rtt) built with 32_17_embedded_rust's toolchain, run in cmsim, frames decoded by defmt-print; J-Link commands checked (no probe; exit 3 without 32_17)
# Usage (through ./segger-box examples ...): example.sh build | run | test
set -euo pipefail
act=${1:-run}
OUT=${EX_OUT:?run through ./segger-box examples}
L="${BOXT_ROOT:?}/segger-box"
fail() { echo "FAIL $*"; exit 1; }
[[ -x "${SEGGER_RUST_ID:-}/rust-box" ]] || { echo "skip: 32_17_embedded_rust not found (BOX_EMBEDDED_RUST)"; exit 3; }
build() { "$L" new rust_defmt_rtt rustlog --dir "$OUT" --force >/dev/null; }
case "$act" in
  build) build ;;
  run|test)
    build
    d="$OUT/rustlog"
    out=$(OUT="$OUT/build" "$d/check.sh" 2>&1) || fail "$out"
    [[ "$act" = run ]] && echo "$out"
    grep -q '^PASS rustlog' <<<"$out" || fail "$out"
    echo "PASS rust_defmt_rtt_sim (defmt frames over RTT decoded; simulated, no probe)" ;;
  *) echo "usage: example.sh build|run|test" >&2; exit 2 ;;
esac
