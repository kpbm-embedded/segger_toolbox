#!/usr/bin/env bash
# @NAME@: build with 32_17_embedded_rust's pinned toolchain (reached, not copied), run the ELF in cmsim,
# decode the RTT bytes with defmt-print (32_17), and check the J-Link side (RTT address, Commander script).
# Usage: segger-box run @NAME@/check.sh      exit 3 = 32_17_embedded_rust not found (skip)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
rust=${SEGGER_RUST_ID:-}
[[ -x "$rust/rust-box" ]] || { echo "skip: 32_17_embedded_rust not found (set BOX_EMBEDDED_RUST)"; exit 3; }
out=${OUT:-$here/build}
mkdir -p "$out"
(cd "$here" && RUST_BOX_TARGET_DIR="$out/target" "$rust/rust-box" cargo build --release --offline --quiet)
elf="$out/target/thumbv7em-none-eabihf/release/@NAME@"
python3 "${SEGGER_BOX_ROOT:?run inside segger-box shell}/lib/cmsim.py" run "$elf" --raw-out "$out/rtt0.bin" >/dev/null
"$rust/rust-box" defmt-print -e "$elf" <"$out/rtt0.bin" >"$out/log.txt" 2>&1 || true
cat "$out/log.txt"
for want in '@NAME@ start' 'reading Reading { channel: 2, millivolts: 1400 }' 'sum = 3900 mV' '@NAME@ done'; do
  grep -qF "$want" "$out/log.txt" || { echo "FAIL @NAME@: '$want' not decoded"; exit 1; }
done
if grep -q 'compiled out' "$out/log.txt"; then echo "FAIL @NAME@: trace! not filtered"; exit 1; fi
addr=0x$("$rust/rust-box" run llvm-nm "$elf" | awk '$3=="_SEGGER_RTT" {print $1}')
printf 'r\nh\nloadfile %s\nr\ng\nexit\n' "$elf" >"$out/flash.jlink"
python3 "$SEGGER_BOX_ROOT/lib/jlink_check.py" commander "$out/flash.jlink" --files-exist >/dev/null
echo "J-Link: segger-box jlink -device STM32F411CE -if SWD -speed 4000 -autoconnect 1 -CommanderScript $out/flash.jlink"
echo "        segger-box rtt-logger -Device STM32F411CE -If SWD -Speed 4000 -RTTAddress $addr -RTTChannel 0 rtt.bin"
echo "        then: defmt-print -e $elf < rtt.bin"
echo "PASS @NAME@ (defmt over RTT decoded from cmsim; _SEGGER_RTT at $addr)"
