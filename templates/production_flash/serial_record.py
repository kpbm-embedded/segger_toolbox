"""@NAME@: 16-byte serial-number record: magic 'SN01', u32 serial, u32 unix time, u32 CRC-32 of the first 12 bytes.
  serial_record.py write SERIAL OUT.bin | read IN.bin [SERIAL] | fits FW.bin FW_BASE SN_BASE"""
import os
import struct
import sys
import time
import zlib


def write(serial, out):
    body = struct.pack("<4sII", b"SN01", int(serial), int(os.environ.get("SOURCE_DATE_EPOCH", time.time())))
    open(out, "wb").write(body + struct.pack("<I", zlib.crc32(body)))


def read(path, want=None):
    data = open(path, "rb").read()
    assert len(data) == 16, f"{path}: {len(data)} bytes, want 16"
    magic, serial, stamp, crc = struct.unpack("<4sIII", data)
    assert magic == b"SN01" and crc == zlib.crc32(data[:12]), f"{path}: bad magic or CRC"
    assert want is None or serial == int(want), f"{path}: serial {serial} != {want}"
    print(f"ok serial record {serial} (CRC 0x{crc:08x})")


def fits(fw, fw_base, sn_base):
    end = int(fw_base, 0) + os.path.getsize(fw)
    assert end <= int(sn_base, 0), f"firmware ends at 0x{end:08x}, inside the serial sector {sn_base}"
    print(f"ok firmware 0x{int(fw_base, 0):08x}-0x{end:08x} below the serial sector {sn_base}")


if __name__ == "__main__":
    cmd, *args = sys.argv[1:]
    {"write": write, "read": read, "fits": fits}[cmd](*args)
