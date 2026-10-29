"""@NAME@: flash layout checks on the built images (no probe): ranges, vector tables, merged image."""
import struct
import sys
from pathlib import Path

from elftools.elf.elffile import ELFFile

BOOT, APP, FLASH_END = 0x08000000, 0x08008000, 0x08080000
build = Path(sys.argv[1])


def flash_range(path):
    with open(path, "rb") as f:
        elf = ELFFile(f)
        segs = [(s["p_paddr"], s["p_paddr"] + s["p_filesz"]) for s in elf.iter_segments()
                if s["p_type"] == "PT_LOAD" and s["p_filesz"] and s["p_paddr"] >= BOOT]
        vt = elf.get_section_by_name(".isr_vector")["sh_addr"]
    return min(a for a, _ in segs), max(b for _, b in segs), vt


b_lo, b_hi, b_vt = flash_range(build / "boot.elf")
a_lo, a_hi, a_vt = flash_range(build / "app.elf")
assert (b_lo, b_vt) == (BOOT, BOOT), f"bootloader must start at 0x{BOOT:08x}"
assert b_hi <= APP, f"bootloader ends at 0x{b_hi:08x}, overlaps the app at 0x{APP:08x}"
assert (a_lo, a_vt) == (APP, APP), f"app vector table must be at 0x{APP:08x} (VTOR), is 0x{a_vt:08x}"
assert a_hi <= FLASH_END, "app does not fit the 512 KB flash"
merged = (build / "@NAME@_merged.bin").read_bytes()
assert len(merged) == a_hi - BOOT, f"merged image size {len(merged)} != {a_hi - BOOT}"
assert set(merged[b_hi - BOOT:APP - BOOT]) <= {0xFF}, "gap between bootloader and app not erased-flash 0xFF"
sp, entry = struct.unpack("<II", merged[APP - BOOT:APP - BOOT + 8])
assert 0x20000000 <= sp <= 0x20020000 and entry & 1, "app vector table in the merged image looks wrong"
script = (build / "flash_@NAME@.jlink").read_text().split("\n")
assert "loadbin " + str(build / "@NAME@_merged.bin") + " 0x08000000" in script and script[-2] == "exit"
print(f"PASS @NAME@ layout: boot 0x{b_lo:08x}-0x{b_hi:08x}, app 0x{a_lo:08x}-0x{a_hi:08x}, merged {len(merged)} bytes")
