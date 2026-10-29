#!/usr/bin/env bash
# about: CI-style RTT check: cmsim plays JLinkGDBServer (GDB port + RTT telnet port), GDB loads and runs, templates/rtt_telnet_client waits for the done line (no probe)
# Usage (through ./segger-box examples ...): example.sh build | run | test
set -euo pipefail
act=${1:-run}
OUT=${EX_OUT:?run through ./segger-box examples}
L="${BOXT_ROOT:?}/segger-box"
SIM="python3 $BOXT_ROOT/lib/cmsim.py"
fail() { echo "FAIL $*"; exit 1; }
build() {
  "$L" new rtt_firmware cifw --dir "$OUT" --force >/dev/null
  make -s -C "$OUT/cifw" BOARD=nicenano_nrf52840 all >/dev/null
  "$L" new rtt_telnet_client rttci --dir "$OUT" --force >/dev/null
}
free_port() { python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])'; }
case "$act" in
  build) build ;;
  run|test)
    build
    elf="$OUT/cifw/build/nicenano_nrf52840/cifw.elf"
    gport=$(free_port); rport=$(free_port)
    $SIM gdbserver "$elf" --port "$gport" --rtt-port "$rport" >"$OUT/server.log" 2>&1 &
    srv=$!
    for _ in $(seq 50); do grep -q listening "$OUT/server.log" 2>/dev/null && break; sleep 0.1; done
    python3 "$OUT/rttci/rttci.py" --port "$rport" --expect 'cifw: done' --fail 'HardFault' --timeout 60 \
      --log "$OUT/rtt.log" >"$OUT/client.out" 2>&1 &
    cli=$!
    sleep 0.5
    timeout 120 arm-none-eabi-gdb -nx -batch -ex "target remote localhost:$gport" -ex 'monitor reset' -ex load \
      -ex continue -ex detach "$elf" >"$OUT/gdb.log" 2>&1 || { cat "$OUT/gdb.log"; fail "gdb"; }
    rc=0; wait "$cli" || rc=$?
    wait "$srv" || true
    [[ "$act" = run ]] && cat "$OUT/client.out"
    [[ "$rc" = 0 ]] || { cat "$OUT/client.out"; fail "RTT client exit $rc"; }
    grep -q 'cifw: tick 3' "$OUT/rtt.log" || fail "rtt.log incomplete"
    echo "PASS rtt_telnet_sim (RTT over the telnet port while GDB runs the target; simulated)" ;;
  *) echo "usage: example.sh build|run|test" >&2; exit 2 ;;
esac
