#!/usr/bin/env bash
# @NAME@: run @NAME@.gdb with the pinned arm-none-eabi-gdb against cmsim's GDB server (no probe):
# the same remote protocol and `monitor` commands JLinkGDBServer answers. Usage: ./check.sh fw.elf
set -euo pipefail
fw=${1:?usage: ./check.sh firmware.elf}
here=$(cd "$(dirname "$0")" && pwd)
cmsim=${CMSIM:-"python3 ${SEGGER_BOX_ROOT:?run inside segger-box shell}/lib/cmsim.py"}
out=${OUT:-$here/build}
mkdir -p "$out"
port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
sed "s/localhost:2331/localhost:$port/" "$here/@NAME@.gdb" >"$out/@NAME@.sim.gdb"
$cmsim gdbserver "$fw" --port "$port" --rtt-port 0 >"$out/server.log" 2>&1 &
srv=$!
for _ in $(seq 50); do grep -q listening "$out/server.log" 2>/dev/null && break; sleep 0.1; done
rc=0
timeout 120 arm-none-eabi-gdb -nx -batch -x "$out/@NAME@.sim.gdb" "$fw" >"$out/gdb.log" 2>&1 || rc=$?
wait "$srv" || true
cat "$out/gdb.log"
[[ "$rc" = 0 ]] || { echo "FAIL @NAME@: gdb exit $rc"; exit 1; }
# C: "Breakpoint 1, main ()"; Zig: "Breakpoint 1, main.main ()"; the pc lies in main after its prologue
grep -Eq 'Breakpoint 1, (\S+\.)?main \(' "$out/gdb.log" || { echo "FAIL @NAME@: breakpoint at main not hit"; exit 1; }
grep -Eq '^main( \+ [0-9]+)? in section \.text' "$out/gdb.log" || { echo "FAIL @NAME@: pc not in main"; exit 1; }
grep -q 'Resetting target' "$out/gdb.log" || { echo "FAIL @NAME@: monitor reset"; exit 1; }
if grep -q 'MIS-MATCHED' "$out/gdb.log"; then echo "FAIL @NAME@: compare-sections"; exit 1; fi
echo "PASS @NAME@: load, compare-sections, break main, monitor commands (cmsim GDB server)"
