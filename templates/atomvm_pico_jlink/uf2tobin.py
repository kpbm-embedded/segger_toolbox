"""@NAME@: UF2 -> raw binary + load address (for J-Link `loadbin`). Checks magics, family and gaps.
  uf2tobin.py IN.uf2 OUT.bin      prints the base address (hex) on stdout"""
import struct
import sys

RP2040_FAMILY = 0xE48BFF56
blocks = []
data = open(sys.argv[1], "rb").read()
for off in range(0, len(data), 512):
    b = data[off:off + 512]
    m0, m1, flags, addr, size, _, _, family = struct.unpack("<8I", b[:32])
    if (m0, m1, struct.unpack("<I", b[508:512])[0]) != (0x0A324655, 0x9E5D5157, 0x0AB16F30):
        sys.exit(f"bad UF2 block at offset {off}")
    if flags & 1:                      # "not main flash": skip
        continue
    if flags & 0x2000 and family != RP2040_FAMILY:
        sys.exit(f"family 0x{family:08x} is not RP2040")
    blocks.append((addr, b[32:32 + size]))
blocks.sort()
base, out = blocks[0][0], bytearray()
for addr, payload in blocks:
    if addr != base + len(out):
        if addr < base + len(out):
            sys.exit(f"overlapping block at 0x{addr:08x}")
        out += b"\xff" * (addr - base - len(out))   # gap: erased flash
    out += payload
open(sys.argv[2], "wb").write(out)
print(f"0x{base:08x}")
