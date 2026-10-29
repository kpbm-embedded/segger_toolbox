#!/usr/bin/env bash
# about: RTT control block in its own section: address from the ELF (nm, readelf, map), then J-Link commands that use it instead of a RAM search (checked, not run)
# Usage (through ./segger-box examples ...): example.sh build | run | test
set -euo pipefail
act=${1:-run}
OUT=${EX_OUT:?run through ./segger-box examples}
L="${BOXT_ROOT:?}/segger-box"
SIM="python3 $BOXT_ROOT/lib/cmsim.py"
CHK="python3 $BOXT_ROOT/lib/jlink_check.py"
fail() { echo "FAIL $*"; exit 1; }
B=blackpill_f411
build() {
  "$L" new rtt_firmware fixed --dir "$OUT" --force >/dev/null
  make -s -C "$OUT/fixed" BOARD=$B all >/dev/null
  elf="$OUT/fixed/build/$B/fixed.elf"
  addr=0x$(arm-none-eabi-nm "$elf" | awk '$3=="_SEGGER_RTT" {print $1}')
  cat >"$OUT/rtt_commands.txt" <<TXT
# RTT control block of fixed.elf: $addr (section .rtt)
./segger-box rtt-logger -Device STM32F411CE -If SWD -Speed 4000 -RTTAddress $addr -RTTChannel 0 rtt.log
./segger-box gdbserver -device STM32F411CE -if SWD -speed 4000 -nogui -rtttelnetport 19021
TXT
  printf 'connect\nexec SetRTTAddr %s\nexit\n' "$addr" >"$OUT/set_rtt_addr.jlink"
}
case "$act" in
  build) build; cat "$OUT/rtt_commands.txt" ;;
  run) build; cat "$OUT/rtt_commands.txt" "$OUT/set_rtt_addr.jlink" ;;
  test)
    build
    elf="$OUT/fixed/build/$B/fixed.elf"
    read -r sec size < <(arm-none-eabi-readelf -S -W "$elf" | awk '{for (i = 1; i < NF; i++) if ($i == ".rtt") print $(i + 2), $(i + 4)}')
    [[ -n "${sec:-}" ]] || fail "no .rtt section"
    (( addr >= 0x$sec && addr + 168 <= 0x$sec + 0x$size )) || fail "_SEGGER_RTT $addr is not inside .rtt (0x$sec, 0x$size bytes)"
    grep -q '^ *\.rtt' "$OUT/fixed/build/$B/fixed.map" || fail ".rtt missing in the map file"
    (( addr >= 0x20000000 && addr < 0x20020000 )) || fail "$addr outside the F411 RAM"
    info=$($SIM info "$elf") || fail "cmsim info"
    grep -q "_SEGGER_RTT    $addr" <<<"$info" || fail "cmsim found another address: $info"
    $CHK commander "$OUT/set_rtt_addr.jlink" >/dev/null || fail "commander script"
    echo "PASS rtt_fixed_address (_SEGGER_RTT at $addr; commands checked, not run)" ;;
  *) echo "usage: example.sh build|run|test" >&2; exit 2 ;;
esac
