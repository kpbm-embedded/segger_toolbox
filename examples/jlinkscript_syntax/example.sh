#!/usr/bin/env bash
# about: every .JLinkScript template (BlackPill reset hook, H743 low-power debug) syntax-checked as C against lib/jlinkscript_api.h, plus a broken one that must fail (not run)
# Usage (through ./segger-box examples ...): example.sh build | run | test
set -euo pipefail
act=${1:-run}
OUT=${EX_OUT:?run through ./segger-box examples}
L="${BOXT_ROOT:?}/segger-box"
CHK="python3 $BOXT_ROOT/lib/jlink_check.py"
fail() { echo "FAIL $*"; exit 1; }
build() {
  "$L" new jlink_script f411hooks --dir "$OUT" --force >/dev/null
  "$L" new jlink_script_h7 h743debug --dir "$OUT" --force >/dev/null
  printf 'int InitTarget(void) {\n  JLINK_MEM_WriteU32(0x40000000);\n  return 0;\n}\nint MyHook(void) { return 0; }\n' >"$OUT/broken.JLinkScript"
}
case "$act" in
  build) build; ls "$OUT"/*/*.JLinkScript ;;
  run|test)
    build
    for f in "$OUT"/f411hooks/f411hooks.JLinkScript "$OUT"/h743debug/h743debug.JLinkScript; do
      $CHK jlinkscript "$f" || fail "$f"
    done
    "$OUT/h743debug/check.sh" >/dev/null || fail "h743debug/check.sh"
    if out=$($CHK jlinkscript "$OUT/broken.JLinkScript" 2>&1); then fail "broken script passed"; fi
    grep -q 'MyHook(): not a J-Link hook' <<<"$out" || fail "broken (hook name): $out"
    grep -q 'too few arguments' <<<"$out" || fail "broken (syntax): $out"
    echo "PASS jlinkscript_syntax (2 scripts ok, broken one rejected; J-Link itself not run)" ;;
  *) echo "usage: example.sh build|run|test" >&2; exit 2 ;;
esac
