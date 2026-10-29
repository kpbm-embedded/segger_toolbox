#!/usr/bin/env python3
"""@NAME@: RTT client for CI. Reads RTT channel 0 from the telnet port that JLinkGDBServer (and
JLinkRTTClient's server side, J-Link Commander, Ozone) open on 19021, timestamps each line into a log
and exits 0 as soon as a line matches --expect, 1 on --fail match, timeout or closed connection.

  python3 @NAME@.py --expect 'PASS' --fail 'FAIL|HardFault' --timeout 30 --log rtt.log
  python3 @NAME@.py --selftest          # built-in fake server, no probe needed
Standard library only.
"""
import argparse
import contextlib
import re
import socket
import sys
import threading
import time


def read_rtt(host, port, expect, fail, timeout, log, send=None):
    deadline = time.monotonic() + timeout
    while True:                                    # the server may not be up yet: retry until the deadline
        try:
            sock = socket.create_connection((host, port), timeout=2)
            break
        except OSError:
            if time.monotonic() > deadline:
                print(f"@NAME@: no RTT server on {host}:{port}", file=sys.stderr)
                return 1
            time.sleep(0.2)
    if send:
        sock.sendall(send.encode())                # goes to down channel 0
    buf, t0 = b"", time.monotonic()
    with sock, (open(log, "w") if log else contextlib.nullcontext()) as lf:
        while time.monotonic() < deadline:
            sock.settimeout(max(0.1, deadline - time.monotonic()))
            try:
                chunk = sock.recv(4096)
            except socket.timeout:
                break
            if not chunk:
                break
            buf += chunk
            while b"\n" in buf:
                raw, buf = buf.split(b"\n", 1)
                line = raw.decode("utf-8", "replace").rstrip("\r")
                if line.startswith("SEGGER J-Link"):   # server banner
                    continue
                stamp = f"{time.monotonic() - t0:9.3f}"
                print(f"[{stamp}] {line}", flush=True)
                if lf:
                    lf.write(f"{stamp} {line}\n")
                if fail and re.search(fail, line):
                    print(f"@NAME@: FAIL pattern matched: {line}", file=sys.stderr)
                    return 1
                if expect and re.search(expect, line):
                    return 0
    print(f"@NAME@: {'timeout' if time.monotonic() >= deadline else 'connection closed'} before {expect!r}",
          file=sys.stderr)
    return 1 if expect else 0


def selftest():
    srv = socket.create_server(("127.0.0.1", 0))
    port = srv.getsockname()[1]

    def serve():
        c, _ = srv.accept()
        c.sendall(b"SEGGER J-Link V9.88 - Real time terminal output\r\n")
        for msg in (b"boot\r\n", b"self test 1/2 ok\r\n", b"self te", b"st 2/2 ok\r\nPASS\r\n"):
            c.sendall(msg)
            time.sleep(0.05)
        c.close()

    threading.Thread(target=serve, daemon=True).start()
    rc = read_rtt("127.0.0.1", port, "^PASS$", "FAIL", 5, None)
    print(f"@NAME@ selftest: {'PASS' if rc == 0 else 'FAIL'}")
    return rc


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--port", type=int, default=19021)
    p.add_argument("--expect", default="", help="regex: success when a line matches")
    p.add_argument("--fail", default="", help="regex: failure when a line matches")
    p.add_argument("--timeout", type=float, default=30)
    p.add_argument("--log", default="")
    p.add_argument("--send", default="", help="text for down channel 0 after connecting")
    p.add_argument("--selftest", action="store_true")
    a = p.parse_args()
    if a.selftest:
        return selftest()
    return read_rtt(a.host, a.port, a.expect, a.fail, a.timeout, a.log, a.send)


if __name__ == "__main__":
    sys.exit(main())
