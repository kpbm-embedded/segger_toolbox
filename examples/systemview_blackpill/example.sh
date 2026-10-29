#!/usr/bin/env bash
# about: SystemView target config (SEGGER_SYSVIEW_Conf_box.h) for BlackPill STM32F411CE, syntax-checked against SEGGER's SystemView + RTT sources (pinned by bootstrap)
# Usage (through ./segger-box examples ...): example.sh build | run | test
set -euo pipefail
act=${1:-run}
OUT=${EX_OUT:?run through ./segger-box examples}
INSTD="${BOXT_ROOT:?}/install"
find_src() { find "$INSTD/systemview-src/" "$INSTD/systemview/" "$INSTD/jlink/" -name "$1" 2>/dev/null | head -1; }
unpack_rtt() { # the J-Link pack keeps RTT as a .tgz under Samples/RTT
  local t; t=$(find "$INSTD/jlink/" -name 'SEGGER_RTT_V*.tgz' 2>/dev/null | head -1)
  [[ -n "$t" ]] && { mkdir -p "$OUT/rtt"; tar -xzf "$t" -C "$OUT/rtt"; }
  return 0
}
build() {
  grep -q 'SEGGER_SYSVIEW_TIMESTAMP_FREQ  (100000000u)' SEGGER_SYSVIEW_Conf_box.h
  local sv rtt cc=(cc)
  sv=$(find_src SEGGER_SYSVIEW.c)
  [[ -n "$sv" ]] || return 77
  unpack_rtt
  rtt=$(find "$INSTD/rtt/" "$OUT/rtt" "$INSTD/systemview/" -name SEGGER_RTT.h 2>/dev/null | head -1)
  [[ -n "$rtt" ]] || return 77
  if command -v arm-none-eabi-gcc >/dev/null; then cc=(arm-none-eabi-gcc -mcpu=cortex-m4 -mthumb)
  elif command -v clang >/dev/null; then cc=(clang --target=thumbv7em-none-eabi -ffreestanding); fi
  local conf; conf=$(find "$(dirname "$(dirname "$sv")")/Config/" "$(dirname "$(dirname "$sv")")/" -name SEGGER_SYSVIEW_Conf.h 2>/dev/null | head -1)
  # RTT V8.58 sets the buffer counts in its ConfDefaults, after SystemView V4.10 checks them: pass them here
  "${cc[@]}" -fsyntax-only -DSEGGER_RTT_MAX_NUM_UP_BUFFERS=3 -DSEGGER_RTT_MAX_NUM_DOWN_BUFFERS=3 \
    -include "$PWD/SEGGER_SYSVIEW_Conf_box.h" -I"$(dirname "$sv")" -I"$(dirname "$rtt")" -I"$(dirname "$(dirname "$sv")")/SEGGER" \
    ${conf:+-I"$(dirname "$conf")"} -I"$(dirname "$(dirname "$rtt")")/Config" "$sv"
}
case "$act" in
  build|test)
    rc=0; build || rc=$?
    case "$rc" in
      0) echo "PASS systemview_blackpill (SEGGER_SYSVIEW.c + box config: syntax ok)" ;;
      77) echo "SKIP systemview_blackpill: SystemView target sources not installed (./segger-box bootstrap)" ;;
      *) echo "FAIL systemview_blackpill (rc=$rc)"; exit 1 ;;
    esac ;;
  run) echo "Add SEGGER_SYSVIEW*.c + SEGGER_RTT*.c and this config to your firmware, call SEGGER_SYSVIEW_Conf(), then ./segger-box systemview" ;;
  *) echo "usage: example.sh build|run|test" >&2; exit 2 ;;
esac
