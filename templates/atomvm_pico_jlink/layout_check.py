"""@NAME@: the three images do not overlap, the VM expects lib/app where they are loaded, the app is a packbeam."""
import struct
import sys

vm, lib, app = (open(p, "rb").read() for p in sys.argv[1:4])
lib_addr, app_addr = (int(x, 0) for x in sys.argv[4:6])
base = 0x10000000
assert base + len(vm) <= lib_addr, f"VM ends at 0x{base + len(vm):08x}, inside lib.avm at 0x{lib_addr:08x}"
assert lib_addr + len(lib) <= app_addr, f"lib.avm ends at 0x{lib_addr + len(lib):08x}, inside main.avm"
assert app_addr + len(app) <= 0x10200000, "main.avm larger than its 512 KB slot"
for addr in (lib_addr, app_addr):
    assert struct.pack("<I", addr) in vm, f"0x{addr:08x} not referenced by the VM image (other AtomVM layout?)"
assert app[:8] == b"#!/usr/b", "app is not a packbeam .avm"
print(f"ok layout: VM {len(vm)} B, lib {len(lib)} B @0x{lib_addr:08x}, app {len(app)} B @0x{app_addr:08x}")
